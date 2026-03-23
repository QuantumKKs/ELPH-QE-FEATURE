!
! Minimal stubs for Quantum ESPRESSO modules.
! Allows compiling and testing elph_manager without a QE installation.
!
MODULE kinds
  IMPLICIT NONE
  INTEGER, PARAMETER :: DP = KIND(1.0D0)
END MODULE kinds

MODULE io_global
  IMPLICIT NONE
  LOGICAL :: ionode    = .TRUE.
  INTEGER :: ionode_id = 0
  INTEGER :: stdout    = 6    ! unit 6 = standard output
END MODULE io_global

MODULE mp_world
  IMPLICIT NONE
  INTEGER :: world_comm = 0
END MODULE mp_world

MODULE mp
  IMPLICIT NONE
CONTAINS
  SUBROUTINE mp_bcast_char(var, root, comm)
    CHARACTER(LEN=*), INTENT(INOUT) :: var
    INTEGER, INTENT(IN) :: root, comm
  END SUBROUTINE
  SUBROUTINE mp_bcast_int(var, root, comm)
    INTEGER, INTENT(INOUT) :: var
    INTEGER, INTENT(IN) :: root, comm
  END SUBROUTINE
  SUBROUTINE mp_bcast_real(var, root, comm)
    USE kinds, ONLY : DP
    REAL(DP), INTENT(INOUT) :: var
    INTEGER, INTENT(IN) :: root, comm
  END SUBROUTINE
  SUBROUTINE mp_bcast_logical(var, root, comm)
    LOGICAL, INTENT(INOUT) :: var
    INTEGER, INTENT(IN) :: root, comm
  END SUBROUTINE
  SUBROUTINE mp_barrier(comm)
    INTEGER, INTENT(IN) :: comm
  END SUBROUTINE
END MODULE mp

MODULE mp_global
  IMPLICIT NONE
CONTAINS
  SUBROUTINE mp_startup(start_images)
    LOGICAL, OPTIONAL, INTENT(IN) :: start_images
  END SUBROUTINE
  SUBROUTINE mp_global_end()
  END SUBROUTINE
END MODULE mp_global

MODULE environment
  IMPLICIT NONE
CONTAINS
  SUBROUTINE environment_start(code)
    CHARACTER(LEN=*), INTENT(IN) :: code
    WRITE(6,'(/,5X,A,A,A)') '=== ', TRIM(code), ' (test mode, no QE) ==='
  END SUBROUTINE
  SUBROUTINE environment_end(code)
    CHARACTER(LEN=*), INTENT(IN) :: code
    WRITE(6,'(5X,A,A,A,/)') '=== ', TRIM(code), ' done ==='
  END SUBROUTINE
END MODULE environment

! Standalone errore (replaces QE's version)
SUBROUTINE errore(routine, msg, ierr)
  IMPLICIT NONE
  CHARACTER(LEN=*), INTENT(IN) :: routine, msg
  INTEGER,          INTENT(IN) :: ierr
  WRITE(6,'(/,A,A,A,A,I0)') 'ERROR in ', TRIM(routine), ': ', TRIM(msg), ierr
  STOP 1
END SUBROUTINE errore
