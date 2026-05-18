---
id: "004-review"
task: "004"
reviewed: 2026-05-18
reviewer: claude-sonnet-4-6
verdict: FAIL
blocking: 2
non_blocking: 2
suggestions: 1
---

# Review — 004 File Explorer Git Status Indicators

## Related Task

`issues/004-file-explorer-git-indicators.md`

## Overall Verdict

**FAIL — 2 blocking findings.**

The core rendering logic and priority order are correct, and most ACs pass on inspection. However, `AC-007` (re-render after `BufWritePost` within `debounce_ms`) is broken: the debounce timer callback updates `cached_status` but never triggers a second `render()`, so the sidebar displays stale indicators after every save. A required test (`UT-003` as specified in the issue) is also missing.

---

## Findings

### F-001 — Debounce re-render never fires after `BufWritePost` [Blocking]

**File**: `config/nvim/lua/sidebar_explorer.lua`, lines 534–542 and `M.refresh` (lines 416–427)

**Observed behaviour:**

The `BufWritePost` autocmd executes:

```lua
file_status_renderer.refresh(state.root)   -- (1) starts debounce timer T1
M.refresh()                                -- (2) render() with stale cache,
                                           --     then file_status_renderer.refresh()
                                           --     cancels T1 and starts T2
```

Step 2 cancels T1 and starts T2. T2's callback (inside `file_status_renderer.refresh`) is:

```lua
vim.schedule_wrap(function()
    cached_status = git_status.get(root) or {}
end)
```

It only updates `cached_status`. It does **not** call `render()`. After `debounce_ms` milliseconds the cache is fresh but the sidebar buffer still shows the symbols from before the save.

**Required fix**: The debounce callback must trigger a re-render. One approach: `file_status_renderer.refresh` accepts an optional `on_done` callback; the `BufWritePost` handler (or `M.refresh`) passes `render` as that callback. Alternatively, `M.refresh` should not call `render()` eagerly on `BufWritePost` — it should schedule a deferred render inside the debounce callback.

**Violated**: `AC-007`, `FR-004`, `FR-005`.

---

### F-002 — Required test `UT-003` (priority order assertion) is absent [Blocking]

**File**: `config/nvim/tests/file_explorer_git_indicators_test.lua`

**Issue spec requires** (under Required Tests → Unit Tests):

> `UT-003`: Assert priority order: a `partial` status beats `staged` which beats `modified`. Covers `FR-002`, `AC-003`.

The test file contains four unit-level blocks labeled `UT-001`, `UT-002`, `UT-003`, and `UT-004`, but the block labelled `UT-003` tests "ignored entry with no tracked status shows ignored symbol" — it does not assert priority order at all. The actual required `UT-003` scenario (inject a file with a `partial` status, confirm it wins over `staged`; inject `staged`, confirm it wins over `modified`) is never exercised.

The priority logic in `file_status_renderer.lua` is almost certainly correct (the `priority` list is ordered correctly), but the DoD explicitly requires this test and it is absent.

**Violated**: DoD item "All unit and integration tests pass under `nvim --headless`" (the required test simply does not exist).

---

### F-003 — `M.refresh` renders with stale cache before debounce fires [Non-blocking]

**File**: `config/nvim/lua/sidebar_explorer.lua`, lines 416–427

`M.refresh` is the entry point used by the `r` keybinding (manual refresh). Its body is:

```lua
render()                               -- uses current (possibly stale) cache
file_status_renderer.refresh(state.root)  -- schedules async update; no re-render
```

For the manual-refresh use-case the user sees a one-frame flash of old symbols, then nothing further updates. This is a lesser version of F-001; it manifests on manual `r` presses as well. A consistent approach would be: schedule a single deferred render inside the debounce callback rather than rendering eagerly with stale data.

This is non-blocking only because the manual-refresh path is not covered by a specific AC. The `BufWritePost` path (F-001) is AC-covered and therefore blocking.

---

### F-004 — `BufWritePost` double-calls `file_status_renderer.refresh`, wasting one timer [Non-blocking]

**File**: `config/nvim/lua/sidebar_explorer.lua`, lines 534–542

The `BufWritePost` callback calls `file_status_renderer.refresh(state.root)` explicitly, then calls `M.refresh()`, which unconditionally calls `file_status_renderer.refresh(state.root)` a second time. The second call immediately cancels and restarts the timer created by the first, so the first call is wasted. The net effect is a single debounce window starting from when `M.refresh()` returns, which is likely the intended behaviour — but it is achieved accidentally rather than by design. The first call to `file_status_renderer.refresh` should be removed from the `BufWritePost` handler.

---

### F-005 — Suggestion: add `IT-002` integration test (non-git directory produces no indicators) [Suggestion]

**File**: `config/nvim/tests/file_explorer_git_indicators_test.lua`

The issue spec requires `IT-002` ("non-git directory produces no indicators" exercised via `build_lines`). The test file exercises the equivalent through `OT-001` (no notifications) and via `UT-003`/`UT-004` using `refresh_sync` on a temp path, but never calls `build_lines` directly with a non-git root. `IT-002` as specified is missing; adding it would increase confidence that the full pipeline (`build_lines` → `get_indicator`) is silent for non-git roots.

---

## AC Evaluation

| AC | Description | Result | Notes |
|----|-------------|--------|-------|
| AC-001 | Modified file → `modified` symbol appended | PASS | Priority list + `build_lines` symbol append correct |
| AC-002 | Staged file → `staged` symbol | PASS | `staged` at index 2 in priority list |
| AC-003 | Partial file → `partial` symbol (highest priority) | PASS | `partial` at index 1; logic correct |
| AC-004 | Untracked file → `untracked` symbol | PASS | `untracked` at index 7; falls through all higher statuses |
| AC-005 | `entry.ignored = true`, no tracked status → `ignored` symbol | PASS | Fallback block after priority loop correct |
| AC-006 | `entry.ignored = true` + tracked status → tracked wins | PASS | Priority loop checked before `entry.ignored` block |
| AC-007 | `BufWritePost` → re-render with updated status within `debounce_ms` | **FAIL** | Debounce callback updates cache only; no `render()` called — see F-001 |
| AC-008 | Non-git directory → no symbols, no error | PASS | Empty cache → all symbols are `""`; no `vim.notify` in renderer |
| AC-009 | Directory entries → no symbol in `build_lines` | PASS | `get_indicator` returns `""` for `entry.type == "directory"` |

---

## Test Coverage Evaluation

| Test ID (issue spec) | Status | Notes |
|---------------------|--------|-------|
| UT-001 | PASS | Correctly asserts symbol + highlight for `modified` |
| UT-002 | PASS | Asserts directory entry returns empty symbol + nil highlight |
| UT-003 | **MISSING** | Block labelled UT-003 in test file tests `ignored` fallback; required priority-order assertion is absent — see F-002 |
| IT-001 | PASS | Full round-trip on real temp git repo with modified file |
| IT-002 | PARTIAL | Non-git directory is tested for silence (OT-001) but `build_lines` pipeline is never exercised — see F-005 |
| OT-001 | PASS | `vim.notify` stub confirms zero notifications on non-git directory |

UT-004 (tracked status beats `entry.ignored`) is a useful addition beyond the spec; no objection.

---

## Observability Evaluation

`OBS-001` (no user notifications for git errors in renderer) is satisfied. `file_status_renderer.lua` contains no `vim.notify` call; `git_status.get` errors are absorbed via `or {}`. `OT-001` provides automated verification.

---

## ADR Compliance

Not applicable — ADR 001 was Accepted before this task started.

---

## Convention Notes

- Symbol append in `build_lines` uses a leading space (`" " .. indicator.symbol`), producing e.g. `  file.txt M`. This matches the implementation summary description and is consistent with typical sidebar decorators.
- `apply_highlights` performs two passes: first the existing `ignored` highlight, then git status highlights. Git status highlights are applied second, so they win over `ignored` background colouring when both apply — consistent with AC-006.
- All eight `GitStatus*` highlight groups are registered in `M.setup` using `cfg.highlights.*` keys from `config.lua`. No hardcoded group names. Consistent with the DoD requirement.
- `file_status_renderer.lua` uses module-level `cached_status` and `timer` variables. This means the cache is shared across all explorer instances in the same Neovim session. For a single-tab explorer (the stated constraint) this is acceptable, but it is worth noting as a latent issue if multi-tab support is added.

---

## Unresolved Assumptions

1. The implementation assumes that `vim.startswith(buf_path, state.root)` is a reliable path-prefix check. On case-insensitive filesystems or with symlinks this can give false negatives. Not a current concern given the Linux target, but worth documenting.
2. The debounce timer is a module-level singleton in `file_status_renderer.lua`. If two explorer roots are active simultaneously (future multi-tab work), the timer and cache will conflict. Acceptable now; flag for Task that lifts the single-tab constraint.
