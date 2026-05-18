local M = {}

local uv = vim.uv or vim.loop

local root_markers = {
    ".git",
    "pyproject.toml",
    "package.json",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
}

function M.normalize_path(path)
    return vim.fs.normalize(path)
end

function M.path_exists(path)
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

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.ERROR)
end

function M.scandir(path)
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
                path = M.normalize_path(path .. "/" .. name),
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

function M.find_git_root(path)
    local marker = vim.fs.find(".git", {
        path = path,
        upward = true,
    })[1]

    if not marker then
        return nil
    end

    return M.normalize_path(vim.fs.dirname(marker))
end

function M.get_ignored_lookup(root, paths)
    local git_root = M.find_git_root(root)
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

local function get_root_search_path()
    local current_buffer = vim.api.nvim_get_current_buf()
    local current_path = vim.api.nvim_buf_get_name(current_buffer)

    if current_path ~= "" then
        local normalized = M.normalize_path(current_path)
        if is_directory(normalized) then
            return normalized
        end

        return vim.fs.dirname(normalized)
    end

    return vim.fn.getcwd()
end

function M.resolve_root()
    local search_path = get_root_search_path()
    local found = vim.fs.find(root_markers, {
        path = search_path,
        upward = true,
    })[1]

    if found then
        if vim.fs.basename(found) == ".git" then
            return M.normalize_path(vim.fs.dirname(found))
        end

        if is_directory(found) then
            return M.normalize_path(found)
        end

        return M.normalize_path(vim.fs.dirname(found))
    end

    return M.normalize_path(vim.fn.getcwd())
end

function M.build_entries(root, expanded)
    local raw_entries = {}

    local function collect_directory(path, depth)
        local entries = M.scandir(path)

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

    local ignored_lookup = M.get_ignored_lookup(root, all_paths)

    for _, entry in ipairs(raw_entries) do
        entry.ignored = ignored_lookup[entry.path] == true
    end

    return raw_entries
end

return M
