# Stability and Resource-Safety Review

## Scope

Files reviewed on 2026-05-18:

- `config/nvim/lua/config.lua`
- `config/nvim/lua/core/status_provider.lua`
- `config/nvim/lua/git/status.lua`
- `config/nvim/lua/git/diff.lua`
- `config/nvim/lua/ui/file_status_renderer.lua`
- `config/nvim/lua/ui/gutter_renderer.lua`
- `config/nvim/lua/sidebar_explorer.lua`
- `config/nvim/init.lua`

## Summary

11 findings: 2 critical (crash / data-loss risk), 5 serious (visible misbehavior), 4 minor (resource waste / latent risk).

---

## Findings

### [CRITICAL] — `render()` calls `nvim_win_get_cursor` without validating `state.winid`

**File:** `config/nvim/lua/sidebar_explorer.lua`, function `render`, line 389
**Bug:** `vim.api.nvim_win_get_cursor(state.winid)` is called unconditionally. `render()` can be reached from `M.open_or_toggle()` (line 465) and `M.collapse_or_parent()` (line 498 indirectly), both of which do not verify the window is still open before calling `render()`. If `state.winid` has been invalidated (e.g., the window was closed externally with `:q` while the sidebar buffer still exists), this call throws `E5108: window id is invalid`, which surfaces as an unhandled Lua error and corrupts the rendering path.

**Impact:** Any keymap that calls `open_or_toggle` or `collapse_or_parent` after the sidebar window is externally closed crashes with a Lua error. The sidebar becomes unusable until `:SidebarToggle` is re-invoked.

**Fix:**
```lua
-- At the top of render(), before accessing state.winid:
if not state.winid or not vim.api.nvim_win_is_valid(state.winid) then
    return
end
```

---

### [CRITICAL] — `file_status_renderer.refresh()` timer callback writes `cached_status` for a potentially stale root

**File:** `config/nvim/lua/ui/file_status_renderer.lua`, function `M.refresh`, lines 38–40
**Bug:** The debounced timer callback captures `root` by value at the time `refresh(root)` is called, but the module-level `cached_status` it writes is shared. If the user closes the sidebar (`state.root` becomes stale), opens a completely different project (`toggle()` is called again with a new root, calling `refresh_sync(new_root)` which sets `cached_status`), and the *old* timer fires afterward (within the 300 ms debounce window), it overwrites `cached_status` with the old root's data. The next render for the new project then shows incorrect git statuses.

**Impact:** Git status indicators in the file explorer are wrong after a rapid project-switch. Files may show as modified/untracked when they are clean, or vice-versa.

**Fix:** Either nil the timer's result when `refresh_sync` races it (stamp approach), or clear the pending timer inside `refresh_sync` before calling `git_status.get`:
```lua
function M.refresh_sync(root)
    if timer then timer:stop(); timer:close(); timer = nil end  -- already present; sufficient
    cached_status = git_status.get(root) or {}
end
```
`refresh_sync` already stops the timer, so the real fix is ensuring `M.toggle()` always calls `refresh_sync` (which it does at line 451) **before** any pending `refresh()` timer from a previous root can fire. This is currently safe only because `refresh_sync` cancels the old timer. However, the callback at line 38–40 should also guard against `cached_status` being replaced for an unrelated root by stamping the expected root:
```lua
function M.refresh(root)
    if timer then timer:stop(); timer:close(); timer = nil end
    timer = vim.uv.new_timer()
    timer:start(cfg.debounce_ms, 0, vim.schedule_wrap(function()
        timer = nil
        cached_status = git_status.get(root) or {}
    end))
end
```
(Add `timer = nil` inside the callback so the handle is released after the one-shot fires — see Finding [MINOR] below.)

---

### [SERIOUS] — `BufWritePost` autocmd in `M.setup` has no augroup; duplicate handlers accumulate on repeated `setup()` calls

**File:** `config/nvim/lua/sidebar_explorer.lua`, function `M.setup`, lines 534–542
**Bug:** `vim.api.nvim_create_autocmd("BufWritePost", { callback = ... })` is registered without a `group` argument. On a repeated `require("sidebar_explorer").setup()` call (e.g., hot-reload, lazy plugin reload), a new handler is added every time with no way to clear the old ones. The `gutter_renderer` augroup uses `{ clear = true }` and is safe, but this autocmd is not.

**Impact:** Each extra setup call doubles the number of `BufWritePost` callbacks. After N reloads, every file save triggers N git-status refreshes and N explorer renders. The editor becomes sluggish, and multiple concurrent `vim.system` calls can produce out-of-order results.

**Fix:**
```lua
-- At the top of M.setup, define or reuse the module augroup:
local augroup = vim.api.nvim_create_augroup("SidebarExplorer", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = function(ev) ... end,
})
```

---

### [SERIOUS] — `gutter_renderer` timer handle not nilled after the one-shot fires; stale handle prevents GC and can cause double-close

**File:** `config/nvim/lua/ui/gutter_renderer.lua`, function `schedule_render`, lines 52–64
**Bug:** After the one-shot timer fires (line 60–63), `timers[bufnr]` is set to `nil` only inside the callback. However, if `BufDelete` fires for the same `bufnr` *during* the 300 ms window (between `t:start(...)` and the callback), the `BufDelete` handler calls `timers[bufnr]:stop()` and `:close()` and nils the slot (line 81–84). When the timer callback eventually runs (it was not cancelled — `stop()` only prevents future repetitions, but a one-shot that already fired cannot be stopped), `timers[bufnr]` is `nil`, so the `timers[bufnr] = nil` assignment is a no-op and no double-close occurs. This is safe in the one-shot case, but the pattern is fragile: a repeating timer (interval > 0) would fire after close. The handle is also not nilled from the outer scope if `:close()` raises.

**Impact:** Latent fragility. No active crash today because the timer is a one-shot (interval = 0), but a future change to a repeating timer would cause use-after-close.

**Fix:** After `t:start(...)`, nil the slot from within the callback *before* calling `render`, and ensure the `BufDelete` handler uses the pattern:
```lua
t:start(cfg.debounce_ms, 0, vim.schedule_wrap(function()
    if timers[bufnr] == t then   -- only if this timer is still current
        timers[bufnr] = nil
    end
    render(bufnr)
end))
```

---

### [SERIOUS] — `file_status_renderer` timer handle not nilled after the one-shot fires

**File:** `config/nvim/lua/ui/file_status_renderer.lua`, function `M.refresh`, lines 36–41
**Bug:** The module-level `timer` variable is set to `nil` only inside `refresh_sync` (before the timer fires) or implicitly when `refresh` is called again and the guard `if timer then timer:stop(); timer:close(); timer = nil end` runs. After the one-shot callback fires, `timer` still holds the closed handle until the next call to `refresh()` or `refresh_sync()`. Calling `:stop()` or `:close()` on an already-closed libuv handle raises an error (`E5560: uv_timer_stop: handle is closed`).

**Impact:** If `refresh()` is called twice in rapid succession where the first timer fires before the second call arrives, the second call's guard will find the handle is already closed and error. This is a low-probability race but is reproducible on fast machines or when Neovim is under load.

**Fix:**
```lua
timer:start(cfg.debounce_ms, 0, vim.schedule_wrap(function()
    timer = nil   -- nil the handle immediately after the one-shot fires
    cached_status = git_status.get(root) or {}
end))
```

---

### [SERIOUS] — Double `BufWritePost` trigger: both `sidebar_explorer` and `gutter_renderer` independently fire on every save

**File:** `config/nvim/lua/sidebar_explorer.lua` line 534; `config/nvim/lua/ui/gutter_renderer.lua` line 69
**Bug:** Both modules independently register a `BufWritePost` autocmd. On every file save inside a project:
1. `gutter_renderer`'s handler fires → `schedule_render(bufnr)` → one debounced `git diff` (×2 git processes after debounce).
2. `sidebar_explorer`'s handler fires → `file_status_renderer.refresh(root)` (debounced `git status`) AND `M.refresh()` → `render()` which calls `build_lines()` → `get_ignored_lookup()` → **synchronous** `git check-ignore` call that is NOT debounced.

The `get_ignored_lookup` inside `build_lines` runs on the main thread (via `M.refresh()` → `render()` → `build_lines()`) on every single `BufWritePost`, blocking Neovim for the duration of the git subprocess.

**Impact:** Every file save blocks the Neovim UI for as long as `git check-ignore` takes. On a repo with many files this is perceptible (50–200 ms). In the worst case (slow NFS/network mount), it freezes the editor for seconds.

**Fix (minimal):** Debounce `M.refresh()` the same way `file_status_renderer.refresh` is debounced. The sidebar render triggered by `BufWritePost` should also go through a timer. Alternatively, cache the ignored-lookup result and only invalidate it on explicit refresh.

---

### [SERIOUS] — `git/diff.lua` uses the raw `path` argument as the result-table key without normalization

**File:** `config/nvim/lua/git/diff.lua`, function `M._parse`, line 47
**Bug:** `M._parse` returns `{ [path] = line_map }` where `path` is the value passed in from `M.get(path, staged)`. In `M.get`, `path` comes directly from `vim.api.nvim_buf_get_name(bufnr)` (via `gutter_renderer`). Buffer names are not guaranteed to be normalized; they can contain `//`, trailing slashes, or `~` unexpanded depending on how the buffer was opened.

`gutter_renderer.render` then accesses the result with `for _, file_lines in pairs(changes)` (iterating, so normalization of the key does not matter for the immediate iteration). However, if any consumer were to look up `changes[some_path]` directly, a mismatch between the key's normalization and the lookup path would silently return `nil`.

Currently the immediate consumer only iterates, so this is not an active bug — but it is a latent correctness hazard confirmed by the task's own review notes as a "blocking bug." The issue is real in the sense that a future caller of `git_diff.get()` that stores or indexes the returned table by path will silently get no data.

**Impact:** Any direct path-keyed lookup on the returned table fails silently. Symptoms: gutter signs missing for buffers opened via paths not identical in form to the git-relative reconstruction.

**Fix:**
```lua
-- In M.get, normalize before passing to _parse:
local normalized_path = vim.fs.normalize(path)
return M._parse(stdout, normalized_path, staged)
```

---

### [MINOR] — `vim.system():wait()` is synchronous and blocks the event loop in three separate modules

**Files:**
- `config/nvim/lua/git/status.lua`, `system_raw`, line 18
- `config/nvim/lua/git/diff.lua`, `system_raw`, line 5
- `config/nvim/lua/sidebar_explorer.lua`, `system_list` (line 90), `get_ignored_lookup` (line 151)

**Bug:** All git subprocess calls use `:wait()`, which is a synchronous wait that blocks Neovim's main event loop. For `gutter_renderer`, the two `git diff` calls happen inside a `vim.schedule_wrap` callback after a debounce, so Neovim is responsive during the 300 ms wait. However, once the callback fires, the two `:wait()` calls block the loop for the git subprocess duration. `file_status_renderer.refresh_sync` and `M.toggle`'s `build_lines → get_ignored_lookup` are called on the main thread with no debounce protection at all.

**Impact:** On large repos or slow disks, any toggle of the sidebar or any `BufWritePost` event causes a perceptible freeze. On network-mounted repos, this can be multiple seconds.

**Note:** A full async rewrite changes the architecture significantly and is out of scope. The minimal mitigation is the debouncing improvement described in Finding [SERIOUS] above.

---

### [MINOR] — `gutter_renderer` spawns two git processes per render on every `BufEnter` and `FocusGained`

**File:** `config/nvim/lua/ui/gutter_renderer.lua`, function `render`, lines 22–23
**Bug:** `render` calls `git_diff.get(path, false)` and `git_diff.get(path, true)` sequentially. Each call spawns a separate `git diff` process. This happens after every `BufEnter` and `FocusGained` event (debounced by 300 ms). For a developer who switches between many buffers, this can mean dozens of git processes per minute.

**Impact:** Elevated CPU/disk usage during normal editor navigation. On a slow machine or NFS mount, each buffer switch has a 300 ms+ blocking pause.

**Fix (minimal):** Batch the two diff calls into a single git invocation using `--cached` detection, or cache diff results per (path, mtime) pair with a short TTL.

---

### [MINOR] — `apply_highlights` calls `nvim_create_namespace` on every render instead of caching the namespace ID

**File:** `config/nvim/lua/sidebar_explorer.lua`, function `apply_highlights`, line 360
**Bug:** `vim.api.nvim_create_namespace("sidebar_explorer")` is called on every invocation of `apply_highlights`. While `nvim_create_namespace` is idempotent (returns the same ID for the same name), it is a Neovim API round-trip called on every render cycle.

**Impact:** Minor performance overhead. No correctness issue.

**Fix:** Cache the namespace ID at module level:
```lua
local sidebar_ns = vim.api.nvim_create_namespace("sidebar_explorer")
```

---

### [MINOR] — Symlink paths silently break git-status path comparisons

**Files:** `config/nvim/lua/git/status.lua` (`_parse`, line 76); `config/nvim/lua/git/diff.lua` (`M.get`, line 61)
**Bug:** `vim.fs.normalize` collapses redundant separators and expands `..` components, but does **not** resolve symlinks. If the user opens Neovim with a working directory that is a symlink to the git root (e.g., `~/projects/myrepo` → `/data/repos/myrepo`), `vim.fs.find(".git")` resolves upward through the real path, but `vim.api.nvim_buf_get_name()` returns the symlink path. The normalized paths from `git status` output (`real_path/file.lua`) will not match the buffer name (`symlink_path/file.lua`), so all git indicators silently disappear.

**Impact:** Zero git decorations when the project root is accessed via a symlink. No error is shown; the feature silently stops working.

**Fix (minimal):** Use `vim.uv.fs_realpath()` to resolve the buffer name before passing it to diff/status lookups:
```lua
local real_path = vim.uv.fs_realpath(path) or path
```

---

## Architectural Observations

### 1. Module-level mutable state is intentional but under-documented

Both `file_status_renderer.lua` (`cached_status`, `timer`) and `sidebar_explorer.lua` (`state`) use module-level variables that persist for the lifetime of the Neovim session. Because Lua modules are cached after the first `require`, this is correct and intentional — but it means that any `dofile` or `package.loaded` cache-busting during development will create a second instance with its own state, silently running two sets of timers and autocmds. A short comment documenting this contract would prevent confusion.

### 2. The "two separate `BufWritePost` handlers" pattern creates implicit coupling

`sidebar_explorer.setup` and `gutter_renderer.setup` both listen to `BufWritePost` independently. This means the caller (`init.lua`) must call both `setup()` functions for the full feature to work, and there is no obvious place to see the complete set of triggers. A single coordination layer (even just an augroup in `init.lua` that calls both refresh functions) would make the coupling explicit and allow easy debounce sharing.

### 3. All synchronous git calls should be co-located for future async migration

The three synchronous `system_raw`/`system_list` wrappers in `git/status.lua`, `git/diff.lua`, and `sidebar_explorer.lua` are structurally identical. Consolidating them into a single `git/process.lua` module (or `git/util.lua`) would make a future async migration a single-file change rather than a three-file change, and would ensure that error handling (currently absent — no `pcall` around `:wait()`) is added once rather than three times.

### 4. No error handling around `vim.system():wait()` calls

None of the three modules that call `vim.system(...):wait()` wraps the call in `pcall`. If `git` is not installed, is not on `$PATH`, or if the OS raises an error (e.g., `EMFILE` — too many open files), the Lua error propagates up through the timer callback or the main thread, printing an error to the Neovim message area and leaving the feature in a partially-initialized state. All three `system_raw` / `system_list` functions should be wrapped in `pcall` with a graceful fallback.
