---
id: "002"
task: tasks/issues/002-nvim-compat-shim.md
date: 2026-05-24
status: complete
---

# Implementation Summary: Neovim 0.8 Compat Shim

## Files Changed

- `config/nvim/lua/compat.lua` — new; exposes `M.uv` and `M.fs_relpath` with inline fallbacks
- `config/nvim/lua/ui/gutter_renderer.lua` — adds `require("compat")`; replaces `vim.uv` with `compat.uv` at line 59
- `config/nvim/lua/ui/file_status_renderer.lua` — adds `require("compat")`; replaces `vim.uv` with `compat.uv` at line 38
- `config/nvim/lua/git/diff.lua` — adds `require("compat")`; replaces `vim.fs.relpath` with `compat.fs_relpath` at line 63
- `config/nvim/lua/explorer/init.lua` — adds `require("compat")`; replaces `vim.fs.relpath` with `compat.fs_relpath` at line 117

## Behaviour Implemented

- `compat.uv` — returns `vim.uv` on 0.10+ (no deprecation warning); falls back to `vim.loop` on 0.8
- `compat.fs_relpath(base, path)` — delegates to `vim.fs.relpath` on 0.10+; on 0.8 uses `vim.fs.normalize` + prefix matching, returning `nil` when path is not under base

## Tests Added

- `config/nvim/tests/compat_test.lua` — four unit tests matching UT-001 through UT-004

## Validations Run

- `nvim --headless -l tests/compat_test.lua` → `compat_test: ok`
- Full test suite: all other tests pass; `shell_cmd_refresh_test.lua` (IT-001) was already failing before this change

## Test Categories Not Applicable

- IT, SMK, E2E, REG, PT, ST, UX, OT — all marked not applicable in the task spec for the same reasons stated there

## Unresolved Assumptions

- `shell_cmd_refresh_test.lua` IT-001 failure is pre-existing (confirmed via `git stash` + re-run). It is unrelated to this shim.
