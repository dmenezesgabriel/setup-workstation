---
id: "005"
created: 2026-05-18
updated: 2026-05-18
status: active
---

# Task: Mouse click support for sidebar explorer

## Priority

P1 — Depends on task 004 (decouple explorer). The keymap must be added to the post-refactor `ensure_buffer()` in `sidebar_explorer.lua`. Can begin immediately after task 004 is done.

## Dependencies

- Depends on Task 004: `tasks/issues/004-decouple-explorer-module.md` — `ensure_buffer()` must be in its final post-refactor location before adding keymaps.
- No ADR dependency; this task uses existing architecture (`ensure_buffer`, `M.open_or_toggle`).

## Assignability

**AFK** — all requirements and acceptance criteria are fully resolved; no irreversible architectural decisions remain open; safe to delegate once task 004 is complete.

## Context

`vim.opt.mouse = "a"` is already set in `init.lua`, enabling mouse support across the whole session. The sidebar explorer buffer uses `buftype=nofile` with buffer-local keymaps for keyboard navigation (`<CR>`, `l`, `h`, `r`, `q`), but has no mouse bindings.

In Neovim, a `<LeftMouse>` event in normal mode first moves the cursor to the clicked line (handled by Neovim internally), then fires the keymap. Mapping `<LeftMouse>` buffer-locally to `M.open_or_toggle()` is therefore sufficient — it reads the cursor position after the click lands.

`<2-LeftMouse>` (double-click) also fires after `<LeftMouse>`. Without a mapping it triggers word selection in visual mode, which is undesirable in the sidebar. It should be mapped to `<Nop>` to suppress the default behavior while leaving the first-click action intact.

Both mappings go into `ensure_buffer()` alongside the existing keyboard keymaps.

## Use Cases

- **Feature**: Sidebar mouse interaction
- **Scenario**: User clicks a file in the sidebar
- **Given** the sidebar is open and the user has a mouse
- **When** the user left-clicks a file entry
- **Then** the file opens in the edit window, matching the behavior of pressing `<CR>`

---

- **Scenario**: User clicks a directory in the sidebar
- **Given** the sidebar is open showing a collapsed directory
- **When** the user left-clicks the directory entry
- **Then** the directory toggles open, matching the behavior of pressing `l`

---

- **Scenario**: User double-clicks in the sidebar
- **Given** the sidebar is open
- **When** the user double-clicks any entry
- **Then** no visual selection is started; the first click's action (open/toggle) already fired

## Definition of Ready

- Task 004 is complete: `sidebar_explorer.lua` is the post-refactor presentation layer with `ensure_buffer()` in its final form.
- `M.open_or_toggle()` is stable and handles both files and directories correctly.

## Functional Requirements

- `FR-001`: A `<LeftMouse>` buffer-local keymap is registered on the sidebar buffer in `ensure_buffer()`. It calls `M.open_or_toggle()`.
- `FR-002`: A `<2-LeftMouse>` buffer-local keymap is registered on the sidebar buffer in `ensure_buffer()`. It maps to `<Nop>` to suppress visual selection on double-click.
- `FR-003`: Clicking a file entry opens it in the edit window (`get_edit_window()` target), exactly as `<CR>` does.
- `FR-004`: Clicking a directory entry toggles its expanded state and re-renders the sidebar, exactly as `<CR>` does.
- `FR-005`: The mouse keymaps are only active in the sidebar buffer; they must not affect other buffers.

## Non-Functional Requirements

- `NFR-001`: The two new keymap calls follow the same `vim.keymap.set("n", ..., { buffer = state.bufnr, silent = true })` pattern used by all existing sidebar keymaps.
- `NFR-002`: No new functions, modules, or state fields are introduced; the change is two `vim.keymap.set` calls added inside `ensure_buffer()`.

## Observability Requirements

Not applicable — keymap additions have no logging, metrics, or tracing surface.

## Acceptance Criteria

- `AC-001`: **Given** the sidebar is open, **When** the user left-clicks a file entry, **Then** the file opens in the edit window.
- `AC-002`: **Given** the sidebar is open showing a collapsed directory, **When** the user left-clicks the directory, **Then** the directory expands and children appear in the sidebar.
- `AC-003`: **Given** the sidebar is open showing an expanded directory, **When** the user left-clicks the directory, **Then** the directory collapses and children disappear.
- `AC-004`: **Given** the sidebar is open, **When** the user double-clicks any entry, **Then** no visual selection is started and the cursor stays in normal mode.
- `AC-005`: **Given** the sidebar buffer exists, **When** buffer-local keymaps are inspected for `<LeftMouse>` and `<2-LeftMouse>`, **Then** both are registered.

## Required Tests

### Unit Tests

- `UT-001`: After `sidebar_explorer.setup()` and `ensure_buffer()` creation, assert that a buffer-local keymap for `<LeftMouse>` exists on the sidebar buffer. Covers `FR-001`, `AC-005`.
- `UT-002`: After `sidebar_explorer.setup()` and `ensure_buffer()` creation, assert that a buffer-local keymap for `<2-LeftMouse>` exists on the sidebar buffer. Covers `FR-002`, `AC-005`.

### Integration Tests

Not applicable — the mouse interaction itself requires a real UI session and cannot be exercised headlessly. `UT-001` and `UT-002` verify registration; AC-001 through AC-004 are verified manually.

### Smoke Tests

Not applicable — no deploy surface.

### End-to-End Tests

Not applicable — mouse clicks cannot be replayed headlessly; AC-001 through AC-004 require manual verification.

### Regression Tests

- `REG-001`: **Scenario**: Existing keyboard keymaps are unaffected  
  **Given** the two mouse keymaps are added to `ensure_buffer()`  
  **When** all existing test suites are run headlessly  
  **Then** all suites pass with no new failures  
  Covers `NFR-001`.

### Performance Tests

Not applicable — two keymap registrations have no measurable performance impact.

### Security Tests

Not applicable — no authentication, authorization, or trust-boundary changes.

### Usability Tests

Not applicable — no form, modal, or validation state is introduced; AC-001 through AC-004 cover the interaction directly.

### Observability Tests

Not applicable — no logs, metrics, or analytics introduced.

## Definition of Done

- `<LeftMouse>` and `<2-LeftMouse>` keymaps are added inside `ensure_buffer()` in `sidebar_explorer.lua`.
- `UT-001` and `UT-002` pass headlessly.
- `REG-001` passes: all pre-existing test suites continue to print `ok`.
- AC-001 through AC-004 are verified manually in an interactive Neovim session.
