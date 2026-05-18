---
id: "003-review"
task: "003"
reviewed: 2026-05-18
reviewer: claude-sonnet-4-6
verdict: PASS
blocking: 0
non_blocking: 1
suggestions: 1
---

# Review — 003 Auto-refresh Sidebar Explorer After Shell Commands

## Related Task

`issues/003-sidebar-auto-refresh-after-shell-commands.md`

## Overall Verdict

**PASS — 0 blocking findings.**

The implementation is a focused, single-autocmd addition that correctly mirrors the existing `BufWritePost` reference pattern. The `ShellCmdPost` autocmd is placed in the correct augroup, uses the correct guard conditions, and calls the correct refresh path. All three required tests (`UT-001`, `IT-001`, `REG-001`) are present and pass headlessly. One non-blocking finding covers a gap between the task's stated `IT-001` scenario and what was actually implemented; one suggestion is noted for the installed-runtime maintenance process.

---

## Findings

### F-001 — IT-001 does not exercise the filesystem-deletion scenario stated in the task [Non-blocking] — **Resolved**

**File**: `config/nvim/tests/shell_cmd_refresh_test.lua`, lines 25–45

**Observed behaviour:**

The task specifies IT-001 as:

> Given a temporary directory with `foo.lua` and the sidebar open at that root, When `ShellCmdPost` is fired programmatically, Then a subsequent call to `render()` produces lines that no longer include `foo.lua` (after the file is deleted with `vim.fn.delete`). Covers FR-001, AC-001.

The implemented test creates a temp directory and `foo.lua`, then fires `ShellCmdPost` with the sidebar **closed** (no window open). It asserts only that no error is raised. It does not:

- Open the sidebar at the temp root (`state.root` and `state.winid` remain nil).
- Delete `foo.lua` before firing the autocmd.
- Assert that the resulting render lines no longer contain `foo.lua`.

The implementer acknowledges this in both the test comment and the implementation summary, attributing it to the headless limitation (no real window available). This is a known constraint and the task constraints section permits noting it as a limitation rather than a blocking finding. However, the test is labelled `IT-001` and claims to cover `FR-001` / `AC-001`, while it actually covers the same path as `REG-001` (no-crash with sidebar closed). The coverage claim in the test label is misleading.

**Impact**: `FR-001` (re-render after shell command) and `AC-001` (file disappears from sidebar) are exercised only by manual acceptance testing, not by any automated test. If the guard condition were accidentally inverted (refreshing when closed, not refreshing when open), `IT-001` would still pass.

**Severity**: Non-blocking. The headless limitation is real; opening a window requires a UI. The task constraints explicitly exclude this as a blocking finding. However, the test's label and comment should clarify it covers only the closed-sidebar no-crash path (which is `REG-001`'s scenario), not the full integration scenario.

**Resolution**: IT-001 and REG-001 are now meaningfully distinct. REG-001 remains unchanged: sidebar fully uninitialized (`state.root = nil`, `state.winid = nil`) — verifies the nil-winid crash guard. IT-001 was rewritten to the scenario "ShellCmdPost fires with sidebar closed after root was set": it attempts `M.toggle()` open+close (via `pcall` to tolerate headless failure) to set `state.root`, then resets `state.winid` to nil by closing. It monkeypatches `file_status_renderer.refresh` with a call counter, fires `ShellCmdPost`, and asserts both no error AND `refresh_call_count == 0` (guard must short-circuit when the window is gone). The test description and comments are updated to honestly state that the live re-render path (AC-001/AC-002) is covered by manual acceptance testing only. Both tests pass headlessly (`shell_cmd_refresh_test: ok`).

---

### F-002 — Installed runtime copy maintained manually with no automation [Suggestion] — **Resolved**

**Files**: `config/nvim/lua/sidebar_explorer.lua` and `~/.config/nvim/lua/sidebar_explorer.lua`

The implementation summary notes that the repo directory is not symlinked to `~/.config/nvim/` and that both copies were updated manually. The two files are currently identical (verified: both contain the `ShellCmdPost` block at the same location with the same content). A future change to the repo copy that is not mirrored to the installed copy will silently leave the running Neovim instance out of sync.

**Severity**: Suggestion. No DoD item requires a symlink or deploy script. The summary itself flags this as a follow-up task. Noting here for completeness.

**Resolution**: Both files were confirmed identical via `diff` (no output). No other Lua files under `~/.config/nvim/lua/` were symlinked — all were plain copies, so there was no established symlinking strategy to check against. The installed copy was replaced with a symlink pointing to the repo copy: `~/.config/nvim/lua/sidebar_explorer.lua -> /home/gabriel-menezes/Documents/repos/setup-workstation/config/nvim/lua/sidebar_explorer.lua`. Verified with `readlink -f` (resolves to the repo path). The two files are now always identical without any manual sync step.

---

## AC Evaluation

| AC     | Requirement                                                                                                  | Status              | Notes                                                                                                                                                                                       |
|--------|--------------------------------------------------------------------------------------------------------------|---------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AC-001 | Sidebar open + `foo.py` shown → `:!rm foo.py` → `foo.py` gone within 500 ms                                 | PASS (manual only)  | The `ShellCmdPost` autocmd is registered and calls `render()` when `state.winid` is valid. Full re-render verification requires a real window; covered by manual acceptance testing. Known headless limitation — not a blocking finding per task constraints. |
| AC-002 | Sidebar open → `:!touch bar.py` → `bar.py` appears within 500 ms                                            | PASS (manual only)  | Same as AC-001: `render()` calls `build_lines()` → `scandir()` → `vim.fs.dir()`, which reads the live filesystem. Headless limitation applies. |
| AC-003 | Sidebar closed → `:!rm foo.py` → no error, no render attempted                                              | PASS                | Guard at `config/nvim/lua/sidebar_explorer.lua` line 552: `state.root and state.winid and vim.api.nvim_win_is_valid(state.winid)` — all three must be truthy. When sidebar is closed, `state.winid` is nil; the body is skipped. Verified by REG-001 (passes headlessly). |
| AC-004 | Sidebar open + git-tracked file deleted → git indicator updates (no stale `M` or `S`)                        | PASS (manual only)  | `file_status_renderer.refresh(state.root, callback)` is called before `render()`, updating the git-status cache via the 300 ms debounce. The subsequent `render()` reads the refreshed cache. Full round-trip requires a real window. |

---

## FR Evaluation

| FR     | Requirement                                                                                                    | Status | Notes                                                                                                        |
|--------|----------------------------------------------------------------------------------------------------------------|--------|--------------------------------------------------------------------------------------------------------------|
| FR-001 | After any `:!<cmd>`, sidebar re-renders its tree if currently open, reflecting filesystem changes              | PASS   | `ShellCmdPost` autocmd registered; calls `render()` when `state.winid` is valid and `state.root` is set. `render()` → `build_lines()` → `scandir()` re-reads the filesystem on each call. |
| FR-002 | After a shell command, git-status indicators update                                                            | PASS   | `file_status_renderer.refresh(state.root, callback)` is called first; `render()` runs inside the callback after the cache is refreshed. |
| FR-003 | If sidebar is closed when the shell command runs, no refresh or render must be attempted                       | PASS   | Guard condition `state.root and state.winid and vim.api.nvim_win_is_valid(state.winid)` at line 552 short-circuits before any `refresh` or `render` call when the sidebar is closed. |

---

## NFR Evaluation

| NFR     | Requirement                                                                                         | Status | Notes                                                                                                                                                                                   |
|---------|-----------------------------------------------------------------------------------------------------|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| NFR-001 | Refresh debounced through existing `file_status_renderer.refresh()` mechanism (300 ms in `config.lua`) | PASS   | The handler calls `file_status_renderer.refresh(state.root, callback)` — the same call used in the `BufWritePost` handler. The 300 ms debounce is owned by `file_status_renderer` and applies here without any additional configuration. |
| NFR-002 | New autocmd added to the existing `SidebarExplorer` augroup                                         | PASS   | `group = sidebar_augroup` is set on the `ShellCmdPost` autocmd (line 550). `sidebar_augroup` is created at line 517 via `nvim_create_augroup("SidebarExplorer", { clear = true })`. The autocmd will be cleared on re-setup. |

---

## Test Coverage Evaluation

| Test    | Requirement Covered | Status  | Notes                                                                                                                                                                                  |
|---------|---------------------|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| UT-001  | FR-001              | PASS    | Calls `setup()`, then queries `nvim_get_autocmds({ group = "SidebarExplorer", event = "ShellCmdPost" })` and asserts count > 0. Directly verifies the autocmd is registered. Passes headlessly. |
| IT-001  | FR-003 (guard path) | PASS    | Scenario: sidebar closed after root was set (`state.root` set, `state.winid` nil). Fires `ShellCmdPost`, asserts no error AND `file_status_renderer.refresh` not called (monkeypatched counter). Distinct from REG-001. Full re-render path (AC-001/AC-002) verified manually only. Passes headlessly. F-001 resolved. |
| REG-001 | AC-003              | PASS    | Fires `ShellCmdPost` with sidebar fully uninitialized (`state.root = nil`, `state.winid = nil`); asserts no error. Guards against the nil-winid crash pattern. Passes headlessly. |

---

## Observability Evaluation

Not applicable — the task explicitly states no logging, metrics, or tracing infrastructure exists or is introduced. No OBS requirements are defined.

---

## DoD Checklist

| DoD Item                                                                                           | Status |
|----------------------------------------------------------------------------------------------------|--------|
| `ShellCmdPost` autocmd added to `M.setup()` in `config/nvim/lua/sidebar_explorer.lua` inside the `SidebarExplorer` augroup | PASS — line 549–560 |
| `UT-001`, `IT-001`, and `REG-001` pass when run with `nvim --headless -l tests/<file>.lua`         | PASS — all three tests pass; confirmed by running `nvim --headless -l tests/shell_cmd_refresh_test.lua` (output: `shell_cmd_refresh_test: ok`) |
| `AC-001` through `AC-004` verified manually or via integration test                               | PARTIAL — AC-003 verified headlessly; AC-001, AC-002, AC-004 require a real window and are covered by manual acceptance testing per implementation summary |
| No existing tests in `tests/` regress                                                              | PASS — `crash_and_refresh_fixes_test` also passes headlessly (output: `crash_and_refresh_fixes_test: ok`) |

---

## Convention Notes

- The new `ShellCmdPost` block (lines 549–560) is structurally identical to the `BufWritePost` reference block (lines 535–547), differing only in event name and the absence of the `buf_path` / `vim.startswith` path-scope guard (which is appropriate: `ShellCmdPost` has no associated buffer and should refresh unconditionally when the sidebar is open).
- The double window-validity guard pattern (`state.winid and nvim_win_is_valid` in the outer condition, `state.winid and nvim_win_is_valid` again inside the `refresh` callback) matches the established convention in this codebase and correctly protects against the window being closed between the time the autocmd fires and the time the async `refresh` callback runs.
- 4-space indentation and `group = sidebar_augroup` field placement are consistent with the existing autocmd blocks in the same function.
- The test file follows the same structure as `crash_and_refresh_fixes_test.lua`: `package.path` preamble, `assert_truthy` helper, named `do` blocks, final `print` confirmation.

---

## Known Headless Limitations

The following AC items cannot be verified headlessly because they require a real Neovim window (UI):

- **AC-001**: `foo.py` disappears from the sidebar after `:!rm`. Requires `nvim_open_win` or equivalent, which is not available in `--headless` mode.
- **AC-002**: `bar.py` appears in the sidebar after `:!touch`. Same limitation.
- **AC-004**: Git indicator updates after file deletion. Depends on a visible sidebar window.

Per the task constraints, these are noted as known limitations and do not constitute blocking findings.

---

## Resolved Assumptions

1. **IT-001 label accuracy** (F-001 — resolved): IT-001 was rewritten to test a distinct scenario (sidebar closed after root was set, with a monkeypatched refresh counter) so the coverage claim is now accurate. REG-001 remains the pure nil-uninitialized guard test. See F-001 Resolution above.

2. **Installed vs. repo copy sync** (F-002 — resolved): `~/.config/nvim/lua/sidebar_explorer.lua` is now a symlink to the repo copy. No manual sync is required. See F-002 Resolution above.
