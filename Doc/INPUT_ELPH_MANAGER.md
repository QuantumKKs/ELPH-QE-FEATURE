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
| `ph_output_file` | CHARACTER | `'ph.out'` | Redirect stdout of ph.x (phase 2) here. |
| `elph_output_file` | CHARACTER | `'elph.out'` | Redirect stdout of ph.x (phase 3) here. |

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

## Smart caching

`elph_manager.x` checks for existing output files before running each phase:

- **SCF done** if `outdir/prefix.save/data-file-schema.xml` exists.
- **Phonons done** if `outdir/_ph0/prefix.dvscf1` exists (or `prefix.q_N/prefix.dvscf1` for any q-point N).
- **Elph done** if `lambda` or `prefix.a2F` file exists.

Use `force_rerun_*` flags to override this caching.

## ph_split_qpoints mode

When `ph_split_qpoints = .true.`, the phonon phase runs each irreducible q-point as a separate ph.x invocation:

```
ph.x -in ph_q1.in > ph_q1.out  (start_q=1, last_q=1)
ph.x -in ph_q2.in > ph_q2.out  (start_q=2, last_q=2)
...
ph.x -in ph_qN.in > ph_qN.out  (start_q=N, last_q=N)
```

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

## MPI execution

`pw.x` and `ph.x` are called from PATH. To run them in parallel, add them to PATH before launching `elph_manager.x` with mpirun:

```bash
export PATH=/path/to/qe/bin:$PATH
mpirun -np 8 elph_manager.x < elph_manager.in > elph_manager.out
```

## Example input

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
  force_rerun_scf  = .false.,
  force_rerun_ph   = .false.,
  force_rerun_elph = .false.,
  verbose          = .true.,
/
```

### Example with split q-points

```fortran
&ELPH_MANAGER
  prefix        = 'Fe',
  outdir        = './tmp',
  pw_input_file = 'scf.in',
  ph_input_file = 'ph.in',
  electron_phonon  = 'simple',
  ph_split_qpoints = .true.,
  nq_irr           = 13,
/
```
