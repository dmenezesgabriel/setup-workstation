---
id: "001"
created: 2026-05-17
updated: 2026-05-17
status: active
---

# Task: Add native Nvim sidebar file explorer

## Priority

P0 — Required first to prove the core sidebar explorer behavior before adding git-ignore styling.

## Dependencies

- Depends on `config/nvim/init.lua` as the current Neovim entrypoint.
- No task dependency; this is the first tracer-bullet slice.
- No ADR dependency; this task uses existing architecture.

## Assignability

**AFK** — all requirements and acceptance criteria are resolved; no irreversible architectural decisions remain open.

## Context

- `config/nvim/init.lua` is a single-file Neovim configuration with custom keymaps, autocommands, and LSP setup.
- The current setup relies on built-in `:Explore`, which does not provide the VS Code-like persistent sidebar experience requested.
- The new explorer should be implemented in pure Lua without external plugins, and should open as a dedicated sidebar that lets the user browse directories and open files from the current working tree.

## Use Cases

- **Feature**: Native sidebar explorer
- **Scenario**: Developer opens a project sidebar while editing code
- **Given** the user is editing a file inside a project
- **When** the user toggles the explorer sidebar
- **Then** a dedicated side window shows the project tree and keeps the editing window available

- **Feature**: Native sidebar explorer
- **Scenario**: Developer navigates folders and opens a file
- **Given** the explorer sidebar is visible
- **When** the user expands a directory and selects a file
- **Then** the selected file opens in the editing area

## Definition of Ready

- The implementation keeps the no-plugin constraint.
- The explorer root behavior is defined as project root when available, otherwise current working directory.
- The sidebar toggle keymap and buffer-local navigation keys are documented in `config/nvim/README.md`.

## Functional Requirements

- `FR-001`: The user can toggle a dedicated file explorer sidebar from normal mode.
- `FR-002`: The sidebar renders directories and files from the resolved explorer root in a hierarchical tree.
- `FR-003`: The user can expand and collapse directories from the sidebar without leaving normal mode.
- `FR-004`: Selecting a file in the sidebar opens that file in the previous editing window and keeps the sidebar available.
- `FR-005`: The sidebar buffer is non-modifiable, dedicated to navigation, and does not behave like a normal editing buffer.

## Non-Functional Requirements

- `NFR-001`: The implementation uses only Neovim built-in Lua APIs and shell commands already available on the workstation.
- `NFR-002`: Explorer code is separated from unrelated editor setup so `config/nvim/init.lua` remains maintainable.
- `NFR-003`: The sidebar opens in under 200 ms for typical repository roots in this dotfiles repository.

## Observability Requirements

- `OBS-001`: User-facing failures such as unreadable directories or failed file opens are surfaced with `vim.notify` messages.
- `OBS-002`: The explorer must not print debug output during normal navigation.
- `OBS-003`: Error notifications must include the affected path without exposing unrelated buffer contents.

## Acceptance Criteria

- `AC-001`: **Given** a file inside this repository is open, **When** the user triggers the explorer toggle, **Then** a left sidebar opens and shows the repository tree from the resolved root.
- `AC-002`: **Given** the sidebar is open on a collapsed directory, **When** the user triggers expand on that directory, **Then** its immediate children become visible in the sidebar.
- `AC-003`: **Given** the sidebar is open on an expanded directory, **When** the user triggers collapse on that directory, **Then** its descendants are hidden from the sidebar.
- `AC-004`: **Given** the cursor is on a file entry in the sidebar, **When** the user triggers open, **Then** the file opens in the editing window and the sidebar remains usable.
- `AC-005`: **Given** the sidebar is open, **When** the user triggers the toggle again, **Then** the sidebar closes without affecting the current file buffer.

## Required Tests

Choose the smallest meaningful test set for this task.
Do not create tests only to satisfy a category.
If a category is not relevant, write `Not applicable — <specific reason>`.

### Unit Tests

- `UT-001`: Validate tree-line generation for mixed file and directory entries, including indentation and expansion state. Covers `FR-002`, `FR-003`.
- `UT-002`: Validate explorer root resolution prefers project markers and falls back to current working directory. Covers `FR-001`.

### Integration Tests

- `IT-001`: **Scenario**: Sidebar opens and lists repository entries  
  **Given** Neovim starts with `config/nvim/init.lua` inside this repository  
  **When** the user runs the sidebar toggle command  
  **Then** the explorer buffer opens in a side window  
  **And** the buffer shows at least the root-level entries for the repository  
  Covers `FR-001`, `FR-002`, `AC-001`.
- `IT-002`: **Scenario**: File opens from the sidebar  
  **Given** the explorer sidebar is open and focused on a visible file entry  
  **When** the user triggers the open action  
  **Then** the target file loads in the editing window  
  **And** the sidebar buffer stays open and non-modifiable  
  Covers `FR-004`, `FR-005`, `AC-004`.

### Smoke Tests

- `SMK-001`: **Scenario**: Neovim loads with the custom config after adding the explorer  
  **Given** the updated `config/nvim/init.lua` is present  
  **When** Neovim starts with `nvim -u init.lua init.lua` from `config/nvim/`  
  **Then** startup completes without Lua errors  
  Covers release confidence for `FR-001`.

### End-to-End Tests

- `E2E-001`: Not applicable — this repository is a local Neovim configuration, so the meaningful boundary is Neovim integration rather than a broader application journey.

### Regression Tests

- `REG-001`: Not applicable — no known previous defect was identified for the requested explorer behavior.

### Performance Tests

- `PT-001`: Open the explorer at the repository root and verify first render completes under 200 ms for this repository size. Covers `NFR-003`.

### Security Tests

- `ST-001`: Validate file open actions use escaped full paths so entries with spaces or shell-sensitive characters do not trigger command injection or path truncation. Covers `FR-004`.

### Usability Tests

- `UX-001`: Verify the sidebar shows clear entry markers for directories versus files so navigation is understandable without extra documentation. Covers `AC-001`, `AC-002`.
- `UX-002`: Verify the documented keymaps are buffer-local to the explorer and do not override normal editing behavior outside the sidebar. Covers `FR-005`.

### Observability Tests

- `OT-001`: Force a read failure on an invalid path and verify the explorer shows a `vim.notify` error with the path and no stack-trace spam. Covers `OBS-001`, `OBS-003`.
- `OT-002`: Trigger successful navigation and verify no debug messages are printed. Covers `OBS-002`.

## Definition of Done

- Explorer behavior is implemented behind a dedicated Lua module or clearly isolated section rather than mixed into unrelated settings.
- Required tests for this task pass.
- Sidebar toggle, expand, collapse, and open behaviors work from the real Neovim UI.
- Failure handling uses `vim.notify` and avoids noisy debug output.
- `config/nvim/README.md` documents the new sidebar workflow and keymaps.
