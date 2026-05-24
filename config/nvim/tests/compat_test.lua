package.path = table.concat(
    {
        vim.fn.getcwd() .. "/lua/?.lua",
        vim.fn.getcwd() .. "/lua/?/init.lua",
        package.path,
    },
    ";"
)

local compat = require("compat")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "assertion failed: value is nil")
    end
end

-- UT-001: compat.uv is not nil and exposes new_timer
do
    assert_not_nil(compat.uv, "UT-001: compat.uv must not be nil")
    assert_not_nil(compat.uv.new_timer, "UT-001: compat.uv must expose new_timer")
end

-- UT-002: fs_relpath with path under base returns relative path
do
    local result = compat.fs_relpath("/tmp/root", "/tmp/root/sub/file.txt")
    assert_equal(result, "sub/file.txt", "UT-002: expected sub/file.txt")
end

-- UT-003: fs_relpath with path not under base returns nil
do
    local result = compat.fs_relpath("/tmp/root", "/tmp/other/file.txt")
    assert_equal(result, nil, "UT-003: expected nil for unrelated path")
end

-- UT-004: on 0.10+, compat.uv is the same reference as vim.uv
do
    if vim.uv then
        assert_equal(compat.uv, vim.uv, "UT-004: on 0.10+, compat.uv must equal vim.uv")
    end
end

print("compat_test: ok")
