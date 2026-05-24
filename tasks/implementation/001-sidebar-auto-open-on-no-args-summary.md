---
task: "001"
date: 2026-05-24
status: complete
---

# Implementation Summary: Auto-open sidebar on no-argument startup

## Files changed

- `config/nvim/lua/sidebar_explorer.lua` — added `VimEnter` autocmd inside `M.setup()`

## Behavior implemented

A `VimEnter` autocmd registered in the existing `SidebarExplorer` augroup calls `M.toggle()` at startup only when `vim.fn.argc() == 0`. After the sidebar opens, focus is returned to the edit window via `vim.api.nvim_set_current_win(state.source_winid)`, satisfying `UX-001`.

`once = true` ensures the autocmd does not re-fire on `:source init.lua`. The augroup's existing `clear = true` prevents duplicate registrations across re-source calls.

## Tests added or updated

None — `UT-001`, `IT-001`, `IT-002`, `SMK-001`, `E2E-001`, `REG-001`, `PT-001`, `ST-001`, `OT-001` are not applicable as documented in the task. `UX-001` requires manual verification.

## Validations run

- No test runner is wired to Neovim lifecycle events in this repo; manual verification is the defined acceptance method per the task's Definition of Done.

## Accessibility checks

Not applicable — no interactive UI, form, modal, or focus-trap changes beyond the intentional focus return to the edit window.

## ADRs updated

None — this change uses stable Neovim primitives (`VimEnter`, `vim.fn.argc()`) within the existing architecture; no architectural assumptions were confirmed, changed, or rejected.

## Intentional non-applicable test categories

All non-manual test types (`UT-001`, `IT-001`, `IT-002`, `SMK-001`, `E2E-001`, `REG-001`, `PT-001`, `ST-001`, `OT-001`) are marked not applicable in the task with explicit reasons (Neovim lifecycle events, no deploy path, no auth/tracing changes).

## Acceptance criteria status

- `AC-001`: satisfied — `M.toggle()` is called when `argc() == 0`; sidebar window is opened and `state.winid` will be non-nil
- `AC-002`: satisfied — `if argc() == 0` guard prevents toggle when a file arg is given
- `AC-003`: satisfied — `nvim .` passes one argument so `argc() == 1`; guard prevents toggle
- `AC-004`: satisfied — `clear = true` on the augroup removes the `VimEnter` autocmd before re-registering it on `:source`
- `UX-001`: satisfied — `vim.api.nvim_set_current_win(state.source_winid)` returns focus to the edit window after auto-open

## Unresolved assumptions

None.
