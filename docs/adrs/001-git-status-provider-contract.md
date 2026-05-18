---
# ADR 001: Git Status Provider Contract Shape

## Status

Accepted

## Date

2026-05-18

## Related Tasks

- `issues/003-git-status-data-layer.md`
- `issues/004-file-explorer-git-indicators.md`
- `issues/005-editor-gutter-git-signs.md`

## Context

The git status indicators feature requires two kinds of data: file-level status (modified, added, etc.) and line-level diff changes. Two UI modules (`file_status_renderer` and `gutter_renderer`) consume this data. A clean boundary between data collection and rendering requires a stable contract. If the shape of normalized data changes after the UI modules are built, all three tasks need coordinated rewrites.

The contract also enables future providers (e.g. a mock for headless tests, or a Neovim LSP-based provider) without touching UI code.

## Decision

Define the provider contract in `core/status_provider.lua` as a documented Lua table with two keys:

```lua
-- M.FileStatus table shape (returned by git/status.lua)
-- { [absolute_path: string] = status: string }
-- status is one of: "modified", "added", "deleted", "renamed",
--                   "untracked", "staged", "partial"
-- "ignored" is handled separately via the existing get_ignored_lookup mechanism.

-- M.LineChanges table shape (returned by git/diff.lua)
-- { [absolute_path: string] = { [line_nr: number] = change_type: string } }
-- change_type is one of: "added", "modified", "deleted", "staged"
-- line_nr is 1-based. Deleted changes map to the line after the deletion point.
```

`git/status.lua` and `git/diff.lua` must return tables conforming to this shape. UI modules must import `core/status_provider` for shape documentation and consume only these shapes.

## Options Considered

1. Define the contract in `core/status_provider.lua` as documentation + optional runtime validation. `(recommended)`
2. Pass raw git output directly to UI modules and let them parse inline.
3. Use a single flat table combining file status and line changes keyed by path.

## Consequences

Positive:
- UI modules are decoupled from git command specifics.
- Headless tests can inject mock data conforming to the contract without running git.
- A future non-git provider (e.g. Mercurial or mock) can be swapped without changing UI code.

Negative:
- Adds one extra module (`core/status_provider.lua`) that is documentation, not logic.
- Implementors must keep the contract file in sync when the shape changes.

## Validation

- `git/status.lua` tests assert the return value matches the FileStatus shape for known `--porcelain=v1 -z` inputs.
- `git/diff.lua` tests assert the return value matches the LineChanges shape for known `--unified=0` diff inputs.
- `ui/file_status_renderer.lua` tests use injected FileStatus mock tables (no git process needed).
- `ui/gutter_renderer.lua` tests use injected LineChanges mock tables (no git process needed).

## Open Questions

- None. The contract shape is fully determined by the parsing requirements and UI consumption patterns.
