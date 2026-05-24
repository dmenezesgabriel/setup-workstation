---
id: "003"
status: Proposed
date: 2026-05-24
related_tasks:
  - tasks/issues/004-localize-nvim-test-images.md
---

# ADR 003: Build local Neovim test images

## Status

Proposed

## Date

2026-05-24

## Related Tasks

- `tasks/issues/004-localize-nvim-test-images.md`

## Context

The Neovim multi-version runner needs `v0.8.3`, `v0.9.5`, `v0.10.4`, and `stable`, but the expected upstream container images are not reliably available.
The test runner must remain lightweight and reproducible for local development.

## Decision

Build small repository-owned Docker images for each required Neovim version and install the matching Neovim binary during image build.
The runner will target those local images instead of pulling `ghcr.io/neovim/neovim:*`.

## Options Considered

1. Build versioned lightweight images that download/install official Neovim release artifacts during image build. `(recommended)`
2. Build Neovim from source inside each image.
3. Keep depending on upstream images and treat registry availability as an external prerequisite.

## Consequences

Positive:
- The runner no longer depends on unavailable upstream images.
- Build inputs are explicit and live in the repository.
- The test matrix becomes reproducible for local development.

Negative:
- The repository now owns image build maintenance.
- The build may still depend on upstream release artifact availability.
- `stable` can change over time unless pinned during build.

## Validation

- Build each image locally and confirm `nvim --headless -u NONE --version` reports the expected version.
- Run `./config/nvim/run_tests.sh` and confirm the matrix completes without registry-denied errors.
- Verify the final summary line still reads `Total: N passed, M failed`.

## Open Questions

- Should `stable` be resolved dynamically at build time or pinned to a specific released version for repeatability?
- Should the images be built with a shared Dockerfile and version build arg, or separate Dockerfiles per version?
