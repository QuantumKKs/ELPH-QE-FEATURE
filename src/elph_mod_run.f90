!
! Copyright (C) 2024 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!=======================================================================
MODULE elph_manager_run
!=======================================================================
  !
  ! Executes the three calculation phases by calling pw.x and ph.x
  ! as subprocesses via EXECUTE_COMMAND_LINE (Fortran 2008).
  !
  ! pw.x and ph.x are looked up from PATH.
  ! Run elph_manager.x with mpirun if needed:
  !   mpirun -np N elph_manager.x < input.in
  !
  ! Each phase:
  !   run_scf()     -> pw.x -in pw_input_file  > pw_output_file
  !   run_phonons() -> ph.x -in ph_input_file  > ph_output_file
  !   run_elph()    -> ph.x -in ph_elph_auto.in > elph_output_file
  !
  IMPLICIT NONE
  SAVE
  !
CONTAINS
  !
  !---------------------------------------------------------------------
  SUBROUTINE run_command(cmd, description, ierr)
  !---------------------------------------------------------------------
    !
    ! Execute a shell command and report result.
    ! Only the ionode actually runs the command.
    !
    USE io_global, ONLY : ionode, stdout
    !
    CHARACTER(LEN=*), INTENT(IN)  :: cmd, description
    INTEGER,          INTENT(OUT) :: ierr
    !
    ierr = 0
    IF (.NOT. ionode) RETURN
    !
    WRITE(stdout,'(/,5X,A)') REPEAT('=',55)
    WRITE(stdout,'(5X,A)')   '  '//TRIM(description)
    WRITE(stdout,'(5X,A)')   REPEAT('=',55)
    WRITE(stdout,'(5X,A,A)') 'Command: ', TRIM(cmd)
    WRITE(stdout,'(5X,A)')   ''
    !
    CALL EXECUTE_COMMAND_LINE(TRIM(cmd), WAIT=.TRUE., EXITSTAT=ierr)
    !
    IF (ierr /= 0) THEN
       WRITE(stdout,'(5X,A,I0)') &
            'ERROR: command exited with status ', ierr
       WRITE(stdout,'(5X,A)') &
            'Check output file for details.'
    ELSE
       WRITE(stdout,'(5X,A)') 'Completed successfully.'
    END IF
    !
  END SUBROUTINE run_command
  !
  !---------------------------------------------------------------------
  SUBROUTINE run_scf(ierr)
  !---------------------------------------------------------------------
    !
    ! Phase 1: Run pw.x for the SCF electronic structure.
    !
    USE elph_manager_input, ONLY : pw_input_file, pw_output_file
    USE io_global,          ONLY : stdout
    !
    INTEGER, INTENT(OUT) :: ierr
    !
    CHARACTER(LEN=1024) :: cmd
    !
    cmd = 'pw.x -in '//TRIM(pw_input_file)//' > '//TRIM(pw_output_file)//' 2>&1'
    !
    CALL run_command(TRIM(cmd), &
         'Phase 1: SCF electronic structure (pw.x)', ierr)
    !
    IF (ierr /= 0) CALL errore('run_scf', &
         'pw.x failed. Check '//TRIM(pw_output_file), ierr)
    !
  END SUBROUTINE run_scf
  !
  !---------------------------------------------------------------------
  SUBROUTINE run_phonons(ierr)
  !---------------------------------------------------------------------
    !
    ! Phase 2: Run ph.x with trans=.true. to compute phonons and
    ! save the DFPT response potentials (dvscf).
    ! The original ph_input_file is used as-is.
    !
    USE elph_manager_input, ONLY : ph_input_file, ph_output_file
    USE io_global,          ONLY : stdout
    !
    INTEGER, INTENT(OUT) :: ierr
    !
    CHARACTER(LEN=1024) :: cmd
    !
    cmd = 'ph.x -in '//TRIM(ph_input_file)//' > '//TRIM(ph_output_file)//' 2>&1'
    !
    CALL run_command(TRIM(cmd), &
         'Phase 2: Phonon DFPT + dvscf (ph.x)', ierr)
    !
    IF (ierr /= 0) CALL errore('run_phonons', &
         'ph.x phase 2 failed. Check '//TRIM(ph_output_file), ierr)
    !
  END SUBROUTINE run_phonons
  !
  !---------------------------------------------------------------------
  SUBROUTINE run_phonons_split(ierr)
  !---------------------------------------------------------------------
    !
    ! Run ph.x independently for each irreducible q-point.
    ! Uses start_q / last_q to isolate each q-point calculation.
    ! Requires ph_split_qpoints = .TRUE. and nq_irr > 0.
    !
    USE elph_manager_input,    ONLY : ph_output_file, nq_irr, verbose
    USE elph_manager_generate, ONLY : generate_single_q_input
    USE io_global,             ONLY : stdout
    !
    INTEGER, INTENT(OUT) :: ierr
    !
    INTEGER            :: iq, exit_status
    CHARACTER(LEN=256) :: ph_single_file, cmd
    CHARACTER(LEN=8)   :: iq_str
    !
    ierr = 0
    !
    IF (nq_irr <= 0) CALL errore('run_phonons_split', &
         'nq_irr must be > 0 when ph_split_qpoints = .true.', 1)
    !
    IF (verbose) THEN
       WRITE(stdout,'(/,5X,A,I4,A)') &
            'Running ph.x for ', nq_irr, ' q-points independently'
    END IF
    !
    DO iq = 1, nq_irr
       !
       CALL generate_single_q_input(iq, ph_single_file)
       !
       WRITE(iq_str, '(I4)') iq
       cmd = 'ph.x -in '//TRIM(ph_single_file)// &
             ' > ph_q'//TRIM(ADJUSTL(iq_str))//'.out 2>&1'
       !
       IF (verbose) THEN
          WRITE(stdout,'(/,7X,A,I3,A,I3)') &
               'q-point ', iq, ' of ', nq_irr
          WRITE(stdout,'(7X,A,A)') 'Command: ', TRIM(cmd)
       END IF
       !
       CALL EXECUTE_COMMAND_LINE(TRIM(cmd), WAIT=.TRUE., &
                                 EXITSTAT=exit_status)
       !
       IF (exit_status /= 0) THEN
          WRITE(stdout,'(/,5X,A,I3,A,I4)') &
               'ERROR: q-point ', iq, ' exited with status ', exit_status
          ierr = exit_status
          RETURN
       END IF
       !
       IF (verbose) WRITE(stdout,'(7X,A,I3,A)') &
            'q-point ', iq, ' completed.'
       !
    END DO
    !
    IF (verbose) WRITE(stdout,'(/,5X,A)') &
         'All q-points completed successfully.'
    !
  END SUBROUTINE run_phonons_split
  !
  !---------------------------------------------------------------------
  SUBROUTINE run_elph(ph_elph_input_file, ierr)
  !---------------------------------------------------------------------
    !
    ! Phase 3: Run ph.x with trans=.false. and electron_phonon set.
    ! Reuses the dvscf files from Phase 2 -- no DFPT redone.
    ! ph_elph_input_file is the auto-generated input from generate_elph_input().
    !
    USE elph_manager_input, ONLY : elph_output_file
    USE io_global,          ONLY : stdout
    !
    CHARACTER(LEN=256), INTENT(IN)  :: ph_elph_input_file
    INTEGER,            INTENT(OUT) :: ierr
    !
    CHARACTER(LEN=1024) :: cmd
    !
    cmd = 'ph.x -in '//TRIM(ph_elph_input_file)//' > '//TRIM(elph_output_file)//' 2>&1'
    !
    CALL run_command(TRIM(cmd), &
         'Phase 3: Electron-phonon coefficients (ph.x, trans=.false.)', ierr)
    !
    IF (ierr /= 0) CALL errore('run_elph', &
         'ph.x phase 3 failed. Check '//TRIM(elph_output_file), ierr)
    !
  END SUBROUTINE run_elph
  !
END MODULE elph_manager_run
