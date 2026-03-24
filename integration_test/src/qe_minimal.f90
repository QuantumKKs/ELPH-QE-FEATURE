!
! Minimal QE-compatible stubs compilados con MPI real (mpif90).
! Replica exactamente las interfaces de los módulos de QE que usamos.
!
MODULE kinds
  IMPLICIT NONE
  INTEGER, PARAMETER :: DP = KIND(1.0D0)
END MODULE kinds

MODULE io_global
  USE mpi
  IMPLICIT NONE
  SAVE
  INTEGER :: stdout    = 6
  INTEGER :: ionode_id = 0
  LOGICAL :: ionode    = .FALSE.
  LOGICAL :: meta_ionode = .FALSE.
  INTEGER :: meta_ionode_id = 0
CONTAINS
  SUBROUTINE io_global_start(my_rank, root)
    INTEGER, INTENT(IN) :: my_rank, root
    ionode    = (my_rank == root)
    meta_ionode = ionode
    ionode_id = root
    meta_ionode_id = root
  END SUBROUTINE
END MODULE io_global

MODULE mp_world
  USE mpi
  IMPLICIT NONE
  SAVE
  INTEGER :: world_comm = MPI_COMM_WORLD
  INTEGER :: nproc = 1
  INTEGER :: nnode = 1
  INTEGER :: mpime = 0
  INTEGER :: root  = 0
END MODULE mp_world

! Generic mp_bcast interface - replica exacta de QE/UtilXlib/mp.f90
MODULE mp
  USE mpi
  IMPLICIT NONE
  !
  INTERFACE mp_bcast
    MODULE PROCEDURE mp_bcast_char, mp_bcast_int, mp_bcast_real_dp, &
                     mp_bcast_logical
  END INTERFACE mp_bcast
  !
CONTAINS
  !
  SUBROUTINE mp_bcast_char(msg, source, gid)
    CHARACTER(LEN=*), INTENT(INOUT) :: msg
    INTEGER,          INTENT(IN)    :: source, gid
    INTEGER :: ierr
    CALL MPI_Bcast(msg, LEN(msg), MPI_CHARACTER, source, gid, ierr)
  END SUBROUTINE

  SUBROUTINE mp_bcast_int(msg, source, gid)
    INTEGER, INTENT(INOUT) :: msg
    INTEGER, INTENT(IN)    :: source, gid
    INTEGER :: ierr
    CALL MPI_Bcast(msg, 1, MPI_INTEGER, source, gid, ierr)
  END SUBROUTINE

  SUBROUTINE mp_bcast_real_dp(msg, source, gid)
    USE kinds, ONLY : DP
    REAL(DP), INTENT(INOUT) :: msg
    INTEGER,  INTENT(IN)    :: source, gid
    INTEGER :: ierr
    CALL MPI_Bcast(msg, 1, MPI_DOUBLE_PRECISION, source, gid, ierr)
  END SUBROUTINE

  SUBROUTINE mp_bcast_logical(msg, source, gid)
    LOGICAL, INTENT(INOUT) :: msg
    INTEGER, INTENT(IN)    :: source, gid
    INTEGER :: ierr
    CALL MPI_Bcast(msg, 1, MPI_LOGICAL, source, gid, ierr)
  END SUBROUTINE

  SUBROUTINE mp_barrier(gid)
    INTEGER, INTENT(IN) :: gid
    INTEGER :: ierr
    CALL MPI_Barrier(gid, ierr)
  END SUBROUTINE

END MODULE mp

MODULE mp_global
  USE mpi
  IMPLICIT NONE
CONTAINS
  SUBROUTINE mp_startup(start_images)
    USE mp_world,  ONLY : mpime, nproc
    USE io_global, ONLY : io_global_start
    LOGICAL, OPTIONAL, INTENT(IN) :: start_images
    INTEGER :: ierr
    CALL MPI_Init(ierr)
    CALL MPI_Comm_rank(MPI_COMM_WORLD, mpime, ierr)
    CALL MPI_Comm_size(MPI_COMM_WORLD, nproc, ierr)
    CALL io_global_start(mpime, 0)
  END SUBROUTINE

  SUBROUTINE mp_global_end()
    INTEGER :: ierr
    CALL MPI_Finalize(ierr)
  END SUBROUTINE
END MODULE mp_global

MODULE environment
  IMPLICIT NONE
CONTAINS
  SUBROUTINE environment_start(code)
    USE io_global, ONLY : ionode, stdout
    CHARACTER(LEN=*), INTENT(IN) :: code
    IF (ionode) WRITE(stdout,'(/,5X,A,A)') '=== ', TRIM(code)//' ==='
  END SUBROUTINE
  SUBROUTINE environment_end(code)
    USE io_global, ONLY : ionode, stdout
    CHARACTER(LEN=*), INTENT(IN) :: code
    IF (ionode) WRITE(stdout,'(5X,A,A,/)') '=== ', TRIM(code)//' done ==='
  END SUBROUTINE
END MODULE environment

! errore: replica de QE
SUBROUTINE errore(routine, msg, ierr)
  IMPLICIT NONE
  CHARACTER(LEN=*), INTENT(IN) :: routine, msg
  INTEGER,          INTENT(IN) :: ierr
  WRITE(6,'(/,A,": ",A," (ierr=",I0,")")') TRIM(routine), TRIM(msg), ierr
  STOP 1
END SUBROUTINE errore
