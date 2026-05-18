package.path = table.concat(
    {
        vim.fn.getcwd() .. "/lua/?.lua",
        vim.fn.getcwd() .. "/lua/?/init.lua",
        package.path,
    },
    ";"
)

local function assert_truthy(value, message)
    if not value then
        error(message or "assertion failed")
    end
end

-- UT-001: After setup() and buffer creation, <LeftMouse> keymap is registered on the sidebar buffer.
do
    package.loaded["sidebar_explorer"] = nil
    local sidebar = require("sidebar_explorer")
    sidebar.setup()
    pcall(function() sidebar.toggle() end)

    local bufnr = nil
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].filetype == "sidebar_explorer" then
            bufnr = b
            break
        end
    end

    assert_truthy(bufnr ~= nil, "UT-001: sidebar buffer should exist after toggle()")

    local keymaps = vim.api.nvim_buf_get_keymap(bufnr, "n")
    local found = false
    for _, km in ipairs(keymaps) do
        if km.lhs == "<LeftMouse>" then
            found = true
            break
        end
    end
    assert_truthy(found, "UT-001: <LeftMouse> buffer-local keymap should be registered on sidebar buffer")
end

-- UT-002: After setup() and buffer creation, <2-LeftMouse> keymap is registered on the sidebar buffer.
do
    package.loaded["sidebar_explorer"] = nil
    local sidebar = require("sidebar_explorer")
    sidebar.setup()
    pcall(function() sidebar.toggle() end)

    local bufnr = nil
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].filetype == "sidebar_explorer" then
            bufnr = b
            break
        end
    end

    assert_truthy(bufnr ~= nil, "UT-002: sidebar buffer should exist after toggle()")

    local keymaps = vim.api.nvim_buf_get_keymap(bufnr, "n")
    local found = false
    for _, km in ipairs(keymaps) do
        if km.lhs == "<2-LeftMouse>" then
            found = true
            break
        end
    end
    assert_truthy(found, "UT-002: <2-LeftMouse> buffer-local keymap should be registered on sidebar buffer")
end

print("mouse_support_test: ok")
