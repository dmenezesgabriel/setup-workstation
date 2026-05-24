---
id: "004"
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Task: Localize Neovim test images for the multi-version runner

## Priority

P1 — unblocks the multi-version test runner from relying on unavailable upstream images.

## Dependencies

- Depends on Task 003: Multi-version Neovim test runner script.
- Depends on ADR `docs/adrs/003-build-local-nvim-test-images.md`.
- Depends on the existing `config/nvim/tests/*.lua` test matrix.

## Assignability

**AFK** — the image strategy, target versions, and verification behavior are fully specified once the ADR is accepted.

## Context

The current runner tries to execute `ghcr.io/neovim/neovim:v0.8.3`, `v0.9.5`, `v0.10.4`, and `stable`, but those images are not available in practice.
This task replaces that dependency with lightweight local Docker images that install the required Neovim versions during image build, so the runner can execute the full matrix without depending on upstream containers.

## Use Cases

- **Feature**: Multi-version Neovim test environment
- **Scenario**: A developer runs the compatibility matrix locally
- **Given** Docker is available on the host
- **When** the versioned images are built and `./config/nvim/run_tests.sh` is executed
- **Then** the script runs each test file against each local Neovim image and prints the matrix

## Definition of Ready

- ADR `docs/adrs/003-build-local-nvim-test-images.md` exists and is accepted.
- The required Neovim versions remain `v0.8.3`, `v0.9.5`, `v0.10.4`, and `stable`.
- The runner contract from Task 003 remains unchanged.

## Functional Requirements

- `FR-001`: The repository provides a lightweight Docker build path for each required Neovim version.
- `FR-002`: Each image installs the matching Neovim version without depending on the unavailable `ghcr.io/neovim/neovim` images.
- `FR-003`: The multi-version runner uses the locally built images and still executes every `config/nvim/tests/*.lua` file against every required version.
- `FR-004`: The `stable` target resolves to a current stable Neovim build at image build time.

## Non-Functional Requirements

- `NFR-001`: The image build path remains simple enough to run from the repository without additional tooling beyond Docker and bash.
- `NFR-002`: Images should be as small and reproducible as practical for a developer test helper.
- `NFR-003`: Re-running the build and test flow with unchanged inputs should produce the same runner outcome.

## Observability Requirements

- `OBS-001`: When a version build or run fails, the command output must include the image tag and version label that failed.
- `OBS-002`: The final test runner summary continues to report `Total: N passed, M failed` as the last line.

## Acceptance Criteria

- `AC-001`: **Given** Docker is available, **When** the local Neovim images are built and the runner is executed, **Then** the full version/test matrix completes without trying to pull `ghcr.io/neovim/neovim:*`.
- `AC-002`: **Given** the requested Neovim version is `v0.8.3`, `v0.9.5`, `v0.10.4`, or `stable`, **When** the corresponding image is built, **Then** that image contains the matching Neovim binary and can run `nvim --headless -u NONE`.
- `AC-003`: **Given** one version fails, **When** the runner completes, **Then** the failure output names the version and test file and the script exits non-zero.
- `AC-004`: **Given** no source inputs change, **When** the images and runner are executed twice, **Then** the observable pass/fail result is the same.

## Required Tests

### Unit Tests

- `UT-001`: Not applicable — this task is a Docker build-and-run workflow, not isolated pure logic.

### Integration Tests

- `IT-001`: **Scenario**: Versioned Docker image boots Neovim
  **Given** one versioned local image has been built
  **When** the image runs `nvim --headless -u NONE --version`
  **Then** the expected Neovim version is reported
  **And** the container exits 0
  Covers `FR-001`, `FR-002`, `AC-002`.

### Smoke Tests

- `SMK-001`: **Scenario**: Runner works against locally built images
  **Given** the local versioned images exist
  **When** `./config/nvim/run_tests.sh` is executed
  **Then** the full matrix runs without registry-denied errors
  Covers `FR-003`, `AC-001`.

### End-to-End Tests

- `E2E-001`: **Scenario**: Compatibility matrix runs end-to-end on all versions
  **Given** the local images are built and the compat shim is in place
  **When** the runner executes all test files against all versions
  **Then** the matrix prints a result for every version/test combination
  **And** the script exits 0 only when all combinations pass
  Covers `FR-003`, `AC-001`, `AC-003`.

### Regression Tests

- `REG-001`: Not applicable — there is no prior defect case beyond the missing upstream images already captured by the new runner task.

### Performance Tests

- `PT-001`: Not applicable — the task optimizes developer workflow but does not set a measurable runtime constraint.

### Security Tests

- `ST-001`: Not applicable — the task does not change authentication, authorization, or data exposure boundaries.

### Usability Tests

- `UX-001`: Not applicable — the task changes build/runtime plumbing rather than user-facing UI.

### Observability Tests

- `OT-001`: Verify that a failing version run prints the version and test file before the final summary line. Covers `OBS-001`, `OBS-002`.

## Definition of Done

- The local image build path is documented or encoded in the repository.
- The runner no longer depends on unavailable upstream Neovim images.
- The full matrix can be executed with Docker alone.
- Any new build scripts or Dockerfiles pass a basic syntax check or build validation.
