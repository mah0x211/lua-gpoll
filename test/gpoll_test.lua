require('luacov')
local assert = require('assert')
local errno = require('errno')
local gpoll = require('gpoll')
local default_pollable = gpoll.pollable

do
    -- test that default returns
    assert.is_false(gpoll.pollable())
    for _, fn in ipairs({
        gpoll.wait_readable,
        gpoll.wait_writable,
        gpoll.unwait,
        gpoll.unwait_readable,
        gpoll.unwait_writable,
        gpoll.read_lock,
        gpoll.write_lock,
        gpoll.read_unlock,
        gpoll.write_unlock,
    }) do
        local ok, err, timeout = fn(1)
        assert.is_false(ok)
        assert.equal(err.type, errno.ENOTSUP)
        assert.is_nil(timeout)
    end
end

do
    -- test that poller return true
    gpoll.set_poller({
        pollable = function()
            return true
        end,
        wait_readable = function()
            return true
        end,
        wait_writable = function()
            return true
        end,
        unwait = function()
            return true
        end,
        unwait_readable = function()
            return true
        end,
        unwait_writable = function()
            return true
        end,
        read_lock = function()
            return true
        end,
        write_lock = function()
            return true
        end,
        read_unlock = function()
            return true
        end,
        write_unlock = function()
            return true
        end,
    })
    assert.is_true(gpoll.pollable())

    for _, v in ipairs({
        {
            fn = 'wait_readable',
            ok = true,
        },
        {
            fn = 'wait_writable',
            ok = true,
        },
        {
            fn = 'unwait',
            ok = true,
        },
        {
            fn = 'unwait_readable',
            ok = true,
        },
        {
            fn = 'unwait_writable',
            ok = true,
        },
        {
            fn = 'read_lock',
            ok = true,
        },
        {
            fn = 'write_lock',
            ok = true,
        },
        {
            fn = 'read_unlock',
            ok = true,
        },
        {
            fn = 'write_unlock',
            ok = true,
        },
    }) do
        local ok, err, timeout = gpoll[v.fn](1)
        assert.equal(ok, v.ok)
        assert.is_nil(err)
        assert.is_nil(timeout)
    end

    -- test that set default poller if poller argument is nil
    gpoll.set_poller()
    assert.equal(gpoll.pollable, default_pollable)

    -- test that throws an error if poller api is not function
    do
        local err = assert.throws(gpoll.set_poller, {
            pollable = 'pollable',
            wait_readable = 'wait_readable',
            wait_writable = 'wait_writable',
            unwait = 'unwait',
            unwait_readable = 'unwait_readable',
            unwait_writable = 'unwait_writable',
            read_lock = 'read_lock',
            write_lock = 'write_lock',
            read_unlock = 'read_unlock',
            write_unlock = 'write_unlock',
        })
        assert.match(err, 'is not function')
    end

    -- test that throws an error if fd argument is invalid
    for _, v in ipairs({
        'wait_readable',
        'wait_writable',
        'unwait',
        'unwait_readable',
        'unwait_writable',
        'read_lock',
        'write_lock',
        'read_unlock',
        'write_unlock',
    }) do
        local err = assert.throws(gpoll[v], 'hello')
        assert.match(err, 'fd must be uint')
    end

    -- test that throws an error if duration argument is invalid
    for _, v in ipairs({
        'wait_readable',
        'wait_writable',
        'read_lock',
        'write_lock',
    }) do
        local err = assert.throws(gpoll[v], 1, 'hello')
        assert.match(err, 'duration must be uint')
    end

    -- test that throws an error if hookfn argument is not function
    for _, v in ipairs({
        'wait_readable',
        'wait_writable',
    }) do
        local err = assert.throws(gpoll[v], 1, 123, 'hello')
        assert.match(err, 'hookfn must be function')
    end
end

do
    -- test that poller return timeout
    gpoll.set_poller({
        pollable = function()
            return true
        end,
        wait_readable = function()
            return false, errno.ETIMEDOUT:new('wait_readable'), true
        end,
        wait_writable = function()
            return false, errno.ETIMEDOUT:new('wait_writable'), true
        end,
        unwait = function()
            return false, errno.ETIMEDOUT:new('unwait'), true
        end,
        unwait_readable = function()
            return false, errno.ETIMEDOUT:new('unwait_readable'), true
        end,
        unwait_writable = function()
            return false, errno.ETIMEDOUT:new('unwait_writable'), true
        end,
        read_lock = function()
            return false, errno.ETIMEDOUT:new('read_lock'), true
        end,
        write_lock = function()
            return false, errno.ETIMEDOUT:new('write_lock'), true
        end,
        read_unlock = function()
            return false, errno.ETIMEDOUT:new('read_unlock')
        end,
        write_unlock = function()
            return false, errno.ETIMEDOUT:new('write_unlock')
        end,
    })
    assert.is_true(gpoll.pollable())
    for _, v in ipairs({
        {
            fn = 'wait_readable',
            ok = false,
            err = errno.ETIMEDOUT,
            timeout = true,
        },
        {
            fn = 'wait_writable',
            ok = false,
            err = errno.ETIMEDOUT,
            timeout = true,
        },
        {
            fn = 'unwait',
            ok = false,
            err = errno.ETIMEDOUT,
        },
        {
            fn = 'unwait_readable',
            ok = false,
            err = errno.ETIMEDOUT,
        },
        {
            fn = 'unwait_writable',
            ok = false,
            err = errno.ETIMEDOUT,
        },
        {
            fn = 'read_lock',
            ok = false,
            err = errno.ETIMEDOUT,
            timeout = true,
        },
        {
            fn = 'write_lock',
            ok = false,
            err = errno.ETIMEDOUT,
            timeout = true,
        },
        {
            fn = 'read_unlock',
            ok = false,
            err = errno.ETIMEDOUT,
        },
        {
            fn = 'write_unlock',
            ok = false,
            err = errno.ETIMEDOUT,
        },
    }) do
        local ok, err, timeout = gpoll[v.fn](1)
        assert.equal(ok, v.ok)
        assert.equal(err.type, v.err)
        assert.equal(timeout, v.timeout)
    end
end

do
    -- test that poller.wait_* functions calls hook function
    gpoll.set_poller({
        pollable = function()
            return true
        end,
        wait_readable = function()
            return true
        end,
        wait_writable = function()
            return true
        end,
        unwait = function()
            return true
        end,
        unwait_readable = function()
            return true
        end,
        unwait_writable = function()
            return true
        end,
        read_lock = function()
            return true
        end,
        write_lock = function()
            return true
        end,
        read_unlock = function()
            return true
        end,
        write_unlock = function()
            return true
        end,
    })
    for _, v in ipairs({
        'wait_readable',
        'wait_writable',
    }) do
        local ok, err = gpoll[v](1, 123, function(ctx, deadline)
            assert.equal(ctx, 'context')
            assert.equal(deadline, 123)
            return false, 'hook failure'
        end, 'context')
        assert.is_false(ok)
        assert.match(err, 'hook failure')
    end

    -- test that throws an error if hook function return false without error
    for _, v in ipairs({
        'wait_readable',
        'wait_writable',
    }) do
        local err = assert.throws(gpoll[v], 1, 123, function()
            return false
        end)
        assert.match(err, 'hookfn returned false|nil without an error')
    end
end

do
    -- test that throws an error if return false without error
    gpoll.set_poller({
        pollable = function()
            return false
        end,
        wait_readable = function()
            return false
        end,
        wait_writable = function()
            return false
        end,
        unwait = function()
            return false
        end,
        unwait_readable = function()
            return false
        end,
        unwait_writable = function()
            return false
        end,
        read_lock = function()
            return false
        end,
        write_lock = function()
            return false
        end,
        read_unlock = function()
            return false
        end,
        write_unlock = function()
            return false
        end,
    })
    for _, v in ipairs({
        'wait_readable',
        'wait_writable',
        'unwait',
        'unwait_readable',
        'unwait_writable',
        'read_lock',
        'write_lock',
        'read_unlock',
        'write_unlock',
    }) do
        local err = assert.throws(gpoll[v], 1)
        assert.match(err, v .. ' returned false|nil without an error')
    end
end

-- pollable = pollable,
-- wait_readable = wait_readable,
-- wait_writable = wait_writable,
-- unwait = unwait,
-- unwait_readable = unwait_readable,
-- unwait_writable = unwait_writable,
-- read_lock = read_lock,
-- write_lock = write_lock,
-- read_unlock = read_unlock,
-- write_unlock = write_unlock,
