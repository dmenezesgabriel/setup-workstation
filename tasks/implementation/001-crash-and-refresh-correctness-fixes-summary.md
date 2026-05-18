---
id: "001"
created: 2026-05-18
status: done
---

# Implementation Summary: Crash prevention and refresh correctness fixes

## Changes

### config/nvim/lua/sidebar_explorer.lua

- **FR-001**: Added `state.winid and vim.api.nvim_win_is_valid(state.winid)` guard to the cursor restoration block in `render()`. Buffer content updates remain unconditional.
- **FR-002**: Added `local sidebar_augroup = vim.api.nvim_create_augroup("SidebarExplorer", { clear = true })` at the start of `M.setup()`. The `BufWritePost` autocmd is now registered under this group.
- **FR-004**: Replaced the `BufWritePost` handler body: now calls only `file_status_renderer.refresh(state.root, on_done)` where `on_done` calls `render()` guarded by `state.winid` validity. Removed the direct `M.refresh()` call and the redundant `file_status_renderer.refresh(state.root)` call that was inside `M.refresh()`.

### config/nvim/lua/ui/file_status_renderer.lua

- **FR-003**: `M.refresh(root, on_done?)` now accepts an optional callback. Captures the timer as local `t`; the debounce callback checks `timer ~= t` before proceeding, preventing stale callbacks from overwriting `cached_status` or calling `on_done` after cancellation.

### config/nvim/lua/git/diff.lua

- **FR-005**: `M.get` now passes `vim.fs.normalize(path)` to `M._parse` so the returned table key is always a normalized path. `M._parse` is unchanged.

## Tests added

`config/nvim/tests/crash_and_refresh_fixes_test.lua` — three unit tests:

- **UT-001**: Verifies `M.refresh()` with no open sidebar (nil winid) does not raise.
- **UT-002**: Verifies stale `on_done` is not called after `refresh_sync` cancels the pending timer.
- **UT-003**: Verifies `diff.get` returns a table keyed by the normalized path.

## Regression

All four existing test suites pass: `sidebar_explorer_validation`, `git_status_data_layer_test`, `file_explorer_git_indicators_test`, `gutter_renderer_test`.
