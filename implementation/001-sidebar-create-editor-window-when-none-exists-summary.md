# Implementation Summary: 001 — Create editor window when none exists

## Issue
When all editor windows were closed (e.g. via `:q`) while the sidebar remained open, calling `open_or_toggle` on a file entry caused `get_edit_window()` to return `nil`. The old code responded with an error notification and returned early, leaving the sidebar unable to open any file.

## Change Made

**File:** `config/nvim/lua/sidebar_explorer.lua`, inside `M.open_or_toggle` (around line 457).

Replaced the nil-guard that showed an error and aborted:

```lua
-- before
local target_win = get_edit_window()
if not target_win then
    notify("Sidebar explorer cannot find an editing window for: " .. entry.path)
    return
end
```

with logic that creates a new editor window to the right of the sidebar when none is found:

```lua
-- after
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

The subsequent lines (`state.source_winid = target_win`, `vim.api.nvim_set_current_win(target_win)`, and `vim.cmd("edit ...")`) were left unchanged.

## Test Result

`config/nvim/tests/sidebar_explorer_validation.lua` passed with no failures:

```
sidebar_explorer_validation: ok
```

---

## Follow-up Fix: Restore sidebar width after split

**Problem:** When `rightbelow vsplit` was called with the sidebar as the only window, Neovim split the full-width sidebar 50/50. Both the sidebar and the new editor pane ended up at equal width instead of the sidebar keeping its configured narrow width (`config.width`, default 32 columns).

**Fix applied** (`config/nvim/lua/sidebar_explorer.lua`, same block):

Added one line immediately after capturing `target_win` to reset the sidebar window's width:

```lua
target_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_width(state.winid, config.width)   -- <-- added
vim.api.nvim_set_current_win(state.winid)
```

`config.width` is in scope at that point (captured by the closure over the module-level `config` table). The existing tests still pass after this change.
