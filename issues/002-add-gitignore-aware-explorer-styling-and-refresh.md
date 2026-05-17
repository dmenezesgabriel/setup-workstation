---
id: "002"
created: 2026-05-17
updated: 2026-05-17
status: active
---

# Task: Add gitignore-aware explorer styling and refresh

## Priority

P1 — Depends on the core sidebar explorer because ignored-file styling only matters after the native tree exists.

## Dependencies

- Depends on Task 1: Add native Nvim sidebar file explorer.
- Depends on git metadata being available through the repository `.git` directory or `git` CLI.
- No ADR dependency; this task uses existing architecture.

## Assignability

**AFK** — all requirements and acceptance criteria are resolved; no irreversible architectural decisions remain open.

## Context

- The requested developer experience includes a VS Code-like cue where git-ignored files look visually de-emphasized.
- `config/nvim/init.lua` currently has custom highlight setup and can define additional highlight groups without plugins.
- After the core explorer exists, the tree needs a refresh strategy so ignored-state styling stays correct when the sidebar is reopened or manually refreshed.

## Use Cases

- **Feature**: Gitignore-aware explorer styling
- **Scenario**: Developer distinguishes ignored files from tracked files
- **Given** the explorer sidebar is open in a git repository
- **When** an entry matches git ignore rules
- **Then** that entry appears visually grayed compared with normal files

- **Feature**: Gitignore-aware explorer styling
- **Scenario**: Developer refreshes the sidebar after filesystem changes
- **Given** files or directories changed on disk
- **When** the user refreshes the explorer view
- **Then** the visible tree and ignored styling update to match the current filesystem state

## Definition of Ready

- Task 1 explorer rendering and navigation are working in Neovim.
- The ignored-state source is defined as real git ignore evaluation, not filename heuristics.
- A muted highlight group for ignored entries is defined and documented.

## Functional Requirements

- `FR-001`: The explorer detects whether a visible file or directory is ignored by git rules in the current repository.
- `FR-002`: Ignored entries render with a muted highlight distinct from normal entries while remaining readable.
- `FR-003`: Non-ignored entries keep the standard explorer styling and are not falsely muted.
- `FR-004`: The user can manually refresh the explorer tree to reload filesystem entries and git-ignore state.
- `FR-005`: When the explorer is opened outside a git repository, it still works and falls back to normal styling without errors.

## Non-Functional Requirements

- `NFR-001`: Git-ignore detection must not require any external Neovim plugin or Lua rock.
- `NFR-002`: Explorer refresh should avoid perceptible lag for typical directories in this repository during normal use.
- `NFR-003`: Highlight definitions must work with the current `slate` colorscheme and `termguicolors` setting.

## Observability Requirements

- `OBS-001`: Failures in git-ignore detection are surfaced with `vim.notify` only when they affect visible explorer behavior.
- `OBS-002`: The explorer must not emit repeated notifications during successful refreshes.
- `OBS-003`: If git metadata is unavailable, the fallback path is silent and leaves entries unmuted instead of crashing.

## Acceptance Criteria

- `AC-001`: **Given** the sidebar is open inside a git repository, **When** a file is matched by `.gitignore`, **Then** that file is displayed with the muted ignored highlight.
- `AC-002`: **Given** the sidebar is open inside a git repository, **When** a file is not matched by `.gitignore`, **Then** that file keeps the normal explorer highlight.
- `AC-003`: **Given** the sidebar is open and filesystem contents changed, **When** the user triggers refresh, **Then** added, removed, and ignored entries are redrawn to match the current state.
- `AC-004`: **Given** the explorer is opened in a directory without git metadata, **When** the tree renders, **Then** the sidebar remains functional and no ignore-detection error is shown.

## Required Tests

Choose the smallest meaningful test set for this task.
Do not create tests only to satisfy a category.
If a category is not relevant, write `Not applicable — <specific reason>`.

### Unit Tests

- `UT-001`: Validate ignored-state mapping applies the muted highlight only to entries returned as ignored. Covers `FR-001`, `FR-002`, `FR-003`.
- `UT-002`: Validate non-git directories use the fallback styling path without raising detection errors. Covers `FR-005`.

### Integration Tests

- `IT-001`: **Scenario**: Git-ignored files are muted in the explorer  
  **Given** a test repository with one tracked file and one ignored file  
  **When** the explorer renders the directory  
  **Then** the ignored file line uses the muted highlight  
  **And** the tracked file line uses the normal highlight  
  Covers `FR-001`, `FR-002`, `FR-003`, `AC-001`, `AC-002`.
- `IT-002`: **Scenario**: Explorer refresh updates ignore state and tree contents  
  **Given** the explorer is open on a git repository  
  **When** files are added or removed and the user triggers refresh  
  **Then** the visible entries are redrawn from the current filesystem state  
  **And** ignored styling is recalculated for the refreshed entries  
  Covers `FR-004`, `AC-003`.

### Smoke Tests

- `SMK-001`: **Scenario**: Explorer opens in a non-git directory  
  **Given** Neovim starts in a directory without `.git` metadata  
  **When** the user opens the sidebar explorer  
  **Then** the sidebar loads without crash or notification spam  
  Covers release confidence for `FR-005`.

### End-to-End Tests

- `E2E-001`: Not applicable — the behavior is fully exercised at the Neovim integration boundary and does not require a larger application journey.

### Regression Tests

- `REG-001`: Not applicable — no known previous defect was identified for ignored-file styling.

### Performance Tests

- `PT-001`: Refresh the explorer in this repository and verify ignored-state recalculation completes without perceptible lag during normal navigation. Covers `NFR-002`.

### Security Tests

- `ST-001`: Validate git-ignore detection handles paths with spaces and shell-sensitive characters safely when calling git, or uses argument lists that avoid shell interpolation. Covers `FR-001`, `FR-004`.

### Usability Tests

- `UX-001`: Verify muted ignored entries remain legible while clearly de-emphasized against the current colorscheme. Covers `FR-002`, `NFR-003`.
- `UX-002`: Verify the refresh action is documented and discoverable from `config/nvim/README.md`. Covers `FR-004`.

### Observability Tests

- `OT-001`: Simulate a git-ignore detection failure and verify the explorer emits at most one actionable notification for the affected refresh. Covers `OBS-001`, `OBS-002`.
- `OT-002`: Open the explorer outside a git repository and verify it falls back silently without notifications. Covers `OBS-003`.

## Definition of Done

- Ignored-entry highlighting is implemented in the native explorer without introducing plugins.
- Required tests for this task pass.
- Explorer refresh updates tree contents and ignored styling from the real filesystem state.
- The muted highlight integrates with the existing colorscheme and remains readable.
- `config/nvim/README.md` documents ignored-file styling and the refresh workflow.
