package.path = table.concat(
    {
        vim.fn.getcwd() .. "/lua/?.lua",
        vim.fn.getcwd() .. "/lua/?/init.lua",
        package.path,
    },
    ";"
)

local renderer = require("ui.file_status_renderer")
local cfg = require("config")

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

-- UT-001: get_indicator returns correct symbol for each tracked status
do
    local root = make_temp_git_repo()
    local file_path = root .. "/file.txt"
    vim.fn.writefile({ "original" }, file_path)
    vim.fn.system({ "git", "-C", root, "add", "file.txt" })
    vim.fn.system({ "git", "-C", root, "commit", "-m", "initial" })
    vim.fn.writefile({ "modified" }, file_path)

    renderer.refresh_sync(root)

    local normalized = vim.fs.normalize(file_path)
    local indicator = renderer.get_indicator({ path = normalized, type = "file", ignored = false })
    assert_equal(indicator.symbol, cfg.symbols.modified, "UT-001: modified file should show modified symbol")
    assert_equal(indicator.highlight, cfg.highlights.modified, "UT-001: modified file should use modified highlight")

    vim.fn.delete(root, "rf")
end

-- UT-002: directory entries get no symbol
do
    local indicator = renderer.get_indicator({ path = "/any/path", type = "directory", ignored = false })
    assert_equal(indicator.symbol, "", "UT-002: directory should have no symbol")
    assert_equal(indicator.highlight, nil, "UT-002: directory should have no highlight")
end

-- UT-003: ignored entry with no tracked status shows ignored symbol
do
    renderer.refresh_sync(vim.fn.tempname())

    local indicator = renderer.get_indicator({ path = "/no/such/path", type = "file", ignored = true })
    assert_equal(indicator.symbol, cfg.symbols.ignored, "UT-003: ignored file with no tracked status should show ignored symbol")
    assert_equal(indicator.highlight, cfg.highlights.ignored, "UT-003: ignored file should use ignored highlight")
end

-- UT-004: tracked status takes priority over ignored
do
    local root = make_temp_git_repo()
    local file_path = root .. "/new_file.txt"
    vim.fn.writefile({ "untracked content" }, file_path)

    renderer.refresh_sync(root)

    local normalized = vim.fs.normalize(file_path)
    local indicator = renderer.get_indicator({ path = normalized, type = "file", ignored = true })
    assert_equal(indicator.symbol, cfg.symbols.untracked, "UT-004: untracked status should take priority over ignored")

    vim.fn.delete(root, "rf")
end

-- IT-001: modified file shows indicator after refresh_sync
do
    local root = make_temp_git_repo()
    local file_path = root .. "/tracked.txt"
    vim.fn.writefile({ "original content" }, file_path)
    vim.fn.system({ "git", "-C", root, "add", "tracked.txt" })
    vim.fn.system({ "git", "-C", root, "commit", "-m", "initial" })
    vim.fn.writefile({ "modified content" }, file_path)

    renderer.refresh_sync(root)

    local normalized = vim.fs.normalize(file_path)
    local indicator = renderer.get_indicator({ path = normalized, type = "file", ignored = false })
    assert_equal(indicator.symbol, cfg.symbols.modified, "IT-001: modified file should show modified symbol after refresh_sync")

    vim.fn.delete(root, "rf")
end

-- OT-001: no notification on non-git directory
do
    local non_git_dir = vim.fn.tempname()
    vim.fn.mkdir(non_git_dir, "p")

    local notifications = {}
    local original_notify = vim.notify
    vim.notify = function(message, level)
        table.insert(notifications, { message = message, level = level })
    end

    renderer.refresh_sync(non_git_dir)

    vim.notify = original_notify

    assert_equal(#notifications, 0, "OT-001: no notifications should be emitted for non-git directory")

    vim.fn.delete(non_git_dir, "rf")
end

print("file_explorer_git_indicators_test: ok")
