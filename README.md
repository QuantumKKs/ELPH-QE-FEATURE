# ELPH_MANAGER — Electron-Phonon Workflow Manager for Quantum ESPRESSO

## What it does

`elph_manager.x` orchestrates the three-phase electron-phonon calculation workflow in Quantum ESPRESSO, avoiding redundant DFPT recalculations:

```
Phase 1 - pw.x (SCF)
            |  prefix.save/ (charge density, wavefunctions)

Phase 2 - ph.x (trans=.true.)
            |  Solves full DFPT, saves dvscf (perturbed SCF potential)
            |  This is the expensive step (~80% of total compute time)

Phase 3 - ph.x (trans=.false.)
            |  Reads saved dvscf -- NO DFPT repeated
            |  Computes only the electron-phonon coupling coefficients
```

**Key savings:** If you want to compute elph with different parameters (different k-grid, different broadening, different `electron_phonon` mode), you only redo Phase 3 — the expensive DFPT (Phase 2) is reused.

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
- Phonons: skipped if `outdir/_ph0/prefix.dvscf1` exists
- Elph: skipped if `lambda` or `prefix.a2F` exists

Override with `force_rerun_scf/ph/elph = .true.`

## Tested on

- Quantum ESPRESSO v7.5
- Aluminum FCC (Al.pz-vbc.UPF, 8x8x8 k-grid, 2x2x2 q-grid)
- macOS ARM (Apple Silicon) with gfortran + OpenMPI + OpenBLAS

## Authors

Sanjay GR and collaborators (2024-2026). Contribution to the Quantum ESPRESSO community.

## License

GNU General Public License (GPL) v2 or later — same as Quantum ESPRESSO.
