---
id: "003"
task: tasks/issues/003-nvim-multi-version-test-runner.md
date: 2026-05-24
status: complete
---

# Implementation Summary: Neovim Multi-version Test Runner

## Files Changed

- `config/nvim/run_tests.sh` — new executable shell runner for the Neovim version matrix

## Behavior Implemented

- Runs every `config/nvim/tests/*.lua` file against `ghcr.io/neovim/neovim:v0.8.3`, `v0.9.5`, `v0.10.4`, and `stable`
- Uses isolated Docker containers with `--rm` and a read-only mount of `config/nvim`
- Captures and prints full failed run output inline
- Prints a sorted `PASS/FAIL  <version>/<test_name>` matrix after all runs complete
- Exits `0` only when every version/test combination passes; otherwise exits `1`
- Fails fast with a clear message if Docker is unavailable or the daemon is not running

## Tests Added or Updated

- None; this task adds a shell orchestrator only

## Validations Run

- `bash -n config/nvim/run_tests.sh`
- End-to-end script exercise with a temporary fake `docker` wrapper to verify:
  - matrix printing
  - failure output capture
  - non-zero exit on failure
  - summary line as the final line

## Accessibility Checks

- Not applicable; no UI was changed

## ADRs Updated

- None

## Intentional Non-applicable Test Categories

- UT, IT, REG, PT, ST, UX, OT — marked not applicable in the task spec

## Unresolved Assumptions

- Full Docker-backed validation was not run here; the script was verified with a fake Docker wrapper to exercise the orchestration and output contract without pulling Neovim images
