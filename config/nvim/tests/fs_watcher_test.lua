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

-- WT-001: uv.new_fs_event() handle is available on all supported Neovim versions
do
    local uv = vim.uv or vim.loop
    assert_truthy(uv ~= nil, "WT-001: vim.uv or vim.loop should be available")
    local handle = uv.new_fs_event()
    assert_truthy(handle ~= nil, "WT-001: uv.new_fs_event() should return a handle")
    if not handle:is_closing() then
        handle:close()
    end
end

-- WT-002: uv.new_timer() + vim.schedule_wrap fires within the event loop
-- This is the mechanism schedule_refresh() relies on.
do
    local uv = vim.uv or vim.loop
    local fired = false
    local timer = uv.new_timer()
    timer:start(10, 0, vim.schedule_wrap(function()
        fired = true
        timer:close()
    end))
    vim.wait(500, function() return fired end)
    assert_truthy(fired, "WT-002: uv timer with vim.schedule_wrap should fire within 500ms")
end

-- WT-003: handle:start() on a valid directory succeeds
do
    local uv = vim.uv or vim.loop
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    local handle = uv.new_fs_event()
    assert_truthy(handle ~= nil, "WT-003: new_fs_event handle should be created")

    -- start() returns 0 (older libuv) or true (newer) on success; nil/false on failure
    local ok = handle:start(temp_dir, {}, function() end)
    assert_truthy(ok ~= false and ok ~= nil, "WT-003: handle:start() on a valid dir should succeed")

    if not handle:is_closing() then
        handle:stop()
        handle:close()
    end
    vim.fn.delete(temp_dir, "rf")
end

-- WT-004: fs_event fires when a file is created in the watched directory
do
    local uv = vim.uv or vim.loop
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    local event_fired = false
    local handle = uv.new_fs_event()
    handle:start(temp_dir, {}, function(err)
        if not err then
            event_fired = true
        end
    end)

    vim.fn.writefile({ "trigger" }, temp_dir .. "/new_file.txt")
    vim.wait(1000, function() return event_fired end)

    assert_truthy(event_fired, "WT-004: fs_event should fire when a file is created in the watched directory")

    if not handle:is_closing() then
        handle:stop()
        handle:close()
    end
    vim.fn.delete(temp_dir, "rf")
end

-- WT-005: toggle open+close cycle does not raise from watcher start/stop
do
    package.loaded["sidebar_explorer"] = nil
    local sidebar = require("sidebar_explorer")
    sidebar.setup()

    local ok_open, err_open = pcall(function() sidebar.toggle() end)
    local ok_close, err_close = pcall(function() sidebar.toggle() end)
    -- Window creation may fail in headless mode; only watcher-path errors matter here.
    -- We guard on sidebar_explorer-specific prefixes to ignore unrelated window errors.
    local watcher_err = function(err)
        return err and (
            tostring(err):find("watcher") or
            tostring(err):find("fs_event") or
            tostring(err):find("timer")
        )
    end
    assert_truthy(not watcher_err(err_open), "WT-005: open toggle should not raise from watcher code: " .. tostring(err_open))
    assert_truthy(not watcher_err(err_close), "WT-005: close toggle (stop_watchers) should not raise: " .. tostring(err_close))
end

-- WT-006: M.refresh() with nil winid does not crash after watcher code was added
do
    package.loaded["sidebar_explorer"] = nil
    local sidebar = require("sidebar_explorer")
    sidebar.setup()

    local ok, err = pcall(function() sidebar.refresh() end)
    assert_truthy(ok, "WT-006: M.refresh() with nil winid should not raise: " .. tostring(err))
end

print("fs_watcher_test: ok")
