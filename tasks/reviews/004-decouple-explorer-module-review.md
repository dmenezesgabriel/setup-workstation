---
id: "004-review"
task: "004"
reviewed: 2026-05-18
reviewer: claude-sonnet-4-6
verdict: PASS
blocking: 0
non_blocking: 1
suggestions: 1
---

# Review — 004 Decouple File-Tree Logic into `lua/explorer/` Module

## Related Task

`tasks/issues/004-decouple-explorer-module.md`

## Overall Verdict

**PASS — 0 blocking findings.**

The decoupling is clean and complete. `lua/explorer/init.lua` provides all seven required public functions, has zero `require("ui.*")` or `require("config")` calls, and follows the established `local M = {}` / `return M` Lua style. `sidebar_explorer.lua` delegates all filesystem and tree operations to `explorer`, retains a local `build_lines()` that applies icons and indicators, and has no trace of the old `M._test` escape hatch. `sidebar_explorer_validation.lua` has been fully migrated to `require("explorer")` with entry-property assertions replacing all display-string assertions. All six test suites pass headlessly with exit code 0. One non-blocking finding covers explicit test-ID labels; one suggestion covers a duplicate `assert_equal` in the validation test.

---

## Findings

### F-001 — Test IDs UT-001–UT-004 are not labelled in `sidebar_explorer_validation.lua` [Non-blocking]

**File**: `config/nvim/tests/sidebar_explorer_validation.lua`

**Observed behaviour:**

The task names four unit tests (UT-001 through UT-004) and one regression test (REG-001). The validation file contains inline scenarios that satisfy all of these, but only one scenario carries an explicit label (`-- IT-002`). UT-001 through UT-004 and REG-001 have no corresponding comments identifying them.

Concretely:
- **UT-001** (collapsed root = 1 entry) is covered by lines 84–85 with no label.
- **UT-002** (expanded root with known files at correct depths) is covered by lines 47–66 with no label.
- **UT-003** (`get_ignored_lookup` marks ignored, excludes tracked) is covered by lines 77–82 with no label.
- **UT-004** (`resolve_root` returns git-ancestor root) is covered by lines 87–92 with no label.
- **REG-001** (no crash after `sidebar_explorer_validation` runs) is implicitly satisfied by the full suite passing, but not labelled.

**Impact**: Traceability between task requirements and specific test assertions requires reading the full file. If a test scenario is removed in a future refactor it is non-obvious which requirement ID it covered.

**Severity**: Non-blocking. All required scenarios are present and pass; the gap is documentation only.

---

### F-002 — Duplicate `assert_equal` on `entries[1].type` [Suggestion]

**File**: `config/nvim/tests/sidebar_explorer_validation.lua`, lines 54 and 66

**Observed behaviour:**

`assert_equal(entries[1].type, "directory", "root entry should be a directory")` appears twice in the same test scope — at line 54 (correct position, inside the initial assertion block) and again at line 66 (redundant, between the `lua_entry` and `example_entry` blocks). The second assertion adds no coverage.

**Severity**: Suggestion. The redundant assertion does not harm correctness but adds noise. A future editor may wonder if the two assertions are intentionally testing different things.

---

## AC Evaluation

| AC     | Requirement                                                                                                                                | Status                         | Notes |
|--------|--------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------|-------|
| AC-001 | `explorer.build_entries(root, {[root]=true})` returns a table whose first entry has `type=="directory"`, `depth==0`, `root==true`          | PASS                           | `build_entries` always inserts the root entry first (`init.lua` lines 241–248). Root entry has `type="directory"`, `depth=0`, `root=true`. Verified by UT-002 assertions (`entries[1].type`, `entries[1].expanded`) and confirmed via code inspection. |
| AC-002 | No `ui.*` or `config` module imported by `explorer/init.lua`                                                                               | PASS                           | Only `require` hit in `explorer/init.lua` is the string `"requirements.txt"` inside the `root_markers` table (not a `require` call). Confirmed with `grep -n "require" explorer/init.lua` which returns only that string literal. No `require("ui.*")` or `require("config")` calls exist. |
| AC-003 | Sidebar displays file/directory names, git-ignore dimming, and git status indicators exactly as before after the split                      | Requires interactive verification | `sidebar_explorer.lua` delegates to `explorer.build_entries()` and applies icons and `file_status_renderer.get_indicator()` in local `build_lines()` (lines 32–48). Logic is structurally equivalent to the previous monolith. No code defect detected. Full render verification requires a real Neovim window — not a blocking finding per task constraints. |
| AC-004 | All six test files run headlessly, print `ok`, and exit with code 0                                                                        | PASS                           | All six suites passed: `sidebar_explorer_validation: ok`, `crash_and_refresh_fixes_test: ok`, `shell_cmd_refresh_test: ok`, `git_status_data_layer_test: ok`, `file_explorer_git_indicators_test: ok`, `gutter_renderer_test: ok`. All exited with code 0. |

---

## FR Evaluation

| FR     | Requirement                                                                                                                                                                              | Status | Notes |
|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|-------|
| FR-001 | `lua/explorer/init.lua` exposes `build_entries`, `scandir`, `find_git_root`, `get_ignored_lookup`, `normalize_path`, `path_exists`, and `resolve_root` as public functions               | PASS   | All seven functions are present as `M.*` at lines 14, 19, 45, 93, 106, 194, 216 of `explorer/init.lua`. |
| FR-002 | `explorer.build_entries(root, expanded)` returns raw entry data without display strings                                                                                                  | PASS   | Each entry in `raw_entries` has `{path, name, type, depth, expanded, ignored, root?}`. No icon characters, no indicator symbols, no formatted strings. `build_lines()` in `sidebar_explorer.lua` is the sole place where icons and symbols are applied. |
| FR-003 | `sidebar_explorer.lua` imports `explorer`, delegates filesystem/tree ops to it, and has a local `build_lines()` that calls `explorer.build_entries()` then formats lines                 | PASS   | `local explorer = require("explorer")` at line 3. `build_lines()` at lines 32–48 calls `explorer.build_entries()` then formats icons and indicators. `M.refresh` uses `explorer.path_exists` and `explorer.resolve_root`. `M.open_or_toggle` uses `explorer.path_exists`. `M.collapse_or_parent` uses `explorer.normalize_path`. All filesystem operations delegated. |
| FR-004 | `lua/explorer/init.lua` has no `require` calls to `ui/file_status_renderer`, `ui/gutter_renderer`, or `config`                                                                           | PASS   | Confirmed: `grep -n "require" explorer/init.lua` returns only the string `"requirements.txt"` inside the `root_markers` table — not a `require()` call. Zero `ui.*` or `config` imports in the module. |
| FR-005 | `M._test` escape hatch removed from `sidebar_explorer`; `sidebar_explorer_validation.lua` updated to `require("explorer")` directly and assert entry properties instead of display strings | PASS   | `grep -n "_test" sidebar_explorer.lua` returns no output. Old code had `M._test = { ... }` (confirmed via `git show HEAD:...`). Validation test uses `local explorer = require("explorer")` (line 10) with zero `_test.*` calls. All assertions check `entry.type`, `entry.depth`, `entry.name`, `entry.expanded`, `entry.ignored`. `has_line_suffix` helper removed. |

---

## NFR Evaluation

| NFR     | Requirement                                                                                                                                      | Status | Notes |
|---------|--------------------------------------------------------------------------------------------------------------------------------------------------|--------|-------|
| NFR-001 | All six test suites pass after the split; no test file modified except `sidebar_explorer_validation.lua`                                          | PASS   | `git diff HEAD -- tests/crash_and_refresh_fixes_test.lua tests/shell_cmd_refresh_test.lua tests/git_status_data_layer_test.lua tests/file_explorer_git_indicators_test.lua tests/gutter_renderer_test.lua` produces zero output. Only `sidebar_explorer_validation.lua`, `sidebar_explorer.lua`, and the new `explorer/init.lua` are in scope. All six suites pass. |
| NFR-002 | `lua/explorer/init.lua` follows `local M = {}` / `return M` style matching `lua/git/` and `lua/core/` modules                                     | PASS   | `local M = {}` at line 1; `return M` at line 268. Style matches `git/status.lua` (line 1: `local M = {}`, line 107: `return M`) and `core/status_provider.lua` (line 1: `local M = {}`, line 12: `return M`). |

---

## Test Coverage Evaluation

| Test    | Requirement Covered            | Status  | Notes |
|---------|-------------------------------|---------|-------|
| UT-001  | FR-002, AC-001                 | Present | Lines 84–85: `explorer.build_entries(temp_root, {})` → assert `#collapsed_entries == 1`. Passes headlessly. No label comment; see F-001. |
| UT-002  | FR-002                         | Present | Lines 47–66: `explorer.build_entries` with expanded root → assert entries include root name, lua dir at depth 1, example.lua. Passes headlessly. No label comment; see F-001. |
| UT-003  | FR-001                         | Present | Lines 77–82: `explorer.get_ignored_lookup` → asserts `ignored.txt` included, `tracked.txt` excluded. Passes headlessly. No label comment; see F-001. |
| UT-004  | FR-001                         | Present | Lines 87–92: `explorer.resolve_root()` → asserts result equals normalized git root. `explorer.find_git_root(temp_root)` → asserts normalized root. Passes headlessly. No label comment; see F-001. |
| IT-001  | NFR-001, AC-004                | Present | The combined suite run verifies all six test files still pass after the refactor. Confirmed: all six exit 0. |
| REG-001 | AC-003, AC-004                 | Present | `sidebar_explorer_validation.lua` passing headlessly verifies the decoupling has not broken any previously verified behavior. Passes headlessly. |

---

## DoD Checklist

| DoD Item                                                                                                                                        | Status |
|-------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| `lua/explorer/init.lua` exists with the full public API from the ADR (`build_entries`, `scandir`, `find_git_root`, `get_ignored_lookup`, `normalize_path`, `path_exists`, `resolve_root`) | PASS — all seven functions present in `explorer/init.lua` |
| `lua/sidebar_explorer.lua` delegates all filesystem/tree operations to `explorer`                                                                | PASS — `local explorer = require("explorer")` at line 3; all tree and filesystem calls route through `explorer.*` |
| `sidebar_explorer_validation.lua` updated: `require("explorer")` replaces `require("sidebar_explorer")`, display-string assertions replaced with entry-property assertions | PASS — confirmed via `git diff HEAD` and direct inspection; `_test.*` calls removed, entry-property assertions present |
| All six test suites pass headlessly                                                                                                              | PASS — all six print `ok` and exit 0 |
| `lua/explorer/init.lua` contains no `require("ui.*")` or `require("config")` imports                                                            | PASS — zero such imports, confirmed by grep |
| ADR `docs/adrs/002-explorer-module-boundary.md` updated from `Proposed` to `Accepted`                                                           | PASS — ADR status is `Accepted` (line 5 of the file) |

---

## Convention Notes

- `explorer/init.lua` private helpers (`is_directory`, `get_name`, `sort_entries`, `notify`, `system_list`, `get_root_search_path`) are correctly `local function` declarations and are not exposed on `M`, matching the convention in `git/status.lua` and `git/diff.lua`.
- The `build_entries` root entry is always inserted before `collect_directory` runs, guaranteeing `entries[1]` is always the root. This matches the AC-001 expectation and is consistent with the prior behavior.
- `sidebar_explorer.lua` retains its own `local notify` and `local config` table rather than importing `config` at module load time; `require("config")` is deferred to `M.setup()` at line 283, which is correct — `M.setup()` is called after the Neovim config is fully loaded and `config.lua` is resolvable.
- 4-space indentation is consistent throughout `explorer/init.lua`.

---

## Known Interactive-Only Verification

The following AC item cannot be verified headlessly because it requires a real Neovim window:

- **AC-003**: Sidebar renders file/directory names, git-ignore dimming, and git status indicators exactly as before. No code defect was found that would cause a regression; the `build_lines()` logic in `sidebar_explorer.lua` is structurally equivalent to the former inline version. Manual verification is recommended after merge.
