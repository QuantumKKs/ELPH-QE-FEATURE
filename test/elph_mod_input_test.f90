!
! Test-adapted version of elph_mod_input.f90
! Replaces generic mp_bcast calls with stub-compatible individual calls.
!
MODULE elph_manager_input
  USE kinds, ONLY : DP
  IMPLICIT NONE
  SAVE

  CHARACTER(LEN=256) :: pw_input_file    = 'scf.in'
  CHARACTER(LEN=256) :: ph_input_file    = 'ph.in'
  CHARACTER(LEN=256) :: pw_output_file   = 'scf.out'
  CHARACTER(LEN=256) :: ph_output_file   = 'ph.out'
  CHARACTER(LEN=256) :: elph_output_file = 'elph.out'
  CHARACTER(LEN=256) :: pw_command  = 'pw.x'
  CHARACTER(LEN=256) :: ph_command  = 'ph.x'
  CHARACTER(LEN=256) :: mpi_prefix  = ''
  CHARACTER(LEN=256) :: prefix = 'pwscf'
  CHARACTER(LEN=256) :: outdir = './'
  CHARACTER(LEN=256) :: electron_phonon = 'lambda_tetra'
  INTEGER  :: nk1 = 0, nk2 = 0, nk3 = 0
  INTEGER  :: k1  = 0, k2  = 0, k3  = 0
  INTEGER  :: el_ph_nsigma = 10
  REAL(DP) :: el_ph_sigma  = 0.02_DP
  LOGICAL  :: force_rerun_scf   = .FALSE.
  LOGICAL  :: force_rerun_ph    = .FALSE.
  LOGICAL  :: force_rerun_elph  = .FALSE.
  LOGICAL  :: verbose = .TRUE.

CONTAINS

  SUBROUTINE elph_manager_readin()
    USE io_global, ONLY : ionode, ionode_id, stdout
    USE mp,        ONLY : mp_bcast_char, mp_bcast_int, &
                          mp_bcast_real, mp_bcast_logical
    USE mp_world,  ONLY : world_comm
    IMPLICIT NONE
    INTEGER :: ios

    NAMELIST / ELPH_MANAGER / &
         pw_input_file, ph_input_file,           &
         pw_output_file, ph_output_file,          &
         elph_output_file,                        &
         pw_command, ph_command, mpi_prefix,      &
         prefix, outdir,                          &
         electron_phonon,                         &
         nk1, nk2, nk3, k1, k2, k3,              &
         el_ph_nsigma, el_ph_sigma,               &
         force_rerun_scf, force_rerun_ph,         &
         force_rerun_elph, verbose

    IF (ionode) THEN
       READ(5, ELPH_MANAGER, IOSTAT=ios)
       IF (ios /= 0) CALL errore('elph_manager_readin', &
            'Error reading &ELPH_MANAGER namelist', ABS(ios))
    END IF

    ! Broadcast (no-ops in serial test)
    CALL mp_bcast_char(pw_input_file,    ionode_id, world_comm)
    CALL mp_bcast_char(ph_input_file,    ionode_id, world_comm)
    CALL mp_bcast_char(pw_output_file,   ionode_id, world_comm)
    CALL mp_bcast_char(ph_output_file,   ionode_id, world_comm)
    CALL mp_bcast_char(elph_output_file, ionode_id, world_comm)
    CALL mp_bcast_char(pw_command,       ionode_id, world_comm)
    CALL mp_bcast_char(ph_command,       ionode_id, world_comm)
    CALL mp_bcast_char(mpi_prefix,       ionode_id, world_comm)
    CALL mp_bcast_char(prefix,           ionode_id, world_comm)
    CALL mp_bcast_char(outdir,           ionode_id, world_comm)
    CALL mp_bcast_char(electron_phonon,  ionode_id, world_comm)
    CALL mp_bcast_int(nk1,               ionode_id, world_comm)
    CALL mp_bcast_int(nk2,               ionode_id, world_comm)
    CALL mp_bcast_int(nk3,               ionode_id, world_comm)
    CALL mp_bcast_int(k1,                ionode_id, world_comm)
    CALL mp_bcast_int(k2,                ionode_id, world_comm)
    CALL mp_bcast_int(k3,                ionode_id, world_comm)
    CALL mp_bcast_int(el_ph_nsigma,      ionode_id, world_comm)
    CALL mp_bcast_real(el_ph_sigma,      ionode_id, world_comm)
    CALL mp_bcast_logical(force_rerun_scf,  ionode_id, world_comm)
    CALL mp_bcast_logical(force_rerun_ph,   ionode_id, world_comm)
    CALL mp_bcast_logical(force_rerun_elph, ionode_id, world_comm)
    CALL mp_bcast_logical(verbose,          ionode_id, world_comm)

    IF (ionode .AND. verbose) THEN
       WRITE(stdout,'(/,5X,A)') REPEAT('-',50)
       WRITE(stdout,'(5X,A)')   '  ELPH_MANAGER input summary'
       WRITE(stdout,'(5X,A)')   REPEAT('-',50)
       WRITE(stdout,'(5X,A,A)') 'prefix            = ', TRIM(prefix)
       WRITE(stdout,'(5X,A,A)') 'outdir            = ', TRIM(outdir)
       WRITE(stdout,'(5X,A,A)') 'pw_input_file     = ', TRIM(pw_input_file)
       WRITE(stdout,'(5X,A,A)') 'ph_input_file     = ', TRIM(ph_input_file)
       WRITE(stdout,'(5X,A,A)') 'electron_phonon   = ', TRIM(electron_phonon)
       IF (nk1 > 0) THEN
          WRITE(stdout,'(5X,A,3I4)') 'elph k-grid       = ', nk1, nk2, nk3
       ELSE
          WRITE(stdout,'(5X,A)') 'elph k-grid       = (from ph_input_file)'
       END IF
       WRITE(stdout,'(5X,A,L1)') 'force_rerun_scf   = ', force_rerun_scf
       WRITE(stdout,'(5X,A,L1)') 'force_rerun_ph    = ', force_rerun_ph
       WRITE(stdout,'(5X,A,L1)') 'force_rerun_elph  = ', force_rerun_elph
       WRITE(stdout,'(5X,A)')    REPEAT('-',50)
    END IF

  END SUBROUTINE elph_manager_readin

END MODULE elph_manager_input
