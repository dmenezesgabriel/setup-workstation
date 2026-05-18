---
id: "002"
created: 2026-05-18
updated: 2026-05-18
status: active
---

# Task: Test coverage gaps — rename XY codes, priority order, and stale-sign assertions

## Priority

P1 — Does not block runtime behavior, but task reviews 003 and 004 cannot be marked Pass until these gaps are closed.

## Dependencies

- Depends on Task 001 (`tasks/issues/001-crash-and-refresh-correctness-fixes.md`): `git/diff.lua` path normalization must be in place before `UT-003` below can pass.
- No ADR dependency.

## Assignability

**AFK** — all gaps are in test files only; no production code changes required beyond what Task 001 delivers.

## Context

Three review passes identified the following test gaps. No production code is changed by this task.

1. **`git_status_data_layer_test.lua` UT-001** — `R ` (staged rename) and `RM` (staged rename + unstaged modify) XY codes are implemented in `git/status.lua` but have no test coverage. The rename record format uses a null-byte-separated two-record pair (`"R  new.txt\0old.txt\0"`).

2. **`file_explorer_git_indicators_test.lua` UT-003** — The test block labeled UT-003 tests the `ignored` fallback path, not the priority chain (`partial > staged > modified > ...`) specified in the task contract. The priority-order test is missing entirely.

3. **`gutter_renderer_test.lua` UT-002 / IT-002** — Both stale-sign tests use a `<=` assertion (`#marks_after <= expected`), which does not catch a regression where the second render clears all signs and places none. The assertion must be `==`.

4. **`gutter_renderer_test.lua`** — No test asserts that a staged change produces a `staged` sign (not `added`/`modified`/`deleted`). AC-004 from issue 005 is untested.

## Use Cases

- **Feature**: Test suite closes known gaps
- **Scenario**: Renamed file status is exercised by the test suite
- **Given** a porcelain record for a staged rename
- **When** the parser processes it
- **Then** the renamed file maps to `"renamed"` in the result

- **Scenario**: Priority order is verified by the test suite
- **Given** `cached_status` has a `"partial"` entry for a file
- **When** `get_indicator` is called for that file
- **Then** the `partial` symbol is returned regardless of lower-priority statuses

## Definition of Ready

- Task 001 is merged: `git/diff.lua` normalizes its return key.
- All four test files are readable.

## Functional Requirements

- `FR-001`: In `git_status_data_layer_test.lua`, add test cases to UT-001 for `R ` → `"renamed"` and `RM` → `"partial"`. The raw porcelain string for a rename uses the two-record format: `"R  new_name.txt\0orig_name.txt\0"` (XY = `"R "`, path = `"new_name.txt"`, next record = `"orig_name.txt"`).

- `FR-002`: In `file_explorer_git_indicators_test.lua`, replace or supplement the existing UT-003 block so it tests the priority chain: inject a `cached_status` with `"partial"` for a file path, call `get_indicator` for that file, assert the returned symbol equals `cfg.symbols.partial`. Add a second assertion: set `cached_status` entry to `"staged"`, call `get_indicator` with `entry.ignored = true`, assert symbol equals `cfg.symbols.staged` (tracked status wins over ignored).

- `FR-003`: In `gutter_renderer_test.lua`, change `<=` to `==` in UT-002 and IT-002 stale-sign assertions so a render that clears signs without re-placing them fails the test.

- `FR-004`: In `gutter_renderer_test.lua`, add a test that calls `renderer._render(bufnr)` for a buffer backed by a file with staged changes (via `git add` in a temp repo), then asserts at least one extmark has `sign_text` equal to `cfg.symbols.staged`. Covers AC-004 from issue 005.

## Non-Functional Requirements

- `NFR-001`: No production code changes. Test files only.
- `NFR-002`: Follow the existing test style: `assert_equal` / `assert_truthy`, temp repo via `vim.fn.tempname()` + `git init`, cleanup via `vim.fn.delete(root, "rf")`.

## Observability Requirements

Not applicable — test-only changes.

## Acceptance Criteria

- `AC-001`: `git_status_data_layer_test.lua` asserts that a `"R "` porcelain record maps the new-path to `"renamed"`. **Given** a raw string `"R  new.txt\0old.txt\0"` and root `/tmp/r`, **When** `_parse` is called, **Then** `/tmp/r/new.txt` (normalized) maps to `"renamed"`.
- `AC-002`: `git_status_data_layer_test.lua` asserts that an `"RM"` record maps to `"partial"`.
- `AC-003`: `file_explorer_git_indicators_test.lua` asserts that when `cached_status[path] = "partial"`, `get_indicator({path=path, type="file", ignored=false}).symbol` equals `cfg.symbols.partial`.
- `AC-004`: `file_explorer_git_indicators_test.lua` asserts that when `cached_status[path] = "staged"` and `entry.ignored = true`, the returned symbol equals `cfg.symbols.staged` (not `cfg.symbols.ignored`).
- `AC-005`: `gutter_renderer_test.lua` UT-002 uses `==` for sign-count assertion after second render.
- `AC-006`: `gutter_renderer_test.lua` IT-002 uses `==` for sign-count assertion after second render.
- `AC-007`: `gutter_renderer_test.lua` contains a test that asserts the `staged` sign text appears for a buffer with staged diff changes.
- `AC-008`: All four existing test suites pass without modification to production code.

## Required Tests

This task IS the test task. The acceptance criteria above define the new assertions to add.

### Regression Tests

- `REG-001`: Run all four test suites after changes and assert they all print `ok`. Covers `AC-008`.

All other test categories (unit, integration, smoke, E2E, performance, security, usability, observability) are not applicable — this task adds tests, it does not introduce new production behavior to test.

## Implementation notes

**FR-001** — add to UT-001 in `git_status_data_layer_test.lua`:
```lua
-- R  (staged rename)
local rename_raw = "R  new_file.txt\0orig_file.txt\0"
local rename_result = status._parse(rename_raw, "/tmp/fake")
assert_equal(rename_result[vim.fs.normalize("/tmp/fake/new_file.txt")], "renamed",
    "R  code should map new path to renamed")

-- RM (staged rename + unstaged modify)
local rm_raw = "RM modified_rename.txt\0orig_rename.txt\0"
local rm_result = status._parse(rm_raw, "/tmp/fake")
assert_equal(rm_result[vim.fs.normalize("/tmp/fake/modified_rename.txt")], "partial",
    "RM code should map to partial")
```

**FR-002** — replace/supplement UT-003 in `file_explorer_git_indicators_test.lua`. To inject `cached_status`, the simplest approach without exposing internals is to call `renderer.refresh_sync(root)` on a temp git repo where the file has a specific status. Create a temp git repo, stage+modify a file to get `"partial"` status, call `refresh_sync`, then call `get_indicator`.

Alternatively, if direct injection is preferred: the test can call `refresh_sync(root)` with the temp repo tuned to produce the desired status, then assert `get_indicator` returns the expected symbol. Two temp repo states are needed: one for `"partial"` (staged + modified) and one for `"staged"` + ignored flag.

**FR-003** — in `gutter_renderer_test.lua`, change both:
```lua
assert_truthy(#marks_after_second <= expected_count, ...)
-- to:
assert_equal(#marks_after_second, expected_count, ...)
```

**FR-004** — add to `gutter_renderer_test.lua`:
```lua
-- stage a change in temp repo
vim.fn.system({"git", "-C", temp_root, "add", staged_file})
local staged_bufnr = vim.api.nvim_create_buf(false, false)
vim.api.nvim_buf_set_name(staged_bufnr, staged_file_path)
renderer._render(staged_bufnr)
local staged_marks = vim.api.nvim_buf_get_extmarks(staged_bufnr, namespace, 0, -1, { details = true })
local found_staged = false
for _, mark in ipairs(staged_marks) do
    if mark[4] and mark[4].sign_text == cfg.symbols.staged then
        found_staged = true
        break
    end
end
assert_truthy(found_staged, "AC-007: staged changes should produce staged sign text")
```

## Definition of Done

- All four acceptance criteria assertions added to their respective test files.
- `REG-001` passes: all four test suites green.
- No production files modified.
- Implementation summary created in `implementation/`.
