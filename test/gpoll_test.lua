require('luacov')
local assert = require('assert')
local errno = require('errno')
local fork = require('fork')
local getpid = require('getpid')
local msleep = require('nanosleep.msleep')
local signal = require('signal')
local gpoll = require('gpoll')
local TMPFILE = assert(io.tmpfile())
local TMPFD = require('io.fileno')(TMPFILE)
local NOOP = function()
end

local function test_default()
    -- test that default returns
    local ok, err = gpoll.pollable()
    assert.is_false(ok)
    assert.is_nil(err)

    ok, err = gpoll.later()
    assert.is_true(ok)
    assert.is_nil(err)

    local timeout
    for _, fn in ipairs({
        gpoll.unwait,
        gpoll.unwait_readable,
        gpoll.unwait_writable,
        gpoll.read_lock,
        gpoll.write_lock,
        gpoll.read_unlock,
        gpoll.write_unlock,
    }) do
        ok, err, timeout = fn(1)
        assert.is_false(ok)
        assert.equal(err.type, errno.ENOTSUP)
        assert.is_nil(timeout)
    end

    -- wait readable/writable
    for _, fn in ipairs({
        gpoll.wait_readable,
        gpoll.wait_writable,
    }) do
        ok, err, timeout = fn(TMPFD)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.is_nil(timeout)
    end
end

local function test_set_poller()
    -- test that set custom poller
    gpoll.set_poller({
        pollable = function()
            return true
        end,
        later = function()
            return true
        end,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = NOOP,
        sigwait = NOOP,
    })
    assert.is_true(gpoll.pollable())

    -- test that set default poller if poller argument is nil
    gpoll.set_poller()
    assert.is_false(gpoll.pollable())

    -- test that throws an error if poller api is not function
    local err = assert.throws(gpoll.set_poller, {
        pollable = 'pollable',
        later = 'later',
        wait_readable = 'wait_readable',
        wait_writable = 'wait_writable',
        unwait = 'unwait',
        unwait_readable = 'unwait_readable',
        unwait_writable = 'unwait_writable',
        read_lock = 'read_lock',
        write_lock = 'write_lock',
        read_unlock = 'read_unlock',
        write_unlock = 'write_unlock',
        sleep = 'sleep',
        sigwait = 'sigwait',
    })
    assert.match(err, 'is not function')
end

local function test_wait()
    for _, waitfn in ipairs({
        gpoll.wait_readable,
        gpoll.wait_writable,
    }) do
        gpoll.set_poller()

        -- test that true if fd is wait readable/writable
        local ok, err, timeout = waitfn(TMPFD)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.is_nil(timeout)

        -- test that hookfn is called before waiting for fd event
        local called = false
        ok, err, timeout = waitfn(TMPFD, nil, function()
            called = true
            return true
        end)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.is_nil(timeout)
        assert.is_true(called)

        -- test that return error from hookfn
        ok, err, timeout = waitfn(TMPFD, nil, function()
            return false, 'hook error'
        end)
        assert.is_false(ok)
        assert.match(err, 'hook error')
        assert.is_nil(timeout)

        -- test that return timeout from hookfn
        ok, err, timeout = waitfn(TMPFD, nil, function()
            return false, nil, true
        end)
        assert.is_false(ok)
        assert.is_nil(err)
        assert.is_true(timeout)

        -- test that return error
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = function()
                return false, 'wait error'
            end,
            wait_writable = function()
                return false, 'wait error'
            end,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err, timeout = waitfn(TMPFD)
        assert.is_false(ok)
        assert.match(err, 'wait error')
        assert.is_nil(timeout)

        -- test that return timeout
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = function()
                return false, nil, true
            end,
            wait_writable = function()
                return false, nil, true
            end,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err, timeout = waitfn(TMPFD)
        assert.is_false(ok)
        assert.is_nil(err)
        assert.is_true(timeout)

        -- test that throws an error if fd is invalid
        err = assert.throws(waitfn, 'hello')
        assert.match(err, 'fd must be uint')

        -- test that throws an error if duration is invalid
        err = assert.throws(waitfn, TMPFD, 'hello')
        assert.match(err, 'duration must be uint')

        -- test that throws an error if hookfn is invalid
        err = assert.throws(waitfn, TMPFD, nil, {})
        assert.match(err, 'hookfn must be function')

        -- test that throws an error if hookfn return false with neither error nor timeout
        err = assert.throws(waitfn, TMPFD, nil, function()
            return false
        end)
        assert.match(err, 'hookfn .+ neither error nor timeout', false)

        -- test that throws an error if wait_readable return false with neither error nor timeout
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = function()
                return false
            end,
            wait_writable = function()
                return false
            end,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        err = assert.throws(waitfn, TMPFD)
        assert.match(err, 'wait_.+ neither error nor timeout', false)
    end
end

local function test_unwait()
    for _, fn in ipairs({
        gpoll.unwait,
        gpoll.unwait_readable,
        gpoll.unwait_writable,
    }) do
        gpoll.set_poller()

        -- test that true if fd is unwait readable/writable
        local ok, err = fn(TMPFD)
        assert.is_false(ok)
        assert.equal(err.type, errno.ENOTSUP)

        -- test that return true
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = function()
                return true
            end,
            unwait_readable = function()
                return true
            end,
            unwait_writable = function()
                return true
            end,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err = fn(TMPFD)
        assert.is_true(ok)
        assert.is_nil(err)

        -- test that return error
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = function()
                return false, 'unwait error'
            end,
            unwait_readable = function()
                return false, 'unwait error'
            end,
            unwait_writable = function()
                return false, 'unwait error'
            end,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err = fn(TMPFD)
        assert.is_false(ok)
        assert.match(err, 'unwait error')

        -- test that throws an error if fd is invalid
        err = assert.throws(fn, 'hello')
        assert.match(err, 'fd must be uint')

        -- test that throws an error if wait_readable return false without error
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = function()
                return false
            end,
            unwait_readable = function()
                return false
            end,
            unwait_writable = function()
                return false
            end,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        err = assert.throws(fn, TMPFD)
        assert.match(err, 'unwait.+ without an error', false)
    end
end

local function test_lock()
    for _, fn in ipairs({
        gpoll.read_lock,
        gpoll.write_lock,
    }) do
        gpoll.set_poller()

        -- test that true if fd is read_lock/write_lock
        local ok, err, timeout = fn(TMPFD)
        assert.is_false(ok)
        assert.equal(err.type, errno.ENOTSUP)
        assert.is_nil(timeout)

        -- test that return true
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = function()
                return true
            end,
            write_lock = function()
                return true
            end,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err, timeout = fn(TMPFD)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.is_nil(timeout)

        -- test that return error
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = function()
                return false, 'lock error'
            end,
            write_lock = function()
                return false, 'lock error'
            end,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err, timeout = fn(TMPFD)
        assert.is_false(ok)
        assert.match(err, 'lock error')
        assert.is_nil(timeout)

        -- test that return timeout
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = function()
                return false, nil, true
            end,
            write_lock = function()
                return false, nil, true
            end,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err, timeout = fn(TMPFD)
        assert.is_false(ok)
        assert.is_nil(err)
        assert.is_true(timeout)

        -- test that throws an error if fd is invalid
        err = assert.throws(fn, 'hello')
        assert.match(err, 'fd must be uint')

        -- test that throws an error if duration is invalid
        err = assert.throws(fn, TMPFD, 'hello')
        assert.match(err, 'duration must be uint')

        -- test that throws an error if wait_readable return false with neither error nor timeout
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = function()
                return false
            end,
            write_lock = function()
                return false
            end,
            read_unlock = NOOP,
            write_unlock = NOOP,
            sleep = NOOP,
            sigwait = NOOP,
        })
        err = assert.throws(fn, TMPFD)
        assert.match(err, '_lock.+ neither error nor timeout', false)
    end
end

local function test_unlock()
    for _, fn in ipairs({
        gpoll.read_unlock,
        gpoll.write_unlock,
    }) do
        gpoll.set_poller()

        -- test that true if fd is read_unlock/write_unlock
        local ok, err = fn(TMPFD)
        assert.is_false(ok)
        assert.equal(err.type, errno.ENOTSUP)

        -- test that return true
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = function()
                return true
            end,
            write_unlock = function()
                return true
            end,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err = fn(TMPFD)
        assert.is_true(ok)
        assert.is_nil(err)

        -- test that return error
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = function()
                return false, 'unlock error'
            end,
            write_unlock = function()
                return false, 'unlock error'
            end,
            sleep = NOOP,
            sigwait = NOOP,
        })
        ok, err = fn(TMPFD)
        assert.is_false(ok)
        assert.match(err, 'unlock error')

        -- test that throws an error if fd is invalid
        err = assert.throws(fn, 'hello')
        assert.match(err, 'fd must be uint')

        -- test that throws an error if wait_readable return false without error
        gpoll.set_poller({
            pollable = NOOP,
            later = NOOP,
            wait_readable = NOOP,
            wait_writable = NOOP,
            unwait = NOOP,
            unwait_readable = NOOP,
            unwait_writable = NOOP,
            read_lock = NOOP,
            write_lock = NOOP,
            read_unlock = function()
                return false
            end,
            write_unlock = function()
                return false
            end,
            sleep = NOOP,
            sigwait = NOOP,
        })
        err = assert.throws(fn, TMPFD)
        assert.match(err, '_unlock.+ without an error', false)
    end
end

local function test_sleep()
    -- test that sleep for 1 sec
    local rem, err = gpoll.sleep(1000)
    assert.equal(rem, 0)
    assert.is_nil(err)

    -- test that set custome sleep function
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = function()
            return 2
        end,
        sigwait = NOOP,
    })
    rem, err = gpoll.sleep(1)
    assert.equal(rem, 2)
    assert.is_nil(err)

    -- test that return error
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = function()
            return nil, 'sleep error'
        end,
        sigwait = NOOP,
    })
    rem, err = gpoll.sleep(1)
    assert.is_nil(rem)
    assert.match(err, 'sleep error')

    -- test that throws an error if duration is invalid
    err = assert.throws(gpoll.sleep, math.huge)
    assert.match(err, 'duration must be uint')

    -- test that throws an error if sleep return non-uint value
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = function()
            return math.huge
        end,
        sigwait = NOOP,
    })
    err = assert.throws(gpoll.sleep, 1)
    assert.match(err, 'sleep returned non-uint value')

    -- test that throws an error if sleep return nil without an error
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = function()
            return nil
        end,
        sigwait = NOOP,
    })
    err = assert.throws(gpoll.sleep, 1)
    assert.match(err, 'sleep returned nil without an error')
end

local function test_sigwait()
    -- test that wait signal
    local pid = getpid()
    local p = assert(fork())
    if p:is_child() then
        msleep(200)
        signal.kill(signal.SIGINT, pid)
        os.exit(0)
    end
    local signo, err, timeout = gpoll.sigwait(500, signal.SIGINT)
    assert.equal(signo, signal.SIGINT)
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that timeout
    signo, err, timeout = signal.wait(100, signal.SIGINT)
    assert.is_nil(signo)
    assert.is_nil(err)
    assert.is_true(timeout)

    -- test that set custome sigwait function
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = NOOP,
        sigwait = function()
            return 123
        end,
    })
    signo, err, timeout = gpoll.sigwait(100, signal.SIGINT)
    assert.equal(signo, 123)
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that return error
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = NOOP,
        sigwait = function()
            return nil, 'sigwait error'
        end,
    })
    signo, err, timeout = gpoll.sigwait(100)
    assert.is_nil(signo)
    assert.match(err, 'sigwait error')
    assert.is_nil(timeout)

    -- test that return timeout
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = NOOP,
        sigwait = function()
            return nil, nil, true
        end,
    })
    signo, err, timeout = gpoll.sigwait(100)
    assert.is_nil(signo)
    assert.is_nil(err)
    assert.is_true(timeout)

    -- test that throws an error if duration is invalid
    err = assert.throws(gpoll.sigwait, math.huge)
    assert.match(err, 'duration must be uint')

    -- test that throws an error if sigwait return non-int value
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = NOOP,
        sigwait = function()
            return math.huge
        end,
    })
    err = assert.throws(gpoll.sigwait, 1)
    assert.match(err, 'sigwait returned non-int value')

    -- test that throws an error if sigwait return nil without an error
    gpoll.set_poller({
        pollable = NOOP,
        later = NOOP,
        wait_readable = NOOP,
        wait_writable = NOOP,
        unwait = NOOP,
        unwait_readable = NOOP,
        unwait_writable = NOOP,
        read_lock = NOOP,
        write_lock = NOOP,
        read_unlock = NOOP,
        write_unlock = NOOP,
        sleep = NOOP,
        sigwait = function()
            return nil
        end,
    })
    err = assert.throws(gpoll.sigwait, 1)
    assert.match(err, 'sigwait returned nil with neither error nor timeout')
end

for k, f in pairs({
    test_default = test_default,
    test_set_poller = test_set_poller,
    test_wait = test_wait,
    test_unwait = test_unwait,
    test_lock = test_lock,
    test_unlock = test_unlock,
    test_sleep = test_sleep,
    test_sigwait = test_sigwait,
}) do
    gpoll.set_poller()
    local ok, err = xpcall(f, debug.traceback)
    if ok then
        print(k .. ': ok')
    else
        print(k .. ': fail')
        print(err)
    end
end

