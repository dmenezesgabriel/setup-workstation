local M = {}

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
}

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.ERROR)
end

local function normalize_path(path)
    return vim.fs.normalize(path)
end

local function path_exists(path)
    return uv.fs_stat(path) ~= nil
end

local function is_directory(path)
    local stat = uv.fs_stat(path)
    return stat and stat.type == "directory" or false
end

local function get_name(path)
    return vim.fs.basename(path)
end

local function sort_entries(entries)
    table.sort(entries, function(left, right)
        if left.type ~= right.type then
            return left.type == "directory"
        end

        return left.name:lower() < right.name:lower()
    end)
end

local function scandir(path)
    if not is_directory(path) then
        notify("Sidebar explorer cannot read directory: " .. path)
        return {}
    end

    local ok, iterator = pcall(vim.fs.dir, path)
    if not ok then
        notify("Sidebar explorer cannot read directory: " .. path)
        return {}
    end

    local entries = {}

    for name, entry_type in iterator do
        if name ~= "." and name ~= ".." then
            table.insert(entries, {
                name = name,
                path = normalize_path(path .. "/" .. name),
                type = entry_type,
            })
        end
    end

    sort_entries(entries)

    return entries
end

local function system_list(command)
    if vim.system then
        local result = vim.system(command, { text = true }):wait()
        local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
        return {
            code = result.code,
            lines = lines,
            stderr = result.stderr or "",
        }
    end

    local lines = vim.fn.systemlist(command)
    return {
        code = vim.v.shell_error,
        lines = lines,
        stderr = "",
    }
end

local function find_git_root(path)
    local marker = vim.fs.find(".git", {
        path = path,
        upward = true,
    })[1]

    if not marker then
        return nil
    end

    return normalize_path(vim.fs.dirname(marker))
end

local function get_ignored_lookup(root, paths)
    local git_root = find_git_root(root)
    if not git_root or #paths == 0 then
        return {}
    end

    local relative_paths = {}
    local path_by_relative = {}

    for _, path in ipairs(paths) do
        local relative = vim.fs.relpath(git_root, path)
        if relative then
            table.insert(relative_paths, relative)
            path_by_relative[relative] = path
        end
    end

    if #relative_paths == 0 then
        return {}
    end

    local command = {
        "git",
        "-C",
        git_root,
        "check-ignore",
        "--stdin",
    }

    local result
    if vim.system then
        result = vim.system(command, {
            text = true,
            stdin = table.concat(relative_paths, "\n") .. "\n",
        }):wait()
    else
        local input_path = vim.fn.tempname()
        vim.fn.writefile(relative_paths, input_path)
        local shell_command = table.concat({
            "git",
            "-C",
            vim.fn.shellescape(git_root),
            "check-ignore",
            "--stdin",
            "<",
            vim.fn.shellescape(input_path),
        }, " ")
        local stdout = vim.fn.system(shell_command)
        result = {
            code = vim.v.shell_error,
            stdout = stdout,
            stderr = "",
        }
        vim.fn.delete(input_path)
    end

    if result.code ~= 0 and result.code ~= 1 then
        notify("Sidebar explorer git ignore check failed for: " .. git_root)
        return {}
    end

    local ignored_lookup = {}
    for _, relative in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
        local path = path_by_relative[relative]
        if path then
            ignored_lookup[path] = true
        end
    end

    return ignored_lookup
end

local function build_lines(root, expanded)
    local raw_entries = {}

    local function collect_directory(path, depth)
        local entries = scandir(path)

        for _, entry in ipairs(entries) do
            local is_dir = entry.type == "directory"
            local is_expanded = expanded[entry.path] == true

            table.insert(raw_entries, {
                path = entry.path,
                name = entry.name,
                type = entry.type,
                depth = depth,
                expanded = is_expanded,
            })

            if is_dir and is_expanded then
                collect_directory(entry.path, depth + 1)
            end
        end
    end

    local root_expanded = expanded[root] == true
    table.insert(raw_entries, {
        path = root,
        name = get_name(root),
        type = "directory",
        depth = 0,
        expanded = root_expanded,
        root = true,
    })

    if root_expanded then
        collect_directory(root, 1)
    end

    local all_paths = {}
    for _, entry in ipairs(raw_entries) do
        table.insert(all_paths, entry.path)
    end

    local ignored_lookup = get_ignored_lookup(root, all_paths)
    local lines = {}
    local line_entries = {}

    for _, entry in ipairs(raw_entries) do
        local is_dir = entry.type == "directory"
        local indent = string.rep("  ", entry.depth)
        local icon = is_dir and (entry.expanded and "▾ " or "▸ ") or "  "

        table.insert(lines, indent .. icon .. entry.name)
        entry.ignored = ignored_lookup[entry.path] == true
        table.insert(line_entries, entry)
    end

    return lines, line_entries
end

local function get_root_search_path()
    local current_buffer = vim.api.nvim_get_current_buf()
    local current_path = vim.api.nvim_buf_get_name(current_buffer)

    if current_path ~= "" then
        local normalized = normalize_path(current_path)
        if is_directory(normalized) then
            return normalized
        end

        return vim.fs.dirname(normalized)
    end

    return vim.fn.getcwd()
end

local function resolve_root()
    local search_path = get_root_search_path()
    local found = vim.fs.find(config.root_markers, {
        path = search_path,
        upward = true,
    })[1]

    if found then
        if vim.fs.basename(found) == ".git" then
            return normalize_path(vim.fs.dirname(found))
        end

        if is_directory(found) then
            return normalize_path(found)
        end

        return normalize_path(vim.fs.dirname(found))
    end

    return normalize_path(vim.fn.getcwd())
end

local function is_sidebar_buffer(bufnr)
    return bufnr ~= nil
        and vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].filetype == "sidebar_explorer"
end

local function get_edit_window()
    if state.source_winid and vim.api.nvim_win_is_valid(state.source_winid) then
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

local function close_window()
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
end

local function render()
    local bufnr = ensure_buffer()
    local lines, line_entries = build_lines(state.root, state.expanded)

    state.line_entries = line_entries

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    apply_highlights(bufnr, line_entries)
    vim.bo[bufnr].modifiable = false

    if #lines > 0 then
        local line = vim.api.nvim_win_get_cursor(state.winid)[1]
        line = math.max(1, math.min(line, #lines))
        vim.api.nvim_win_set_cursor(state.winid, { line, 0 })
    end
end

local function open_sidebar_window()
    local bufnr = ensure_buffer()

    vim.cmd("topleft vsplit")
    state.winid = vim.api.nvim_get_current_win()
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
    if not state.root or not path_exists(state.root) then
        state.root = resolve_root()
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

    state.root = resolve_root()
    state.expanded[state.root] = true

    open_sidebar_window()
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
        return
    end

    local target_win = get_edit_window()
    if not target_win then
        notify("Sidebar explorer cannot find an editing window for: " .. entry.path)
        return
    end

    if not path_exists(entry.path) then
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
        return
    end

    if entry.root then
        return
    end

    local parent_path = normalize_path(vim.fs.dirname(entry.path))
    for index, candidate in ipairs(state.line_entries) do
        if candidate.path == parent_path then
            vim.api.nvim_win_set_cursor(0, { index, 0 })
            break
        end
    end
end

function M.setup(options)
    config = vim.tbl_deep_extend("force", config, options or {})

    vim.api.nvim_set_hl(0, config.ignored_highlight, {
        fg = "#6c6c6c",
        ctermfg = 242,
        italic = true,
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

M._test = {
    build_lines = build_lines,
    resolve_root = resolve_root,
    normalize_path = normalize_path,
    get_ignored_lookup = get_ignored_lookup,
    find_git_root = find_git_root,
}

return M
