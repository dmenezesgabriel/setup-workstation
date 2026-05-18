---
id: "005"
created: 2026-05-18
updated: 2026-05-18
status: active
---

# Task: Editor gutter git signs

## Priority

P1 — Depends on Task 003. Can be implemented in parallel with Task 004 once Task 003 is done.

## Dependencies

- Depends on Task 003 (`issues/003-git-status-data-layer.md`): requires `git/diff.lua` and `config.lua`.
- Depends on ADR `docs/adrs/001-git-status-provider-contract.md` for the `LineChanges` shape.

## Assignability

**AFK** — all requirements and acceptance criteria are fully specified; extmark API usage is well-defined in Neovim built-ins.

## Context

When a file is open in an editor window, the gutter (sign column) should show per-line indicators for added, modified, deleted, and staged changes. This task introduces `ui/gutter_renderer.lua`, which owns a `"git_gutter"` extmark namespace, clears stale signs before each redraw, and places new extmarks based on `git/diff.lua` output.

Autocommands trigger refreshes on `BufWritePost`, `BufEnter`, and `FocusGained`. A debounce timer (shared module state in the renderer) prevents redundant git invocations on rapid events.

Both unstaged (`git diff --unified=0`) and staged (`git diff --cached --unified=0`) changes are shown. Staged changes use a distinct symbol/highlight.

The renderer is wired into `init.lua` via `require("ui.gutter_renderer").setup()`. It is self-contained and does not call into `sidebar_explorer.lua`.

## Use Cases

- **Feature**: Editor gutter git signs
- **Scenario**: User edits a tracked file
- **Given** an editor buffer is open for a file inside a git repository
- **When** the user saves the file
- **Then** the sign column shows per-line indicators for added, modified, and deleted lines within the debounce window

- **Scenario**: User stages changes
- **Given** a file has staged hunks
- **When** the buffer is entered or focused
- **Then** staged lines show the `staged` indicator instead of (or in addition to) the unstaged indicator

- **Scenario**: Buffer is outside a git repository
- **Given** a buffer's file has no `.git` ancestor
- **When** `BufEnter` or `BufWritePost` fires
- **Then** no signs are placed and no error is shown

## Definition of Ready

- Task 003 is complete: `git/diff.lua` and `lua/config.lua` exist and pass tests.
- ADR 001 is accepted.
- `vim.api.nvim_buf_set_extmark` and `nvim_buf_clear_namespace` are available (Neovim ≥ 0.7, satisfied by the existing environment).

## Functional Requirements

- `FR-001`: Create `lua/ui/gutter_renderer.lua` with a `setup()` entry point that registers autocommands for `BufWritePost`, `BufEnter`, and `FocusGained`.
- `FR-002`: On each refresh, clear all extmarks in the `"git_gutter"` namespace for the buffer via `nvim_buf_clear_namespace`, then re-place extmarks for each changed line.
- `FR-003`: For each line in the `LineChanges` map, place an extmark using `nvim_buf_set_extmark` with `sign_text` (from `config.symbols`) and `sign_hl_group` (from `config.highlights`). Staged changes (from `git diff --cached`) use the `staged` symbol/highlight.
- `FR-004`: A debounce timer (`vim.uv.new_timer()`, delay from `config.debounce_ms`) is used per buffer. Each autocommand restarts the timer before scheduling the refresh callback.
- `FR-005`: When `git/diff.lua` returns an empty table (non-git file or error), all existing signs for the buffer are cleared and no new ones are placed.
- `FR-006`: Line numbers in extmarks are 0-based (Neovim API convention); convert from the 1-based `LineChanges` format.
- `FR-007`: `init.lua` calls `require("ui.gutter_renderer").setup()` once during startup.

## Non-Functional Requirements

- `NFR-001`: `gutter_renderer.lua` must not call `git/diff.lua` for non-file buffers (no file name, `buftype ~= ""`).
- `NFR-002`: No external Lua packages.
- `NFR-003`: The `"git_gutter"` namespace is created once via `nvim_create_namespace` and reused.

## Observability Requirements

- `OBS-001`: No user-facing notifications for git errors or non-git buffers; silent clear of existing signs.

## Acceptance Criteria

- `AC-001`: **Given** a tracked file with added lines is open in an editor buffer, **When** the buffer is saved, **Then** those line numbers show the `added` sign in the gutter within `config.debounce_ms` ms.
- `AC-002`: **Given** a tracked file with modified lines, **When** the buffer is entered, **Then** those lines show the `modified` sign.
- `AC-003`: **Given** a tracked file with deleted lines, **When** the buffer is saved, **Then** the line after the deletion point shows the `deleted` sign.
- `AC-004`: **Given** a file with staged hunks, **When** the buffer is focused, **Then** staged lines show the `staged` sign.
- `AC-005`: **Given** a buffer outside a git repository, **When** `BufWritePost` fires, **Then** no signs are placed and no error is shown.
- `AC-006`: **Given** signs are already present from a previous refresh, **When** a new refresh runs, **Then** all old signs are cleared before new ones are placed (no stale signs).
- `AC-007`: **Given** rapid `BufWritePost` events fire within `config.debounce_ms` ms of each other, **When** the debounce window elapses, **Then** only one git diff invocation occurs.
- `AC-008`: **Given** a non-file buffer (e.g. the sidebar explorer buffer), **When** `BufEnter` fires, **Then** no git diff is invoked.

## Required Tests

### Unit Tests

- `UT-001`: Given a mock `LineChanges` table and a real buffer created with `nvim_create_buf`, assert that `nvim_buf_get_extmarks` returns extmarks at the correct 0-based line positions with the correct sign text. Covers `FR-003`, `FR-006`, `AC-001`–`AC-004`.
- `UT-002`: Call refresh twice in succession; assert the namespace is cleared before the second placement (no duplicate signs). Covers `FR-002`, `AC-006`.
- `UT-003`: Call refresh on a buffer with `buftype = "nofile"`; assert no extmarks are placed. Covers `NFR-001`, `AC-008`.

### Integration Tests

- `IT-001`: **Scenario**: Added lines appear in the gutter after save  
  **Given** a temp git repo with a committed file, modified to add two lines  
  **When** a Neovim buffer is opened for the file and the gutter renderer runs  
  **Then** `nvim_buf_get_extmarks` returns extmarks at those two line positions with the `added` sign text  
  Covers `AC-001`, `FR-003`.

- `IT-002`: **Scenario**: Stale signs are cleared on re-render  
  **Given** a buffer with existing gutter extmarks from a previous render  
  **When** the renderer runs again  
  **Then** `nvim_buf_get_extmarks` returns only the signs from the latest render  
  Covers `AC-006`, `FR-002`.

- `IT-003`: **Scenario**: Non-git buffer produces no signs  
  **Given** a buffer opened for a file outside any git repository  
  **When** the gutter renderer runs  
  **Then** `nvim_buf_get_extmarks` returns an empty list and `vim.notify` is not called  
  Covers `AC-005`, `OBS-001`.

### Smoke Tests

Not applicable — no standalone startup path.

### End-to-End Tests

Not applicable — no automated E2E harness.

### Regression Tests

Not applicable — new feature.

### Performance Tests

Not applicable — extmark placement is O(n) in changed lines; no measurable concern for typical file sizes.

### Security Tests

Not applicable — only absolute paths from Neovim buffer names are passed to git; no user-provided shell input.

### Usability Tests

- `UX-001`: Confirm signs appear in the sign column (not the text area) and do not shift line content. Covers visual correctness of `FR-003`.

### Observability Tests

- `OT-001`: **Scenario**: Non-git buffer triggers no notification  
  **Given** `vim.notify` is stubbed  
  **When** the renderer runs for a buffer outside a git repo  
  **Then** `vim.notify` is not called  
  Covers `OBS-001`.

## Definition of Done

- `lua/ui/gutter_renderer.lua` created.
- `init.lua` updated to call `require("ui.gutter_renderer").setup()`.
- All unit and integration tests pass under `nvim --headless`.
- Debounce correctly coalesces rapid autocommand events.
- Non-file buffers (sidebar, quickfix) never trigger git diff.
- `config.lua` symbols and highlights are used throughout; no hardcoded strings.
