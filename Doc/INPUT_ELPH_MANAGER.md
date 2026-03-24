# INPUT_ELPH_MANAGER — Reference Manual

`elph_manager.x` reads a single namelist `&ELPH_MANAGER` from standard input.

## Usage

```
elph_manager.x < elph_manager.in > elph_manager.out
```

## Namelist &ELPH_MANAGER

### File paths

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `prefix` | CHARACTER | `'pwscf'` | Same as in pw.x and ph.x inputs. Used to locate output files. |
| `outdir` | CHARACTER | `'./'` | Same as `outdir` in pw.x/ph.x. Directory for temporary files. |
| `pw_input_file` | CHARACTER | `'scf.in'` | Path to the pw.x input file (SCF). |
| `ph_input_file` | CHARACTER | `'ph.in'` | Path to the ph.x input file (phonons). Must contain `fildvscf` and `diagonalization='cg'`. |
| `pw_output_file` | CHARACTER | `'scf.out'` | Redirect stdout of pw.x here. |
| `ph_output_file` | CHARACTER | `'ph.out'` | Redirect stdout of ph.x (phase 2, DFPT) here. |
| `elph_output_file` | CHARACTER | `'elph.out'` | Redirect stdout of ph.x (phase 4, elph coupling) here. |

### Electron-phonon parameters

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `electron_phonon` | CHARACTER | `'lambda_tetra'` | Elph mode passed to ph.x. Options: `'simple'`, `'interpolated'`, `'lambda_tetra'`, `'gamma_tetra'`, `'epa'`, `'ahc'`, `'wannier'`. Note: `'lambda_tetra'` requires `occupations='tetrahedra'` in the SCF. For smearing-based SCF, use `'simple'`. |
| `el_ph_nsigma` | INTEGER | `10` | Number of Gaussian broadening values for elph. |
| `el_ph_sigma` | REAL | `0.02` | Gaussian broadening in Ry for elph. |

> **k-grid:** The k-grid for the elph calculation is read directly from `ph_input_file`. Do not attempt to override it here — QE reads the wavefunctions from the SCF run, and changing the k-grid dimensions would cause ph.x to fail.

### Workflow control

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `force_rerun_scf` | LOGICAL | `.false.` | If `.true.`, run pw.x even if `prefix.save/` already exists. |
| `force_rerun_ph` | LOGICAL | `.false.` | If `.true.`, run ph.x (phonons) even if dvscf files already exist. |
| `force_rerun_elph` | LOGICAL | `.false.` | If `.true.`, run ph.x (elph) even if lambda/a2F files already exist. |
| `verbose` | LOGICAL | `.true.` | Print detailed status messages. |
| `ph_split_qpoints` | LOGICAL | `.false.` | If `.true.`, run ph.x separately for each irreducible q-point. See below. |
| `nq_irr` | INTEGER | `0` | Number of irreducible q-points. Required when `ph_split_qpoints = .true.`. |

### Optional phase: phonon dispersion (q2r.x + matdyn.x)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `compute_matdyn` | LOGICAL | `.false.` | If `.true.`, run q2r.x and matdyn.x after the phonon phase to compute the phonon dispersion. |
| `matdyn_qpath_file` | CHARACTER | `''` | Path to the q-point path file for matdyn.x. Required when `compute_matdyn = .true.`. |
| `matdyn_output_file` | CHARACTER | `'matdyn.out'` | Redirect stdout of matdyn.x here. |

### Optional phase: electronic band structure (pw.x bands + bands.x)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `compute_bands` | LOGICAL | `.false.` | If `.true.`, run pw.x in bands mode and then bands.x after the SCF phase. |
| `bands_kpath_file` | CHARACTER | `''` | Path to the k-point path file for the bands calculation. Required when `compute_bands = .true.`. |
| `bands_output_file` | CHARACTER | `'bands.out'` | Redirect stdout of pw.x (bands) here. |
| `bandspp_output_file` | CHARACTER | `'bandspp.out'` | Redirect stdout of bands.x (post-processing) here. |

## Workflow

`elph_manager.x` runs up to five sequential phases:

```
Phase 1 — pw.x SCF          → prefix.save/
Phase 2 — ph.x DFPT         → dvscf, prefix.dyn*
Phase 3 — q2r.x + matdyn.x  → matdyn.freq  (optional: compute_matdyn=.true.)
Phase 4 — ph.x elph         → lambda, prefix.dyn*.elph.*
Phase 5 — pw.x + bands.x    → prefix.bands.dat.gnu  (optional: compute_bands=.true.)
```

**Key savings:** If you want to compute elph with different parameters (different broadening, different `electron_phonon` mode), you only redo Phase 4 — the expensive DFPT (Phase 2) is reused.

## Smart caching

`elph_manager.x` checks for existing output files before running each phase:

- **SCF done** if `outdir/prefix.save/data-file-schema.xml` exists.
- **Phonons done** if `outdir/_ph0/prefix.dvscf1` exists, or `outdir/_ph0/prefix.q_1/prefix.dvscf1` for split q-point runs.
- **Matdyn done** if `matdyn.freq` exists.
- **Elph done** if `lambda`, `lambda.dat`, `prefix.a2F`, or `prefix.dyn1.elph.1` exists.
- **Bands done** if `prefix.bands.dat.gnu` or `bands.dat.gnu` exists.

Use `force_rerun_*` flags to override caching for SCF, phonon, and elph phases.

## ph_split_qpoints mode

When `ph_split_qpoints = .true.`, the phonon phase runs each irreducible q-point as a separate ph.x invocation:

```
ph.x -in ph_q1.in > ph_q1.out  (start_q=1, last_q=1)
ph.x -in ph_q2.in > ph_q2.out  (start_q=2, last_q=2)
...
ph.x -in ph_qN.in > ph_qN.out  (start_q=N, last_q=N)
```

`elph_manager.x` generates `ph_q1.in`, `ph_q2.in`, ..., `ph_qN.in` automatically from `ph_input_file`, inserting `start_q=N, last_q=N` for each.

This is useful when:
- MPI resources are limited (each q-point job is smaller)
- You want to restart a single failed q-point without redoing all others
- You are running on a cluster where short jobs are scheduled faster

**Note:** `nq_irr` must be set manually. To find it, run `ph.x` once with your q-grid and check the output for "Number of q in the star". For typical systems: 2x2x2 FCC = 3 q-points, 4x4x4 FCC = 8 q-points.

## Required parameters in ph_input_file

For `elph_manager.x` to work correctly, `ph_input_file` (ph.in) **must** contain:

```fortran
fildvscf     = 'dvscf'     ! Tells ph.x where to save the dvscf
diagonalization = 'cg'     ! Avoids S-matrix numerical issues (recommended)
```

## Path file formats

**matdyn_qpath_file** — list of q-points with weights (crystal coordinates):

```
6
0.000 0.000 0.000  30
0.500 0.000 0.500  30
0.500 0.250 0.750  10
0.375 0.375 0.750  30
0.000 0.000 0.000  40
0.500 0.500 0.500  20
```

**bands_kpath_file** — same format (K_POINTS crystal_b content):

```
6
0.000 0.000 0.000  30
0.500 0.000 0.500  30
0.500 0.250 0.750  10
0.375 0.375 0.750  30
0.000 0.000 0.000  40
0.500 0.500 0.500  20
```

## MPI execution

`pw.x`, `ph.x`, `q2r.x`, `matdyn.x`, and `bands.x` are called from PATH. No MPI prefix is configured in the namelist. To run the QE binaries in parallel, export the correct PATH before launching `elph_manager.x`:

```bash
export PATH=/path/to/qe/bin:$PATH
elph_manager.x < elph_manager.in > elph_manager.out
```

## Example input — Aluminum FCC (complete 5-phase run)

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

This example was tested on Al FCC (Al.pz-vbc.UPF, 8x8x8 k-grid, 2x2x2 q-grid) with Quantum ESPRESSO v7.5 on macOS ARM. It produced: `scf.out`, `ph.out`, `elph.out` (with lambda values), `matdyn.freq` (phonon dispersion), and `Al.bands.dat.gnu` (electronic bands).

### Example with split q-points

```fortran
&ELPH_MANAGER
  prefix           = 'Fe',
  outdir           = './tmp',
  pw_input_file    = 'scf.in',
  ph_input_file    = 'ph.in',
  electron_phonon  = 'simple',
  ph_split_qpoints = .true.,
  nq_irr           = 13,
/
```
