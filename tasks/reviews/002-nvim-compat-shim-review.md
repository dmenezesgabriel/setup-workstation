---
id: "002"
issue: "tasks/issues/002-nvim-compat-shim.md"
created: 2026-05-24
updated: 2026-05-24
---

# Review: Add compat module and fix version-specific call sites

## Related Task

- `tasks/issues/002-nvim-compat-shim.md`

## Overall Verdict

**Pass**

## Findings

None.

## AC Evaluation

| AC | Result | Notes |
|----|--------|-------|
| AC-001 | Pass | `compat.uv` is defined as `vim.uv or vim.loop`, so it returns a libuv handle on 0.8 and 0.10+. |
| AC-002 | Pass | On 0.10+, `compat.uv` resolves to `vim.uv`, avoiding `vim.loop` access. |
| AC-003 | Pass | `compat.fs_relpath("/tmp/root", "/tmp/root/sub/file.txt")` returns `sub/file.txt` via direct delegation or fallback prefix stripping. |
| AC-004 | Pass | The fallback returns `nil` when the path is not under the base. |
| AC-005 | Pass | `gutter_renderer.lua` and `file_status_renderer.lua` now use `compat.uv.new_timer()`, removing direct `vim.uv` access. |
| AC-006 | Pass | `git/diff.lua` now uses `compat.fs_relpath()` instead of `vim.fs.relpath()`. |

## Test Coverage Evaluation

| Test Category | Status | Notes |
|---------------|--------|-------|
| Unit (UT-001) | Present | `config/nvim/tests/compat_test.lua` covers `compat.uv` and `new_timer`. |
| Unit (UT-002) | Present | `config/nvim/tests/compat_test.lua` checks under-base relpath resolution. |
| Unit (UT-003) | Present | `config/nvim/tests/compat_test.lua` checks out-of-tree relpath returns nil. |
| Unit (UT-004) | Present | `config/nvim/tests/compat_test.lua` conditionally asserts `compat.uv == vim.uv` on 0.10+. |
| Integration (IT-001) | Not applicable | Marked not applicable in the task spec. |
| Smoke (SMK-001) | Not applicable | Marked not applicable in the task spec. |
| E2E | Not applicable | Marked not applicable in the task spec. |
| Regression | Not applicable | Marked not applicable in the task spec. |
| Performance | Not applicable | Marked not applicable in the task spec. |
| Security | Not applicable | Marked not applicable in the task spec. |
| Usability (UX-001) | Not applicable | Marked not applicable in the task spec. |

## Observability Evaluation

Not applicable — no OBS requirements defined in the task.

## ADR Compliance

Not applicable — no ADR dependencies listed in the task.

## Convention Notes

None.

## Unresolved Assumptions or Follow-Up

- None.
