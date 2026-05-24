---
id: "004"
task: tasks/issues/004-localize-nvim-test-images.md
date: 2026-05-24
status: complete
---

# Implementation Summary: Local Neovim Test Images

## Files Changed

- `config/nvim/Dockerfile.nvim-test` — new Docker build for versioned local Neovim images
- `config/nvim/build_images.sh` — new helper that builds `v0.8.3`, `v0.9.5`, `v0.10.4`, and `stable`
- `config/nvim/run_tests.sh` — now builds and uses local images instead of `ghcr.io/neovim/neovim:*`
- `config/nvim/README.md` — documented the local image build flow

## Behavior Implemented

- Builds lightweight local Neovim images from the repository using Docker only
- Installs the requested Neovim release into each image during build
- Resolves `stable` at build time and selects the correct release asset for the local CPU architecture
- Updates the runner to build images automatically before running the matrix
- Runs every `config/nvim/tests/*.lua` file against every local versioned image
- Preserves the final `Total: N passed, M failed` summary line
- Prints version/image context on build failures and version/test/image context on run failures

## Tests Added or Updated

- None; this task changes Docker/build orchestration rather than pure logic

## Validations Run

- `bash -n config/nvim/build_images.sh config/nvim/run_tests.sh`
- `bash config/nvim/build_images.sh`
- `docker run --rm local/neovim-test:v0.8.3 nvim --headless -u NONE --version`
- `docker run --rm local/neovim-test:v0.9.5 nvim --headless -u NONE --version`
- `docker run --rm local/neovim-test:v0.10.4 nvim --headless -u NONE --version`
- `docker run --rm local/neovim-test:stable nvim --headless -u NONE --version`
- `bash config/nvim/run_tests.sh` → `Total: 32 passed, 0 failed`

## Accessibility Checks

- Not applicable; no UI was changed

## ADRs Updated

- None

## Intentional Non-applicable Test Categories

- UT, IT, REG, PT, ST, UX — marked not applicable in the task spec

## Unresolved Assumptions

- `stable` currently resolves to `v0.12.2`, so reproducibility for that tag depends on the latest upstream stable release at build time as allowed by the ADR/task
