package.path = table.concat(
    {
        vim.fn.getcwd() .. "/lua/?.lua",
        vim.fn.getcwd() .. "/lua/?/init.lua",
        package.path,
    },
    ";"
)

local explorer = require("sidebar_explorer")

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

local function find_entry(entries, name)
    for _, entry in ipairs(entries) do
        if entry.name == name then
            return entry
        end
    end

    return nil
end

local function has_line_suffix(lines, suffix)
    for _, line in ipairs(lines) do
        if vim.endswith(line, suffix) then
            return true
        end
    end

    return false
end

local temp_root = vim.fn.tempname()
vim.fn.mkdir(temp_root, "p")
vim.fn.mkdir(temp_root .. "/lua", "p")
vim.fn.mkdir(temp_root .. "/lua/nested", "p")
vim.fn.mkdir(temp_root .. "/ignored-dir", "p")
vim.fn.system({ "git", "init", temp_root })
vim.fn.writefile({ "ignored.txt", "ignored-dir/" }, temp_root .. "/.gitignore")
vim.fn.writefile({ "print('hello')" }, temp_root .. "/lua/nested/example.lua")
vim.fn.writefile({ "tracked" }, temp_root .. "/tracked.txt")
vim.fn.writefile({ "ignored" }, temp_root .. "/ignored.txt")
vim.fn.writefile({ "inside ignored dir" }, temp_root .. "/ignored-dir/child.txt")

local normalized_root = explorer._test.normalize_path(temp_root)
local lines, entries = explorer._test.build_lines(temp_root, {
    [normalized_root] = true,
    [explorer._test.normalize_path(temp_root .. "/lua")] = true,
    [explorer._test.normalize_path(temp_root .. "/lua/nested")] = true,
})

assert_equal(lines[1], "▾ " .. vim.fs.basename(temp_root), "root line should show the expanded root directory")
assert_truthy(vim.tbl_contains(lines, "  ▾ lua"), "expanded directories should be rendered with an expanded marker")
assert_truthy(has_line_suffix(lines, "example.lua"), "nested files should be rendered when parent directories are expanded")
assert_equal(entries[1].type, "directory", "root entry should be a directory")

local ignored_file_entry = find_entry(entries, "ignored.txt")
assert_truthy(ignored_file_entry and ignored_file_entry.ignored, "gitignored file should be marked as ignored")

local tracked_file_entry = find_entry(entries, "tracked.txt")
assert_truthy(tracked_file_entry and not tracked_file_entry.ignored, "tracked file should not be marked as ignored")

local ignored_dir_entry = find_entry(entries, "ignored-dir")
assert_truthy(ignored_dir_entry and ignored_dir_entry.ignored, "gitignored directory should be marked as ignored")

local ignored_lookup = explorer._test.get_ignored_lookup(temp_root, {
    explorer._test.normalize_path(temp_root .. "/ignored.txt"),
    explorer._test.normalize_path(temp_root .. "/tracked.txt"),
})
assert_truthy(ignored_lookup[explorer._test.normalize_path(temp_root .. "/ignored.txt")], "ignored lookup should include ignored file")
assert_truthy(not ignored_lookup[explorer._test.normalize_path(temp_root .. "/tracked.txt")], "ignored lookup should exclude tracked file")

local collapsed_lines = explorer._test.build_lines(temp_root, {})
assert_equal(#collapsed_lines, 1, "collapsed root should hide child entries")

vim.cmd("cd " .. vim.fn.fnameescape(temp_root))
vim.cmd("edit " .. vim.fn.fnameescape(temp_root .. "/lua/nested/example.lua"))

local resolved_root = explorer._test.resolve_root()
assert_equal(resolved_root, normalized_root, "root resolution should prefer the nearest project marker")
assert_equal(explorer._test.find_git_root(temp_root), normalized_root, "git root discovery should resolve the repository root")

local fallback_root = vim.fn.tempname()
vim.fn.mkdir(fallback_root, "p")
local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level)
    table.insert(notifications, { message = message, level = level })
end

local fallback_lookup = explorer._test.get_ignored_lookup(fallback_root, {
    explorer._test.normalize_path(fallback_root .. "/plain.txt"),
})
assert_equal(vim.tbl_count(fallback_lookup), 0, "non-git directories should return an empty ignored lookup")
assert_equal(#notifications, 0, "non-git fallback should not notify")
vim.notify = original_notify

-- IT-002: build_lines reflects new files and updated ignore state after filesystem changes
local new_tracked = temp_root .. "/newly_added.txt"
vim.fn.writefile({ "new content" }, new_tracked)
local after_add_lines, after_add_entries = explorer._test.build_lines(temp_root, { [normalized_root] = true })
assert_truthy(has_line_suffix(after_add_lines, "newly_added.txt"), "build_lines should include files added after the initial render")

vim.fn.writefile({ "ignored.txt", "ignored-dir/", "newly_added.txt" }, temp_root .. "/.gitignore")
local after_ignore_lines, after_ignore_entries = explorer._test.build_lines(temp_root, { [normalized_root] = true })
local newly_ignored_entry = find_entry(after_ignore_entries, "newly_added.txt")
assert_truthy(newly_ignored_entry and newly_ignored_entry.ignored, "build_lines should recalculate ignored state when gitignore is updated")

-- OT-001: git detection failure emits at most one notification per call
local corrupted_git_root = vim.fn.tempname()
vim.fn.mkdir(corrupted_git_root .. "/.git", "p")
local ot_001_notifications = {}
local ot_001_original_notify = vim.notify
vim.notify = function(message, level)
    table.insert(ot_001_notifications, { message = message, level = level })
end
explorer._test.get_ignored_lookup(corrupted_git_root, {
    explorer._test.normalize_path(corrupted_git_root .. "/file.txt"),
})
vim.notify = ot_001_original_notify
assert_truthy(#ot_001_notifications <= 1, "git detection failure should emit at most one notification")
vim.fn.delete(corrupted_git_root, "rf")

vim.cmd("bwipeout!")
vim.fn.delete(fallback_root, "rf")
vim.fn.delete(temp_root, "rf")

print("sidebar_explorer_validation: ok")
