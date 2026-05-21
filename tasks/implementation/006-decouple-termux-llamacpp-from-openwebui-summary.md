---
id: "006"
created: 2026-05-20
status: done
---

# Implementation Summary: Decouple Termux llama.cpp from OpenWebUI

## Files Changed

- `termux/scripts/12-llamacpp.sh`
- `termux/scripts/14-openwebui-llamacpp-auto.sh`
- `termux/scripts/15-auto-tune-llamacpp.sh`
- `termux/scripts/16-monitor-llamacpp.sh`
- `termux/scripts/17-estimate-memory.sh`
- `termux/scripts/17-estimate-memory.py`
- `termux/scripts/00-bootstrap-openwebui-llamacpp.sh`

## What Was Added

### Standalone llama.cpp build outputs

`termux/scripts/12-llamacpp.sh` now configures `llama.cpp` with both tools and server support enabled and attempts to build standalone targets for:

- `llama-cli`
- `llama-server` / `server`
- fallback utility targets when available

This makes the Termux setup capable of CLI, single-model server, and router mode without depending on OpenWebUI.

### Generic llama.cpp runtime helper

`termux/scripts/14-openwebui-llamacpp-auto.sh` now installs a generic helper at `~/.local/bin/llamacpp` and uses a neutral home directory default of `~/.local/llamacpp`.

Supported commands:

- `llamacpp router`
- `llamacpp router-start|router-stop|router-status`
- `llamacpp server [model]`
- `llamacpp server-start [model]`
- `llamacpp server-stop|server-status`
- `llamacpp cli [model] [extra args]`
- `llamacpp stop|status`

The helper:

- loads `config.env` when present
- auto-discovers the first `.gguf` model when no explicit model is passed
- keeps router/server PID and log files separate
- preserves the OpenWebUI compatibility flow by keeping router mode available

### Aliases

`termux/scripts/14-openwebui-llamacpp-auto.sh` now writes idempotent zsh aliases for both standalone llama.cpp usage and OpenWebUI-compatible router usage:

- `llama-router`, `llama-router-start`, `llama-router-stop`, `llama-router-status`
- `llama-server`, `llama-server-start`, `llama-server-stop`, `llama-server-status`
- `llama-cli`, `llamacpp-status`
- `owui-start`, `owui-stop`, `owui-status`

### Neutralized llama.cpp state path

The supporting scripts now default to `~/.local/llamacpp` while remaining compatible with the previous `ROUTER_DIR` environment variable:

- `termux/scripts/15-auto-tune-llamacpp.sh`
- `termux/scripts/16-monitor-llamacpp.sh`
- `termux/scripts/17-estimate-memory.sh`
- `termux/scripts/17-estimate-memory.py`

### Bootstrap updates

`termux/scripts/00-bootstrap-openwebui-llamacpp.sh` now documents and uses the decoupled flow:

- builds standalone llama.cpp binaries
- starts router mode through `~/.local/bin/llamacpp`
- prints the standalone aliases for server and CLI usage

## Requirements Covered

- llama.cpp can be started without OpenWebUI
- standalone server mode is available
- router mode remains available for OpenWebUI
- CLI mode is available
- aliases are installed for the common modes
- OpenWebUI compatibility is preserved instead of removed

## Validation Results

Ran successfully:

- `shellcheck termux/scripts/12-llamacpp.sh termux/scripts/14-openwebui-llamacpp-auto.sh termux/scripts/15-auto-tune-llamacpp.sh termux/scripts/16-monitor-llamacpp.sh termux/scripts/17-estimate-memory.sh termux/scripts/00-bootstrap-openwebui-llamacpp.sh`
- `python3 -m py_compile termux/scripts/17-estimate-memory.py`
- `bash -n termux/scripts/12-llamacpp.sh termux/scripts/14-openwebui-llamacpp-auto.sh termux/scripts/15-auto-tune-llamacpp.sh termux/scripts/16-monitor-llamacpp.sh termux/scripts/17-estimate-memory.sh termux/scripts/00-bootstrap-openwebui-llamacpp.sh`

## Intentional Non-Applicable Test Categories

- No unit/integration test suite exists for these Termux shell installers.
- No accessibility checks were applicable.
- No ADR update was required.

## Follow-up

- The legacy `termux/scripts/13-openwebui-llamacpp.sh` entrypoint has been removed as part of the cleanup.
- `README.md` documents only the current decoupled flow and the canonical `~/.local/llamacpp/models` location.
