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

-- UT-001: M.refresh() with nil winid does not raise an error
do
    local sidebar = require("sidebar_explorer")
    local ok = pcall(function() sidebar.refresh() end)
    assert_truthy(ok, "UT-001: M.refresh() with nil winid should not raise an error")
end

-- UT-002: stale on_done is not called after refresh_sync cancels the timer
do
    local renderer = require("ui.file_status_renderer")
    local temp_a = vim.fn.tempname()
    local temp_b = vim.fn.tempname()
    vim.fn.mkdir(temp_a, "p")
    vim.fn.mkdir(temp_b, "p")

    local on_done_called = false
    renderer.refresh(temp_a, function() on_done_called = true end)
    renderer.refresh_sync(temp_b)

    vim.wait(500, function() return false end)

    assert_truthy(not on_done_called, "UT-002: stale on_done should not fire after refresh_sync")

    vim.fn.delete(temp_a, "rf")
    vim.fn.delete(temp_b, "rf")
end

-- UT-003: git/diff.lua returns normalized path key
do
    local diff = require("git.diff")
    local temp_root = vim.fn.tempname()
    vim.fn.mkdir(temp_root, "p")
    vim.fn.system({ "git", "init", temp_root })
    vim.fn.system({ "git", "-C", temp_root, "config", "user.email", "test@test.com" })
    vim.fn.system({ "git", "-C", temp_root, "config", "user.name", "Test" })

    local test_file = temp_root .. "/test.lua"
    vim.fn.writefile({ "line1", "line2" }, test_file)
    vim.fn.system({ "git", "-C", temp_root, "add", "test.lua" })
    vim.fn.system({ "git", "-C", temp_root, "commit", "-m", "init" })
    vim.fn.writefile({ "line1", "line2", "line3" }, test_file)

    local result = diff.get(test_file, false)
    local normalized_key = vim.fs.normalize(test_file)
    assert_truthy(result[normalized_key] ~= nil, "UT-003: diff.get should return normalized path key")

    vim.fn.delete(temp_root, "rf")
end

print("crash_and_refresh_fixes_test: ok")
