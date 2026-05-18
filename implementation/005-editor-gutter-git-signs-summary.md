# Implementation Summary: 005 Editor Gutter Git Signs

## Files Created

- `config/nvim/lua/ui/gutter_renderer.lua` — new module
- `config/nvim/tests/gutter_renderer_test.lua` — test suite

## Files Modified

- `config/nvim/init.lua` — added `require("ui.gutter_renderer").setup()` after `require("sidebar_explorer").setup()`

## What Was Done

`gutter_renderer.lua` implements FR-001 through FR-007:

- `setup()` registers autocommands for `BufWritePost`, `BufEnter`, and `FocusGained` that schedule a debounced render via `vim.uv.new_timer()` per buffer.
- `render()` (internal) clears the `"git_gutter"` namespace, calls `git_diff.get(path, false)` and `git_diff.get(path, true)` to collect unstaged and staged line changes, merges them (staged wins on conflict), then places extmarks via `nvim_buf_set_extmark` using `cfg.symbols` and `cfg.highlights`.
- Line numbers are converted from 1-based (`LineChanges` format) to 0-based (Neovim API) with `lnum - 1`.
- Non-file buffers (`buftype ~= ""` or no name) are skipped before any git invocation.
- `BufDelete` handler stops and closes any pending timer for the deleted buffer.
- `M._render = render` exposes the internal function for testing.

## Tests

All seven test cases pass under `nvim --headless`:

- UT-001: extmarks placed at correct 0-based lines after render
- UT-002: stale signs cleared on re-render (no accumulation)
- UT-003: nofile/scratch buffer produces no extmarks
- IT-001: real temp git repo file gets extmarks after modification
- IT-002: second render count does not exceed first render count
- IT-003: non-git file produces no extmarks
- OT-001: `vim.notify` is never called for non-git buffers (covered within IT-003)

## All test suites

```
gutter_renderer_test: ok
file_explorer_git_indicators_test: ok
git_status_data_layer_test: ok
sidebar_explorer_validation: ok
```
