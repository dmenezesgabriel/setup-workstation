---
id: "005"
created: 2026-05-18
status: done
---

# Implementation Summary: Mouse click support for sidebar explorer

## Files Changed

- `config/nvim/lua/sidebar_explorer.lua` — two keymap additions inside `ensure_buffer()`
- `config/nvim/tests/mouse_support_test.lua` — created (new test file)

## What Was Added

### `config/nvim/lua/sidebar_explorer.lua`

Two `vim.keymap.set` calls were inserted inside `ensure_buffer()`, immediately after the existing `q` keymap:

- `<LeftMouse>` → calls `M.open_or_toggle()`, matching the behavior of `<CR>` and `l`.
- `<2-LeftMouse>` → maps to `<Nop>`, suppressing the default word-selection visual mode that Neovim triggers on double-click.

Both use the same `{ buffer = state.bufnr, silent = true }` pattern as all existing sidebar keymaps. No new functions, modules, or state fields were introduced.

### `config/nvim/tests/mouse_support_test.lua`

Two unit tests following the `shell_cmd_refresh_test.lua` style:

- `UT-001`: Calls `setup()` and `toggle()` (to trigger buffer creation), then inspects `vim.api.nvim_buf_get_keymap(bufnr, "n")` and asserts a keymap with `lhs == "<LeftMouse>"` exists.
- `UT-002`: Same approach, asserts a keymap with `lhs == "<2-LeftMouse>"` exists.

The `<LeftMouse>` and `<2-LeftMouse>` lhs string values were confirmed via a debug run before writing assertions — Neovim encodes them in angle-bracket notation exactly as written.

## Requirements Covered

- `FR-001`: `<LeftMouse>` buffer-local keymap registered in `ensure_buffer()`, calls `M.open_or_toggle()`.
- `FR-002`: `<2-LeftMouse>` buffer-local keymap registered in `ensure_buffer()`, maps to `<Nop>`.
- `FR-005`: Both keymaps use `{ buffer = state.bufnr }` — they only affect the sidebar buffer.
- `NFR-001`: Follows the existing `vim.keymap.set("n", ..., { buffer = state.bufnr, silent = true })` pattern.
- `NFR-002`: No new functions, modules, or state fields.
- `AC-005`: `UT-001` and `UT-002` verify keymap registration.

## Validation Results

All seven test suites pass with exit code 0:

- `tests/mouse_support_test.lua` — ok
- `tests/sidebar_explorer_validation.lua` — ok
- `tests/crash_and_refresh_fixes_test.lua` — ok
- `tests/shell_cmd_refresh_test.lua` — ok
- `tests/git_status_data_layer_test.lua` — ok
- `tests/file_explorer_git_indicators_test.lua` — ok
- `tests/gutter_renderer_test.lua` — ok

`REG-001` confirmed: no regressions in pre-existing suites.

## Manual Verification Required

AC-001 through AC-004 (actual mouse click behavior — open file, expand/collapse directory, suppress double-click selection) require manual testing in an interactive Neovim session with `vim.opt.mouse = "a"` active.
