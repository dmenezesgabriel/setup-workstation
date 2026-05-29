local M = {}

local explorer = require("explorer")
local file_status_renderer = require("ui.file_status_renderer")
local uv = vim.uv or vim.loop

local config = {
    width = 32,
    ignored_highlight = "SidebarExplorerIgnored",
    root_markers = {
        ".git",
        "pyproject.toml",
        "package.json",
        "setup.py",
        "setup.cfg",
        "requirements.txt",
    },
}

local state = {
    bufnr = nil,
    winid = nil,
    source_winid = nil,
    root = nil,
    expanded = {},
    line_entries = {},
    watchers = {},
    refresh_timer = nil,
}

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.ERROR)
end

local function build_lines(root, expanded)
    local entries = explorer.build_entries(root, expanded)
    local lines = {}
    local line_entries = {}

    for _, entry in ipairs(entries) do
        local is_dir = entry.type == "directory"
        local indent = string.rep("  ", entry.depth)
        local icon = is_dir and (entry.expanded and "▾ " or "▸ ") or "  "
        local indicator = file_status_renderer.get_indicator(entry)
        local symbol = indicator.symbol ~= "" and (" " .. indicator.symbol) or ""
        table.insert(lines, indent .. icon .. entry.name .. symbol)
        table.insert(line_entries, entry)
    end

    return lines, line_entries
end

local function is_sidebar_buffer(bufnr)
    return bufnr ~= nil
        and vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].filetype == "sidebar_explorer"
end

local function get_edit_window()
    if state.source_winid
        and vim.api.nvim_win_is_valid(state.source_winid)
        and state.source_winid ~= state.winid then
        return state.source_winid
    end

    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local bufnr = vim.api.nvim_win_get_buf(winid)
        if not is_sidebar_buffer(bufnr) then
            return winid
        end
    end

    return nil
end

local function stop_watchers()
    for _, handle in pairs(state.watchers) do
        if not handle:is_closing() then
            handle:stop()
            handle:close()
        end
    end
    state.watchers = {}
end

local function schedule_refresh()
    if state.refresh_timer then
        state.refresh_timer:stop()
        state.refresh_timer:close()
        state.refresh_timer = nil
    end

    local timer = uv.new_timer()
    state.refresh_timer = timer
    timer:start(150, 0, vim.schedule_wrap(function()
        if state.refresh_timer == timer then
            state.refresh_timer = nil
        end
        timer:close()
        M.refresh()
    end))
end

local function watch_dir(path)
    if state.watchers[path] then return end

    local handle = uv.new_fs_event()
    if not handle then return end

    local ok = handle:start(path, {}, function(err)
        if err then return end
        schedule_refresh()
    end)

    if ok then
        state.watchers[path] = handle
    else
        if not handle:is_closing() then
            handle:close()
        end
    end
end

local function update_watchers()
    stop_watchers()
    if not state.root or not state.winid or not vim.api.nvim_win_is_valid(state.winid) then
        return
    end

    watch_dir(state.root)
    for path, is_expanded in pairs(state.expanded) do
        if is_expanded then
            watch_dir(path)
        end
    end
end

local function close_window()
    stop_watchers()

    if state.winid and vim.api.nvim_win_is_valid(state.winid) then
        vim.api.nvim_win_close(state.winid, true)
    end

    state.winid = nil
end

local function ensure_buffer()
    if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
        return state.bufnr
    end

    state.bufnr = vim.api.nvim_create_buf(false, true)

    vim.bo[state.bufnr].buftype = "nofile"
    vim.bo[state.bufnr].bufhidden = "hide"
    vim.bo[state.bufnr].swapfile = false
    vim.bo[state.bufnr].modifiable = false
    vim.bo[state.bufnr].filetype = "sidebar_explorer"

    vim.api.nvim_buf_set_name(state.bufnr, "sidebar-explorer")

    vim.keymap.set("n", "<CR>", function()
        M.open_or_toggle()
    end, { buffer = state.bufnr, silent = true })

    vim.keymap.set("n", "l", function()
        M.open_or_toggle()
    end, { buffer = state.bufnr, silent = true })

    vim.keymap.set("n", "h", function()
        M.collapse_or_parent()
    end, { buffer = state.bufnr, silent = true })

    vim.keymap.set("n", "r", function()
        M.refresh()
    end, { buffer = state.bufnr, silent = true })

    vim.keymap.set("n", "q", function()
        M.toggle()
    end, { buffer = state.bufnr, silent = true })

    vim.keymap.set("n", "<LeftMouse>", function()
        local pos = vim.fn.getmousepos()
        if pos.line < 1 then return end
        vim.api.nvim_win_set_cursor(0, { pos.line, 0 })
        M.open_or_toggle()
    end, { buffer = state.bufnr, silent = true })

    vim.keymap.set("n", "<2-LeftMouse>", "<Nop>", { buffer = state.bufnr, silent = true })

    return state.bufnr
end

local function apply_highlights(bufnr, line_entries)
    local namespace = vim.api.nvim_create_namespace("sidebar_explorer")
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    for index, entry in ipairs(line_entries) do
        if entry.ignored then
            vim.api.nvim_buf_add_highlight(bufnr, namespace, config.ignored_highlight, index - 1, 0, -1)
        end
    end

    for index, entry in ipairs(line_entries) do
        local indicator = file_status_renderer.get_indicator(entry)
        if indicator.highlight then
            vim.api.nvim_buf_add_highlight(bufnr, namespace, indicator.highlight, index - 1, 0, -1)
        end
    end
end

local function render()
    local bufnr = ensure_buffer()
    local lines, line_entries = build_lines(state.root, state.expanded)

    state.line_entries = line_entries

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    apply_highlights(bufnr, line_entries)
    vim.bo[bufnr].modifiable = false

    if #lines > 0 and state.winid and vim.api.nvim_win_is_valid(state.winid) then
        local line = vim.api.nvim_win_get_cursor(state.winid)[1]
        line = math.max(1, math.min(line, #lines))
        vim.api.nvim_win_set_cursor(state.winid, { line, 0 })
    end
end

local function is_empty_unnamed_win(winid)
    local buf = vim.api.nvim_win_get_buf(winid)
    return vim.api.nvim_buf_get_name(buf) == ""
        and not vim.bo[buf].modified
        and vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

local function open_sidebar_window()
    local bufnr = ensure_buffer()

    local wins = vim.api.nvim_tabpage_list_wins(0)
    if #wins == 1 and is_empty_unnamed_win(wins[1]) then
        state.winid = wins[1]
    else
        vim.cmd("topleft vsplit")
        state.winid = vim.api.nvim_get_current_win()
    end

    vim.api.nvim_win_set_buf(state.winid, bufnr)
    vim.api.nvim_win_set_width(state.winid, config.width)

    vim.wo[state.winid].winfixwidth = true
    vim.wo[state.winid].number = false
    vim.wo[state.winid].relativenumber = false
    vim.wo[state.winid].cursorline = true
    vim.wo[state.winid].signcolumn = "no"
    vim.wo[state.winid].foldcolumn = "0"
    vim.wo[state.winid].spell = false
    vim.wo[state.winid].list = false
    vim.wo[state.winid].wrap = false

    render()
end

function M.refresh()
    if not state.root or not explorer.path_exists(state.root) then
        state.root = explorer.resolve_root()
    end

    if not state.winid or not vim.api.nvim_win_is_valid(state.winid) then
        return
    end

    render()
end

function M.toggle()
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()

    if state.winid and vim.api.nvim_win_is_valid(state.winid) then
        if #vim.api.nvim_tabpage_list_wins(0) <= 1 then
            return
        end

        if current_win == state.winid then
            state.source_winid = get_edit_window()
        elseif not is_sidebar_buffer(current_buf) then
            state.source_winid = current_win
        end

        close_window()
        return
    end

    if not is_sidebar_buffer(current_buf) then
        state.source_winid = current_win
    end

    state.root = explorer.resolve_root()
    state.expanded[state.root] = true

    file_status_renderer.refresh_sync(state.root)
    open_sidebar_window()
    update_watchers()
end

function M.open_or_toggle()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local entry = state.line_entries[line]

    if not entry then
        return
    end

    if entry.type == "directory" then
        state.expanded[entry.path] = not state.expanded[entry.path]
        render()
        update_watchers()
        return
    end

    local target_win = get_edit_window()
    if not target_win then
        vim.api.nvim_set_current_win(state.winid)
        vim.cmd("rightbelow vsplit")
        target_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_width(state.winid, config.width)
        vim.api.nvim_set_current_win(state.winid)
    end

    if not explorer.path_exists(entry.path) then
        notify("Sidebar explorer cannot open path: " .. entry.path)
        return
    end

    state.source_winid = target_win
    vim.api.nvim_set_current_win(target_win)
    vim.cmd("edit " .. vim.fn.fnameescape(entry.path))
end

function M.collapse_or_parent()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local entry = state.line_entries[line]

    if not entry then
        return
    end

    if entry.type == "directory" and state.expanded[entry.path] and not entry.root then
        state.expanded[entry.path] = false
        render()
        update_watchers()
        return
    end

    if entry.root then
        return
    end

    local parent_path = explorer.normalize_path(vim.fs.dirname(entry.path))
    for index, candidate in ipairs(state.line_entries) do
        if candidate.path == parent_path then
            vim.api.nvim_win_set_cursor(0, { index, 0 })
            break
        end
    end
end

function M.setup(options)
    config = vim.tbl_deep_extend("force", config, options or {})

    local sidebar_augroup = vim.api.nvim_create_augroup("SidebarExplorer", { clear = true })

    vim.api.nvim_set_hl(0, config.ignored_highlight, {
        fg = "#6c6c6c",
        ctermfg = 242,
        italic = true,
    })

    local cfg = require("config")
    vim.api.nvim_set_hl(0, cfg.highlights.modified,  { fg = "#e5c07b", bold = true })
    vim.api.nvim_set_hl(0, cfg.highlights.added,     { fg = "#98c379" })
    vim.api.nvim_set_hl(0, cfg.highlights.deleted,   { fg = "#e06c75" })
    vim.api.nvim_set_hl(0, cfg.highlights.renamed,   { fg = "#61afef" })
    vim.api.nvim_set_hl(0, cfg.highlights.untracked, { fg = "#abb2bf" })
    vim.api.nvim_set_hl(0, cfg.highlights.ignored,   { fg = "#6c6c6c", italic = true })
    vim.api.nvim_set_hl(0, cfg.highlights.staged,    { fg = "#98c379", bold = true })
    vim.api.nvim_set_hl(0, cfg.highlights.partial,   { fg = "#e5c07b" })

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

    vim.api.nvim_create_autocmd("ShellCmdPost", {
        group = sidebar_augroup,
        callback = function()
            if state.root and state.winid and vim.api.nvim_win_is_valid(state.winid) then
                file_status_renderer.refresh(state.root, function()
                    if state.winid and vim.api.nvim_win_is_valid(state.winid) then
                        render()
                    end
                end)
            end
        end,
    })

    vim.api.nvim_create_autocmd("VimEnter", {
        group = sidebar_augroup,
        once = true,
        callback = function()
            if vim.fn.argc() == 0 then
                M.toggle()
            end
        end,
    })

    pcall(vim.api.nvim_del_user_command, "SidebarToggle")
    vim.api.nvim_create_user_command("SidebarToggle", function()
        M.toggle()
    end, { desc = "Toggle sidebar file explorer" })

    vim.keymap.set(
        "n",
        "<leader>e",
        function()
            M.toggle()
        end,
        { desc = "Toggle sidebar explorer", silent = true }
    )
end

return M
