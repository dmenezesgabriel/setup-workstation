---
id: "004"
created: 2026-05-18
updated: 2026-05-18
status: active
---

# Task: File explorer git status indicators

## Priority

P1 — Depends on Task 003. Delivers the visible git indicators in the sidebar explorer.

## Dependencies

- Depends on Task 003 (`issues/003-git-status-data-layer.md`): requires `git/status.lua` and `config.lua`.
- Depends on ADR `docs/adrs/001-git-status-provider-contract.md` for the `FileStatus` shape.

## Assignability

**AFK** — all requirements and acceptance criteria are fully specified; integration point with `sidebar_explorer.lua` is well-understood from existing code.

## Context

The sidebar explorer (`lua/sidebar_explorer.lua`) already renders file entries and marks ignored files via `entry.ignored`. This task adds a file status indicator symbol (e.g. `M`, `A`, `D`) to each entry line, sourced from `git/status.lua`.

A new module `ui/file_status_renderer.lua` handles symbol/highlight mapping so `sidebar_explorer.lua` stays free of git command knowledge. The renderer is called during the existing `render()` cycle; no new render path is introduced.

Debouncing uses `vim.uv.new_timer()` to rate-limit `git/status.lua` calls on explorer refresh. The cached `FileStatus` table is stored in the renderer's module state and reused between renders until the timer fires.

The `ignored` indicator continues to come from the existing `get_ignored_lookup` mechanism. `file_status_renderer` checks `entry.ignored` first before consulting the FileStatus map.

## Use Cases

- **Feature**: File explorer git status indicators
- **Scenario**: User opens the sidebar in a git repository
- **Given** the sidebar is toggled open on a git repository
- **When** the explorer renders
- **Then** each file with a tracked git status shows a status symbol at the end of its line

- **Scenario**: User saves a file
- **Given** the sidebar is open
- **When** a buffer is saved (`BufWritePost`)
- **Then** the explorer refreshes its git status within the debounce window and re-renders

- **Scenario**: Explorer opened outside a git repository
- **Given** the current directory has no `.git` ancestor
- **When** the sidebar renders
- **Then** no status symbols appear and no error is shown

## Definition of Ready

- Task 003 is complete: `git/status.lua` and `lua/config.lua` exist and pass tests.
- ADR 001 is accepted.

## Functional Requirements

- `FR-001`: Create `lua/ui/file_status_renderer.lua` with a `render(line_entries, file_status_map)` function that returns a list of `{ symbol, highlight }` pairs (one per entry, empty string for no status).
- `FR-002`: Symbol and highlight group for each status come from `lua/config.lua`. Priority order when multiple statuses apply: `partial` > `staged` > `modified` > `added` > `deleted` > `renamed` > `untracked`. If `entry.ignored` is true, the `ignored` indicator is shown only when no tracked status is present.
- `FR-003`: `sidebar_explorer.lua`'s `build_lines` appends the status symbol to each file entry line (not directory entries). Highlights are applied via `apply_highlights` using the existing namespace approach.
- `FR-004`: A debounce timer (from `config.debounce_ms`) rate-limits `git/status.lua` calls. The cached result is stored in the renderer's module state. On first open, the status is fetched synchronously (before first render) to avoid a blank-then-update flash.
- `FR-005`: Refresh is triggered on: `sidebar_explorer.lua`'s `M.refresh()` call and `BufWritePost` autocommand (when the saved buffer is under the explorer's current root).
- `FR-006`: When `git/status.lua` returns an empty table (non-git directory), no symbols or highlights are shown.

## Non-Functional Requirements

- `NFR-001`: `sidebar_explorer.lua` must not call `git/status.lua` directly; it calls `file_status_renderer` functions only.
- `NFR-002`: No external Lua packages.

## Observability Requirements

- `OBS-001`: No user-facing notifications for git errors in the renderer; silent fallback to no indicators.

## Acceptance Criteria

- `AC-001`: **Given** a git repository with a modified file, **When** the sidebar opens, **Then** the modified file's line ends with the configured `modified` symbol (e.g. `M`).
- `AC-002`: **Given** a staged file, **When** the sidebar renders, **Then** the file's line shows the `staged` symbol.
- `AC-003`: **Given** a partially staged file, **When** the sidebar renders, **Then** the file's line shows the `partial` symbol (takes priority over `modified`/`staged`).
- `AC-004`: **Given** an untracked file, **When** the sidebar renders, **Then** the file's line shows the `untracked` symbol.
- `AC-005`: **Given** a file with `entry.ignored = true` and no tracked status, **When** the sidebar renders, **Then** the file's line shows the `ignored` symbol.
- `AC-006`: **Given** a file with both `entry.ignored = true` and a tracked status, **When** the sidebar renders, **Then** the tracked status symbol is shown (tracked status takes priority over ignored).
- `AC-007`: **Given** the explorer is open and a file is saved, **When** the save triggers `BufWritePost`, **Then** the explorer re-renders with updated status within `config.debounce_ms` milliseconds.
- `AC-008`: **Given** a non-git directory, **When** the explorer renders, **Then** no status symbols appear and no error is shown.
- `AC-009`: **Given** the `build_lines` function runs, **When** an entry is a directory, **Then** no status symbol is appended to its line.

## Required Tests

### Unit Tests

- `UT-001`: Call `file_status_renderer.render(entries, file_status_map)` with a mock entries list and mock FileStatus table; assert correct symbol and highlight for each status type. Covers `FR-001`, `FR-002`, `AC-001`–`AC-006`.
- `UT-002`: Assert that directory entries receive no symbol regardless of what the FileStatus map contains. Covers `AC-009`.
- `UT-003`: Assert priority order: a `partial` status beats `staged` which beats `modified`. Covers `FR-002`, `AC-003`.

### Integration Tests

- `IT-001`: **Scenario**: Modified file shows indicator in rendered lines  
  **Given** a temp git repo with a committed-then-modified file  
  **When** `build_lines` is called with the explorer root  
  **Then** the modified file's line string ends with the configured `modified` symbol  
  Covers `AC-001`, `FR-003`.

- `IT-002`: **Scenario**: Non-git directory produces no indicators  
  **Given** a temp directory with no `.git`  
  **When** `build_lines` is called  
  **Then** no line contains a status symbol  
  Covers `AC-008`.

### Smoke Tests

Not applicable — no standalone startup path.

### End-to-End Tests

Not applicable — no automated E2E harness.

### Regression Tests

Not applicable — no prior defect.

### Performance Tests

Not applicable — symbol appending is O(n) in the number of entries; no measurable latency concern.

### Security Tests

Not applicable — renderer only reads normalized data; no user input or shell commands.

### Usability Tests

- `UX-001`: Verify directory entries do not display a status symbol (visual clarity). Covers `AC-009`.

### Observability Tests

- `OT-001`: **Scenario**: Git error in renderer produces no notification  
  **Given** `vim.notify` is stubbed  
  **When** `git/status.lua` returns an empty table for a non-git directory  
  **Then** `vim.notify` is not called by the renderer  
  Covers `OBS-001`.

## Definition of Done

- `lua/ui/file_status_renderer.lua` created.
- `lua/sidebar_explorer.lua` updated to call the renderer; no direct git calls added.
- All unit and integration tests pass under `nvim --headless`.
- Debounce timer correctly rate-limits refresh on save.
- `config.lua` symbols and highlights are used throughout; no hardcoded strings.
