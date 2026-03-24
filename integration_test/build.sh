#!/bin/bash
set -e

FC="mpif90"
FFLAGS="-O0 -g -fcheck=all -Wall -Wno-unused-dummy-argument -std=f2008"
SRC="../ELPH_MANAGER/src"
STUB="src"

echo "=== Compilando elph_manager.x con MPI real ==="

# Paso 1: stubs que reemplazan los módulos de QE (kinds, io_global, mp, etc.)
echo "[1/6] Compilando stubs de QE (kinds, io_global, mp, mp_global, environment)..."
$FC $FFLAGS -c $STUB/qe_minimal.f90
echo "      OK"

# Paso 2: módulo de input (lee namelist &ELPH_MANAGER)
echo "[2/6] Compilando elph_mod_input.f90..."
$FC $FFLAGS -c $SRC/elph_mod_input.f90
echo "      OK"

# Paso 3: módulo de detección de estado
echo "[3/6] Compilando elph_mod_status.f90..."
$FC $FFLAGS -c $SRC/elph_mod_status.f90
echo "      OK"

# Paso 4: generador de ph_elph_auto.in
echo "[4/6] Compilando elph_mod_generate.f90..."
$FC $FFLAGS -c $SRC/elph_mod_generate.f90
echo "      OK"

# Paso 5: ejecutor de comandos
echo "[5/6] Compilando elph_mod_run.f90..."
$FC $FFLAGS -c $SRC/elph_mod_run.f90
echo "      OK"

# Paso 6: programa principal
echo "[6/6] Compilando elph_manager.f90 (programa principal)..."
$FC $FFLAGS -c $SRC/elph_manager.f90
echo "      OK"

# Link final
echo "--- Linkeando elph_manager.x ---"
$FC $FFLAGS -o elph_manager.x \
    qe_minimal.o \
    elph_mod_input.o \
    elph_mod_status.o \
    elph_mod_generate.o \
    elph_mod_run.o \
    elph_manager.o

echo ""
echo "=== BUILD EXITOSO: elph_manager.x listo ==="
