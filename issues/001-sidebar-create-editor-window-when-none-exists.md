---
id: "001"
title: "Create editor window when sidebar tries to open a file but no editor window exists"
priority: P0
status: todo
classification: AFK
---

## Context

The sidebar explorer (`lua/sidebar_explorer.lua`) opens files by finding an existing non-sidebar window via `get_edit_window()`. If the user closes all editor windows with `:q` while the sidebar is still open, `get_edit_window()` returns `nil`. The current code (line 457-460) responds by notifying an error and aborting — leaving the sidebar in a broken state where it cannot open any file.

## Use cases

- User opens the sidebar, opens a file, then closes the editor window with `:q`. The sidebar remains open. The user tries to open another file from the sidebar.
- User launches Neovim directly into the sidebar (e.g. via a keybind that opens the sidebar before any file is edited).

## Requirements

1. When `open_or_toggle` is invoked on a file entry and `get_edit_window()` returns `nil`, create a new editor window instead of showing an error.
2. The new window must be positioned to the right of the sidebar (a vertical split that does not disturb the sidebar's left-anchored layout).
3. After creating the window, open the file in it and update `state.source_winid`.
4. The sidebar must remain open and focused on the just-opened entry after the file opens.
5. No change to the directory-toggle path — directories still just expand/collapse.

## Acceptance criteria

- [ ] Opening a file from the sidebar when no editor window exists opens the file in a new window to the right of the sidebar without an error message.
- [ ] After opening, the sidebar window is still visible on the left.
- [ ] `state.source_winid` is updated to the newly created window so subsequent opens reuse it.
- [ ] Opening a file when an editor window already exists continues to reuse it (no regression).
- [ ] The existing test suite (`tests/sidebar_explorer_validation.lua`) still passes.

## Implementation notes

In `open_or_toggle` (line 443, `lua/sidebar_explorer.lua`), replace the early-return error branch:

```lua
-- before
local target_win = get_edit_window()
if not target_win then
    notify("Sidebar explorer cannot find an editing window for: " .. entry.path)
    return
end
```

with logic that creates a new window when none is found:

```lua
local target_win = get_edit_window()
if not target_win then
    -- No editor window exists; create one to the right of the sidebar.
    vim.api.nvim_set_current_win(state.winid)
    vim.cmd("rightbelow vsplit")
    target_win = vim.api.nvim_get_current_win()
    -- Return focus to sidebar so the rest of the function can proceed.
    vim.api.nvim_set_current_win(state.winid)
end
```

Then the existing lines that set `state.source_winid`, switch to `target_win`, and run `vim.cmd("edit ...")` proceed unchanged.

## Tests

| Type        | Applicable | Notes |
|-------------|-----------|-------|
| Unit        | No        | Pure-Lua unit tests cannot drive Neovim window state. |
| Integration | Yes       | Manual smoke test: open sidebar, close all editor windows with `:q`, press `<CR>` on a file — expect it opens in a new window. |
| Regression  | Yes       | Run `nvim --headless -u config/nvim/init.lua -S tests/sidebar_explorer_validation.lua` to verify the existing suite still passes. |
| E2E         | No        | No automated E2E harness in this repo. |

## Unresolved assumptions

None. The fix is self-contained.
