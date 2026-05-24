local M = {}

local compat     = require("compat")
local git_status = require("git.status")
local cfg        = require("config")

local cached_status = {}
local timer = nil

local priority = { "partial", "staged", "modified", "added", "deleted", "renamed", "untracked" }

function M.get_indicator(entry)
    if entry.type == "directory" then
        return { symbol = "", highlight = nil }
    end

    for _, status in ipairs(priority) do
        if cached_status[entry.path] == status then
            return {
                symbol    = cfg.symbols[status] or "",
                highlight = cfg.highlights[status],
            }
        end
    end

    if entry.ignored then
        return {
            symbol    = cfg.symbols.ignored or "",
            highlight = cfg.highlights.ignored,
        }
    end

    return { symbol = "", highlight = nil }
end

function M.refresh(root, on_done)
    if timer then timer:stop(); timer:close(); timer = nil end
    local t = compat.uv.new_timer()
    timer = t
    t:start(cfg.debounce_ms, 0, vim.schedule_wrap(function()
        if timer ~= t then return end
        timer = nil
        cached_status = git_status.get(root) or {}
        if on_done then on_done() end
    end))
end

function M.refresh_sync(root)
    if timer then timer:stop(); timer:close(); timer = nil end
    cached_status = git_status.get(root) or {}
end

return M
