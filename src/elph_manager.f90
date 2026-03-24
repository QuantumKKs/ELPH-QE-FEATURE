!
! Authors: Sanjay Gopal Ramchandani, Fabian Jofré Parra
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!-----------------------------------------------------------------------
PROGRAM elph_manager
!-----------------------------------------------------------------------
  !
  ! Workflow manager for electron-phonon calculations in Quantum ESPRESSO.
  !
  ! This program orchestrates the three-phase electron-phonon workflow:
  !
  !   Phase 1 - SCF (pw.x):
  !     Computes the ground-state electronic structure.
  !     Output: prefix.save/  (wavefunctions, charge density)
  !
  !   Phase 2 - Phonons + dvscf (ph.x, trans=.true.):
  !     Solves the DFPT linear response and saves the SCF potential
  !     response (dvscf). This is the most expensive step.
  !     Output: _ph0/prefix.dvscf1, prefix.dyn*
  !
  !   Phase 3 - Electron-phonon (ph.x, trans=.false.):
  !     Reads the saved dvscf from Phase 2 and computes the
  !     electron-phonon coupling matrix elements WITHOUT repeating
  !     the DFPT calculation (~80% cost saving).
  !     Output: lambda, prefix.a2F, etc.
  !
  ! Smart caching: each phase is skipped if its output files already exist.
  ! Force-rerun flags (force_rerun_scf, force_rerun_ph, force_rerun_elph)
  ! override this behavior.
  !
  ! Usage:
  !   elph_manager.x < elph_manager.in > elph_manager.out
  !
  ! Input: &ELPH_MANAGER namelist (see Doc/INPUT_ELPH_MANAGER.md)
  !
  !-----------------------------------------------------------------------
  !
  USE kinds,                 ONLY : DP
  USE io_global,             ONLY : stdout, ionode, ionode_id
  USE mp_global,             ONLY : mp_startup, mp_global_end
  USE environment,           ONLY : environment_start, environment_end
  USE mp_world,              ONLY : world_comm
  USE mp,                    ONLY : mp_bcast, mp_barrier
  !
  USE elph_manager_input,    ONLY : elph_manager_readin,              &
                                    force_rerun_scf, force_rerun_ph,  &
                                    force_rerun_elph, verbose,        &
                                    ph_split_qpoints, nq_irr,         &
                                    compute_matdyn, compute_bands
  USE elph_manager_status,   ONLY : check_all_status,                 &
                                    scf_done, dvscf_done, elph_done,  &
                                    matdyn_done, bands_done
  USE elph_manager_generate, ONLY : generate_elph_input,              &
                                    generate_q2r_input,               &
                                    generate_matdyn_input,            &
                                    generate_bands_input
  USE elph_manager_run,      ONLY : run_scf, run_phonons,             &
                                    run_phonons_split, run_elph,      &
                                    run_q2r, run_matdyn, run_bands
  !
  IMPLICIT NONE
  !
  CHARACTER(LEN=12) :: code = 'ELPH_MANAGER'
  CHARACTER(LEN=256) :: ph_elph_input_file
  CHARACTER(LEN=256) :: q2r_input_file, matdyn_input_file
  CHARACTER(LEN=256) :: pw_bands_file, bandspp_file
  INTEGER :: ierr
  !
  ! ============================================================
  ! Initialize MPI and QE environment
  ! ============================================================
  CALL mp_startup(start_images=.FALSE.)
  CALL environment_start(code)
  !
  IF (ionode) THEN
     WRITE(stdout,'(/)')
     WRITE(stdout,'(5X,A)') REPEAT('*',55)
     WRITE(stdout,'(5X,A)') '  ELPH_MANAGER - Electron-Phonon Workflow Manager'
     WRITE(stdout,'(5X,A)') '  Quantum ESPRESSO contribution'
     WRITE(stdout,'(5X,A)') REPEAT('*',55)
     WRITE(stdout,'(5X,A)') '  Workflow: pw.x -> ph.x (dvscf) -> ph.x (elph)'
     WRITE(stdout,'(5X,A)') '  dvscf is reused: no DFPT repeated for elph.'
     WRITE(stdout,'(5X,A)') REPEAT('*',55)
  END IF
  !
  ! ============================================================
  ! Read &ELPH_MANAGER namelist
  ! ============================================================
  CALL elph_manager_readin()
  !
  ! ============================================================
  ! Check which phases are already done
  ! ============================================================
  CALL check_all_status()
  !
  ! Apply force-rerun overrides
  IF (force_rerun_scf)  scf_done    = .FALSE.
  IF (force_rerun_ph)   dvscf_done  = .FALSE.
  IF (force_rerun_elph) elph_done   = .FALSE.
  IF (force_rerun_scf)  bands_done  = .FALSE.
  IF (force_rerun_ph)   matdyn_done = .FALSE.
  !
  ! ============================================================
  ! Execute phases (only on ionode: manager runs serially,
  ! each subprocess handles its own MPI internally)
  ! ============================================================
  IF (ionode) THEN
     !
     ! --- Phase 1: SCF ---
     IF (.NOT. scf_done) THEN
        CALL run_scf(ierr)
     ELSE
        IF (verbose) WRITE(stdout,'(/,5X,A)') &
             'Phase 1 (SCF): SKIPPED — prefix.save/ found'
     END IF
     !
     ! --- Phase 2: Phonons + dvscf ---
     IF (.NOT. dvscf_done) THEN
        IF (ph_split_qpoints) THEN
           CALL run_phonons_split(ierr)
        ELSE
           CALL run_phonons(ierr)
        END IF
     ELSE
        IF (verbose) WRITE(stdout,'(/,5X,A)') &
             'Phase 2 (Phonons): SKIPPED — dvscf files found'
     END IF
     !
     ! --- Phase 3: Phonon dispersion (optional) ---
     IF (compute_matdyn) THEN
        IF (.NOT. matdyn_done) THEN
           CALL generate_q2r_input(q2r_input_file)
           CALL run_q2r(q2r_input_file, ierr)
           CALL generate_matdyn_input(matdyn_input_file)
           CALL run_matdyn(matdyn_input_file, ierr)
        ELSE
           IF (verbose) WRITE(stdout,'(/,5X,A)') &
                'Phase 3 (Matdyn): SKIPPED — matdyn.freq found'
        END IF
     END IF
     !
     ! --- Phase 4: Electron-phonon coefficients ---
     IF (.NOT. elph_done) THEN
        !
        ! Generate the ph.x input for this phase (trans=.false.)
        CALL generate_elph_input(ph_elph_input_file)
        !
        CALL run_elph(ph_elph_input_file, ierr)
        !
     ELSE
        IF (verbose) WRITE(stdout,'(/,5X,A)') &
             'Phase 4 (Elph): SKIPPED — lambda/a2F files found'
     END IF
     !
     ! --- Phase 5: Band structure (optional) ---
     IF (compute_bands) THEN
        IF (.NOT. bands_done) THEN
           CALL generate_bands_input(pw_bands_file, bandspp_file)
           CALL run_bands(pw_bands_file, bandspp_file, ierr)
        ELSE
           IF (verbose) WRITE(stdout,'(/,5X,A)') &
                'Phase 5 (Bands): SKIPPED — bands.dat.gnu found'
        END IF
     END IF
     !
     ! --- Summary ---
     WRITE(stdout,'(/,5X,A)') REPEAT('*',55)
     WRITE(stdout,'(5X,A)')   '  ELPH_MANAGER: workflow completed.'
     WRITE(stdout,'(5X,A)')   REPEAT('*',55)
     !
  END IF
  !
  ! ============================================================
  ! Finalize
  ! ============================================================
  CALL environment_end(code)
  CALL mp_global_end()
  !
END PROGRAM elph_manager
