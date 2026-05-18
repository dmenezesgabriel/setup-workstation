package.path = table.concat(
    {
        vim.fn.getcwd() .. "/lua/?.lua",
        vim.fn.getcwd() .. "/lua/?/init.lua",
        package.path,
    },
    ";"
)

local git_status = require("git.status")
local git_diff = require("git.diff")

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

-- UT-001: status parser with hand-crafted porcelain strings
do
    local root = "/tmp/fake-root"
    local raw = "?? untracked.txt\0M  staged.txt\0 M modified.txt\0MM partial.txt\0A  staged_add.txt\0D  staged_del.txt\0 D deleted.txt\0"
    local result = git_status._parse(raw, root)

    assert_equal(result[vim.fs.normalize(root .. "/untracked.txt")], "untracked", "UT-001: ?? maps to untracked")
    assert_equal(result[vim.fs.normalize(root .. "/staged.txt")], "staged", "UT-001: M  maps to staged")
    assert_equal(result[vim.fs.normalize(root .. "/modified.txt")], "modified", "UT-001: ' M' maps to modified")
    assert_equal(result[vim.fs.normalize(root .. "/partial.txt")], "partial", "UT-001: MM maps to partial")
    assert_equal(result[vim.fs.normalize(root .. "/staged_add.txt")], "staged", "UT-001: A  maps to staged")
    assert_equal(result[vim.fs.normalize(root .. "/staged_del.txt")], "staged", "UT-001: D  maps to staged")
    assert_equal(result[vim.fs.normalize(root .. "/deleted.txt")], "deleted", "UT-001: ' D' maps to deleted")
end

-- UT-002: diff parser with hand-crafted diff output
do
    local path = "/tmp/fake-root/file.txt"

    local added_diff = "@@ -0,0 +1,3 @@\n+line1\n+line2\n+line3\n"
    local added_result = git_diff._parse(added_diff, path, false)
    assert_equal(added_result[path][1], "added", "UT-002: hunk -0,0 +1,3 line 1 is added")
    assert_equal(added_result[path][2], "added", "UT-002: hunk -0,0 +1,3 line 2 is added")
    assert_equal(added_result[path][3], "added", "UT-002: hunk -0,0 +1,3 line 3 is added")

    local deleted_diff = "@@ -5,2 +5,0 @@\n-line5\n-line6\n"
    local deleted_result = git_diff._parse(deleted_diff, path, false)
    assert_equal(deleted_result[path][5], "deleted", "UT-002: hunk -5,2 +5,0 line 5 is deleted")

    local modified_diff = "@@ -3,2 +3,2 @@\n-old3\n-old4\n+new3\n+new4\n"
    local modified_result = git_diff._parse(modified_diff, path, false)
    assert_equal(modified_result[path][3], "modified", "UT-002: hunk -3,2 +3,2 line 3 is modified")
    assert_equal(modified_result[path][4], "modified", "UT-002: hunk -3,2 +3,2 line 4 is modified")

    local staged_diff = "@@ -3,2 +3,2 @@\n-old3\n+new3\n"
    local staged_result = git_diff._parse(staged_diff, path, true)
    assert_equal(staged_result[path][3], "staged", "UT-002: staged=true produces staged change type")
end

-- IT-001: status from real temp git repo
local temp_root = vim.fn.tempname()
vim.fn.mkdir(temp_root, "p")
vim.fn.system({ "git", "init", temp_root })
vim.fn.system({ "git", "-C", temp_root, "config", "user.email", "test@test.com" })
vim.fn.system({ "git", "-C", temp_root, "config", "user.name", "Test" })
vim.fn.writefile({ "original content" }, temp_root .. "/file.txt")
vim.fn.system({ "git", "-C", temp_root, "add", "file.txt" })
vim.fn.system({ "git", "-C", temp_root, "commit", "-m", "initial" })
vim.fn.writefile({ "modified content" }, temp_root .. "/file.txt")

local it001_result = git_status.get(temp_root)
local normalized_file = vim.fs.normalize(temp_root .. "/file.txt")
assert_equal(it001_result[normalized_file], "modified", "IT-001: modified file maps to 'modified'")

-- IT-002 / OT-001: non-git directory returns empty without notification
local non_git_dir = vim.fn.tempname()
vim.fn.mkdir(non_git_dir, "p")
local non_git_file = non_git_dir .. "/somefile.txt"
vim.fn.writefile({ "content" }, non_git_file)

local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level)
    table.insert(notifications, { message = message, level = level })
end

local it002_status = git_status.get(non_git_dir)
local it002_diff = git_diff.get(non_git_file)

vim.notify = original_notify

assert_equal(vim.tbl_count(it002_status), 0, "IT-002: non-git dir returns empty status table")
assert_equal(vim.tbl_count(it002_diff), 0, "IT-002: non-git dir returns empty diff table")
assert_equal(#notifications, 0, "OT-001: no notifications emitted for non-git directory")

vim.fn.delete(temp_root, "rf")
vim.fn.delete(non_git_dir, "rf")

print("git_status_data_layer_test: ok")
