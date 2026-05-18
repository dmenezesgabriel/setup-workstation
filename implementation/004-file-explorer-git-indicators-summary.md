# Implementation Summary — 004 File Explorer Git Status Indicators

## Files changed

- **Created**: `config/nvim/lua/ui/file_status_renderer.lua`
- **Modified**: `config/nvim/lua/sidebar_explorer.lua`
- **Created**: `config/nvim/tests/file_explorer_git_indicators_test.lua`

## Behavior implemented

- `ui/file_status_renderer.lua` caches the git `FileStatus` table per root and exposes `get_indicator(entry)`, `refresh(root)` (debounced), and `refresh_sync(root)` (blocking).
- `get_indicator` applies the priority order `partial > staged > modified > added > deleted > renamed > untracked`; falls back to `ignored` if `entry.ignored` is true and no tracked status is present; returns an empty symbol for directories.
- `sidebar_explorer.lua`'s `build_lines` appends the status symbol (` M`, ` A`, etc.) to each file entry line.
- `apply_highlights` adds a second pass after the ignored-highlight loop to apply git status highlight groups.
- `M.toggle` calls `refresh_sync` before opening the window so the first render is never symbol-free.
- `M.refresh` triggers a debounced `file_status_renderer.refresh` after re-rendering.
- A `BufWritePost` autocommand in `M.setup` triggers a debounced refresh when a buffer under the explorer root is saved.
- All git status highlight groups (`GitStatusModified`, `GitStatusAdded`, etc.) are registered in `M.setup`.

## Tests added

`config/nvim/tests/file_explorer_git_indicators_test.lua`:

| ID | Description |
|----|-------------|
| UT-001 | `get_indicator` returns the `modified` symbol and highlight for a modified file after `refresh_sync` |
| UT-002 | Directory entries always receive an empty symbol and nil highlight |
| UT-003 | An entry with `ignored=true` and no cached status receives the `ignored` symbol |
| UT-004 | A cached `untracked` status takes priority over `entry.ignored = true` |
| IT-001 | Full round-trip: `refresh_sync` on a real temp git repo with a modified file yields the `modified` symbol |
| OT-001 | `refresh_sync` on a non-git directory emits zero notifications |

## Validations run

- `nvim --headless -u init.lua -S tests/file_explorer_git_indicators_test.lua` — **ok**
- `nvim --headless -u init.lua -S tests/git_status_data_layer_test.lua` — **ok**
- `nvim --headless -u init.lua -S tests/sidebar_explorer_validation.lua` — **ok**

## Accessibility

Not applicable — terminal UI, no HTML or ARIA concerns.

## ADRs updated

None. Implementation follows the existing ADR 001 provider contract without changing architectural assumptions.

## Non-applicable test categories

- Smoke, E2E, regression, performance, security tests — rationale matches the issue's own assessment (no standalone startup path, no automated E2E harness, no prior defect, O(n) symbol append, renderer reads only normalized data).

## Unresolved assumptions

None.
