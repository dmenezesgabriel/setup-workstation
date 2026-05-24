local M = {}

M.uv = vim.uv or vim.loop

if vim.fs.relpath then
    M.fs_relpath = vim.fs.relpath
else
    function M.fs_relpath(base, path)
        base = vim.fs.normalize(base)
        path = vim.fs.normalize(path)
        local prefix = base .. "/"
        if path:sub(1, #prefix) == prefix then
            return path:sub(#prefix + 1)
        end
    end
end

return M
