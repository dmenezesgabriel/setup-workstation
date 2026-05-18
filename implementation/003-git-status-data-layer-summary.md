# Implementation Summary: 003 — Git Status Data Layer

## Files Created

- `config/nvim/lua/config.lua` — Shared config constants: `symbols`, `highlights`, `debounce_ms` (300), `sign_priority` (10).
- `config/nvim/lua/core/status_provider.lua` — Documentation-only module. Exports `FileStatus` and `LineChanges` shape stubs with comments describing the normalized table contracts.
- `config/nvim/lua/git/status.lua` — Exports `get(root) → FileStatus` and `_parse(raw, root)`. Runs `git -C <root> status --porcelain=v1 -z`, splits on null bytes, maps XY codes (`??`, `M `, ` M`, `MM`, `A `, ` A`, `D `, ` D`, `R `, `RM`) to normalized status strings. Silently returns `{}` if not in a git repo or if git exits non-zero.
- `config/nvim/lua/git/diff.lua` — Exports `get(path, staged?) → LineChanges` and `_parse(raw, path, staged)`. Runs `git diff --unified=0` (or `--cached` when staged). Parses `@@ -l,s +l,s @@` hunk headers: old_count=0 → added, new_count=0 → deleted (mapped to new_start), both nonzero → modified. With `staged=true`, all change types become `"staged"`. Silently returns `{}` if not in a git repo.
- `config/nvim/tests/git_status_data_layer_test.lua` — Headless test suite covering UT-001, UT-002, IT-001, IT-002, OT-001.

## Behavior Implemented

- `git/status.lua` uses `vim.system` with a `vim.fn.system` fallback (same pattern as `system_list` in `sidebar_explorer.lua`). All paths normalized via `vim.fs.normalize`.
- `git/diff.lua` finds the git root via `vim.fs.find(".git", { upward = true })` matching the `find_git_root` pattern in `sidebar_explorer.lua`.
- Both modules return `{}` silently (no `vim.notify`) when outside a git repo or on git command failure.
- Rename records in porcelain output (`R ` XY) consume the following null-byte record as the new path.

## Tests Added

- **UT-001**: Parser tested against hand-crafted porcelain strings for all 7 XY codes without spawning a git process.
- **UT-002**: Diff parser tested for added (`-0,0 +1,3`), deleted (`-5,2 +5,0`), modified (`-3,2 +3,2`), and staged variants.
- **IT-001**: Real temp git repo: commit a file, modify it without staging, assert `get(root)` returns `"modified"`.
- **IT-002 / OT-001**: Non-git temp directory: `vim.notify` stubbed, both `get` functions called, assert empty results and zero notifications.

## Validations Run

```
nvim --headless -u init.lua -S tests/git_status_data_layer_test.lua +q
# → git_status_data_layer_test: ok

nvim --headless -u init.lua -S tests/sidebar_explorer_validation.lua +q
# → sidebar_explorer_validation: ok
```

## ADR Updated

`docs/adrs/001-git-status-provider-contract.md` changed from `Status: Proposed` to `Status: Accepted`.
