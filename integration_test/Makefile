FC     = mpif90
FFLAGS = -O0 -g -fcheck=all -Wall -Wno-unused-dummy-argument -std=f2008

SRC    = ../ELPH_MANAGER/src
STUB   = src

# Compilation order matters: modules before programs that use them
OBJS = \
    kinds.o \
    io_global.o \
    mp_world.o \
    mp.o \
    mp_global.o \
    environment.o \
    elph_mod_input.o \
    elph_mod_status.o \
    elph_mod_generate.o \
    elph_mod_run.o \
    elph_manager.o

.PHONY: all run clean

all: elph_manager.x

elph_manager.x: $(OBJS)
	$(FC) $(FFLAGS) -o $@ $(OBJS)
	@echo ""
	@echo "=== BUILD SUCCESSFUL: elph_manager.x compiled with real MPI ==="

# --- Stubs (replace QE infrastructure) ---
kinds.o:        $(STUB)/qe_minimal.f90
	$(FC) $(FFLAGS) -c $(STUB)/qe_minimal.f90 -o kinds_tmp.o
	# Split compilation: compile all stubs together
	$(FC) $(FFLAGS) -c $(STUB)/qe_minimal.f90

io_global.o:    kinds.o
mp_world.o:     io_global.o
mp.o:           mp_world.o
mp_global.o:    mp.o
environment.o:  mp_global.o

# Since all stubs are in one file, compile them together once
kinds.o io_global.o mp_world.o mp.o mp_global.o environment.o: $(STUB)/qe_minimal.f90
	$(FC) $(FFLAGS) -c $(STUB)/qe_minimal.f90 -o _stubs_combined.o
	@touch kinds.o io_global.o mp_world.o mp.o mp_global.o environment.o

# --- elph_manager modules ---
elph_mod_input.o: environment.o $(SRC)/elph_mod_input.f90
	$(FC) $(FFLAGS) -c $(SRC)/elph_mod_input.f90

elph_mod_status.o: elph_mod_input.o $(SRC)/elph_mod_status.f90
	$(FC) $(FFLAGS) -c $(SRC)/elph_mod_status.f90

elph_mod_generate.o: elph_mod_input.o $(SRC)/elph_mod_generate.f90
	$(FC) $(FFLAGS) -c $(SRC)/elph_mod_generate.f90

elph_mod_run.o: elph_mod_input.o $(SRC)/elph_mod_run.f90
	$(FC) $(FFLAGS) -c $(SRC)/elph_mod_run.f90

elph_manager.o: elph_mod_input.o elph_mod_status.o elph_mod_generate.o \
                elph_mod_run.o $(SRC)/elph_manager.f90
	$(FC) $(FFLAGS) -c $(SRC)/elph_manager.f90

run: elph_manager.x
	@mkdir -p run_test/Al.save run_test/_ph0
	@touch run_test/Al.save/data-file-schema.xml
	@touch run_test/_ph0/Al.dvscf1
	@cp $(SRC)/../examples/Al/ph.in run_test/
	@printf "&ELPH_MANAGER\n\
  prefix           = 'Al',\n\
  outdir           = './run_test',\n\
  ph_input_file    = 'run_test/ph.in',\n\
  pw_command       = 'echo [pw.x simulado]',\n\
  ph_command       = 'echo [ph.x simulado]',\n\
  electron_phonon  = 'lambda_tetra',\n\
  nk1=16, nk2=16, nk3=16,\n\
  verbose          = .true.,\n\
/\n" > run_test/elph_manager.in
	@echo "=== CORRIENDO elph_manager.x ==="
	cd run_test && ../elph_manager.x < elph_manager.in

clean:
	rm -f elph_manager.x *.mod *.o _stubs_combined.o
	rm -rf run_test
