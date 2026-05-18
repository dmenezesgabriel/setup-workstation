---
id: "003"
created: 2026-05-18
updated: 2026-05-18
status: active
---

# Task: Auto-refresh sidebar explorer after shell commands

## Priority

P0 — This is the only task; it fixes the reported bug and unblocks nothing else.

## Dependencies

- No task dependency; this is a self-contained bug fix.
- No ADR dependency; this task uses the existing autocmd and refresh architecture already in place.

## Assignability

**AFK** — all requirements and acceptance criteria are fully resolved; the change is a one-autocmd addition mirroring an existing pattern in the same function.

## Context

The sidebar explorer (`config/nvim/lua/sidebar_explorer.lua`) already handles file-system changes caused by buffer writes via a `BufWritePost` autocmd in `M.setup()` (lines 535–547). This handler calls `file_status_renderer.refresh()` followed by `render()` when the sidebar window is open.

When the user runs `:!rm <file>` (or any `:!<cmd>` shell invocation), Neovim fires the `ShellCmdPost` event after the command exits. Because no `ShellCmdPost` handler exists, the sidebar keeps showing the deleted file until the user closes and reopens the explorer.

The fix is to add a `ShellCmdPost` autocmd to the `SidebarExplorer` augroup inside `M.setup()`, using the same guard and refresh pattern already used for `BufWritePost`:

```lua
vim.api.nvim_create_autocmd("ShellCmdPost", {
    group = sidebar_augroup,
    callback = function()
        if state.root and state.winid and vim.api.nvim_win_is_valid(state.winid) then
            file_status_renderer.refresh(state.root, function()
                if state.winid and vim.api.nvim_win_is_valid(state.winid) then
                    render()
                end
            end)
        end
    end,
})
```

`render()` calls `build_lines()` → `scandir()` → `vim.fs.dir()`, which reads the real filesystem, so deleted or created files will be picked up automatically. The `file_status_renderer.refresh()` call updates the git-status cache so git indicators (e.g. `D` for deleted) also update correctly.

## Use Cases

- **Feature**: Sidebar explorer filesystem sync
- **Scenario**: User deletes a file from the Neovim command line
- **Given** the sidebar explorer is open and showing a file named `foo.py`
- **When** the user runs `:!rm foo.py`
- **Then** `foo.py` disappears from the sidebar without requiring the user to close and reopen the explorer

---

- **Scenario**: User creates a file from the Neovim command line
- **Given** the sidebar explorer is open
- **When** the user runs `:!touch bar.py`
- **Then** `bar.py` appears in the sidebar without requiring a manual refresh

## Definition of Ready

- `sidebar_explorer.lua` is understood: `M.setup()` owns all autocmds; `SidebarExplorer` augroup is created at the top of `setup()`; `render()` and `file_status_renderer.refresh()` are already callable from that scope.
- The `BufWritePost` autocmd (lines 535–547) is the reference pattern for the new handler.
- No ADR stub is needed; the fix uses existing architecture.

## Functional Requirements

- `FR-001`: After any `:!<cmd>` shell command completes, the sidebar explorer must re-render its tree if it is currently open, reflecting any filesystem changes (files deleted, created, or renamed by the shell command).
- `FR-002`: After a shell command, the git-status indicators in the sidebar (e.g. `D`, `?`, `M`) must also update to reflect the current git state.
- `FR-003`: If the sidebar is closed when the shell command runs, no refresh or render must be attempted.

## Non-Functional Requirements

- `NFR-001`: The refresh must be debounced through the existing `file_status_renderer.refresh()` mechanism (300 ms debounce defined in `config.lua`) to avoid redundant git-status calls when shell commands complete in rapid succession.
- `NFR-002`: The new autocmd must be added to the existing `SidebarExplorer` augroup so it is cleared correctly on re-setup.

## Observability Requirements

- Not applicable — this is a UI-only refresh fix in a local Neovim plugin with no logging, metrics, or tracing infrastructure.

## Acceptance Criteria

- `AC-001`: **Given** the sidebar is open and shows `foo.py`, **When** the user runs `:!rm foo.py`, **Then** `foo.py` is no longer listed in the sidebar within 500 ms of the command completing.
- `AC-002`: **Given** the sidebar is open, **When** the user runs `:!touch bar.py` inside the explorer root, **Then** `bar.py` appears in the sidebar within 500 ms of the command completing.
- `AC-003`: **Given** the sidebar is closed, **When** the user runs `:!rm foo.py`, **Then** no error is raised and no render is attempted.
- `AC-004`: **Given** the sidebar is open, **When** a file tracked by git is deleted via `:!rm`, **Then** the git indicator updates to reflect the deletion (no stale `M` or `S` symbol for the now-deleted path).

## Required Tests

### Unit Tests

- `UT-001`: Verify that a `ShellCmdPost` autocmd is registered in the `SidebarExplorer` augroup after `require("sidebar_explorer").setup()` is called. Covers `FR-001`.

### Integration Tests

- `IT-001`: **Scenario**: Sidebar re-renders after shell deletion  
  **Given** a temporary directory with `foo.lua` and the sidebar open at that root  
  **When** `ShellCmdPost` is fired programmatically via `vim.api.nvim_exec_autocmds`  
  **Then** a subsequent call to `render()` produces lines that no longer include `foo.lua` (after the file is deleted with `vim.fn.delete`)  
  Covers `FR-001`, `AC-001`.

### Smoke Tests

Not applicable — this is a local Neovim Lua plugin with no deploy or startup surface.

### End-to-End Tests

Not applicable — the autocmd event can be fired directly in the integration test; no full user-journey runner is needed.

### Regression Tests

- `REG-001`: **Scenario**: Sidebar does not crash when `ShellCmdPost` fires with no sidebar open  
  **Given** `sidebar_explorer.setup()` has been called but the sidebar window is not open  
  **When** `ShellCmdPost` is fired programmatically  
  **Then** no error is raised  
  Covers `AC-003` and guards against the nil-winid crash pattern previously fixed in `crash_and_refresh_fixes_test.lua`.

### Performance Tests

Not applicable — no measurable performance constraint; the debounce is already handled by `file_status_renderer.refresh()`.

### Security Tests

Not applicable — no authentication, authorization, input handling, or trust-boundary changes.

### Usability Tests

Not applicable — the fix is invisible to the user (automatic sidebar refresh); no validation placement or empty-state concern.

### Observability Tests

Not applicable — no logs, metrics, or traces are introduced or modified.

## Definition of Done

- `ShellCmdPost` autocmd is added to `M.setup()` in `config/nvim/lua/sidebar_explorer.lua` inside the `SidebarExplorer` augroup.
- `UT-001`, `IT-001`, and `REG-001` pass when run with `nvim --headless -l tests/<file>.lua`.
- `AC-001` through `AC-004` are verified manually or via the integration test.
- No existing tests in `tests/` regress.
