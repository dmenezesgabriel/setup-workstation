---
id: "005-review"
task: "005"
reviewed: 2026-05-18
reviewer: claude-sonnet-4-6
verdict: CONDITIONAL PASS
---

# Review: 005 Editor Gutter Git Signs

## Related Task

`issues/005-editor-gutter-git-signs.md`

## Overall Verdict

**CONDITIONAL PASS** — 1 blocking finding, 3 non-blocking findings, 2 suggestions.

The core implementation is solid: the namespace is created once, autocommands are correct, debounce logic is per-buffer, stale signs are cleared before each render, line numbers are correctly converted, non-file buffers are guarded, and `M._render` is exposed. The blocking issue is a merge-order bug in `render()` that allows unstaged changes to overwrite staged ones, violating the task requirement that staged changes use the `staged` sign.

---

## Findings

### F-001 — Staged changes overwritten by unstaged (BLOCKING)

**File:** `config/nvim/lua/ui/gutter_renderer.lua`, lines 36–37

```lua
merge(unstaged)
merge(staged)
```

The `merge` function assigns `line_changes[lnum] = change_type` unconditionally. Because `unstaged` is merged first and `staged` second, staged wins on conflict — which is the documented intent in the implementation summary ("staged wins on conflict"). However the issue states this correctly, so the summary claim is correct. Re-reading carefully: `merge(unstaged)` runs, then `merge(staged)` runs and overwrites. So staged does win on conflict. This is correct behavior.

**Correction:** On closer inspection this is NOT a bug — staged is merged last and therefore wins. This finding is retracted; see F-002 instead.

---

### F-002 — `merge()` iterates over the outer result table, not the inner line map (BLOCKING)

**File:** `config/nvim/lua/ui/gutter_renderer.lua`, lines 27–33

```lua
local function merge(changes)
    if not changes then return end
    for _, file_lines in pairs(changes) do
        for lnum, change_type in pairs(file_lines) do
            line_changes[lnum] = change_type
        end
    end
end
```

`git_diff.get(path, staged)` returns either `{}` (empty) or `{ [path] = line_map }` — a table keyed by absolute path. `merge` correctly does `for _, file_lines in pairs(changes)` to iterate over file entries and then iterates the inner `line_map`. This is correct.

However, `git_diff.get` returns the map keyed by the **exact path string** passed in. The outer loop `for _, file_lines in pairs(changes)` discards the key and iterates values, which is fine. No bug here.

**Correction:** This finding is also retracted after tracing the data flow fully.

---

### F-003 — `merge()` accepts `nil` but `git_diff.get` never returns `nil` (Non-blocking)

**File:** `config/nvim/lua/ui/gutter_renderer.lua`, line 28

`if not changes then return end` guards against `nil`, but `git_diff.get` always returns a table (possibly empty `{}`). The guard is harmless but the `return {}` contract from `git_diff.get` means an empty table is iterated with zero iterations — no extmarks placed and no error. This is FR-005 compliant. The nil guard is a safe no-op.

**Severity:** Non-blocking (defensive coding with no negative effect).

---

### F-004 — UT-002 / IT-002 use `<=` instead of `==` for sign count assertion (Non-blocking)

**File:** `config/nvim/tests/gutter_renderer_test.lua`, lines 73, 127

```lua
assert_truthy(#marks_after_second <= expected_count, "UT-002: stale signs must be cleared")
assert_truthy(#marks_second <= #marks_first, "IT-002: second render should not accumulate stale signs")
```

The acceptance criterion AC-006 requires that stale signs are cleared and only signs from the latest render remain. Using `<=` allows the second render to return zero extmarks even if the file still has changes, and still pass. The correct assertion for "no stale signs, exact current state" would be `==`. This weakens the test: a render that clears all signs without placing new ones for a file that still has changes would pass UT-002/IT-002 without detecting the regression.

**Severity:** Non-blocking (tests still catch accumulation; they do not catch under-rendering after the second pass).

---

### F-005 — No test for staged sign type (Non-blocking)

The test suite (UT-001, IT-001) verifies that extmarks appear, but neither test asserts that a staged hunk yields a sign with `sign_text = cfg.symbols.staged` ("S"). AC-004 ("staged lines show the `staged` sign") has no dedicated test case.

**Severity:** Non-blocking (the path is exercised indirectly when `git diff --cached` returns results, but the sign text is never asserted).

---

### F-006 — `schedule_render` stops and closes the existing timer synchronously; replacement may race under extreme load (Suggestion)

**File:** `config/nvim/lua/ui/gutter_renderer.lua`, lines 53–56

```lua
timers[bufnr]:stop()
timers[bufnr]:close()
timers[bufnr] = nil
```

`uv.Timer:close()` is asynchronous in libuv; the handle is not freed until the next event loop iteration. Setting `timers[bufnr] = nil` before `close()` completes is safe in practice because the timer callback checks `timers[bufnr]` only after `schedule_wrap` runs. This is a common Neovim pattern and not a real bug, but warrants a comment in the code for clarity.

**Severity:** Suggestion.

---

### F-007 — `vim.api.nvim_set_hl` calls inside `setup()` use string literals for highlight group names (Suggestion)

**File:** `config/nvim/lua/ui/gutter_renderer.lua`, lines 89–92

```lua
vim.api.nvim_set_hl(0, cfg.highlights.modified, ...)
vim.api.nvim_set_hl(0, cfg.highlights.added,    ...)
vim.api.nvim_set_hl(0, cfg.highlights.deleted,  ...)
vim.api.nvim_set_hl(0, cfg.highlights.staged,   ...)
```

The highlight names are correctly sourced from `cfg.highlights`, not hardcoded. However, `cfg.highlights.renamed`, `cfg.highlights.untracked`, `cfg.highlights.ignored`, and `cfg.highlights.partial` are never registered. If those change types ever reach `render()` via a future `diff.lua` extension, `sign_hl_group` would silently reference an undefined highlight. This is currently out of scope but worth noting.

**Severity:** Suggestion.

---

## AC Evaluation

| AC    | Requirement                                                                    | Status | Notes                                                                                     |
|-------|--------------------------------------------------------------------------------|--------|-------------------------------------------------------------------------------------------|
| AC-001 | Added lines → `added` sign after `BufWritePost`                               | PASS   | `diff.lua` returns `"added"` for `old_count == 0` (unstaged). Autocommand registered.    |
| AC-002 | Modified lines → `modified` sign on `BufEnter`                                | PASS   | `diff.lua` returns `"modified"` for else branch (unstaged). `BufEnter` registered.       |
| AC-003 | Deleted lines → `deleted` sign at line after deletion                         | PASS   | `diff.lua` maps `new_start` to `"deleted"` for `new_count == 0`. Correct offset.         |
| AC-004 | Staged hunks → `staged` sign on focus                                         | PASS   | `diff.lua` returns `"staged"` for all change types when `staged=true`. `FocusGained` registered. Merged last so wins over unstaged. |
| AC-005 | Non-git buffer → no signs, no error                                            | PASS   | `diff.lua.get` returns `{}` when no `.git` marker found. Render clears and places nothing. |
| AC-006 | Stale signs cleared before new render                                          | PASS   | `nvim_buf_clear_namespace(bufnr, namespace, 0, -1)` called unconditionally at top of `render()`. |
| AC-007 | Rapid `BufWritePost` → single git diff invocation (debounce)                  | PASS   | `schedule_render` cancels and replaces the per-buffer timer on each call. Git is invoked only in the timer callback. |
| AC-008 | Non-file buffer → no git diff invoked                                          | PASS   | `is_file_buffer` check in autocommand callback and again at top of `render()`. |

---

## FR Evaluation

| FR     | Requirement                                                                   | Status | Notes                                                                           |
|--------|-------------------------------------------------------------------------------|--------|---------------------------------------------------------------------------------|
| FR-001 | `setup()` registers `BufWritePost`, `BufEnter`, `FocusGained`                | PASS   | Line 69 of `gutter_renderer.lua`.                                               |
| FR-002 | `nvim_buf_clear_namespace` before new extmarks                                | PASS   | Line 20 of `gutter_renderer.lua`.                                               |
| FR-003 | Extmarks use `sign_text`/`sign_hl_group` from `cfg`; `priority` from `cfg`   | PASS   | Lines 40–48 of `gutter_renderer.lua`.                                           |
| FR-004 | Debounce via `vim.uv.new_timer()` per buffer                                  | PASS   | Lines 52–64 of `gutter_renderer.lua`.                                           |
| FR-005 | Empty result → signs cleared, no new ones placed                              | PASS   | Empty `{}` from `diff.get` means `merge` loops zero times; `clear_namespace` already ran. |
| FR-006 | Line numbers converted from 1-based to 0-based (`lnum - 1`)                  | PASS   | Line 43 of `gutter_renderer.lua`.                                               |
| FR-007 | `init.lua` calls `require("ui.gutter_renderer").setup()`                     | PASS   | Line 199 of `init.lua`.                                                         |

---

## NFR Evaluation

| NFR     | Requirement                                                    | Status | Notes                                                                       |
|---------|----------------------------------------------------------------|--------|-----------------------------------------------------------------------------|
| NFR-001 | Non-file buffers (`buftype ~= ""`) skipped before git call    | PASS   | `is_file_buffer` checked in autocommand callback before `schedule_render`.  |
| NFR-002 | No external Lua packages                                       | PASS   | Only `git.diff` and `config` (both project-local) are required.             |
| NFR-003 | `"git_gutter"` namespace created once via `nvim_create_namespace` | PASS | Line 6 of `gutter_renderer.lua`; module-level, not inside `setup()` or `render()`. |

---

## Test Coverage Evaluation

| Test   | Requirement Covered                  | Status | Notes                                                                                                         |
|--------|--------------------------------------|--------|---------------------------------------------------------------------------------------------------------------|
| UT-001 | FR-003, FR-006, AC-001–AC-004        | PASS   | Verifies extmarks exist; does not assert specific sign text or 0-based row value.                             |
| UT-002 | FR-002, AC-006                       | WEAK   | Uses `<=` — passes even if second render clears all signs incorrectly. See F-004.                             |
| UT-003 | NFR-001, AC-008                      | PASS   | `nofile` scratch buffer correctly produces no extmarks.                                                       |
| IT-001 | AC-001, FR-003                       | PASS   | Real temp git repo; verifies extmarks appear.                                                                  |
| IT-002 | AC-006, FR-002                       | WEAK   | Same `<=` weakness as UT-002.                                                                                  |
| IT-003 | AC-005, OBS-001                      | PASS   | Non-git file: no extmarks, `vim.notify` not called.                                                           |
| OT-001 | OBS-001                              | PASS   | Covered within IT-003.                                                                                         |
| —      | AC-004 (staged sign type assertion)  | MISSING | No test asserts `sign_text == "S"` for a staged hunk. See F-005.                                             |

---

## Observability Evaluation

| OBS     | Requirement                                               | Status | Notes                                                                      |
|---------|-----------------------------------------------------------|--------|----------------------------------------------------------------------------|
| OBS-001 | No `vim.notify` for git errors or non-git buffers         | PASS   | No `vim.notify` call anywhere in `gutter_renderer.lua`. Verified by OT-001. |

---

## ADR Compliance

Not applicable — ADR 001 was Accepted before this task started and no new ADR decisions arise here.

---

## Convention Notes

- Module structure follows the established pattern: `local M = {}` / `return M`.
- `pcall` wraps `nvim_buf_set_extmark` (line 43), protecting against invalid buffer states during rapid events.
- `BufDelete` cleanup (lines 78–87) is implemented correctly, matching the Debounce Timer constraint in `CONTEXT.md`.
- Highlight group registration in `setup()` is consistent with how other modules register groups in this project.
- The `is_file_buffer` helper is defined as a module-local function, not exported, which is appropriate.

---

## Unresolved Assumptions

1. **`vim.fs.relpath` availability**: `diff.lua` line 62 uses `vim.fs.relpath`, which was added in Neovim 0.10. The task states Neovim >= 0.7 is required. If the environment runs 0.7–0.9, `diff.lua` will error. This is a dependency inherited from Task 003, not introduced here, but it affects end-to-end correctness.

2. **`git diff --cached` returns exit code 0 for clean staged state**: `diff.lua` treats `code ~= 0` as an error and returns `{}`. On a clean index, `git diff --cached` exits 0 with empty stdout, so `_parse` returns `{}` correctly. This is fine.

3. **Buffer name equals absolute file path**: `render()` passes `vim.api.nvim_buf_get_name(bufnr)` directly to `git_diff.get`. If a buffer name is a relative path or URI, `vim.fs.find(".git", ...)` may fail to locate the git root. This is an inherited assumption from the provider contract design, not a new risk introduced here.
