---
id: "003"
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Task: Multi-version Neovim test runner script

## Priority

P1 — Depends on Task 002; the compat shim must exist before this script has something meaningful to verify across versions.

## Dependencies

- Depends on Task 002 (compat shim) — without the fix, the 0.8 run will fail for the wrong reason and the matrix provides no signal.
- Depends on Docker being available on the host (confirmed: Docker 29.5.0 present).
- Depends on `ghcr.io/neovim/neovim` image tags: `v0.8.3`, `v0.9.5`, `v0.10.4`, `stable`.

## Assignability

**AFK** — Docker, the test file list, the image registry, and the exit-code contract are all fully specified; no judgment calls required.

## Context

The existing tests in `config/nvim/tests/` run via `nvim --headless -u NONE -c "luafile <test>" -c "qa!"`. Each test prints `<name>: ok` on success and calls `error()` on failure, causing Neovim to exit non-zero.

The runner script mounts `config/nvim` read-only into each container, runs every test file against every target version, and prints a pass/fail matrix. It uses `nvim --headless -u NONE` (not `-l`) so it works on 0.8 as well as 0.9+.

```
ghcr.io/neovim/neovim:v0.8.3  ──┐
ghcr.io/neovim/neovim:v0.9.5  ──┤ ── mount config/nvim ── run each test ── matrix
ghcr.io/neovim/neovim:v0.10.4 ──┤
ghcr.io/neovim/neovim:stable  ──┘
```

The script exits 0 only when every test passes on every version.

## Use Cases

- **Feature**: Multi-version test runner
- **Scenario**: Developer verifies compatibility before pushing
- **Given** Docker is running and the compat shim is in place
- **When** `./config/nvim/run_tests.sh` is executed
- **Then** a pass/fail matrix is printed for every test × every Neovim version, and the script exits non-zero if any combination fails

---

- **Scenario**: Test fails on 0.8 after a code change
- **Given** a developer changes `gutter_renderer.lua` using a 0.10+ API without updating `compat.lua`
- **When** `./config/nvim/run_tests.sh` is executed
- **Then** the 0.8 row for `gutter_renderer_test` shows `FAIL` and the script exits 1

## Definition of Ready

- Task 002 is complete (compat shim in place and tested on the host version).
- All test files in `config/nvim/tests/` are known and listed.
- `ghcr.io/neovim/neovim` image availability confirmed for the four target tags.

## Functional Requirements

- `FR-001`: The script runs every `*.lua` file in `config/nvim/tests/` against Neovim `v0.8.3`, `v0.9.5`, `v0.10.4`, and `stable`.
- `FR-002`: Each test is run in an isolated Docker container; no state leaks between runs.
- `FR-003`: A test is `PASS` when Neovim exits 0; `FAIL` when it exits non-zero.
- `FR-004`: The script prints a sorted matrix of `PASS/FAIL  <version>/<test_name>` after all runs complete.
- `FR-005`: The script exits 0 only when all tests pass on all versions; exits 1 otherwise.
- `FR-006`: Failed runs print the captured output so the failure reason is visible without re-running manually.

## Non-Functional Requirements

- `NFR-001`: The script is a single self-contained shell file at `config/nvim/run_tests.sh` with no external tooling dependency beyond Docker and `bash`.
- `NFR-002`: Docker images are pulled automatically if not cached; no manual `docker pull` step.
- `NFR-003`: The script is idempotent; running it twice produces the same result.

## Observability Requirements

- `OBS-001`: For each FAIL, the script prints the full Docker run output (stdout + stderr) so the Lua error is visible inline.
- `OBS-002`: The final summary line reads `Total: N passed, M failed` and is always the last line printed.

## Acceptance Criteria

- `AC-001`: **Given** all tests pass, **When** `run_tests.sh` is executed, **Then** it prints a matrix with all `PASS` and exits 0.
- `AC-002`: **Given** a test errors on 0.8 only, **When** `run_tests.sh` is executed, **Then** the 0.8 row shows `FAIL`, the Lua error is printed, and the script exits 1.
- `AC-003`: **Given** Docker is not running, **When** `run_tests.sh` is executed, **Then** it fails fast with a clear error message before attempting any test.
- `AC-004`: **Given** the script is run twice in a row, **When** no files have changed, **Then** the output and exit code are identical.

## Required Tests

### Unit Tests

- `UT-001`: Not applicable — the script is a pure shell orchestrator; its logic (exit-code passthrough, output capture, matrix printing) is verified end-to-end by the smoke tests below.

### Integration Tests

- `IT-001`: Not applicable — the script delegates entirely to Docker and `nvim --headless`; there are no internal boundaries to test in isolation.

### Smoke Tests

- `SMK-001`: **Scenario**: Script runs successfully on the host version  
  **Given** Docker is running and the compat shim is in place  
  **When** `./config/nvim/run_tests.sh` is executed  
  **Then** the `stable` column shows all `PASS` and the script exits 0  
  Covers `FR-001`, `FR-003`, `AC-001`.

- `SMK-002`: **Scenario**: Docker unavailable produces a clear error  
  **Given** Docker daemon is stopped  
  **When** `./config/nvim/run_tests.sh` is executed  
  **Then** the script prints a human-readable error and exits 1 before running any test  
  Covers `AC-003`.

### End-to-End Tests

- `E2E-001`: **Scenario**: Compat shim passes on all four versions  
  **Given** Task 002 is complete  
  **When** `./config/nvim/run_tests.sh` is executed  
  **Then** the matrix shows `PASS` for every test on every version  
  Covers `FR-001`, `FR-004`, `FR-005`, `AC-001`.

### Regression Tests

- `REG-001`: Not applicable — no previous defect to guard against.

### Performance Tests

- `PT-001`: Not applicable — the script is a developer tool; total wall-clock time is bounded by Docker image pulls and is not a measurable performance constraint.

### Security Tests

- `ST-001`: Not applicable — the script mounts the config directory read-only and does not expose any trust boundary beyond what Docker already provides.

### Usability Tests

- `UX-001`: Failed run output includes the version, test name, and Lua error without requiring the developer to re-run in verbose mode. Covers `FR-006`, `OBS-001`.

### Observability Tests

- `OT-001`: The final summary line `Total: N passed, M failed` is always the last line of output. Covers `OBS-002`.

## Definition of Done

- `config/nvim/run_tests.sh` is executable and passes `bash -n` (syntax check).
- Running the script with all tests passing on the host version exits 0.
- Running the script after introducing a deliberate 0.8 breakage (e.g. adding a bare `vim.uv` call) causes the 0.8 row to show `FAIL` and the script to exit 1.
- No temporary files or containers are left behind after a run.
