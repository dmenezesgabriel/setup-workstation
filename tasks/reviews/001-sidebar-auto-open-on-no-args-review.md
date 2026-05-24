---
id: "001"
issue: "tasks/issues/001-sidebar-auto-open-on-no-args.md"
created: 2026-05-24
updated: 2026-05-24
---

# Review: Auto-open sidebar when nvim is started with no arguments

## Related Task

- `tasks/issues/001-sidebar-auto-open-on-no-args.md`

## Overall Verdict

**Pass**

No Blocking findings.

## Findings

| ID | Level | Requirement | Description | Evidence |
|----|-------|-------------|-------------|----------|
| F-001 | Suggestion | IT-001, IT-002 | Implementation summary classifies IT-001 and IT-002 as "not applicable as documented in the task," but the issue defines them as concrete test scenarios — the DoD escape hatch says they should "pass (or are marked as manual)." "Not applicable" and "marked as manual" are distinct statuses; using the wrong label may mislead future readers. No code impact. | `tasks/implementation/001-sidebar-auto-open-on-no-args-summary.md` — "Tests added or updated" section |

## AC Evaluation

| AC | Result | Notes |
|----|--------|-------|
| AC-001 | Pass | `VimEnter` callback calls `M.toggle()` when `argc() == 0`; `M.toggle()` calls `open_sidebar_window()` which renders the sidebar with `state.root` as the first entry. Focus is then returned to the edit window via `nvim_set_current_win(state.source_winid)`. Sidebar is visible and showing the project root. `sidebar_explorer.lua:328–339` |
| AC-002 | Pass | Guard `if vim.fn.argc() == 0` prevents `M.toggle()` from firing when argc is 1 or more. Sidebar stays closed. `sidebar_explorer.lua:332` |
| AC-003 | Pass | `nvim .` passes one argument; `argc()` returns 1; guard condition is false; sidebar is not opened. `sidebar_explorer.lua:332` |
| AC-004 | Pass | `vim.api.nvim_create_augroup("SidebarExplorer", { clear = true })` clears all autocmds in the augroup before re-registering on every `M.setup()` call. Additionally `once = true` ensures the `VimEnter` autocmd fires at most once per Neovim session. `sidebar_explorer.lua:283, 330` |

## Test Coverage Evaluation

| Test Category | Status | Notes |
|---------------|--------|-------|
| Unit (UT-001) | Not applicable | Issue marks UT-001 not applicable — VimEnter lifecycle event has no isolatable pure logic function. |
| Integration (IT-001) | Manual | No automated test runner is wired to Neovim lifecycle events in this repo. DoD escape hatch invoked. Behavior verified via code inspection: `argc() == 0` path calls `M.toggle()` and sets `state.winid`. |
| Integration (IT-002) | Manual | Same rationale. `argc() >= 1` path: guard is false, `M.toggle()` is not called, `state.winid` remains nil. |
| Smoke (SMK-001) | Not applicable | Issue marks SMK-001 not applicable — startup UX tweak, not a deploy/build path. |
| E2E (E2E-001) | Not applicable | Issue marks E2E-001 not applicable — no multi-step user journey changes. |
| Regression (REG-001) | Not applicable | Issue marks REG-001 not applicable — no prior defect being fixed. |
| Performance (PT-001) | Not applicable | Issue marks PT-001 not applicable — opening one window at startup has no measurable performance risk. |
| Security (ST-001) | Not applicable | Issue marks ST-001 not applicable — no auth, authorization, input, or trust-boundary changes. |
| Usability (UX-001) | Manual | Code at `sidebar_explorer.lua:334–336` calls `nvim_set_current_win(state.source_winid)` after auto-open, returning cursor to the edit window. Manual verification required per DoD. |
| Observability (OT-001) | Not applicable | Issue marks OT-001 not applicable — no logs, metrics, or traces involved. |

## Observability Evaluation

Not applicable — no OBS requirements defined in the task (`OBS-001` marked not applicable in the issue).

## ADR Compliance

Not applicable — no ADR dependencies listed in the task.

## Convention Notes

- `F-001` — Suggestion — The implementation summary uses "not applicable" for IT-001 and IT-002, which the issue's Required Tests section defines as concrete (manually runnable) scenarios. The issue's DoD explicitly differentiates "pass" from "marked as manual" — using "not applicable" conflates two distinct statuses. A future implementer relying on the summary may incorrectly conclude the issue itself waived these tests. Recommend updating the summary to say "manual — no automated test runner available for Neovim lifecycle events."

## Unresolved Assumptions or Follow-Up

- `UX-001` requires live manual verification (cursor lands in the edit window, not the sidebar, after `nvim` startup with no args). The code satisfies the scenario structurally but runtime confirmation has not been captured in the implementation summary.
- `IT-001` and `IT-002` are manual scenarios; if a Neovim test runner (e.g., `mini.test` or `plenary.nvim`) is ever added to this repo, these scenarios should be automated at that time.
