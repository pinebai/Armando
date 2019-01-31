      program SPH

c----------------------------------------------------------------------
c     This is a three dimensional SPH code. the followings are the 
c     basic parameters needed in this codeor calculated by this code

c     mass-- mass of particles                                      [in]
c     np-- total particle number used                               [in]
c     dt--- Time step used in the time integration                  [in]
c     itype-- types of particles                                    [in]
c     x-- coordinates of particles                              [in/out]
c     v-- velocities of particles                               [in/out]
c     rho-- dnesities of particles                              [in/out]
c     p-- pressure  of particles                                [in/out]
c     u-- internal energy of particles                          [in/out]
c     h-- smoothing lengths of particles                        [in/out]
c     c-- sound velocity of particles                              [out]
c     s-- entropy of particles                                     [out]
c     e-- total energy of particles                                [out]
c	
c     sffluka-- size scale factor (size_sph = sf*size_fluka)       [in]
c     effluka-- energy scale factor (energy_sph = ef*energy_fluka) [in]
c     npfluka-- number of particles                                [in]
c     dtfluka-- deposition time                                    [in]
c     ofluka-- the origin of the binning                           [in]
c     dfluka-- cell side of the binning                            [in]
c     nfluka-- number of cells for each index                      [in]
c     tfluka-- identifier for the fluka grid type                  [in]
c     datafluka-- data of the binning                              [in]
c	

      implicit none     
      include 'options.inc'

c     SPH algorithm for particle approximation (pa_sph)
c     pa_sph = 0 : (e.g. (p(i)+p(j))/(rho(i)*rho(j))
c              1 : (e.g. (p(i)/rho(i)**2+p(j)/rho(j)**2)
c
c     Nearest neighbor particle searching (nnps) method
c     nnps = 0 : Simplest and direct searching
c            1 : Sorting grid linked list
c            2 : Tree algorithm
c	
c     Smoothing length evolution (sle) algorithm
c     sle = 0 : Keep unchanged,
c           1 : h = fac * (m/rho)^(1/dim)
c           2 : dh/dt = (-1/dim)*(h/rho)*(drho/dt)
c           3 : Other approaches (e.g. h = h_0 * (rho_0/rho)**(1/dim) )
c	
c     Smoothing kernel function
c     skf = 0, cubic spline kernel by W4 - Spline (Monaghan 1985)
c         = 1, Gauss kernel   (Gingold and Monaghan 1981)
c         = 2, Quintic kernel (Morris 1997)
c	
c     Density calculation method
c     density_method = 0, continuity equation
c			       = 1, summation density
c                    = 2, normalized summation density
	
	character (len = 120) :: filedir
      integer pa_sph, nnps, sle, skf, density_method
	

c     Switches for different senarios
	
c     average_velocity = .TRUE. : Monaghan treatment on average velocity,
c                        .FALSE.: No average treatment.
c     virtual_part = .TRUE. : Use virtual particle,
c                    .FALSE.: No use of virtual particle.
c     visc = .true. : Consider viscosity,
c            .false.: No viscosity.
c     visc_artificial = .true. : Consider artificial viscosity,
c                       .false.: No considering of artificial viscosity.
c     heat_artificial = .true. : Consider artificial heating,
c                       .false.: No considering of artificial heating.
c     heat_external = .true. : Consider external heating,
c                     .false.: No considering of external heating.
c     self_gravity = .true. : Considering self_gravity,
c                    .false.: No considering of self_gravity
      logical average_velocity, virtual_part, visc, 
     &	heat_artificial, heat_external, visc_artificial, self_gravity
	
c     Simulation cases
c     shocktube = .true. : carry out shock tube simulation
c     shearcavity = .true. : carry out shear cavity simulation
      logical shocktube, shearcavity
	
	integer np, nv, steps, refresh_step, save_step, d, m, i
      double precision prop(16, 40), dt
	double precision trfluka(3), sffluka, effluka, npfluka, dtfluka,
     &                 ofluka(3), dfluka(3)
	integer nfluka(3), tfluka

	integer, dimension(:), allocatable :: mat
      double precision, dimension(:,:), allocatable :: x, v 
      double precision, dimension(:), allocatable :: h, mass, rho, p, 
     & 	                                           u, c, s, e 
	
	double precision, dimension(:), allocatable :: datafluka

      double precision s1, s2
	

	allocate(mat(maxn))
      allocate(x(dim, maxn), v(dim, maxn)) 
      allocate(h(maxn), mass(maxn), rho(maxn), p(maxn))
      allocate(u(maxn), c(maxn), s(maxn), e(maxn))
	allocate(datafluka(max_fluka))
	

	call default(filedir, pa_sph, nnps, sle, skf, density_method, 
     &	 average_velocity, virtual_part, visc, 
     &	 visc_artificial, heat_artificial, heat_external, self_gravity, 
     &	 refresh_step, save_step)
	
	shocktube = .false.
	shearcavity = .false.
	
      if (.not. (shearcavity .or. shocktube .or. debug)) then
        call read_input_file(filedir, pa_sph, nnps, sle, skf, 
     &                       density_method, average_velocity, 
     &                       virtual_part, visc,
     &                       visc_artificial, heat_artificial, 
     &                       heat_external, self_gravity,
     &                       prop, dt, steps, refresh_step, save_step, 
     &                       trfluka, sffluka, effluka, 
     &                       npfluka, dtfluka)
	endif

      if (shocktube) then
	  dt = 0.005
	  steps = 40
	  prop(1, 1) = 1.4
	  prop(2, 1) = 0.0
	  call shock_tube(np, x, v, mat, h, mass, rho, p, u)
	endif
	
      if (debug) then
c	  dt = 2 * 4.19463E-7
c	  steps = 2000 / 2
c	  prop(1,21) = 1.354000e+004
c	  prop(2,21) = 1.490000e+003
c	  prop(3,21) = 1.960000
c	  prop(4,21) = 2.047000
c	  prop(5,21) = -1.0E30
c	  prop(6,21) = 0.0d-3
c	  call partly_heated_rod(np, x, v, mat, h, mass, rho, p, u)
c
c	  pa_sph = 1
c	  nnps = 0
c	  sle = 0
c	  skf = 0
c	  density_method = 0
c
c	  average_velocity  = .true.
c	  virtual_part  = .false.
c	  visc  = .false.
c	  visc_artificial  = .true.
c	  heat_artificial  = .true.
c	  heat_external  = .false.
c	  self_gravity  = .false.
c
c	  refresh_step = 100 /2
c	  save_step = 100 /2
c
c
c	  dt = 5.0E-8
c	  steps = 1600
c	  prop(1,21) = 1.354000e+004
c	  prop(2,21) = 1.490000e+003
c	  prop(3,21) = 1.960000
c	  prop(4,21) = 2.047000
c	  prop(5,21) = -1.0E30
c	  prop(6,21) = 0.0d-3
c	  call partly_heated_disc(np, nv, x, v, mat, h, mass, rho, p, u)
c
c	  pa_sph = 0
c	  nnps = 1
c	  sle = 0
c	  skf = 0
c	  density_method = 0
c	  
c	  average_velocity  = .true.
c	  virtual_part  = .true.
c	  visc  = .false.
c	  visc_artificial  = .true.
c	  heat_artificial  = .false.
c	  heat_external  = .false.
c	  self_gravity  = .false.
c
c	  refresh_step = 100
c	  save_step = 100
c
c
c
c	  dt = 10.0d-9 !5 * 2.0E-8
c	  steps = 14 !1000 /5
c
c	  prop(1,31) = 1549.000
c	  prop(2,31) = 1.317e+010
c	  prop(3,31) = 1.537e+010
c	  prop(4,31) = 0.0
c	  prop(5,31) = 0.300000
c	  prop(6,31) = 0.250000
c	  prop(7,31) = 1.250000e+006
c	  prop(8,31) = 1.317e+010
c	  prop(9,31) = 1.537e+010
c	  prop(10,31) = -1.50000e+008
c	  prop(11,31) = 0.0d-3
c	  
c	  call fluka_heated_disc(np, nv, x, v, mat, h, mass, rho, p, u)
c
c	  pa_sph = 1
c	  nnps = 1
c	  sle = 0
c	  skf = 0
c	  density_method = 0
c	  
c	  average_velocity  = .true. 
c	  virtual_part  = .true.
c	  visc  = .false.
c	  visc_artificial  = .true.
c	  heat_artificial  = .false.
c	  heat_external  = .true.
c	  self_gravity  = .false.
c
c	  refresh_step = 1! 50 /5
c	  save_step = 50 /5
c
c	  sffluka = 1.0d-2
c	  effluka = 1.602d-10
c	  npfluka = 3.03d13
c	  dtfluka = 140d-9
c	  trfluka(3) = 15.d-2 !10d-2
c	  !trfluka(1) = 1.8d-2
c
c
c
	  dt = 10.0E-8
	  steps = 400
	  prop(1,21) = 1.354000e+004
	  prop(2,21) = 1.490000e+003
	  prop(3,21) = 1.960000
	  prop(4,21) = 2.047000
	  prop(5,21) = -1.0E30
	  prop(6,21) = 0.0d-3
	  call partly_heated_bar(np, nv, x, v, mat, h, mass, rho, p, u)

	  pa_sph = 1
	  nnps = 1
	  sle = 0
	  skf = 0
	  density_method = 0
	  
	  average_velocity  = .true.
	  virtual_part  = .true.
	  visc  = .false.
	  visc_artificial  = .false.
	  heat_artificial  = .false.
	  heat_external  = .false.
	  self_gravity  = .false.

	  refresh_step = 1
	  save_step = 50


c
c
c	  dt = 2.0E-7
c	  steps = 2000
c	  prop(1,21) = 1.354000e+004
c	  prop(2,21) = 1.490000e+003
c	  prop(3,21) = 1.960000
c	  prop(4,21) = 2.047000
c	  prop(5,21) = -1.5E5
c	  prop(6,21) = 0.0d-3
c	  call partly_heated_cylinder(np, nv, x, v, mat, h, mass, rho, p, u)
c
c	  pa_sph = 0
c	  nnps = 1
c	  sle = 0
c	  skf = 0
c	  density_method = 0
c	  
c	  average_velocity  = .false.
c	  virtual_part  = .false.
c	  visc  = .false.
c	  visc_artificial  = .true.
c	  heat_artificial  = .false.
c	  heat_external  = .false.
c	  self_gravity  = .false.
c
c	  refresh_step = 1
c	  save_step = 100
c
	endif
	
      if (shearcavity) then
	  dt = 5.0e-5
	  steps = 3000
	  prop(1,11) = 1000.0
	  prop(2,11) = 1.0d-1
	  prop(3,11) = 0.

	  prop(4,11) = 0.
	  prop(5,11) = 0.
	  prop(6,11) = 0.
	  prop(7,11) = prop(2,11)
	  prop(8,11) = 0.0
	  prop(9,11) = -1.0E30
	  prop(10,11) = 1.0d-3
	  call shear_cavity(np, nv, x, v, mat, h, mass, rho, p, u)
	  density_method = 1
	  refresh_step = 1
	  save_step = 500
	endif
	
      if (.not. (shearcavity .or. shocktube .or. debug)) then
	  call read_initial_conditions(np, x, v, mat, h, 
     &                               mass, rho, p, u, filedir)
        if (virtual_part) then
	    call read_virtual_particles(np, nv, x, v, mat, h, 
     &	                            mass, rho, p, u, filedir)
	  endif
	endif
	
	if (heat_external) then
	  call read_binning_bin(trfluka, sffluka, effluka, npfluka, 
     &                        dtfluka, ofluka, dfluka, nfluka, tfluka, 
     &                        datafluka, filedir)
	endif
	
	if (virtual_part) then
	  call smooth_particles(np, nv, x, v, h, mass, rho, 
     &                        virtual_part)
	endif
	
      call time_print
      call time_elapsed(s1)
	
      call time_integration(np, nv, x, v, mat, h, 
     &     mass, rho, p, u, c, s, e, prop, 
     &     dt, steps, refresh_step, save_step,
     &     dtfluka, ofluka, dfluka, nfluka, tfluka, datafluka, 
     &     pa_sph, nnps, sle, skf, density_method, 
     &	   average_velocity, virtual_part, visc, 
     &     visc_artificial, heat_artificial, 
     &     heat_external, self_gravity, filedir)
	
      call time_print
      call time_elapsed(s2)      
      write (*,*)'        Elapsed CPU time = ', s2-s1
      write (15,*)'        Elapsed CPU time = ', s2-s1
      
	deallocate(mat)
      deallocate(x, v) 
      deallocate(h, mass, rho, p)
      deallocate(u, c, s, e)
	deallocate(datafluka)

      end