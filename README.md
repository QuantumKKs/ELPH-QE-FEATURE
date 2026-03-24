# ELPH_MANAGER — Electron-Phonon Workflow Manager for Quantum ESPRESSO

## What it does

`elph_manager.x` orchestrates a five-phase electron-phonon calculation workflow in Quantum ESPRESSO, avoiding redundant DFPT recalculations and optionally computing phonon dispersions and electronic band structures:

```
Phase 1 — pw.x SCF
            |  prefix.save/ (charge density, wavefunctions)

Phase 2 — ph.x DFPT (trans=.true.)
            |  Solves full DFPT, saves dvscf (perturbed SCF potential)
            |  and prefix.dyn* (dynamical matrices)
            |  This is the expensive step (~80% of total compute time)

Phase 3 — q2r.x + matdyn.x  [optional: compute_matdyn=.true.]
            |  Fourier-transforms dynamical matrices to real space
            |  and computes phonon dispersion along a q-path → matdyn.freq

Phase 4 — ph.x elph (trans=.false.)
            |  Reads saved dvscf — NO DFPT repeated
            |  Computes electron-phonon coupling coefficients
            |  Produces lambda, prefix.dyn*.elph.*, prefix.a2F

Phase 5 — pw.x (bands) + bands.x  [optional: compute_bands=.true.]
            |  Non-self-consistent bands calculation along a k-path
            |  Produces prefix.bands.dat.gnu
```

**Key savings:** If you want to compute elph with different parameters (different broadening, different `electron_phonon` mode), you only redo Phase 4 — the expensive DFPT (Phase 2) is reused.

## Installation

Place the `ELPH_MANAGER/` directory inside the QE root directory (same level as `PW/`, `PHonon/`, etc.):

```
q-e/
├── PW/
├── PHonon/
├── Modules/
├── ELPH_MANAGER/      <- here
│   ├── src/
│   │   ├── elph_manager.f90
│   │   ├── elph_mod_input.f90
│   │   ├── elph_mod_status.f90
│   │   ├── elph_mod_generate.f90
│   │   ├── elph_mod_run.f90
│   │   └── Makefile
│   ├── Doc/
│   │   └── INPUT_ELPH_MANAGER.md
│   └── README.md
└── bin/
    └── elph_manager.x  <- installed here after make
```

### Build

```bash
cd ELPH_MANAGER/src
make
```

This requires QE to be already compiled (pw.x, ph.x). The Makefile reads `../../make.inc` from the QE root.

## Usage

```bash
cd /your/calculation/directory
elph_manager.x < elph_manager.in > elph_manager.out
```

## Required files

- `elph_manager.in` — workflow input (see `Doc/INPUT_ELPH_MANAGER.md`)
- `scf.in` — pw.x input (standard QE format)
- `ph.in` — ph.x input; **must** contain `fildvscf = 'dvscf'` and `diagonalization = 'cg'`

## Supported electron-phonon modes

| Mode | Description | SCF occupation required |
|------|-------------|------------------------|
| `simple` | Gaussian broadening on given k-grid | smearing |
| `interpolated` | BZ interpolation (Wierzbowska et al.) | smearing |
| `lambda_tetra` | Tetrahedron method for lambda(q,v) | tetrahedra |
| `gamma_tetra` | Tetrahedron method for gamma(q,v) | tetrahedra |
| `epa` | Electron-phonon averaged approx. | smearing |
| `ahc` | Anomalous Hall conductivity | smearing |
| `wannier` | Wannier interpolation | smearing |

## Smart caching

Each phase is skipped if its output already exists:

- SCF: skipped if `outdir/prefix.save/data-file-schema.xml` exists
- Phonons: skipped if `outdir/_ph0/prefix.dvscf1` exists (or `outdir/_ph0/prefix.q_1/prefix.dvscf1` for split q-point runs)
- Matdyn: skipped if `matdyn.freq` exists
- Elph: skipped if `lambda`, `lambda.dat`, `prefix.a2F`, or `prefix.dyn1.elph.1` exists
- Bands: skipped if `prefix.bands.dat.gnu` or `bands.dat.gnu` exists

Override with `force_rerun_scf = .true.`, `force_rerun_ph = .true.`, or `force_rerun_elph = .true.`.

## MPI execution

`pw.x`, `ph.x`, `q2r.x`, `matdyn.x`, and `bands.x` are called from PATH. No MPI prefix is configured in the namelist. Export the QE bin directory to PATH before running:

```bash
export PATH=/path/to/qe/bin:$PATH
elph_manager.x < elph_manager.in > elph_manager.out
```

## Example input — Aluminum FCC

```fortran
&ELPH_MANAGER
  prefix           = 'Al',
  outdir           = './tmp',
  pw_input_file    = 'scf.in',
  ph_input_file    = 'ph.in',
  pw_output_file   = 'scf.out',
  ph_output_file   = 'ph.out',
  elph_output_file = 'elph.out',
  electron_phonon  = 'simple',
  el_ph_nsigma     = 10,
  el_ph_sigma      = 0.02,
  compute_matdyn   = .true.,
  matdyn_qpath_file = 'Al_qpath.dat',
  compute_bands    = .true.,
  bands_kpath_file = 'Al_kpath.dat',
/
```

## Tested on

- Quantum ESPRESSO v7.5
- Aluminum FCC (Al.pz-vbc.UPF, 8x8x8 k-grid, 2x2x2 q-grid, electron_phonon='simple')
- Full 5-phase run completed: scf.out, ph.out, matdyn.freq, elph.out, Al.bands.dat.gnu
- macOS ARM (Apple Silicon) with gfortran + OpenMPI + OpenBLAS

## Authors

Sanjay Gopal Ramchandani and Fabian Jofré Parra. Contribution to the Quantum ESPRESSO community.

## License

GNU General Public License (GPL) v2 or later — same as Quantum ESPRESSO.
