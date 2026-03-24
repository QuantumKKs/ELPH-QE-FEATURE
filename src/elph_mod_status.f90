!
! Copyright (C) 2024 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!=======================================================================
MODULE elph_manager_status
!=======================================================================
  !
  ! Checks the completion status of each calculation phase by
  ! inspecting key output files written by pw.x and ph.x.
  !
  ! Phase detection logic:
  !
  !   SCF done   -> prefix.save/data-file-schema.xml  exists
  !
  !   dvscf done -> _ph0/prefix.dvscf1                exists (Gamma / no ldisp)
  !              OR _ph0/prefix.q_1/prefix.dvscf1      exists (ldisp grid)
  !              We check both; either one indicates phonons are done.
  !
  !   elph done  -> 'lambda' or 'lambda.dat'          exists in outdir
  !              OR prefix.a2F                         exists (for EPA/tetra)
  !
  IMPLICIT NONE
  SAVE
  !
  LOGICAL :: scf_done    = .FALSE.
  LOGICAL :: dvscf_done  = .FALSE.
  LOGICAL :: elph_done   = .FALSE.
  LOGICAL :: matdyn_done = .FALSE.
  LOGICAL :: bands_done  = .FALSE.
  !
CONTAINS
  !
  !---------------------------------------------------------------------
  SUBROUTINE check_all_status()
  !---------------------------------------------------------------------
    !
    USE elph_manager_input, ONLY : prefix, outdir, verbose, &
                                   compute_matdyn, compute_bands
    USE io_global,          ONLY : ionode, stdout
    !
    IMPLICIT NONE
    !
    CHARACTER(LEN=512) :: filename
    LOGICAL            :: exst
    !
    ! ----------------------------------------------------------------
    ! Phase 1: SCF electronic structure
    ! Key file: prefix.save/data-file-schema.xml
    ! Written by pw.x at the end of a successful SCF run.
    ! ----------------------------------------------------------------
    filename = TRIM(outdir)//'/'//TRIM(prefix)//'.save/data-file-schema.xml'
    INQUIRE(FILE=TRIM(filename), EXIST=scf_done)
    !
    ! ----------------------------------------------------------------
    ! Phase 2: Phonon DFPT + dvscf
    ! Key files (check both Gamma-only and ldisp cases):
    !   _ph0/prefix.dvscf1          (Gamma or single q-point)
    !   _ph0/prefix.q_1/prefix.dvscf1  (first q-point of ldisp grid)
    ! ----------------------------------------------------------------
    dvscf_done = .FALSE.
    !
    ! Check Gamma / single q-point case
    filename = TRIM(outdir)//'/_ph0/'//TRIM(prefix)//'.dvscf1'
    INQUIRE(FILE=TRIM(filename), EXIST=exst)
    IF (exst) dvscf_done = .TRUE.
    !
    ! Check ldisp grid case (q_1 subdirectory)
    IF (.NOT. dvscf_done) THEN
       filename = TRIM(outdir)//'/_ph0/'//TRIM(prefix)// &
                  '.q_1/'//TRIM(prefix)//'.dvscf1'
       INQUIRE(FILE=TRIM(filename), EXIST=exst)
       IF (exst) dvscf_done = .TRUE.
    END IF
    !
    ! Also accept the newer phsave directory layout used in recent QE versions
    IF (.NOT. dvscf_done) THEN
       filename = TRIM(outdir)//'/'//TRIM(prefix)//'.phsave/dvscf_q1_irr1.dat'
       INQUIRE(FILE=TRIM(filename), EXIST=exst)
       IF (exst) dvscf_done = .TRUE.
    END IF
    !
    ! ----------------------------------------------------------------
    ! Phase 3: Electron-phonon coefficients
    ! Key files (any of these indicates elph is done):
    !   lambda            (simple / interpolated modes)
    !   lambda.dat
    !   prefix.a2F        (EPA / tetra modes)
    !   elph_dir/         (AHC mode - check directory existence)
    ! ----------------------------------------------------------------
    elph_done = .FALSE.
    !
    ! lambda file (simple/interpolated modes) — in current dir or outdir
    INQUIRE(FILE='lambda', EXIST=exst)
    IF (exst) elph_done = .TRUE.
    !
    IF (.NOT. elph_done) THEN
       filename = TRIM(outdir)//'/lambda'
       INQUIRE(FILE=TRIM(filename), EXIST=exst)
       IF (exst) elph_done = .TRUE.
    END IF
    !
    IF (.NOT. elph_done) THEN
       INQUIRE(FILE='lambda.dat', EXIST=exst)
       IF (exst) elph_done = .TRUE.
    END IF
    !
    ! prefix.a2F (EPA/tetra modes)
    IF (.NOT. elph_done) THEN
       filename = TRIM(prefix)//'.a2F'
       INQUIRE(FILE=TRIM(filename), EXIST=exst)
       IF (exst) elph_done = .TRUE.
    END IF
    !
    ! prefix.dyn1.elph.1 — written by 'simple' mode in current dir
    IF (.NOT. elph_done) THEN
       filename = TRIM(prefix)//'.dyn1.elph.1'
       INQUIRE(FILE=TRIM(filename), EXIST=exst)
       IF (exst) elph_done = .TRUE.
    END IF
    !
    ! ----------------------------------------------------------------
    ! Phase 3b: matdyn phonon dispersion
    ! Key file: matdyn.freq
    ! ----------------------------------------------------------------
    INQUIRE(FILE='matdyn.freq', EXIST=matdyn_done)
    !
    ! ----------------------------------------------------------------
    ! Phase 5: Electronic band structure
    ! Key files: prefix.bands.dat.gnu or bands.dat.gnu
    ! ----------------------------------------------------------------
    INQUIRE(FILE=TRIM(prefix)//'.bands.dat.gnu', EXIST=bands_done)
    IF (.NOT. bands_done) INQUIRE(FILE='bands.dat.gnu', EXIST=bands_done)
    !
    ! ----------------------------------------------------------------
    ! Report status
    ! ----------------------------------------------------------------
    IF (ionode) THEN
       WRITE(stdout,'(/,5X,A)') REPEAT('-',50)
       WRITE(stdout,'(5X,A)')   '  Calculation status'
       WRITE(stdout,'(5X,A)')   REPEAT('-',50)
       CALL report_phase('Phase 1 - SCF (pw.x)          ', scf_done,   .TRUE.)
       CALL report_phase('Phase 2 - Phonons (ph.x)      ', dvscf_done, .TRUE.)
       CALL report_phase('Phase 3 - Matdyn (matdyn.x)   ', matdyn_done, compute_matdyn)
       CALL report_phase('Phase 4 - Elph (ph.x)         ', elph_done,  .TRUE.)
       CALL report_phase('Phase 5 - Bands (pw.x/bands.x)', bands_done, compute_bands)
       WRITE(stdout,'(5X,A)')   REPEAT('-',50)
    END IF
    !
  END SUBROUTINE check_all_status
  !
  !---------------------------------------------------------------------
  SUBROUTINE report_phase(label, done, enabled)
  !---------------------------------------------------------------------
    !
    USE io_global, ONLY : stdout
    !
    CHARACTER(LEN=*), INTENT(IN) :: label
    LOGICAL,          INTENT(IN) :: done, enabled
    !
    IF (.NOT. enabled) THEN
       WRITE(stdout,'(5X,A,A)') TRIM(label), ' [DISABLED]'
    ELSE IF (done) THEN
       WRITE(stdout,'(5X,A,A)') TRIM(label), ' [DONE - will skip]'
    ELSE
       WRITE(stdout,'(5X,A,A)') TRIM(label), ' [PENDING - will run]'
    END IF
    !
  END SUBROUTINE report_phase
  !
END MODULE elph_manager_status
