---
id: "007"
created: 2026-05-21
status: done
---

# Implementation Summary: Clean up Termux llama.cpp to a single current flow

## Files Changed

- `termux/scripts/14-openwebui-llamacpp-auto.sh`
- `README.md`
- `tasks/implementation/006-decouple-termux-llamacpp-from-openwebui-summary.md`
- `termux/scripts/13-openwebui-llamacpp.sh` — removed

## What Changed

- Removed the legacy `termux/scripts/13-openwebui-llamacpp.sh` entrypoint.
- Removed the legacy `~/.local/bin/start-llama-openwebui.sh` helper generation.
- Kept a single canonical helper: `~/.local/bin/llamacpp`.
- Kept a single canonical models directory default: `~/.local/llamacpp/models`.
- Updated `termux/scripts/14-openwebui-llamacpp-auto.sh` to auto-run `scripts/15-auto-tune-llamacpp.sh` before starting router mode, so a fresh install starts with the safe tuned config instead of risky defaults.
- Updated `termux/scripts/15-auto-tune-llamacpp.sh` so router mode remains conservative but still autoloads the requested model when serving requests.
- Updated `README.md` to document only the current flow.

## Fresh Start Validation

Validated the current flow in a clean temporary `HOME` with:

- existing built binaries from `~/src/llama.cpp/build/bin`
- a clean `~/.local/llamacpp`
- a model symlink placed in `~/.local/llamacpp/models`
- `scripts/14-openwebui-llamacpp-auto.sh` run from scratch

Confirmed:

- helper created at `~/.local/bin/llamacpp`
- safe config created at `~/.local/llamacpp/config.env`
- router started successfully on a test port
- `/v1/models` responded successfully
- router status/stop commands worked
- model autoloaded on first request and served a completion successfully
- router log showed projected memory usage reduced to about `526 MiB` for the tuned `Qwen3.5-0.8B-Q4_0` load

## Validation Results

Ran successfully:

- `shellcheck termux/scripts/00-bootstrap-openwebui-llamacpp.sh termux/scripts/12-llamacpp.sh termux/scripts/14-openwebui-llamacpp-auto.sh termux/scripts/15-auto-tune-llamacpp.sh termux/scripts/16-monitor-llamacpp.sh termux/scripts/17-estimate-memory.sh`
- `python3 -m py_compile termux/scripts/17-estimate-memory.py`
- `bash -n termux/scripts/00-bootstrap-openwebui-llamacpp.sh termux/scripts/12-llamacpp.sh termux/scripts/14-openwebui-llamacpp-auto.sh termux/scripts/15-auto-tune-llamacpp.sh termux/scripts/16-monitor-llamacpp.sh termux/scripts/17-estimate-memory.sh`

## Non-Applicable

- No accessibility checks required.
- No ADR updates required.
