!
! Authors: Sanjay Gopal Ramchandani, Fabian Jofré Parra
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!=======================================================================
MODULE elph_manager_input
!=======================================================================
  !
  ! Input parameters and reader for elph_manager.x
  !
  ! The namelist &ELPH_MANAGER controls the workflow:
  !   - Paths to pw.x and ph.x input files
  !   - Electron-phonon parameters for phase 2
  !   - Force-rerun flags for each phase
  !
  ! pw.x and ph.x are called as 'pw.x' / 'ph.x' from PATH.
  ! Run elph_manager.x with mpirun if needed:
  !   mpirun -np N elph_manager.x < input.in
  !
  USE kinds, ONLY : DP
  !
  IMPLICIT NONE
  SAVE
  !
  ! --- Input/output file names ---
  CHARACTER(LEN=256) :: pw_input_file    = 'scf.in'
  CHARACTER(LEN=256) :: ph_input_file    = 'ph.in'
  CHARACTER(LEN=256) :: pw_output_file   = 'scf.out'
  CHARACTER(LEN=256) :: ph_output_file   = 'ph.out'
  CHARACTER(LEN=256) :: elph_output_file = 'elph.out'
  !
  ! --- Prefix and outdir (must match pw.x and ph.x inputs) ---
  CHARACTER(LEN=256) :: prefix = 'pwscf'
  CHARACTER(LEN=256) :: outdir = './'
  !
  ! --- Electron-phonon parameters (phase 2 of ph.x) ---
  !
  ! electron_phonon: mode for coupling calculation
  !   'simple'        - Gaussian smearing on given k-grid
  !   'interpolated'  - BZ interpolation (Wierzbowska et al.)
  !   'lambda_tetra'  - Tetrahedron method for lambda_qv
  !   'gamma_tetra'   - Tetrahedron method for gamma_qv (linewidth)
  !   'epa'           - Electron-phonon averaged approximation
  !   'ahc'           - Anomalous Hall conductivity
  !   'wannier'       - Wannier interpolation (EPW-like)
  CHARACTER(LEN=256) :: electron_phonon = 'lambda_tetra'
  !
  ! Gaussian smearing parameters (for 'simple' and 'interpolated')
  INTEGER  :: el_ph_nsigma = 10
  REAL(DP) :: el_ph_sigma  = 0.02_DP
  !
  ! --- Workflow control flags ---
  LOGICAL :: force_rerun_scf   = .FALSE.
  ! If .TRUE., run pw.x even if prefix.save/ already exists
  !
  LOGICAL :: force_rerun_ph    = .FALSE.
  ! If .TRUE., run ph.x phase 1 even if dvscf files already exist
  !
  LOGICAL :: force_rerun_elph  = .FALSE.
  ! If .TRUE., run ph.x phase 2 even if lambda files already exist
  !
  LOGICAL :: verbose = .TRUE.
  ! If .TRUE., print detailed status messages
  !
  LOGICAL :: ph_split_qpoints = .FALSE.
  ! If .TRUE., run each irreducible q-point as a separate ph.x call.
  ! Requires nq_irr to be set. Useful when resources are limited.
  !
  INTEGER :: nq_irr = 0
  ! Number of irreducible q-points in the phonon grid.
  ! Required when ph_split_qpoints = .TRUE.
  ! For a 2x2x2 grid of FCC Al, nq_irr = 3.
  ! Run ph.x once manually or check QE output to find this number.
  !
  ! --- Optional validation phases ---
  LOGICAL :: compute_matdyn = .FALSE.
  ! If .TRUE., run matdyn.x after phonons to compute phonon dispersion.
  ! Requires matdyn_qpath_file to be set.

  CHARACTER(LEN=256) :: matdyn_qpath_file  = ''
  ! File containing the q-path for matdyn.x phonon dispersion.
  ! Format: same as QE K_POINTS crystal_b card.
  ! Example for FCC Al:
  !   5
  !   0.000 0.000 0.000  30  ! Gamma
  !   0.500 0.000 0.500  30  ! X
  !   0.500 0.250 0.750  10  ! W
  !   0.375 0.375 0.750  30  ! K
  !   0.000 0.000 0.000  30  ! Gamma
  !   0.500 0.500 0.500   1  ! L

  CHARACTER(LEN=256) :: matdyn_output_file = 'matdyn.out'

  LOGICAL :: compute_bands = .FALSE.
  ! If .TRUE., run pw.x (bands) + bands.x after SCF.
  ! Requires bands_kpath_file to be set.

  CHARACTER(LEN=256) :: bands_kpath_file  = ''
  ! File containing the k-path for pw.x bands calculation.
  ! Format: K_POINTS crystal_b card content only (no header).
  ! Example for FCC Al (Gamma-X-W-K-Gamma-L):
  !   6
  !   0.000 0.000 0.000  30
  !   0.500 0.000 0.500  30
  !   0.500 0.250 0.750  10
  !   0.375 0.375 0.750  30
  !   0.000 0.000 0.000  40
  !   0.500 0.500 0.500   1

  CHARACTER(LEN=256) :: bands_output_file   = 'bands.out'
  CHARACTER(LEN=256) :: bandspp_output_file = 'bandspp.out'
  !
CONTAINS
  !
  !---------------------------------------------------------------------
  SUBROUTINE elph_manager_readin()
  !---------------------------------------------------------------------
    !
    ! Read the &ELPH_MANAGER namelist from stdin and broadcast
    ! all variables to all MPI tasks.
    !
    USE io_global, ONLY : ionode, ionode_id, stdout
    USE mp,        ONLY : mp_bcast
    USE mp_world,  ONLY : world_comm
    !
    IMPLICIT NONE
    !
    INTEGER :: ios
    !
    NAMELIST / ELPH_MANAGER / &
         pw_input_file, ph_input_file,           &
         pw_output_file, ph_output_file,          &
         elph_output_file,                        &
         prefix, outdir,                          &
         electron_phonon,                         &
         el_ph_nsigma, el_ph_sigma,               &
         force_rerun_scf, force_rerun_ph,         &
         force_rerun_elph, verbose,               &
         ph_split_qpoints, nq_irr,               &
         compute_matdyn, matdyn_qpath_file,      &
         matdyn_output_file,                     &
         compute_bands, bands_kpath_file,        &
         bands_output_file, bandspp_output_file
    !
    IF (ionode) THEN
       !
       READ(5, ELPH_MANAGER, IOSTAT=ios)
       IF (ios /= 0) CALL errore('elph_manager_readin', &
            'Error reading &ELPH_MANAGER namelist', ABS(ios))
       !
    END IF
    !
    ! --- Broadcast all input variables ---
    CALL mp_bcast(pw_input_file,    ionode_id, world_comm)
    CALL mp_bcast(ph_input_file,    ionode_id, world_comm)
    CALL mp_bcast(pw_output_file,   ionode_id, world_comm)
    CALL mp_bcast(ph_output_file,   ionode_id, world_comm)
    CALL mp_bcast(elph_output_file, ionode_id, world_comm)
    CALL mp_bcast(prefix,           ionode_id, world_comm)
    CALL mp_bcast(outdir,           ionode_id, world_comm)
    CALL mp_bcast(electron_phonon,  ionode_id, world_comm)
    CALL mp_bcast(el_ph_nsigma,     ionode_id, world_comm)
    CALL mp_bcast(el_ph_sigma,      ionode_id, world_comm)
    CALL mp_bcast(force_rerun_scf,  ionode_id, world_comm)
    CALL mp_bcast(force_rerun_ph,   ionode_id, world_comm)
    CALL mp_bcast(force_rerun_elph, ionode_id, world_comm)
    CALL mp_bcast(verbose,          ionode_id, world_comm)
    CALL mp_bcast(ph_split_qpoints,    ionode_id, world_comm)
    CALL mp_bcast(nq_irr,              ionode_id, world_comm)
    CALL mp_bcast(compute_matdyn,      ionode_id, world_comm)
    CALL mp_bcast(matdyn_qpath_file,   ionode_id, world_comm)
    CALL mp_bcast(matdyn_output_file,  ionode_id, world_comm)
    CALL mp_bcast(compute_bands,       ionode_id, world_comm)
    CALL mp_bcast(bands_kpath_file,    ionode_id, world_comm)
    CALL mp_bcast(bands_output_file,   ionode_id, world_comm)
    CALL mp_bcast(bandspp_output_file, ionode_id, world_comm)
    !
    IF (ionode .AND. verbose) THEN
       WRITE(stdout,'(/,5X,A)') REPEAT('-',50)
       WRITE(stdout,'(5X,A)')   '  ELPH_MANAGER input summary'
       WRITE(stdout,'(5X,A)')   REPEAT('-',50)
       WRITE(stdout,'(5X,A,A)') 'prefix            = ', TRIM(prefix)
       WRITE(stdout,'(5X,A,A)') 'outdir            = ', TRIM(outdir)
       WRITE(stdout,'(5X,A,A)') 'pw_input_file     = ', TRIM(pw_input_file)
       WRITE(stdout,'(5X,A,A)') 'ph_input_file     = ', TRIM(ph_input_file)
       WRITE(stdout,'(5X,A,A)') 'electron_phonon   = ', TRIM(electron_phonon)
       WRITE(stdout,'(5X,A)') 'k-grid            = (read from ph_input_file)'
       WRITE(stdout,'(5X,A,L1)') 'force_rerun_scf   = ', force_rerun_scf
       WRITE(stdout,'(5X,A,L1)') 'force_rerun_ph    = ', force_rerun_ph
       WRITE(stdout,'(5X,A,L1)') 'force_rerun_elph  = ', force_rerun_elph
       WRITE(stdout,'(5X,A,L1)') 'ph_split_qpoints  = ', ph_split_qpoints
       IF (ph_split_qpoints) &
          WRITE(stdout,'(5X,A,I4)') 'nq_irr            = ', nq_irr
       WRITE(stdout,'(5X,A,L1)') 'compute_matdyn    = ', compute_matdyn
       IF (compute_matdyn) &
          WRITE(stdout,'(5X,A,A)') 'matdyn_qpath_file = ', TRIM(matdyn_qpath_file)
       WRITE(stdout,'(5X,A,L1)') 'compute_bands     = ', compute_bands
       IF (compute_bands) &
          WRITE(stdout,'(5X,A,A)') 'bands_kpath_file  = ', TRIM(bands_kpath_file)
       WRITE(stdout,'(5X,A)')    REPEAT('-',50)
    END IF
    !
  END SUBROUTINE elph_manager_readin
  !
END MODULE elph_manager_input
