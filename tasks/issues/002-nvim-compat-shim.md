---
id: "002"
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Task: Add compat module and fix version-specific call sites

## Priority

P0 — Required before the test runner (Task 003) can validate the fix; blocks the multi-version CI script from having anything meaningful to test.

## Dependencies

- No task dependency; can start immediately.
- No ADR dependency; this is an implementation shim, not an architectural decision.

## Assignability

**AFK** — all call sites are identified, the shim logic is deterministic, and no irreversible decisions remain open.

## Context

The config currently uses two APIs that do not exist on Neovim 0.8:

- `vim.uv` — renamed from `vim.loop` in 0.10. Used directly (without fallback) in `lua/ui/gutter_renderer.lua:58` and `lua/ui/file_status_renderer.lua:37`.
- `vim.fs.relpath` — added in 0.10. Used directly (without fallback) in `lua/git/diff.lua:61` and `lua/explorer/init.lua:116`.

The fix is a single `lua/compat.lua` module that exposes both APIs with inline fallbacks, and updates the four call sites to import from it. `lua/explorer/init.lua:3` already handles `vim.uv or vim.loop` correctly for its own `uv` usage and does not need to change.

The `vim.system` fallback paths in `git/status.lua`, `git/diff.lua`, and `explorer/init.lua` already use `if vim.system then … else vim.fn.systemlist … end` guards and are already 0.8-compatible.

## Use Cases

- **Feature**: Neovim 0.8 compatibility
- **Scenario**: Config loads without error on a machine running Neovim 0.8.3
- **Given** a machine where `nvim --version` reports 0.8.x
- **When** Neovim starts with this config
- **Then** the gutter renderer, file status renderer, and git integrations all initialise without a `vim.uv` or `vim.fs.relpath` nil-call error

## Definition of Ready

- The four call sites are confirmed: `gutter_renderer.lua:58`, `file_status_renderer.lua:37`, `git/diff.lua:61`, `explorer/init.lua:116`.
- `vim.fs.normalize` is confirmed available on 0.8 (used inside the `fs_relpath` fallback).
- `vim.loop` (the 0.8 name for libuv) is confirmed identical in API to `vim.uv`.

## Functional Requirements

- `FR-001`: `require("compat").uv` returns a libuv handle on both Neovim 0.8 (`vim.loop`) and 0.10+ (`vim.uv`).
- `FR-002`: `require("compat").fs_relpath(base, path)` returns the relative path string on both 0.8 (fallback implementation) and 0.10+ (`vim.fs.relpath`).
- `FR-003`: The `fs_relpath` fallback returns `nil` when `path` is not under `base`, matching the behaviour of `vim.fs.relpath`.
- `FR-004`: `gutter_renderer.lua` and `file_status_renderer.lua` use `require("compat").uv` instead of `vim.uv` directly.
- `FR-005`: `git/diff.lua` and `explorer/init.lua` use `require("compat").fs_relpath` instead of `vim.fs.relpath` directly.

## Non-Functional Requirements

- `NFR-001`: `compat.lua` is ≤20 lines; no abstractions beyond the two shim functions.
- `NFR-002`: On Neovim 0.10+, `compat.uv` evaluates to `vim.uv` (not `vim.loop`), so no deprecation warning is ever emitted.
- `NFR-003`: On Neovim 0.10+, `compat.fs_relpath` delegates directly to `vim.fs.relpath`; the fallback function is never called.

## Observability Requirements

- `OBS-001`: Not applicable — this is a pure API shim with no user-visible behaviour change and no operational surface.

## Acceptance Criteria

- `AC-001`: **Given** Neovim 0.8, **When** `require("compat").uv` is called, **Then** it returns the same handle as `vim.loop` (not nil).
- `AC-002`: **Given** Neovim 0.10+, **When** `require("compat").uv` is called, **Then** it returns `vim.uv` and `vim.loop` is never accessed (no deprecation warning in `:messages`).
- `AC-003`: **Given** base `/tmp/root` and path `/tmp/root/sub/file.txt`, **When** `compat.fs_relpath` is called, **Then** it returns `sub/file.txt`.
- `AC-004`: **Given** base `/tmp/root` and path `/tmp/other/file.txt`, **When** `compat.fs_relpath` is called, **Then** it returns `nil`.
- `AC-005`: **Given** Neovim 0.8, **When** `gutter_renderer` or `file_status_renderer` initialises a timer, **Then** no `attempt to index a nil value (global 'vim.uv')` error is raised.
- `AC-006`: **Given** Neovim 0.8, **When** `git.diff` computes a relative path, **Then** no `attempt to call a nil value (field 'relpath')` error is raised.

## Required Tests

### Unit Tests

- `UT-001`: `compat.uv` is not nil and exposes `new_timer`. Covers `FR-001`, `AC-001`.
- `UT-002`: `compat.fs_relpath("/tmp/root", "/tmp/root/sub/file.txt")` returns `"sub/file.txt"`. Covers `FR-002`, `AC-003`.
- `UT-003`: `compat.fs_relpath("/tmp/root", "/tmp/other/file.txt")` returns `nil`. Covers `FR-003`, `AC-004`.
- `UT-004`: On 0.10+, `compat.uv` is the same reference as `vim.uv`. Covers `NFR-002`, `AC-002`.

### Integration Tests

- `IT-001`: Not applicable — the shim contains no real boundary (filesystem, process, or network) beyond the Neovim version detection already covered by unit tests.

### Smoke Tests

- `SMK-001`: Not applicable — the shim has no deploy or startup surface.

### End-to-End Tests

- `E2E-001`: Not applicable — no complete user journey changes; existing gutter and file-status renderer tests (run via Task 003 on all versions) serve as the cross-version integration check.

### Regression Tests

- `REG-001`: Not applicable — no previous defect to guard against; this is a new compat surface.

### Performance Tests

- `PT-001`: Not applicable — the shim is evaluated once per module load; no runtime performance impact.

### Security Tests

- `ST-001`: Not applicable — the shim does not touch authentication, input handling, storage, or external communication.

### Usability Tests

- `UX-001`: Not applicable — no user-facing behaviour changes.

### Observability Tests

- `OT-001`: Not applicable — the shim introduces no logs, metrics, or traces.

## Definition of Done

- `lua/compat.lua` exists with `M.uv` and `M.fs_relpath`.
- `gutter_renderer.lua` and `file_status_renderer.lua` import `require("compat").uv` and use it in place of `vim.uv`.
- `git/diff.lua` and `explorer/init.lua` import `require("compat").fs_relpath` and use it in place of `vim.fs.relpath`.
- `tests/compat_test.lua` exists and passes all four unit tests above.
- All existing tests continue to pass on the current Neovim version.
