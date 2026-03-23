!
! Test program for elph_manager logic.
! Simulates all three test scenarios without a real QE installation.
!
! Test 1: All phases pending (nothing computed yet)
! Test 2: SCF done, phonons pending  -> skip Phase 1, run 2+3
! Test 3: SCF + phonons done         -> skip 1+2, only run elph
!
PROGRAM test_elph_manager
  USE kinds,                 ONLY : DP
  USE io_global,             ONLY : stdout, ionode, ionode_id
  USE mp_global,             ONLY : mp_startup, mp_global_end
  USE environment,           ONLY : environment_start, environment_end
  USE mp_world,              ONLY : world_comm
  USE elph_manager_input,    ONLY : elph_manager_readin,              &
                                    prefix, outdir,                    &
                                    force_rerun_scf, force_rerun_ph,  &
                                    force_rerun_elph, verbose,         &
                                    pw_input_file, ph_input_file,      &
                                    electron_phonon, nk1, nk2, nk3
  USE elph_manager_status,   ONLY : check_all_status,                 &
                                    scf_done, dvscf_done, elph_done
  USE elph_manager_generate, ONLY : generate_elph_input
  USE elph_manager_run,      ONLY : run_scf, run_phonons, run_elph
  IMPLICIT NONE

  INTEGER :: ierr, npass, nfail
  CHARACTER(LEN=256) :: ph_elph_input_file

  CALL mp_startup()
  CALL environment_start('ELPH_TEST')

  npass = 0
  nfail = 0

  ! ============================================================
  WRITE(stdout,'(/,A)') '========================================'
  WRITE(stdout,'(A)')   ' TEST SUITE: elph_manager.x'
  WRITE(stdout,'(A)')   '========================================'

  ! ============================================================
  ! TEST 1: Status detection - nothing computed
  ! ============================================================
  WRITE(stdout,'(/,A)') '--- TEST 1: Status detection (nothing done) ---'
  CALL setup_empty_workspace()

  prefix  = 'Al'
  outdir  = './mock_workspace'
  verbose = .TRUE.

  scf_done   = .FALSE.
  dvscf_done = .FALSE.
  elph_done  = .FALSE.

  CALL check_all_status()

  CALL assert_false('T1: scf_done should be FALSE',   scf_done,   npass, nfail)
  CALL assert_false('T1: dvscf_done should be FALSE', dvscf_done, npass, nfail)
  CALL assert_false('T1: elph_done should be FALSE',  elph_done,  npass, nfail)

  ! ============================================================
  ! TEST 2: Status detection - SCF done only
  ! ============================================================
  WRITE(stdout,'(/,A)') '--- TEST 2: Status detection (SCF done) ---'
  CALL setup_scf_done()

  scf_done   = .FALSE.
  dvscf_done = .FALSE.
  elph_done  = .FALSE.

  CALL check_all_status()

  CALL assert_true ('T2: scf_done should be TRUE',    scf_done,   npass, nfail)
  CALL assert_false('T2: dvscf_done should be FALSE', dvscf_done, npass, nfail)
  CALL assert_false('T2: elph_done should be FALSE',  elph_done,  npass, nfail)

  ! ============================================================
  ! TEST 3: Status detection - SCF + dvscf done
  ! ============================================================
  WRITE(stdout,'(/,A)') '--- TEST 3: Status detection (SCF + dvscf done) ---'
  CALL setup_phonons_done()

  scf_done   = .FALSE.
  dvscf_done = .FALSE.
  elph_done  = .FALSE.

  CALL check_all_status()

  CALL assert_true ('T3: scf_done should be TRUE',   scf_done,   npass, nfail)
  CALL assert_true ('T3: dvscf_done should be TRUE', dvscf_done, npass, nfail)
  CALL assert_false('T3: elph_done should be FALSE', elph_done,  npass, nfail)

  ! ============================================================
  ! TEST 4: Status detection - All phases done
  ! ============================================================
  WRITE(stdout,'(/,A)') '--- TEST 4: Status detection (all done) ---'
  CALL setup_all_done()

  scf_done   = .FALSE.
  dvscf_done = .FALSE.
  elph_done  = .FALSE.

  CALL check_all_status()

  CALL assert_true('T4: scf_done should be TRUE',   scf_done,   npass, nfail)
  CALL assert_true('T4: dvscf_done should be TRUE', dvscf_done, npass, nfail)
  CALL assert_true('T4: elph_done should be TRUE',  elph_done,  npass, nfail)

  ! ============================================================
  ! TEST 5: Input file generation (generate ph_elph_auto.in)
  ! ============================================================
  WRITE(stdout,'(/,A)') '--- TEST 5: Elph input generation ---'
  CALL create_mock_ph_input()

  ph_input_file   = './mock_workspace/ph.in'
  electron_phonon = 'lambda_tetra'
  nk1 = 16 ; nk2 = 16 ; nk3 = 16
  verbose = .TRUE.

  CALL generate_elph_input(ph_elph_input_file)

  CALL check_generated_input(ph_elph_input_file, npass, nfail)

  ! ============================================================
  ! TEST 6: Workflow simulation (mock commands)
  ! ============================================================
  WRITE(stdout,'(/,A)') '--- TEST 6: Workflow simulation (mock commands) ---'
  CALL setup_empty_workspace()

  ! Use 'echo' as mock commands - they always succeed
  USE_MOCK_COMMANDS: BLOCK
    USE elph_manager_input, ONLY : pw_command, ph_command

    prefix      = 'Al'
    outdir      = './mock_workspace'
    pw_command  = 'echo [MOCK] pw.x would run:'
    ph_command  = 'echo [MOCK] ph.x would run:'
    pw_input_file  = 'scf.in'
    ph_input_file  = './mock_workspace/ph.in'
    electron_phonon = 'lambda_tetra'
    nk1 = 8 ; nk2 = 8 ; nk3 = 8

    scf_done   = .FALSE.
    dvscf_done = .FALSE.
    elph_done  = .FALSE.

    WRITE(stdout,'(/,5X,A)') 'Simulating full workflow (all phases pending):'

    IF (.NOT. scf_done) THEN
       CALL run_scf(ierr)
       CALL assert_int('T6: run_scf exit code = 0', ierr, 0, npass, nfail)
    END IF

    IF (.NOT. dvscf_done) THEN
       CALL run_phonons(ierr)
       CALL assert_int('T6: run_phonons exit code = 0', ierr, 0, npass, nfail)
    END IF

    IF (.NOT. elph_done) THEN
       CALL create_mock_ph_input()
       CALL generate_elph_input(ph_elph_input_file)
       CALL run_elph(ph_elph_input_file, ierr)
       CALL assert_int('T6: run_elph exit code = 0', ierr, 0, npass, nfail)
    END IF

  END BLOCK USE_MOCK_COMMANDS

  ! ============================================================
  ! TEST 7: force_rerun override
  ! ============================================================
  WRITE(stdout,'(/,A)') '--- TEST 7: force_rerun flags ---'
  CALL setup_all_done()

  scf_done   = .FALSE.
  dvscf_done = .FALSE.
  elph_done  = .FALSE.
  CALL check_all_status()

  ! Now apply force_rerun overrides
  force_rerun_scf  = .TRUE.
  force_rerun_ph   = .FALSE.
  force_rerun_elph = .FALSE.

  IF (force_rerun_scf)  scf_done   = .FALSE.
  IF (force_rerun_ph)   dvscf_done = .FALSE.
  IF (force_rerun_elph) elph_done  = .FALSE.

  CALL assert_false('T7: force_rerun_scf -> scf_done=FALSE', scf_done, npass, nfail)
  CALL assert_true ('T7: dvscf_done still TRUE after override', dvscf_done, npass, nfail)
  CALL assert_true ('T7: elph_done still TRUE after override',  elph_done,  npass, nfail)

  ! ============================================================
  ! SUMMARY
  ! ============================================================
  WRITE(stdout,'(/,A)') '========================================'
  WRITE(stdout,'(A)')   ' TEST RESULTS'
  WRITE(stdout,'(A)')   '========================================'
  WRITE(stdout,'(A,I0)') ' PASSED: ', npass
  WRITE(stdout,'(A,I0)') ' FAILED: ', nfail
  WRITE(stdout,'(A)')    '========================================'
  IF (nfail == 0) THEN
     WRITE(stdout,'(A)') ' ALL TESTS PASSED'
  ELSE
     WRITE(stdout,'(A)') ' SOME TESTS FAILED'
     STOP 1
  END IF

  CALL environment_end('ELPH_TEST')
  CALL mp_global_end()

CONTAINS

  !--------------------------------------------------------------------
  SUBROUTINE setup_empty_workspace()
    CALL execute_command_line('rm -rf ./mock_workspace && mkdir -p ./mock_workspace')
  END SUBROUTINE

  SUBROUTINE setup_scf_done()
    CALL execute_command_line('rm -rf ./mock_workspace && ' // &
         'mkdir -p ./mock_workspace/Al.save && ' // &
         'touch ./mock_workspace/Al.save/data-file-schema.xml')
  END SUBROUTINE

  SUBROUTINE setup_phonons_done()
    CALL execute_command_line('rm -rf ./mock_workspace && ' // &
         'mkdir -p ./mock_workspace/Al.save && ' // &
         'touch ./mock_workspace/Al.save/data-file-schema.xml && ' // &
         'mkdir -p "./mock_workspace/_ph0" && ' // &
         'touch ./mock_workspace/_ph0/Al.dvscf1')
  END SUBROUTINE

  SUBROUTINE setup_all_done()
    CALL execute_command_line('rm -rf ./mock_workspace && ' // &
         'mkdir -p ./mock_workspace/Al.save && ' // &
         'touch ./mock_workspace/Al.save/data-file-schema.xml && ' // &
         'mkdir -p "./mock_workspace/_ph0" && ' // &
         'touch ./mock_workspace/_ph0/Al.dvscf1 && ' // &
         'touch ./mock_workspace/lambda')
  END SUBROUTINE

  SUBROUTINE create_mock_ph_input()
    INTEGER :: iunit
    CALL execute_command_line('mkdir -p ./mock_workspace')
    OPEN(UNIT=30, FILE='./mock_workspace/ph.in', STATUS='REPLACE', ACTION='WRITE')
    WRITE(30,'(A)') 'Aluminum phonons'
    WRITE(30,'(A)') '&INPUTPH'
    WRITE(30,'(A)') "  prefix       = 'Al',"
    WRITE(30,'(A)') "  outdir       = './tmp',"
    WRITE(30,'(A)') "  fildyn       = 'Al.dyn',"
    WRITE(30,'(A)') '  tr2_ph       = 1.0d-14,'
    WRITE(30,'(A)') '  ldisp        = .true.,'
    WRITE(30,'(A)') '  nq1          = 4, nq2 = 4, nq3 = 4,'
    WRITE(30,'(A)') '  trans        = .true.,'
    WRITE(30,'(A)') "  electron_phonon = '',"
    WRITE(30,'(A)') '/'
    CLOSE(30)
  END SUBROUTINE

  SUBROUTINE check_generated_input(fname, npass, nfail)
    CHARACTER(LEN=*), INTENT(IN) :: fname
    INTEGER, INTENT(INOUT) :: npass, nfail
    INTEGER :: iunit, ios
    CHARACTER(LEN=512) :: line
    LOGICAL :: found_trans_false, found_elph_mode, found_kgrid
    found_trans_false = .FALSE.
    found_elph_mode   = .FALSE.
    found_kgrid       = .FALSE.
    OPEN(UNIT=31, FILE=TRIM(fname), STATUS='OLD', ACTION='READ', IOSTAT=ios)
    IF (ios /= 0) THEN
       WRITE(stdout,'(A,A)') 'FAIL: Cannot open generated file: ', TRIM(fname)
       nfail = nfail + 1
       RETURN
    END IF
    DO
       READ(31,'(A)', IOSTAT=ios) line
       IF (ios /= 0) EXIT
       IF (INDEX(line,'trans = .false.') > 0)    found_trans_false = .TRUE.
       IF (INDEX(line,'lambda_tetra') > 0)        found_elph_mode   = .TRUE.
       IF (INDEX(line,'nk1') > 0 .AND. &
           INDEX(line,'16')  > 0)                 found_kgrid       = .TRUE.
    END DO
    CLOSE(31)
    CALL assert_true('T5: generated file has trans=.false.',      found_trans_false, npass, nfail)
    CALL assert_true('T5: generated file has electron_phonon',    found_elph_mode,   npass, nfail)
    CALL assert_true('T5: generated file has new k-grid (nk=16)', found_kgrid,       npass, nfail)
  END SUBROUTINE

  !--------------------------------------------------------------------
  SUBROUTINE assert_true(label, val, npass, nfail)
    CHARACTER(LEN=*), INTENT(IN) :: label
    LOGICAL, INTENT(IN) :: val
    INTEGER, INTENT(INOUT) :: npass, nfail
    IF (val) THEN
       WRITE(stdout,'(5X,A,A)') 'PASS: ', TRIM(label)
       npass = npass + 1
    ELSE
       WRITE(stdout,'(5X,A,A)') 'FAIL: ', TRIM(label)
       nfail = nfail + 1
    END IF
  END SUBROUTINE

  SUBROUTINE assert_false(label, val, npass, nfail)
    CHARACTER(LEN=*), INTENT(IN) :: label
    LOGICAL, INTENT(IN) :: val
    INTEGER, INTENT(INOUT) :: npass, nfail
    CALL assert_true(label, .NOT. val, npass, nfail)
  END SUBROUTINE

  SUBROUTINE assert_int(label, val, expected, npass, nfail)
    CHARACTER(LEN=*), INTENT(IN) :: label
    INTEGER, INTENT(IN) :: val, expected
    INTEGER, INTENT(INOUT) :: npass, nfail
    IF (val == expected) THEN
       WRITE(stdout,'(5X,A,A)') 'PASS: ', TRIM(label)
       npass = npass + 1
    ELSE
       WRITE(stdout,'(5X,A,A,I0,A,I0)') 'FAIL: ', TRIM(label)//' got=', val, ' expected=', expected
       nfail = nfail + 1
    END IF
  END SUBROUTINE

END PROGRAM test_elph_manager
