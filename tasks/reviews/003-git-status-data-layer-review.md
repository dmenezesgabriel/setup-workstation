---
id: "003"
issue: "issues/003-git-status-data-layer.md"
created: 2026-05-18
updated: 2026-05-18
---

# Review: Git status data layer

## Related Task
- `issues/003-git-status-data-layer.md`

## Overall Verdict
**Fail**

Two blocking findings prevent sign-off: FR-006 is violated in `git/diff.lua` (returned path key is not normalized), and NFR-001 is partially violated (the `system_raw` fallback in both modules uses `vim.fn.system`, not `vim.fn.systemlist` as required). Additionally, UT-001 omits two of the ten XY code mappings required by FR-003 (`R ` and `RM`), leaving acceptance criteria coverage incomplete.

## Findings

| ID | Level | Requirement | Description | Evidence |
|----|-------|-------------|-------------|----------|
| F-001 | Blocking | FR-006 | `git/diff.lua` uses the raw (possibly un-normalized) `path` argument as the return table key. `M.get` never calls `vim.fs.normalize(path)` before passing it to `M._parse`. | `diff.lua:79`: `M._parse(stdout, path, staged)` — `path` comes from caller with no normalization applied |
| F-002 | Blocking | NFR-001 | NFR-001 requires a `vim.fn.systemlist` fallback, matching the reference pattern in `sidebar_explorer.lua`. Both `git/status.lua` and `git/diff.lua` define `system_raw` with a `vim.fn.system` fallback (not `systemlist`). `system_list` (with `systemlist` fallback) exists in `status.lua` but is dead code — never called by `M.get`. | `status.lua:27,54`; `diff.lua:9`; NFR-001 text |
| F-003 | Non-blocking | FR-003 / UT-001 | UT-001 omits `R ` (renamed) and `RM` (partial-rename) XY codes. The FR-003 mapping table defines 10 codes; only 7 are exercised in the test. The parsing logic for `R ` (consuming the next null-byte record) is implemented but goes untested. | `test line 28`: raw string excludes `R ` and `RM` entries |
| F-004 | Non-blocking | FR-003 | The UT-001 raw string encodes `M ` as `"M  staged.txt"` (3 characters before filename) instead of `"M staged.txt"` (2-char XY + space + filename). The parser uses `record:sub(1,2)` for XY and `record:sub(4)` for path — `"M  staged.txt"` yields XY=`"M "` (correct) and path=`" staged.txt"` (leading space). The key becomes `/tmp/fake-root/ staged.txt`, not `/tmp/fake-root/staged.txt`. The assert_equal passes only because it also has the leading space artifact. The raw input is malformed relative to porcelain spec but happens to survive the assertion. | `test line 28, 32`; git porcelain spec: XY is 2 chars, then a space, then the path |
| F-005 | Suggestion | Style / NFR-002 | `git/status.lua` contains a dead `system_list` function (lines 16–33) that is never called. It should be removed to avoid confusion with `system_raw`, which is the actual helper used by `M.get`. | `status.lua:16-33` |
| F-006 | Suggestion | Convention | `git/diff.lua` does not pass `path` through `vim.fs.normalize` before computing `rel_path` via `vim.fs.relpath`. While `relpath` may tolerate un-normalized paths, normalizing early would make the path handling explicit and consistent with `git/status.lua`'s approach. Fixing this also resolves F-001. | `diff.lua:50-61` |

## AC Evaluation

| AC | Result | Notes |
|----|--------|-------|
| AC-001 | Pass | IT-001 creates a real repo, modifies a file, calls `get(root)` and asserts `"modified"`. |
| AC-002 | Partial | No dedicated IT for staged-only file. UT-001 covers `M ` and `A ` → `"staged"` via parser, but the integration path (real `git add` without commit) is untested. |
| AC-003 | Partial | UT-001 covers `MM` → `"partial"` via parser. No integration test for the staged+unstaged scenario. |
| AC-004 | Partial | UT-001 covers `??` → `"untracked"` via parser. No integration test creates an untracked file and calls `get`. |
| AC-005 | Pass | UT-002 covers added lines (`-0,0 +1,3`), asserts line numbers map to `"added"`. |
| AC-006 | Pass | IT-002 calls both `get` functions on a non-git temp dir and asserts empty results. |
| AC-007 | Fail | FR-006 / AC-007 failed for `git/diff.lua`: the returned path key is the raw (un-normalized) `path` argument. `git/status.lua` correctly uses `vim.fs.normalize(root .. "/" .. rel_path)`. |

## Test Coverage Evaluation

| Test Category | Status | Notes |
|---------------|--------|-------|
| UT-001 (porcelain parser) | Partial | 7 of 10 required XY codes tested. `R ` and `RM` are absent. See F-003. |
| UT-002 (diff parser) | Present | Added, deleted, modified, and staged variants all covered with hand-crafted diff strings. |
| IT-001 (real repo modified file) | Present | Full git lifecycle (init, add, commit, modify) exercised; result asserted. |
| IT-002 (non-git empty return) | Present | Both modules called on a non-git dir; empty results asserted. |
| OT-001 (no notify on non-git dir) | Present | `vim.notify` stubbed before calls; zero notifications asserted after restore. |

## Observability Evaluation

| OBS ID | Requirement | Status | Notes |
|--------|-------------|--------|-------|
| OBS-001 | No user-facing notifications for missing git repo or non-zero exit code | Pass | Neither `git/status.lua` nor `git/diff.lua` call `vim.notify` anywhere. Silent empty return is confirmed by code inspection and OT-001. |

## ADR Compliance

| ADR | Required Action | Status |
|-----|-----------------|--------|
| docs/adrs/001-git-status-provider-contract.md | Must be updated to `Status: Accepted` | Pass — front-matter reads `Accepted` and the contract shape matches what `git/status.lua` and `git/diff.lua` produce. |

## Convention Notes

Reference style is `config/nvim/lua/sidebar_explorer.lua`.

- **4-space indentation**: All four new files use 4-space indentation consistently. Pass.
- **`local M = {} … return M` pattern**: All four files follow this pattern. Pass.
- **Comments**: `core/status_provider.lua` uses comments exclusively to document the shape contract — this is appropriate and matches the FR-002 intent. No spurious comments in the other three files. Pass.
- **`system_list` dead code in `status.lua`**: The function body is copy-pasted from `sidebar_explorer.lua` and returns a structured table, but `M.get` calls `system_raw` instead. This dead helper is inconsistent with the lean style of the reference file. Non-blocking but noisy.
- **NFR-001 pattern mismatch**: `sidebar_explorer.lua:system_list` uses `vim.fn.systemlist` as fallback. The new modules' `system_raw` uses `vim.fn.system`. This is a functionally different fallback (string vs list), not just a naming variant. The NFR requirement names `vim.fn.systemlist` explicitly. Blocking per F-002.

## Unresolved Assumptions or Follow-Up

1. **Rename path direction**: `git status --porcelain=v1 -z` for `R ` records emits `"R <new_path>\0<old_path>"` — the new path comes *first*, old path second. The parser at `status.lua:70-73` reads the *next* null-byte record as the new path and maps the result to it. If the porcelain order is new-then-old, the parser is using the old path as the new path key. This should be confirmed against the git-status porcelain spec and an integration test for rename should be added (covered by the missing UT-001 `R ` case, F-003).

2. **Concurrency / async use**: Both modules use the synchronous `:wait()` form of `vim.system`. If these are ever called from an async context (e.g., a `BufWritePost` autocmd without a callback wrapper), they will block the event loop. No current consumer exists yet, but this assumption should be documented before Tasks 004 and 005 are implemented.

3. **AC-002, AC-003, AC-004**: Only parser-level coverage exists. Full integration tests (real git state + full `get` call path) for staged, partial, and untracked scenarios are missing. These are currently marked non-blocking because the parser path is exercised by UT-001, but the integration gap should be addressed before this task is marked complete.
