# How to contribute ELPH_MANAGER to Quantum ESPRESSO

This document explains how to submit `elph_manager.x` as an official contribution
to the Quantum ESPRESSO (QE) open-source project.

## Overview of the process

QE is available on two platforms — use whichever you prefer:

| Platform | URL | Notes |
|----------|-----|-------|
| **GitLab** | https://gitlab.com/QEF/q-e | Primary development platform |
| **GitHub** | https://github.com/QEF/q-e | Also active, Pull Requests accepted |

The process is:
1. Fork the repository (GitLab or GitHub)
2. Create a feature branch
3. Add your code following QE conventions
4. Open a Merge Request (GitLab) or Pull Request (GitHub)
5. Respond to reviewer comments
6. Get merged into the `develop` branch

## Step-by-step guide

### 1. Fork the repository

**Option A — GitHub:**

Go to https://github.com/QEF/q-e and click **Fork**. Clone your fork:

```bash
git clone https://github.com/YOUR_USERNAME/q-e.git
cd q-e
git remote add upstream https://github.com/QEF/q-e.git
```

**Option B — GitLab:**

Go to https://gitlab.com/QEF/q-e and click **Fork**. Clone your fork:

```bash
git clone https://gitlab.com/YOUR_USERNAME/q-e.git
cd q-e
git remote add upstream https://gitlab.com/QEF/q-e.git
```

### 2. Create a feature branch

```bash
git checkout develop          # start from the develop branch
git pull upstream develop     # make sure it's up to date
git checkout -b feature/elph-manager
```

### 3. Add your code

Copy the `ELPH_MANAGER/` directory into the QE root:

```bash
cp -r /path/to/ELPH_MANAGER ./ELPH_MANAGER
```

Optionally, integrate with the top-level QE Makefile by adding a target in `Makefile`:

```makefile
elph_manager : pw ph
	$(MAKE) -C ELPH_MANAGER/src
```

### 4. Checklist before submitting

- [ ] Code compiles with `make -C ELPH_MANAGER/src` from the QE root
- [ ] `elph_manager.x` runs successfully on at least one test material (Al recommended)
- [ ] Input documentation in `Doc/INPUT_ELPH_MANAGER.md` is complete
- [ ] `README.md` explains the physics and usage
- [ ] All source files have the standard QE license header:
  ```fortran
  ! Copyright (C) 2024 Quantum ESPRESSO group
  ! This file is distributed under the terms of the
  ! GNU General Public License. See the file `License'
  ```
- [ ] No hardcoded paths (all paths come from input or make.inc)
- [ ] Code uses QE standard modules: `kinds`, `io_global`, `mp`, `mp_global`, `environment`
- [ ] Code compiles with both gfortran and ifort (if possible to test)

### 5. Open a Merge Request

```bash
git add ELPH_MANAGER/
git commit -m "Add elph_manager.x: automatic electron-phonon workflow manager

elph_manager.x orchestrates the pw.x -> ph.x(dvscf) -> ph.x(elph)
workflow, reusing the saved dvscf potential to avoid redundant DFPT
calculations when computing electron-phonon coupling coefficients.

Supports all electron_phonon modes available in ph.x, smart caching
of completed phases, MPI launcher configuration, and independent
q-point calculation mode for resource-limited environments."

git push origin feature/elph-manager
```

Then go to https://gitlab.com/YOUR_USERNAME/q-e/-/merge_requests/new and:
- Target branch: `QEF/q-e:develop`
- Title: `Add elph_manager.x: automatic electron-phonon workflow manager`
- Fill in the description template

### 6. What reviewers will check

Based on past QE MRs, expect reviewers to check:
- **Physics correctness**: Does the workflow actually reuse dvscf correctly?
- **QE conventions**: Module names, subroutine structure, error handling with `errore()`
- **Portability**: Works on Linux + macOS, gfortran + ifort
- **Documentation**: Is the input format documented in the QE style?
- **Tests**: Ideally add a test in `test-suite/` that runs a small elph calculation

### 7. Recommended contacts

- QE mailing list: users@lists.quantum-espresso.org
- QE developers list: developers@lists.quantum-espresso.org
- GitLab issues: https://gitlab.com/QEF/q-e/-/issues

Mention in your MR description that this was tested with QE v7.5 on macOS ARM and
Linux x86_64, and reference the physical motivation (avoiding DFPT repetition for
elph parameter sweeps).

## Test case to include

The `example/Al/` directory (or similar) should contain:

```
Al/
├── scf.in          (pw.x input, 8x8x8 k-grid)
├── ph.in           (ph.x input, 2x2x2 q-grid, fildvscf='dvscf')
├── elph_manager.in (elph_manager.x input)
├── pseudo/
│   └── Al.pz-vbc.UPF
└── reference/
    └── elph.out.ref (reference output for comparison)
```

Include a `run_example.sh` script:
```bash
#!/bin/bash
elph_manager.x < elph_manager.in > elph_manager.out
# Check lambda values
grep "lambda" elph.out | tail -5
```
