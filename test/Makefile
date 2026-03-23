FC = gfortran
FFLAGS = -O0 -g -Wall -Wno-unused-dummy-argument -fcheck=all -std=f2008

SRCS = qe_stubs.f90 \
       elph_mod_input_test.f90 \
       ../src/elph_mod_status.f90 \
       ../src/elph_mod_generate.f90 \
       ../src/elph_mod_run.f90 \
       test_main.f90

.PHONY: all run clean

all: test_elph_manager

test_elph_manager: $(SRCS)
	$(FC) $(FFLAGS) -o $@ $(SRCS)

run: test_elph_manager
	./test_elph_manager
	@rm -rf ./mock_workspace ph_elph_auto.in *.mod

clean:
	rm -f test_elph_manager *.mod *.o
	rm -rf mock_workspace ph_elph_auto.in
