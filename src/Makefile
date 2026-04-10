# Makefile for elph_manager.x
# Integrates with Quantum ESPRESSO build system via make.inc
#
# Place this directory as ELPH_MANAGER/ inside the QE root and run:
#   make -C ELPH_MANAGER/src
# or add a target to the top-level QE Makefile.
#
sinclude ../../make.inc

MODULE_FLAGS = \
    -I../../Modules \
    -I../../PHonon/PH \
    -I../../UtilXlib \
    -I../../devxlib/src \
    $(BASEMOD_FLAGS)

ELPH_MGR_OBJS = \
    elph_mod_input.o    \
    elph_mod_status.o   \
    elph_mod_generate.o \
    elph_mod_run.o      \
    elph_manager.o

QE_ROOT = $(abspath ../..)

QE_LIBS = \
    $(QE_ROOT)/PW/src/libpw.a \
    $(QE_ROOT)/LR_Modules/liblrmod.a \
    $(QE_ROOT)/Modules/libqemod.a \
    $(QE_ROOT)/KS_Solvers/libks_solvers.a \
    $(QE_ROOT)/upflib/libupf.a \
    $(QE_ROOT)/XClib/xc_lib.a \
    $(QE_ROOT)/FFTXlib/src/libqefft.a \
    $(QE_ROOT)/LAXlib/libqela.a \
    $(QE_ROOT)/UtilXlib/libutil.a \
    $(QE_ROOT)/MBD/libmbd.a \
    $(firstword $(wildcard $(QE_ROOT)/devxlib/src/libdevXlib.a $(QE_ROOT)/external/devxlib/src/libdevXlib.a)) \
    $(QE_ROOT)/dft-d3/libdftd3qe.a

LIBS = $(QE_LIBS) \
       $(LAPACK_LIBS) $(BLAS_LIBS) $(MPI_LIBS) \
       $(MASS_LIBS) $(HDF5_LIBS) $(SCALAPACK_LIBS)

.PHONY: all clean

all: elph_manager.x

elph_manager.x: $(ELPH_MGR_OBJS)
	$(LD) $(LDFLAGS) -o $@ $(ELPH_MGR_OBJS) $(LIBS)
	cp elph_manager.x ../../bin/
	@echo "=== elph_manager.x instalado en bin/ ==="

%.o: %.f90
	$(MPIF90) $(F90FLAGS) $(MODULE_FLAGS) -c $<

# Module dependencies (explicit, to guarantee correct compilation order)
elph_mod_status.o:   elph_mod_input.o
elph_mod_generate.o: elph_mod_input.o
elph_mod_run.o:      elph_mod_input.o elph_mod_generate.o
elph_manager.o:      elph_mod_input.o elph_mod_status.o \
                     elph_mod_generate.o elph_mod_run.o

clean:
	rm -f *.o *.mod elph_manager.x
