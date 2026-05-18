local M = {}

local git_diff = require("git.diff")
local cfg      = require("config")

local namespace = vim.api.nvim_create_namespace("git_gutter")
local timers    = {}   -- keyed by bufnr

local function is_file_buffer(bufnr)
    return vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function render(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) or not is_file_buffer(bufnr) then
        return
    end

    local path = vim.api.nvim_buf_get_name(bufnr)

    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    local unstaged = git_diff.get(path, false)
    local staged   = git_diff.get(path, true)

    local line_changes = {}

    local function merge(changes)
        if not changes then return end
        for _, file_lines in pairs(changes) do
            for lnum, change_type in pairs(file_lines) do
                line_changes[lnum] = change_type
            end
        end
    end

    merge(unstaged)
    merge(staged)

    for lnum, change_type in pairs(line_changes) do
        local symbol    = cfg.symbols[change_type]    or ""
        local hl_group  = cfg.highlights[change_type] or ""
        if symbol ~= "" then
            pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, lnum - 1, 0, {
                sign_text     = symbol,
                sign_hl_group = hl_group,
                priority      = cfg.sign_priority,
            })
        end
    end
end

local function schedule_render(bufnr)
    if timers[bufnr] then
        timers[bufnr]:stop()
        timers[bufnr]:close()
        timers[bufnr] = nil
    end
    local t = vim.uv.new_timer()
    timers[bufnr] = t
    t:start(cfg.debounce_ms, 0, vim.schedule_wrap(function()
        timers[bufnr] = nil
        render(bufnr)
    end))
end

function M.setup()
    local augroup = vim.api.nvim_create_augroup("GitGutter", { clear = true })

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "FocusGained" }, {
        group    = augroup,
        callback = function(ev)
            if is_file_buffer(ev.buf) then
                schedule_render(ev.buf)
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
        group    = augroup,
        callback = function(ev)
            if timers[ev.buf] then
                timers[ev.buf]:stop()
                timers[ev.buf]:close()
                timers[ev.buf] = nil
            end
        end,
    })

    vim.api.nvim_set_hl(0, cfg.highlights.modified,  { fg = "#e5c07b", bold = true })
    vim.api.nvim_set_hl(0, cfg.highlights.added,     { fg = "#98c379" })
    vim.api.nvim_set_hl(0, cfg.highlights.deleted,   { fg = "#e06c75" })
    vim.api.nvim_set_hl(0, cfg.highlights.staged,    { fg = "#98c379", bold = true })
end

M._render = render

return M
