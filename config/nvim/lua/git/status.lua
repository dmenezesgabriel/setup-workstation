local M = {}

local xy_map = {
    ["??"] = "untracked",
    ["M "] = "staged",
    [" M"] = "modified",
    ["MM"] = "partial",
    ["A "] = "staged",
    [" A"] = "added",
    ["D "] = "staged",
    [" D"] = "deleted",
    ["R "] = "renamed",
    ["RM"] = "partial",
}

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

    return vim.fs.normalize(vim.fs.dirname(marker))
end

local function system_raw(command)
    if vim.system then
        local result = vim.system(command, { text = true }):wait()
        return result.code, result.stdout or ""
    end

    local stdout = vim.fn.system(command)
    return vim.v.shell_error, stdout
end

function M._parse(raw_output, root)
    local result = {}
    local records = vim.split(raw_output, "\0", { plain = true })

    local i = 1
    while i <= #records do
        local record = records[i]
        if #record >= 3 then
            local xy = record:sub(1, 2)
            local rel_path = record:sub(4)
            local status = xy_map[xy]
            if status then
                if xy == "R " and records[i + 1] and #records[i + 1] > 0 then
                    local new_path = records[i + 1]
                    local abs_path = vim.fs.normalize(root .. "/" .. new_path)
                    result[abs_path] = status
                    i = i + 2
                else
                    local abs_path = vim.fs.normalize(root .. "/" .. rel_path)
                    result[abs_path] = status
                    i = i + 1
                end
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end

    return result
end

function M.get(root)
    local git_root = find_git_root(root)
    if not git_root then
        return {}
    end

    local command = { "git", "-C", git_root, "status", "--porcelain=v1", "-z" }
    local code, stdout = system_raw(command)

    if code ~= 0 then
        return {}
    end

    return M._parse(stdout, git_root)
end

return M
