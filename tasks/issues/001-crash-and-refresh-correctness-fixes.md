---
id: "001"
created: 2026-05-18
updated: 2026-05-18
status: active
---

# Task: Crash prevention and refresh correctness fixes

## Priority

P0 — Contains crash-on-invalid-window, stale-data-overwrite race, and a re-render that never fires after a save. All are visible in normal use.

## Dependencies

- No task dependency; fixes are self-contained surgical edits.
- No ADR dependency; no architectural decision is introduced.

## Assignability

**AFK** — all bugs are precisely located and the fixes are mechanical one-to-five-line changes per site.

## Context

Five concrete bugs were identified across three review passes. They are grouped here because they share two files (`sidebar_explorer.lua`, `ui/file_status_renderer.lua`) and fixing them in the wrong order would require re-reading the same functions twice.

```
BufWritePost fires
  │
  ├─ file_status_renderer.refresh(root)  ← timer T1 starts
  └─ M.refresh()
       ├─ render()          ← renders with STALE cached_status
       └─ file_status_renderer.refresh(root)  ← cancels T1, timer T2 starts
                                                 (callback updates cache but never re-renders)
```

The fix threads an `on_done` callback through `file_status_renderer.refresh()` so the re-render fires after the fresh cache lands, and removes the double-call from `M.refresh()`.

## Use Cases

- **Feature**: Safe sidebar rendering and correct post-save git indicators
- **Scenario**: User closes editor window externally while sidebar is open
- **Given** only the sidebar window is open
- **When** a keymap or autocmd triggers `render()`
- **Then** no Neovim error is raised

- **Scenario**: User saves a file with the sidebar open
- **Given** the sidebar is visible and the file is under the current root
- **When** the file is saved
- **Then** the sidebar re-renders with fresh git indicators within `debounce_ms` milliseconds

- **Scenario**: User switches projects between debounce ticks
- **Given** a `refresh()` timer is pending for root A
- **When** `refresh_sync(root_B)` fires before the timer callback runs
- **Then** `cached_status` is not overwritten with root A's data

## Definition of Ready

- Code for all five bug sites has been read (done above).
- No new architectural decisions required.

## Functional Requirements

- `FR-001`: `render()` in `sidebar_explorer.lua` must guard the `nvim_win_get_cursor` / `nvim_win_set_cursor` block with `state.winid and vim.api.nvim_win_is_valid(state.winid)` before accessing cursor position. The lines that set buffer content (`nvim_buf_set_lines`, `apply_highlights`) must remain unconditional — only the cursor restoration block needs guarding.

- `FR-002`: The `BufWritePost` autocmd in `M.setup` (`sidebar_explorer.lua`) must be registered under a named augroup so repeated `setup()` calls (plugin reload, hot-reload) do not accumulate duplicate handlers. A module-level augroup `"SidebarExplorer"` with `{ clear = true }` is the fix.

- `FR-003`: `file_status_renderer.refresh(root, on_done?)` must accept an optional callback. Inside the debounce callback body, the module-level `timer` variable must be compared against the local `t` captured at call time; if they differ (meaning `refresh_sync` or a newer `refresh` has already cancelled this invocation) the callback must return early without updating `cached_status` or calling `on_done`. After a successful update, `timer` must be set to `nil` and `on_done()` must be called if provided.

- `FR-004`: The `BufWritePost` handler in `M.setup` must be changed to call only `file_status_renderer.refresh(state.root, on_done)` where `on_done` calls `render()` (guarded by `state.winid` validity). The separate call to `M.refresh()` inside the `BufWritePost` handler must be removed. `M.refresh()` (the `r` keymap path) remains unchanged — it renders immediately with the current cache, then schedules a debounced update via `file_status_renderer.refresh(state.root)` (no `on_done`).

- `FR-005`: `git/diff.lua`'s `M.get(path, staged)` must normalize the `path` argument before using it as the return table key: `return { [vim.fs.normalize(path)] = line_map }`. `M._parse` stays unchanged — the fix is in `M.get` only.

## Non-Functional Requirements

- `NFR-001`: No new module-level state beyond the augroup handle. No new functions beyond the `on_done` parameter.
- `NFR-002`: Style consistency with existing code (4-space indent, `local M = {}` pattern, no comments unless WHY is non-obvious).

## Observability Requirements

- `OBS-001`: No new user-facing notifications introduced. All fixes must remain silent on error (existing error-handling behavior preserved).

## Acceptance Criteria

- `AC-001`: **Given** `state.winid` is nil or invalid, **When** `render()` is called, **Then** no error is raised and the buffer content is still updated (only cursor restoration is skipped).
- `AC-002`: **Given** `M.setup()` is called twice, **When** a file is saved, **Then** only one `BufWritePost` handler fires (augroup with `clear = true` prevents duplication).
- `AC-003`: **Given** a file under `state.root` is saved, **When** `debounce_ms` milliseconds elapse, **Then** the sidebar re-renders with the fresh `cached_status` (not just the stale one from the time of save).
- `AC-004`: **Given** `refresh_sync(root_B)` is called during the `refresh(root_A)` debounce window, **When** the stale timer callback fires, **Then** `cached_status` is not overwritten with root A's data and `on_done` is not called.
- `AC-005`: **Given** a file path is returned from `git/diff.lua`'s `M.get`, **When** the caller looks up the result by `vim.fs.normalize(path)`, **Then** the lookup succeeds (not `nil`).
- `AC-006`: All four existing test suites continue to pass after these changes.

## Required Tests

### Unit Tests

- `UT-001`: Call `render()` with `state.winid = nil`; assert no error and buffer lines are set. Covers `FR-001`, `AC-001`.
- `UT-002`: Call `file_status_renderer.refresh(root, on_done)` followed immediately by `file_status_renderer.refresh_sync(root_B)`; then wait for the debounce window via `vim.defer_fn`; assert `on_done` was not called and `cached_status` reflects root B. Covers `FR-003`, `AC-004`.
- `UT-003`: Call `git.diff.get(path)` and assert the returned table key equals `vim.fs.normalize(path)`. Covers `FR-005`, `AC-005`.

### Integration Tests

- `IT-001`: **Scenario**: BufWritePost triggers fresh re-render  
  **Given** a temp git repo with a modified file and the sidebar showing stale status  
  **When** a `BufWritePost` event fires for the modified file  
  **Then** after `debounce_ms` ms the sidebar shows the updated indicator  
  Covers `AC-003`, `FR-004`.

### Smoke Tests

Not applicable — no standalone startup or deploy path.

### End-to-End Tests

Not applicable — no automated E2E harness.

### Regression Tests

- `REG-001`: Run all four existing test suites (`sidebar_explorer_validation`, `git_status_data_layer_test`, `file_explorer_git_indicators_test`, `gutter_renderer_test`) and assert they pass. Covers `AC-006`.

### Performance Tests

Not applicable — fixes are O(1) checks.

### Security Tests

Not applicable — no user input involved.

### Usability Tests

Not applicable — these are crash-prevention and correctness fixes with no visible UI change beyond correct indicators.

### Observability Tests

Not applicable — fixes are silent (no new notifications or logs).

## Implementation notes

**FR-001** — change `render()` lines 388-392 in `sidebar_explorer.lua`:
```lua
-- before
if #lines > 0 then
    local line = vim.api.nvim_win_get_cursor(state.winid)[1]
    line = math.max(1, math.min(line, #lines))
    vim.api.nvim_win_set_cursor(state.winid, { line, 0 })
end

-- after
if #lines > 0 and state.winid and vim.api.nvim_win_is_valid(state.winid) then
    local line = vim.api.nvim_win_get_cursor(state.winid)[1]
    line = math.max(1, math.min(line, #lines))
    vim.api.nvim_win_set_cursor(state.winid, { line, 0 })
end
```

**FR-002** — add a module-level augroup at the top of `sidebar_explorer.lua`'s `M.setup` body, and register `BufWritePost` under it:
```lua
local sidebar_augroup = vim.api.nvim_create_augroup("SidebarExplorer", { clear = true })
-- then pass group = sidebar_augroup to the BufWritePost autocmd
```

**FR-003** — replace `M.refresh` in `file_status_renderer.lua`:
```lua
function M.refresh(root, on_done)
    if timer then timer:stop(); timer:close(); timer = nil end
    local t = vim.uv.new_timer()
    timer = t
    t:start(cfg.debounce_ms, 0, vim.schedule_wrap(function()
        if timer ~= t then return end
        timer = nil
        cached_status = git_status.get(root) or {}
        if on_done then on_done() end
    end))
end
```

**FR-004** — replace `BufWritePost` handler in `M.setup` (`sidebar_explorer.lua`):
```lua
vim.api.nvim_create_autocmd("BufWritePost", {
    group = sidebar_augroup,
    callback = function(ev)
        local buf_path = vim.api.nvim_buf_get_name(ev.buf)
        if buf_path ~= "" and state.root and vim.startswith(buf_path, state.root) then
            file_status_renderer.refresh(state.root, function()
                if state.winid and vim.api.nvim_win_is_valid(state.winid) then
                    render()
                end
            end)
        end
    end,
})
```
Remove `file_status_renderer.refresh(state.root)` from `M.refresh()` (leave `render()` call intact).

**FR-005** — change `M.get` in `git/diff.lua` line 47:
```lua
-- before
return { [path] = line_map }
-- after
return { [vim.fs.normalize(path)] = line_map }
```

## Definition of Done

- All five fix sites changed.
- `REG-001` passes: all four existing test suites green.
- `UT-001`/`UT-002`/`UT-003` added and passing.
- No unrelated files modified.
- Implementation summary created in `implementation/`.
