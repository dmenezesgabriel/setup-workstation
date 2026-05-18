---
id: "003"
created: 2026-05-18
updated: 2026-05-18
status: active
---

# Task: Git status data layer — config, provider contract, file status, and diff parsers

## Priority

P0 — Required before Tasks 004 and 005; neither UI module can be implemented without the normalized data shapes.

## Dependencies

- Depends on ADR `docs/adrs/001-git-status-provider-contract.md`.
- No task dependency; this is the foundation.

## Assignability

**AFK** — all requirements and acceptance criteria are fully specified; no architectural decisions remain open beyond the ADR.

## Context

The sidebar explorer and editor gutter both need git data, but neither UI module should run git commands directly. This task introduces the data layer: a config module for tunable constants, a provider contract that documents the normalized shapes, and two git modules that collect and parse the raw git output into those shapes.

The existing `get_ignored_lookup` in `sidebar_explorer.lua` (using `git check-ignore --stdin`) is already responsible for the `ignored` indicator and is not replaced here. `git/status.lua` covers tracked-change statuses only.

The existing `package.path` in `init.lua` already resolves `require("git.status")` to `lua/git/status.lua` — no `init.lua` changes are needed.

## Use Cases

- **Feature**: Git status data layer
- **Scenario**: File status is collected for a git repository
- **Given** a git repository root
- **When** `git.status.get(root)` is called
- **Then** it returns a normalized FileStatus table keyed by absolute path

- **Scenario**: Line changes are collected for an open buffer
- **Given** an absolute file path inside a git repository
- **When** `git.diff.get(path)` is called
- **Then** it returns a normalized LineChanges table for that file

- **Scenario**: Data collection runs outside a git repository
- **Given** a directory with no `.git` ancestor
- **When** either `git.status.get` or `git.diff.get` is called
- **Then** it returns an empty table without error or notification

## Definition of Ready

- ADR `docs/adrs/001-git-status-provider-contract.md` is written.
- The `porcelain=v1` XY code mapping to normalized statuses is defined (see FR-003).
- The unified diff hunk header format is understood (`@@ -l,s +l,s @@`).

## Functional Requirements

- `FR-001`: `lua/config.lua` exports a table with: `symbols` (per-status display characters), `highlights` (per-status highlight group names), `debounce_ms` (default 300), and `sign_priority` (default 10).
- `FR-002`: `lua/core/status_provider.lua` exports documented Lua table shape specs for `FileStatus` and `LineChanges` as described in ADR 001. No runtime logic.
- `FR-003`: `lua/git/status.lua` exports `get(root: string) → FileStatus`. It runs `git -C <root> status --porcelain=v1 -z`, parses null-byte-separated records, and maps XY codes as follows:
  - `??` → `"untracked"`, `M ` → `"staged"`, ` M` → `"modified"`, `MM` → `"partial"`, `A ` → `"staged"`, ` A` → `"added"`, `D ` → `"staged"`, ` D` → `"deleted"`, `R ` → `"renamed"`, `RM` → `"partial"`. Unknown codes are skipped.
- `FR-004`: `lua/git/diff.lua` exports `get(path: string, staged: boolean?) → LineChanges`. It runs `git diff --unified=0` (or `git diff --cached --unified=0` when `staged=true`), parses `@@ -l,s +l,s @@` hunk headers, and returns a per-file line map: added lines (`+l` where old count is 0), deleted lines (mapped to `l` on the new side where new count is 0), modified lines (both sides nonzero).
- `FR-005`: Both `git/status.lua` and `git/diff.lua` return an empty table (no notification) when the directory is not inside a git repository or the git command fails.
- `FR-006`: All returned paths are normalized via `vim.fs.normalize`.

## Non-Functional Requirements

- `NFR-001`: Both modules use `vim.system` (Neovim ≥ 0.10) with a `vim.fn.systemlist` fallback (same pattern as existing `system_list` in `sidebar_explorer.lua`).
- `NFR-002`: No external Lua packages or Neovim plugins. Built-in APIs only.

## Observability Requirements

- `OBS-001`: No user-facing notifications for missing git repositories or non-zero exit codes from `git diff` — silent empty return.

## Acceptance Criteria

- `AC-001`: **Given** a temp git repo with a tracked modified file, **When** `git.status.get(root)` is called, **Then** the file's path maps to `"modified"` in the returned table.
- `AC-002`: **Given** a temp git repo with a staged-only file, **When** `git.status.get(root)` is called, **Then** the file's path maps to `"staged"`.
- `AC-003`: **Given** a temp git repo with both staged and unstaged changes to the same file, **When** `git.status.get(root)` is called, **Then** the file's path maps to `"partial"`.
- `AC-004`: **Given** a temp git repo with an untracked file, **When** `git.status.get(root)` is called, **Then** the file's path maps to `"untracked"`.
- `AC-005`: **Given** a temp git repo with a file that has added lines, **When** `git.diff.get(path)` is called, **Then** those line numbers map to `"added"` in the returned table.
- `AC-006`: **Given** a directory with no `.git` ancestor, **When** `git.status.get` or `git.diff.get` is called, **Then** an empty table is returned and no error is shown.
- `AC-007`: **Given** any call to either module, **When** it returns, **Then** all paths in the result are normalized via `vim.fs.normalize`.

## Required Tests

### Unit Tests

- `UT-001`: Parse raw `--porcelain=v1 -z` output strings (no real git process) and assert correct status mappings for `??`, `M `, ` M`, `MM`, `A `, `D `, `R `. Covers `FR-003`, `AC-001`–`AC-004`.
- `UT-002`: Parse raw unified diff hunk headers (no real git process) and assert correct line-to-type mappings for added, deleted, and modified hunks. Covers `FR-004`, `AC-005`.

### Integration Tests

- `IT-001`: **Scenario**: File status collected from a real temp git repo  
  **Given** a temp git repo created via `git init` with a committed file, then modified  
  **When** `git.status.get(root)` is called  
  **Then** the modified file appears with `"modified"` in the result  
  Covers `AC-001`.

- `IT-002`: **Scenario**: Non-git directory returns empty without error  
  **Given** a temp directory with no `.git` ancestor  
  **When** `git.status.get(path)` and `git.diff.get(path)` are called  
  **Then** both return `{}` and `vim.notify` is not called  
  Covers `AC-006`.

### Smoke Tests

Not applicable — no startup or deployment path.

### End-to-End Tests

Not applicable — no automated E2E harness in this repo.

### Regression Tests

Not applicable — no prior defect in these new modules.

### Performance Tests

Not applicable — data collection is synchronous and bounded by git process time, not Lua logic.

### Security Tests

Not applicable — no user input is passed to git commands; only absolute paths derived from Neovim buffers.

### Usability Tests

Not applicable — no UI in this task.

### Observability Tests

- `OT-001`: **Scenario**: Non-git directory emits no notification  
  **Given** `vim.notify` is stubbed to record calls  
  **When** `git.status.get` is called on a non-git directory  
  **Then** no notification is recorded  
  Covers `OBS-001`.

## Definition of Done

- `lua/config.lua`, `lua/core/status_provider.lua`, `lua/git/status.lua`, `lua/git/diff.lua` are created.
- All unit and integration tests pass under `nvim --headless`.
- No external dependencies introduced.
- ADR `docs/adrs/001-git-status-provider-contract.md` updated to `Accepted`.
