local M = {}

local compat = require("compat")

local function system_raw(command)
    if vim.system then
        local result = vim.system(command, { text = true }):wait()
        return result.code, result.stdout or ""
    end

    local stdout = vim.fn.system(command)
    return vim.v.shell_error, stdout
end

function M._parse(raw_output, path, staged)
    local line_map = {}

    for line in (raw_output .. "\n"):gmatch("([^\n]*)\n") do
        local old_start, old_count, new_start, new_count =
            line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")

        if old_start then
            old_start = tonumber(old_start)
            old_count = old_count == "" and 1 or tonumber(old_count)
            new_start = tonumber(new_start)
            new_count = new_count == "" and 1 or tonumber(new_count)

            if old_count == 0 and new_count > 0 then
                local change = staged and "staged" or "added"
                for nr = new_start, new_start + new_count - 1 do
                    line_map[nr] = change
                end
            elseif new_count == 0 then
                local change = staged and "staged" or "deleted"
                line_map[new_start] = change
            else
                local change = staged and "staged" or "modified"
                for nr = new_start, new_start + new_count - 1 do
                    line_map[nr] = change
                end
            end
        end
    end

    if next(line_map) == nil then
        return {}
    end

    return { [path] = line_map }
end

function M.get(path, staged)
    local git_marker = vim.fs.find(".git", {
        path = vim.fs.dirname(path),
        upward = true,
    })[1]

    if not git_marker then
        return {}
    end

    local git_root = vim.fs.normalize(vim.fs.dirname(git_marker))
    local rel_path = compat.fs_relpath(git_root, path)
    if not rel_path then
        return {}
    end

    local command
    if staged then
        command = { "git", "-C", git_root, "diff", "--cached", "--unified=0", "--", rel_path }
    else
        command = { "git", "-C", git_root, "diff", "--unified=0", "--", rel_path }
    end

    local code, stdout = system_raw(command)

    if code ~= 0 then
        return {}
    end

    return M._parse(stdout, vim.fs.normalize(path), staged)
end

return M
