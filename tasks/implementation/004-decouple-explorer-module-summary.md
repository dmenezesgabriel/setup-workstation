---
id: "004"
created: 2026-05-18
status: done
---

# Implementation Summary: Decouple file-tree logic into `lua/explorer/` module

## Files Changed

- `config/nvim/lua/explorer/init.lua` — created (new module)
- `config/nvim/lua/sidebar_explorer.lua` — refactored
- `config/nvim/tests/sidebar_explorer_validation.lua` — updated
- `docs/adrs/002-explorer-module-boundary.md` — status changed to Accepted
- `~/.config/nvim/lua/explorer` — symlink created pointing to repo copy

## What Moved to Explorer Module

`config/nvim/lua/explorer/init.lua` exposes the following public functions:
- `M.normalize_path(path)` — wraps `vim.fs.normalize`
- `M.path_exists(path)` — wraps `uv.fs_stat`
- `M.scandir(path)` — lists and sorts directory entries
- `M.find_git_root(path)` — resolves nearest `.git` ancestor
- `M.get_ignored_lookup(root, paths)` — runs `git check-ignore` and returns a lookup table
- `M.resolve_root()` — resolves project root from current buffer context
- `M.build_entries(root, expanded)` — collects raw entry tables with `ignored` flags set; no display strings

Private helpers kept inside the module: `is_directory`, `get_name`, `sort_entries`, `notify`, `system_list`, `get_root_search_path`.

The module has no `require("ui.*")` or `require("config")` imports.

## What Stayed in sidebar_explorer

- `local config` table (width, ignored_highlight, root_markers)
- `local state` table (bufnr, winid, source_winid, root, expanded, line_entries)
- `local notify` (sidebar-local error reporting)
- `local build_lines(root, expanded)` — calls `explorer.build_entries()` then applies icons and `file_status_renderer.get_indicator()` to produce display strings
- `local is_sidebar_buffer`, `get_edit_window`, `close_window`, `ensure_buffer`, `apply_highlights`, `render`, `open_sidebar_window` — all window/buffer management
- `M.refresh`, `M.toggle`, `M.open_or_toggle`, `M.collapse_or_parent`, `M.setup` — public API unchanged
- `local explorer = require("explorer")` and `local file_status_renderer = require("ui.file_status_renderer")` at the top
- The `M._test` escape hatch was removed

## Tests Updated

`config/nvim/tests/sidebar_explorer_validation.lua`:
- Changed `require("sidebar_explorer")` to `require("explorer")`
- Replaced `explorer._test.*` calls with direct `explorer.*` calls
- Replaced display-string assertions (`lines[1]`, `has_line_suffix`) with entry-property assertions (`entry.name`, `entry.type`, `entry.expanded`, `entry.depth`)
- Removed `has_line_suffix` helper (no longer needed)
- Updated IT-002 scenario to use `build_entries` and `find_entry` instead of checking line strings

No other test files were modified.

## Validation Results

All six test suites pass with exit code 0:
- `tests/sidebar_explorer_validation.lua` — ok
- `tests/crash_and_refresh_fixes_test.lua` — ok
- `tests/shell_cmd_refresh_test.lua` — ok
- `tests/git_status_data_layer_test.lua` — ok
- `tests/file_explorer_git_indicators_test.lua` — ok
- `tests/gutter_renderer_test.lua` — ok

## ADR Updated

`docs/adrs/002-explorer-module-boundary.md` status changed from `Proposed` to `Accepted`.
