# Project Context

This file defines the domain vocabulary for this project. Both plan-it and implement-it read it at session start to use consistent terminology in task names, requirements, acceptance criteria, test names, and code.

---

## Domain terms

### Sidebar Explorer

**Definition**: The custom Neovim file tree rendered in a left-anchored vertical split, implemented in `config/nvim/lua/sidebar_explorer.lua`.
**Usage**: `sidebar_explorer` module, `state.winid` / `state.bufnr`, `SidebarToggle` command.
**Constraints**: Only one sidebar window per tab. Width is fixed at `config.width` (default 32).

### Explorer Module

**Definition**: The pure data-layer module (`config/nvim/lua/explorer/init.lua`) that owns all file-tree and filesystem logic: directory scanning, git-ignore lookup, project-root resolution, and raw entry collection. It has no window, buffer, or UI dependencies.
**Usage**: `require("explorer")`, `explorer.build_entries(root, expanded)`, `explorer.resolve_root()`, `explorer.get_ignored_lookup(root, paths)`.
**Constraints**: Must not import `ui/file_status_renderer`, `ui/gutter_renderer`, or `config`. Display formatting (icons, status symbols) is the responsibility of `sidebar_explorer`, not `explorer`.

### Provider Contract

**Definition**: The Lua table shape and function signatures that any git status provider must satisfy, defined in `core/status_provider.lua`.
**Usage**: `require("core.status_provider")`, referenced in ADR `docs/adrs/001-git-status-provider-contract.md`.
**Constraints**: UI modules must depend on the contract shape, not on `git/status.lua` or `git/diff.lua` directly.

### Normalized File Status

**Definition**: A Lua table keyed by absolute file path, where each value is one of `"modified"`, `"added"`, `"deleted"`, `"renamed"`, `"untracked"`, `"ignored"`, `"staged"`, or `"partial"` (partially staged).
**Usage**: Returned by `git/status.lua`, consumed by `ui/file_status_renderer.lua`.
**Constraints**: Paths are always normalized via `vim.fs.normalize`. Unknown or unsupported XY combinations are omitted (not errored).

### Normalized Line Changes

**Definition**: A Lua table keyed by absolute file path, where each value is a table mapping line numbers to `"added"`, `"modified"`, `"deleted"`, or `"staged"`.
**Usage**: Returned by `git/diff.lua`, consumed by `ui/gutter_renderer.lua`.
**Constraints**: Line numbers are 1-based. Deleted lines map to the line immediately after the deletion point. Staged changes come from `git diff --cached --unified=0`.

### Gutter Sign

**Definition**: An extmark placed in the sign column of an editor buffer to indicate a line-level git change.
**Usage**: Managed by `ui/gutter_renderer.lua` using `vim.api.nvim_buf_set_extmark` in the `"git_gutter"` namespace.
**Constraints**: Stale signs must be cleared via `nvim_buf_clear_namespace` before each redraw.

### File Status Indicator

**Definition**: A symbol (e.g. `M`, `A`, `D`) appended to a file entry's display line in the sidebar explorer to show its git status.
**Usage**: Rendered by `ui/file_status_renderer.lua`, appended to lines produced by `sidebar_explorer.lua`'s `build_lines`.
**Constraints**: Only one indicator per file. Priority order when multiple statuses apply: `partial` > `staged` > `modified` > `added` > `deleted` > `renamed` > `untracked` > `ignored`.

### Debounce Timer

**Definition**: A `vim.uv.new_timer()` instance that delays a refresh callback by a configurable number of milliseconds, cancelling any pending call before scheduling a new one.
**Usage**: Used in both `ui/file_status_renderer.lua` and `ui/gutter_renderer.lua` to rate-limit git command invocations on save, `BufEnter`, and `FocusGained`.
**Constraints**: Timer must be stopped and closed before replacement to avoid leaks.

---

## Decisions and constraints

### Module loading

The existing `package.path` setup in `init.lua` already supports subdirectory modules: `config_dir .. "/lua/?.lua"` resolves `require("git.status")` to `lua/git/status.lua`. No `init.lua` changes are needed for module loading.

### Ignored file detection

The existing `get_ignored_lookup` in `sidebar_explorer.lua` (via `git check-ignore --stdin`) remains the canonical source for the `ignored` indicator. `git/status.lua` covers tracked-change statuses only (`--porcelain=v1 -z` without `--ignored`). The `file_status_renderer` checks `entry.ignored` (existing) before checking the normalized file status map (new).

---

## Out of scope

- Multi-tab or multi-window git status sync (status is per-tabpage).
- Inline blame or git log views.
- Staging/unstaging files from within Neovim (read-only indicators only).
- External Lua packages or plugins.
