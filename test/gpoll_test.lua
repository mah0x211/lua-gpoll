require('luacov')
local assert = require('assert')
local errno = require('errno')
local signal = require('signal')
local gpoll = require('gpoll')
local pipe = require('os.pipe')
local fork = require('fork')
local gettime = require('time.clock').gettime
local FDR, FDW
do
    local err
    FDR, FDW, err = pipe(true)
    assert(FDR, err)
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
    -- test that wait writable
    local fd, hup
    fd, err, timeout, hup = gpoll.wait_writable(FDW:fd())
    assert.equal(fd, FDW:fd())
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.is_nil(hup)

    -- test that wait readable
    FDW:write('x')
    fd, err, timeout, hup = gpoll.wait_readable(FDR:fd())
    assert.equal(fd, FDR:fd())
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.is_nil(hup)
    FDR:read()

    -- test that readable
    for _, fn in ipairs({
        gpoll.unwait,
        gpoll.unwait_readable,
        gpoll.read_lock,
        gpoll.read_unlock,
        gpoll.unwait_writable,
        gpoll.write_lock,
        gpoll.write_unlock,
    }) do
        ok, err, timeout = fn(FDR:fd())
        assert.is_false(ok)
        assert.equal(err.type, errno.ENOTSUP)
        assert.is_nil(timeout)
    end

    -- wait signal
    local signo
    signo, err, timeout = gpoll.sigwait(0.01, 'SIGINT')
    assert.is_nil(signo)
    assert.is_nil(err)
    assert.is_true(timeout)

    -- wait sleep
    local rem
    rem, err = gpoll.sleep(0.1)
    assert.equal(rem, 0)
    assert.is_nil(err)
end

local function test_set_poller()
    -- test that set custom poller
    gpoll.set_poller({
        pollable = function()
            return true
        end,
    })
    assert.is_true(gpoll.pollable())

    -- test that poller can be reset to default with nil
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

local function test_set_poller_with_ctx()
    -- test that set custom poller with context
    gpoll.set_poller({
        pollable = function(ctx)
            assert.equal(ctx, 'hello')
            return true
        end,
    }, 'hello')
    assert.is_true(gpoll.pollable())
end

local function test_use()
    -- confirm that default poller is not pollable
    assert.is_false(gpoll.pollable())

    -- test that use poller
    gpoll.use('test/mypoller')
    assert.is_true(gpoll.pollable())

    -- test that throws an error if poller returns invalid value
    local err = assert.throws(gpoll.use, 'test/invalidpoller')
    assert.re_match(err, 'module .+ must return table')
end

local function test_wait_readable()
    gpoll.set_poller()

    -- test that return fd if fd is readable
    FDW:write('x')
    local fd, err, timeout, hup = gpoll.wait_readable(FDR:fd())
    assert.equal(fd, FDR:fd())
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.is_nil(hup)
    FDR:read()

    -- test that return fd and hup
    gpoll.set_poller({
        wait_readable = function()
            return 1, 'this error is ignored', true, true
        end,
    })
    fd, err, timeout, hup = gpoll.wait_readable(1)
    assert.equal(fd, 1)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.is_true(hup)

    -- test that return error
    gpoll.set_poller({
        wait_readable = function()
            return nil, 'wait error', true, true
        end,
    })
    fd, err, timeout, hup = gpoll.wait_readable(1)
    assert.is_nil(fd)
    assert.match(err, 'wait error')
    assert.is_true(timeout)
    assert.is_nil(hup)

    -- test that return timeout
    gpoll.set_poller({
        wait_readable = function()
            return nil, nil, true, true
        end,
    })
    fd, err, timeout, hup = gpoll.wait_readable(1)
    assert.is_nil(fd)
    assert.is_nil(err)
    assert.is_true(timeout)
    assert.is_nil(hup)

    -- test that allow no return value
    gpoll.set_poller({
        wait_readable = function()
        end,
    })
    fd, err, timeout, hup = gpoll.wait_readable()
    assert.is_nil(fd)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.is_nil(hup)

    -- test that throws an error if sec is invalid
    err = assert.throws(gpoll.wait_readable, 1, 'hello')
    assert.match(err, 'sec must be unsigned number')

    -- test that throws an error if wait_readable return non-uint fd
    gpoll.set_poller({
        wait_readable = function()
            return true
        end,
    })
    err = assert.throws(gpoll.wait_readable, 1)
    assert.match(err, 'wait_readable returned non-uint fd')
end

local function test_wait_writable()
    gpoll.set_poller()

    -- test that true if fd is wait writable
    local fd, err, timeout, hup = gpoll.wait_writable(FDW:fd())
    assert.equal(fd, FDW:fd())
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.is_nil(hup)

    -- test that return fd and hup
    gpoll.set_poller({
        wait_writable = function()
            return 1, 'this error is ignored', true, true
        end,
    })
    fd, err, timeout, hup = gpoll.wait_writable(1)
    assert.equal(fd, 1)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.is_true(hup)

    -- test that return error and timeout
    gpoll.set_poller({
        wait_writable = function()
            return nil, 'wait error', true, true
        end,
    })
    fd, err, timeout, hup = gpoll.wait_writable(1)
    assert.is_nil(fd)
    assert.match(err, 'wait error')
    assert.is_true(timeout)
    assert.is_nil(hup)

    -- test that return timeout
    gpoll.set_poller({
        wait_writable = function()
            return nil, nil, true, true
        end,
    })
    fd, err, timeout, hup = gpoll.wait_writable(1)
    assert.is_nil(fd)
    assert.is_nil(err)
    assert.is_true(timeout)
    assert.is_nil(hup)

    -- test that allow no return value
    gpoll.set_poller({
        wait_writable = function()
        end,
    })
    fd, err, timeout, hup = gpoll.wait_writable()
    assert.is_nil(fd)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.is_nil(hup)

    -- test that throws an error if sec is invalid
    err = assert.throws(gpoll.wait_writable, 1, 'hello')
    assert.match(err, 'sec must be unsigned number')

    -- test that throws an error if wait_writable return non-uint fd
    gpoll.set_poller({
        wait_writable = function()
            return true
        end,
    })
    err = assert.throws(gpoll.wait_writable, 1)
    assert.match(err, 'wait_writable returned non-uint fd')
end

local function test_unwait_readable()
    gpoll.set_poller()

    -- test that true if fd is unwait readable
    local ok, err = gpoll.unwait_readable(1)
    assert.is_false(ok)
    assert.equal(err.type, errno.ENOTSUP)

    -- test that return only true
    gpoll.set_poller({
        unwait_readable = function()
            return true, 'this error is ignored'
        end,
    })
    ok, err = gpoll.unwait_readable(1)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return error
    gpoll.set_poller({
        unwait_readable = function()
            return false, 'unwait error'
        end,
    })
    ok, err = gpoll.unwait_readable(1)
    assert.is_false(ok)
    assert.match(err, 'unwait error')

    -- test that return false
    gpoll.set_poller({
        unwait_readable = function()
            return false
        end,
    })
    ok, err = gpoll.unwait_readable(1)
    assert.is_false(ok)
    assert.is_nil(err)

    -- test that throws an error if fd is invalid
    err = assert.throws(gpoll.unwait_readable, 'hello')
    assert.match(err, 'fd must be uint')
end

local function test_unwait_writable()
    gpoll.set_poller()

    -- test that true if fd is unwait writable
    local ok, err = gpoll.unwait_writable(1)
    assert.is_false(ok)
    assert.equal(err.type, errno.ENOTSUP)

    -- test that return only true
    gpoll.set_poller({
        unwait_writable = function()
            return true, 'this error is ignored'
        end,
    })
    ok, err = gpoll.unwait_writable(1)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return error
    gpoll.set_poller({
        unwait_writable = function()
            return false, 'unwait error'
        end,
    })
    ok, err = gpoll.unwait_writable(1)
    assert.is_false(ok)
    assert.match(err, 'unwait error')

    -- test that return false
    gpoll.set_poller({
        unwait_writable = function()
            return false
        end,
    })
    ok, err = gpoll.unwait_writable(1)
    assert.is_false(ok)
    assert.is_nil(err)

    -- test that throws an error if fd is invalid
    err = assert.throws(gpoll.unwait_writable, 'hello')
    assert.match(err, 'fd must be uint')
end

local function test_unwait()
    gpoll.set_poller()

    -- test that true if fd is unwait readable/writable
    local ok, err = gpoll.unwait(1)
    assert.is_false(ok)
    assert.equal(err.type, errno.ENOTSUP)

    -- test that return only true
    gpoll.set_poller({
        unwait = function()
            return true, 'this error is ignored'
        end,
    })
    ok, err = gpoll.unwait(1)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return error
    gpoll.set_poller({
        unwait = function()
            return false, 'unwait error'
        end,
    })
    ok, err = gpoll.unwait(1)
    assert.is_false(ok)
    assert.match(err, 'unwait error')

    -- test that return false
    gpoll.set_poller({
        unwait = function()
            return false
        end,
    })
    ok, err = gpoll.unwait(1)
    assert.is_false(ok)
    assert.is_nil(err)

    -- test that throws an error if fd is invalid
    err = assert.throws(gpoll.unwait, 'hello')
    assert.match(err, 'fd must be uint')
end

local function test_read_lock()
    gpoll.set_poller()

    -- test that true if fd is read_lock
    local ok, err, timeout = gpoll.read_lock(1)
    assert.is_false(ok)
    assert.equal(err.type, errno.ENOTSUP)
    assert.is_nil(timeout)

    -- test that return only true
    gpoll.set_poller({
        read_lock = function()
            return true, 'this error is ignored', true
        end,
    })
    ok, err, timeout = gpoll.read_lock(1)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that return error and timeout
    gpoll.set_poller({
        read_lock = function()
            return false, 'lock error', true
        end,
    })
    ok, err, timeout = gpoll.read_lock(1)
    assert.is_false(ok)
    assert.match(err, 'lock error')
    assert.is_true(timeout)

    -- test that return timeout
    gpoll.set_poller({
        read_lock = function()
            return false, nil, true
        end,
    })
    ok, err, timeout = gpoll.read_lock(1)
    assert.is_false(ok)
    assert.is_nil(err)
    assert.is_true(timeout)

    -- test that throws an error if fd is invalid
    err = assert.throws(gpoll.read_lock, 'hello')
    assert.match(err, 'fd must be uint')

    -- test that throws an error if sec is invalid
    err = assert.throws(gpoll.read_lock, 1, 'hello')
    assert.match(err, 'sec must be unsigned number')

    -- test that throws an error if read_lock return false with neither error nor timeout
    gpoll.set_poller({
        read_lock = function()
            return false
        end,
    })
    err = assert.throws(gpoll.read_lock, 1)
    assert.match(err, 'read_lock .+ neither error nor timeout', false)
end

local function test_write_lock()
    gpoll.set_poller()

    -- test that true if fd is write_lock
    local ok, err, timeout = gpoll.write_lock(1)
    assert.is_false(ok)
    assert.equal(err.type, errno.ENOTSUP)
    assert.is_nil(timeout)

    -- test that return only true
    gpoll.set_poller({
        write_lock = function()
            return true, 'this error is ignored', true
        end,
    })
    ok, err, timeout = gpoll.write_lock(1)
    assert.is_true(ok)
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that return error and timeout
    gpoll.set_poller({
        write_lock = function()
            return false, 'lock error', true
        end,
    })
    ok, err, timeout = gpoll.write_lock(1)
    assert.is_false(ok)
    assert.match(err, 'lock error')
    assert.is_true(timeout)

    -- test that return timeout
    gpoll.set_poller({
        write_lock = function()
            return false, nil, true
        end,
    })
    ok, err, timeout = gpoll.write_lock(1)
    assert.is_false(ok)
    assert.is_nil(err)
    assert.is_true(timeout)

    -- test that throws an error if fd is invalid
    err = assert.throws(gpoll.write_lock, 'hello')
    assert.match(err, 'fd must be uint')

    -- test that throws an error if sec is invalid
    err = assert.throws(gpoll.write_lock, 1, 'hello')
    assert.match(err, 'sec must be unsigned number')

    -- test that throws an error if write_lock return false with neither error nor timeout
    gpoll.set_poller({
        write_lock = function()
            return false
        end,
    })
    err = assert.throws(gpoll.write_lock, 1)
    assert.match(err, 'write_lock .+ neither error nor timeout', false)
end

local function test_read_unlock()
    gpoll.set_poller()
    -- test that true if fd is read_unlock
    local ok, err = gpoll.read_unlock(1)
    assert.is_false(ok)
    assert.equal(err.type, errno.ENOTSUP)

    -- test that return only true
    gpoll.set_poller({
        read_unlock = function()
            return true, 'this error is ignored'
        end,
    })
    ok, err = gpoll.read_unlock(1)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return error
    gpoll.set_poller({
        read_unlock = function()
            return false, 'unlock error'
        end,
    })
    ok, err = gpoll.read_unlock(1)
    assert.is_false(ok)
    assert.match(err, 'unlock error')

    -- test that throws an error if fd is invalid
    err = assert.throws(gpoll.read_unlock, 'hello')
    assert.match(err, 'fd must be uint')

    -- test that throws an error if read_unlock return false without error
    gpoll.set_poller({
        read_unlock = function()
            return false
        end,
    })
    err = assert.throws(gpoll.read_unlock, 1)
    assert.match(err, 'read_unlock .+ without an error', false)
end

local function test_write_unlock()
    gpoll.set_poller()

    -- test that true if fd is write_unlock
    local ok, err = gpoll.write_unlock(1)
    assert.is_false(ok)
    assert.equal(err.type, errno.ENOTSUP)

    -- test that return only true
    gpoll.set_poller({
        write_unlock = function()
            return true, 'this error is ignored'
        end,
    })
    ok, err = gpoll.write_unlock(1)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return error
    gpoll.set_poller({
        write_unlock = function()
            return false, 'unlock error'
        end,
    })
    ok, err = gpoll.write_unlock(1)
    assert.is_false(ok)
    assert.match(err, 'unlock error')

    -- test that throws an error if fd is invalid
    err = assert.throws(gpoll.write_unlock, 'hello')
    assert.match(err, 'fd must be uint')

    -- test that throws an error if write_lock return false without error
    gpoll.set_poller({
        write_unlock = function()
            return false
        end,
    })
    err = assert.throws(gpoll.write_unlock, 1)
    assert.match(err, 'write_unlock .+ without an error', false)
end

local function test_sleep()
    -- test that sleep for 1.5 sec
    local t = gettime()
    local rem, err = gpoll.sleep(1.5)
    t = gettime() - t
    assert.equal(rem, 0)
    assert.is_nil(err)
    assert.greater_or_equal(t, 1.5)
    assert.less(t, 1.6)

    -- test that set custome sleep function
    gpoll.set_poller({
        sleep = function()
            return 2
        end,
    })
    rem, err = gpoll.sleep(1)
    assert.equal(rem, 2)
    assert.is_nil(err)

    -- test that return error
    gpoll.set_poller({
        sleep = function()
            return nil, 'sleep error'
        end,
    })
    rem, err = gpoll.sleep(1)
    assert.is_nil(rem)
    assert.match(err, 'sleep error')

    -- test that throws an error if sec is invalid
    err = assert.throws(gpoll.sleep, math.huge)
    assert.match(err, 'sec must be unsigned number')

    -- test that throws an error if sleep return non-unsigned value
    gpoll.set_poller({
        sleep = function()
            return math.huge
        end,
    })
    err = assert.throws(gpoll.sleep, 1)
    assert.match(err, 'sleep returned non-unsigned value')

    -- test that throws an error if sleep return nil without an error
    gpoll.set_poller({
        sleep = function()
            return nil
        end,
    })
    err = assert.throws(gpoll.sleep, 1)
    assert.match(err, 'sleep returned nil without an error')
end

local function test_sigwait()
    -- test that wait SIGINT signal
    local p = assert(fork())
    if p:is_child() then
        gpoll.sleep(1)
        signal.kill(signal.SIGINT, p:ppid())
        os.exit()
        return
    end
    local signo, err, timeout = gpoll.sigwait(1.5, 'SIGINT')
    assert.equal(signo, 'SIGINT')
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that return only signo
    gpoll.set_poller({
        sigwait = function()
            return 123, 'this error is ignored', true
        end,
    })
    signo, err, timeout = gpoll.sigwait(100, 123)
    assert.equal(signo, 123)
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that throws an error if sigwait returns an unrequested signal
    gpoll.set_poller({
        sigwait = function()
            return 456, 'this error is ignored', true
        end,
    })
    err = assert.throws(gpoll.sigwait, 100, 123)
    assert.match(err, 'unrequested signal number 456')

    -- test that return error and timeout
    gpoll.set_poller({
        sigwait = function()
            return nil, 'sigwait error', true
        end,
    })
    signo, err, timeout = gpoll.sigwait(100)
    assert.is_nil(signo)
    assert.match(err, 'sigwait error')
    assert.is_true(timeout)

    -- test that return timeout
    gpoll.set_poller({
        sigwait = function()
            return nil, nil, true
        end,
    })
    signo, err, timeout = gpoll.sigwait(100)
    assert.is_nil(signo)
    assert.is_nil(err)
    assert.is_true(timeout)

    -- test that return nothing
    gpoll.set_poller({
        sigwait = function()
        end,
    })
    signo, err, timeout = gpoll.sigwait(1)
    assert.is_nil(signo)
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that throws an error if sec is invalid
    err = assert.throws(gpoll.sigwait, math.huge)
    assert.match(err, 'sec must be unsigned number')

    -- test that throws an error if signal name is invalid
    err = assert.throws(gpoll.sigwait, 1, 'SIG_UNSUPPORTED')
    assert.match(err, 'unsupported signal')

    -- test that throws an error if signal number is invalid
    err = assert.throws(gpoll.sigwait, 1, -1)
    assert.match(err, 'signal number must be uint')

    -- test that throws an error if sigwait return non-int value
    gpoll.set_poller({
        sigwait = function()
            return math.huge
        end,
    })
    err = assert.throws(gpoll.sigwait, 1)
    assert.match(err, 'sigwait returned non-int value')
end

print('run tests')
for k, f in pairs({
    test_default = test_default,
    test_set_poller = test_set_poller,
    test_set_poller_with_ctx = test_set_poller_with_ctx,
    test_use = test_use,
    test_wait_readable = test_wait_readable,
    test_wait_writable = test_wait_writable,
    test_unwait_readable = test_unwait_readable,
    test_unwait_writable = test_unwait_writable,
    test_unwait = test_unwait,
    test_read_lock = test_read_lock,
    test_write_lock = test_write_lock,
    test_read_unlock = test_read_unlock,
    test_write_unlock = test_write_unlock,
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
print('done')
