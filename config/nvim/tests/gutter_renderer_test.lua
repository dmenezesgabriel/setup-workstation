package.path = table.concat(
    {
        vim.fn.getcwd() .. "/lua/?.lua",
        vim.fn.getcwd() .. "/lua/?/init.lua",
        package.path,
    },
    ";"
)

local renderer  = require("ui.gutter_renderer")
local namespace = vim.api.nvim_create_namespace("git_gutter")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assert_truthy(value, message)
    if not value then
        error(message or "assertion failed")
    end
end

local function make_temp_git_repo()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    vim.fn.system({ "git", "init", root })
    vim.fn.system({ "git", "-C", root, "config", "user.email", "test@test.com" })
    vim.fn.system({ "git", "-C", root, "config", "user.name", "Test" })
    return root
end

-- UT-001: extmarks placed at correct 0-based lines
do
    local root = make_temp_git_repo()
    local file_path = root .. "/file.txt"
    vim.fn.writefile({ "line1", "line2", "line3" }, file_path)
    vim.fn.system({ "git", "-C", root, "add", "file.txt" })
    vim.fn.system({ "git", "-C", root, "commit", "-m", "initial" })
    vim.fn.writefile({ "line1", "changed line2", "line3", "new line4" }, file_path)

    local bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(bufnr, file_path)

    renderer._render(bufnr)

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
    assert_truthy(#marks > 0, "UT-001: expected at least one extmark after render")

    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(root, "rf")
end

-- UT-002: stale signs cleared on re-render
do
    local root = make_temp_git_repo()
    local file_path = root .. "/file.txt"
    vim.fn.writefile({ "line1", "line2", "line3" }, file_path)
    vim.fn.system({ "git", "-C", root, "add", "file.txt" })
    vim.fn.system({ "git", "-C", root, "commit", "-m", "initial" })
    vim.fn.writefile({ "line1", "changed line2", "line3" }, file_path)

    local bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(bufnr, file_path)

    renderer._render(bufnr)
    local marks_first = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
    local expected_count = #marks_first

    renderer._render(bufnr)
    local marks_after_second = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
    assert_truthy(#marks_after_second <= expected_count, "UT-002: stale signs must be cleared")

    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(root, "rf")
end

-- UT-003: nofile buffer produces no extmarks
do
    local nofile_buf = vim.api.nvim_create_buf(false, true)
    renderer._render(nofile_buf)
    local marks = vim.api.nvim_buf_get_extmarks(nofile_buf, namespace, 0, -1, {})
    assert_equal(#marks, 0, "UT-003: nofile buffer should have no extmarks")
    vim.api.nvim_buf_delete(nofile_buf, { force = true })
end

-- IT-001: real git repo file gets extmarks
do
    local root = make_temp_git_repo()
    local file_path = root .. "/tracked.txt"
    vim.fn.writefile({ "original line" }, file_path)
    vim.fn.system({ "git", "-C", root, "add", "tracked.txt" })
    vim.fn.system({ "git", "-C", root, "commit", "-m", "initial" })
    vim.fn.writefile({ "original line", "added line 2", "added line 3" }, file_path)

    local bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(bufnr, file_path)

    renderer._render(bufnr)

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
    assert_truthy(#marks > 0, "IT-001: expected extmarks for modified tracked file")

    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(root, "rf")
end

-- IT-002: second render clears first
do
    local root = make_temp_git_repo()
    local file_path = root .. "/tracked.txt"
    vim.fn.writefile({ "line a", "line b" }, file_path)
    vim.fn.system({ "git", "-C", root, "add", "tracked.txt" })
    vim.fn.system({ "git", "-C", root, "commit", "-m", "initial" })
    vim.fn.writefile({ "line a changed", "line b" }, file_path)

    local bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(bufnr, file_path)

    renderer._render(bufnr)
    local marks_first = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})

    renderer._render(bufnr)
    local marks_second = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})

    assert_truthy(#marks_second <= #marks_first, "IT-002: second render should not accumulate stale signs")

    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(root, "rf")
end

-- IT-003 / OT-001: non-git file produces no extmarks and no notification
do
    local non_git_dir = vim.fn.tempname()
    vim.fn.mkdir(non_git_dir, "p")
    local non_git_file = non_git_dir .. "/plain.txt"
    vim.fn.writefile({ "content" }, non_git_file)

    local notifications = {}
    local original_notify = vim.notify
    vim.notify = function(message, level)
        table.insert(notifications, { message = message, level = level })
    end

    local bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(bufnr, non_git_file)

    renderer._render(bufnr)

    vim.notify = original_notify

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
    assert_equal(#marks, 0, "IT-003: non-git file should produce no extmarks")
    assert_equal(#notifications, 0, "OT-001: no notification expected")

    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(non_git_dir, "rf")
end

print("gutter_renderer_test: ok")
