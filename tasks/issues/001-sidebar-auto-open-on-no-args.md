---
id: "001"
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Task: Auto-open sidebar when nvim is started with no arguments

## Priority

P1 — Standalone UX improvement with no blockers; improves the default editing workflow without touching any other feature.

## Dependencies

- No task dependency; can start immediately.
- No ADR dependency; this task uses existing architecture — the `VimEnter` autocmd and `vim.fn.argc()` are stable Neovim primitives.

## Assignability

**AFK** — the change is fully contained in `lua/sidebar_explorer.lua`; all requirements and acceptance criteria are resolved; no irreversible architectural decisions remain open.

## Context

The sidebar explorer is already fully implemented and toggled with `<leader>e` or `:SidebarToggle`. Currently it is always closed on startup regardless of how nvim is invoked.

The desired behavior is:

- `nvim` (no arguments) → sidebar opens automatically.
- `nvim file.py`, `nvim .`, `nvim +10 file.py` etc. → sidebar stays closed.

`vim.fn.argc()` returns the count of command-line file/path arguments at runtime and is reliable inside a `VimEnter` callback (fires after Neovim has processed all startup arguments). `M.toggle()` in `sidebar_explorer.lua` already handles opening the sidebar from a closed state — it resolves the project root, expands it, refreshes git status, and opens the window.

The change belongs inside `M.setup()` in `lua/sidebar_explorer.lua`, where the `SidebarExplorer` augroup is already managed. Adding a `VimEnter` autocmd there keeps the behavior self-contained and does not pollute `init.lua`.

## Use Cases

- **Feature**: Sidebar auto-open on no-argument startup
- **Scenario**: Developer opens nvim to browse a project
- **Given** the developer runs `nvim` in a project directory with no file arguments
- **When** nvim finishes loading
- **Then** the sidebar explorer is open and showing the project root

---

- **Scenario**: Developer opens a specific file
- **Given** the developer runs `nvim src/main.py`
- **When** nvim finishes loading
- **Then** the sidebar is closed and `src/main.py` is the active buffer with full-width editing space

## Definition of Ready

- `lua/sidebar_explorer.lua` — `M.setup()` and `M.toggle()` are understood and stable.
- `VimEnter` autocmd pattern is confirmed to fire after `argc()` is populated.
- No pending refactors of `sidebar_explorer.lua` in flight.

## Functional Requirements

- `FR-001`: When nvim is started with zero file/path arguments (`vim.fn.argc() == 0`), the sidebar opens automatically after startup completes.
- `FR-002`: When nvim is started with one or more arguments, the sidebar remains closed on startup.
- `FR-003`: The auto-open behavior is implemented inside `M.setup()` in `lua/sidebar_explorer.lua` using a `VimEnter` autocmd registered in the existing `SidebarExplorer` augroup.

## Non-Functional Requirements

- `NFR-001`: The `VimEnter` autocmd fires `once = true` so it does not re-trigger on subsequent `:source` calls.
- `NFR-002`: The implementation must not add a new public option or change the `setup()` call in `init.lua`.

## Observability Requirements

- `OBS-001`: Not applicable — no logging, metrics, or tracing requirements for a startup UX behavior.

## Acceptance Criteria

- `AC-001`: **Given** nvim is launched with `nvim` and no arguments, **When** the `VimEnter` event fires, **Then** the sidebar window is visible and focused on the project root.
- `AC-002`: **Given** nvim is launched with `nvim somefile.lua`, **When** the `VimEnter` event fires, **Then** the sidebar window is not open and `somefile.lua` occupies the full editing area.
- `AC-003`: **Given** nvim is launched with `nvim .` (a directory argument), **When** the `VimEnter` event fires, **Then** the sidebar window is not open (`argc()` returns 1).
- `AC-004`: **Given** the sidebar is already open and the user runs `:source init.lua`, **When** setup re-runs, **Then** no duplicate `VimEnter` autocmd is added (the augroup is cleared with `clear = true`).

## Required Tests

### Unit Tests

- `UT-001`: Not applicable — the behavior is triggered by a Neovim lifecycle event (`VimEnter`); there is no pure logic function to unit-test in isolation.

### Integration Tests

- `IT-001`: **Scenario**: Sidebar opens on no-arg startup  
  **Given** nvim starts with `vim.fn.argc() == 0`  
  **When** the `VimEnter` autocmd fires  
  **Then** `state.winid` is non-nil and valid  
  Covers `FR-001`, `AC-001`.

- `IT-002`: **Scenario**: Sidebar stays closed on file-arg startup  
  **Given** nvim starts with `vim.fn.argc() == 1` (e.g. a file path)  
  **When** the `VimEnter` autocmd fires  
  **Then** `state.winid` is nil  
  Covers `FR-002`, `AC-002`.

### Smoke Tests

- `SMK-001`: Not applicable — this is a startup UX tweak, not a deploy/build path.

### End-to-End Tests

- `E2E-001`: Not applicable — no complete multi-step user journey changes.

### Regression Tests

- `REG-001`: Not applicable — no known previous defect being fixed.

### Performance Tests

- `PT-001`: Not applicable — opening one sidebar window at startup has no measurable performance risk.

### Security Tests

- `ST-001`: Not applicable — no authentication, authorization, input, or trust-boundary changes.

### Usability Tests

- `UX-001`: **Scenario**: Sidebar opens with focus in edit window after auto-open  
  Verify that after auto-open, the cursor is placed in the edit window (not stuck in the sidebar), so the user can start typing immediately. Covers `AC-001`.

### Observability Tests

- `OT-001`: Not applicable — no logs, metrics, or traces are involved.

## Definition of Done

- `lua/sidebar_explorer.lua` — `M.setup()` registers a `VimEnter` autocmd (once, in the `SidebarExplorer` augroup) that calls `M.toggle()` only when `vim.fn.argc() == 0`.
- `init.lua` is unchanged.
- `AC-001` through `AC-004` pass via manual verification.
- `IT-001` and `IT-002` pass (or are marked as manual given no test runner is wired to Neovim lifecycle events in this repo).
- `UX-001` verified manually: cursor is in the edit window, not the sidebar, after auto-open.
