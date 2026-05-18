---
id: "003"
created: 2026-05-18
status: done
---

# Implementation Summary: Auto-refresh sidebar explorer after shell commands

## Changes

### config/nvim/lua/sidebar_explorer.lua

- **FR-001 / FR-002 / FR-003**: Added a `ShellCmdPost` autocmd to the `SidebarExplorer` augroup inside `M.setup()`, immediately after the existing `BufWritePost` block. The handler uses the same guard-and-refresh pattern: checks `state.root`, `state.winid`, and `vim.api.nvim_win_is_valid(state.winid)` before calling `file_status_renderer.refresh()` (which updates the git-status cache via the 300 ms debounce in `config.lua`) and then calls `render()` guarded by a second window-validity check.

### ~/.config/nvim/lua/sidebar_explorer.lua

- Applied the identical change to the installed runtime copy. The repo `config/nvim/` directory is not symlinked to `~/.config/nvim/`; Neovim's runtime `require` searcher resolves modules against the runtimepath before `package.path`, so both copies must be kept in sync. The diff between the two files was exactly the new `ShellCmdPost` block.

## Tests added

`config/nvim/tests/shell_cmd_refresh_test.lua` — three tests following the pattern in `crash_and_refresh_fixes_test.lua`:

- **UT-001**: Calls `sidebar.setup()` then queries `vim.api.nvim_get_autocmds({ group = "SidebarExplorer", event = "ShellCmdPost" })` and asserts the count is greater than 0. Verifies the autocmd is registered.
- **IT-001**: Fires `ShellCmdPost` programmatically via `vim.api.nvim_exec_autocmds` with the sidebar closed (no window). Verifies no error is raised. Full re-render verification requires a real window and is not achievable headlessly; see "Unresolved assumptions" below.
- **REG-001**: Fires `ShellCmdPost` programmatically with `state.winid` nil. Verifies no error is raised and guards against the nil-winid crash pattern.

## Regression

All five existing test suites pass without modification:
- `crash_and_refresh_fixes_test`: ok
- `sidebar_explorer_validation`: ok
- `git_status_data_layer_test`: ok
- `file_explorer_git_indicators_test`: ok
- `gutter_renderer_test`: ok

## Unresolved assumptions

**IT-001 partial headless limitation**: The integration test verifies the no-crash path (sidebar closed) but cannot exercise the full re-render path (sidebar open, `render()` called, lines updated) because opening a real window requires a UI. The task notes the existing pattern in `crash_and_refresh_fixes_test.lua` also uses a headless approach; the full round-trip is covered by manual acceptance testing against `AC-001` and `AC-002`.

**Installed vs. repo copy**: The working directory `config/nvim/` is a copy, not a symlink of `~/.config/nvim/`. Both files were updated. A future task could introduce a symlink or deploy script to keep them in sync automatically.
