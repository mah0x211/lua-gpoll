--
-- Copyright (C) 2022 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local toerror = require('error').toerror
local new_errno = require('errno').new
local io_wait = require('io.wait')
local io_wait_readable = io_wait.readable
local io_wait_writable = io_wait.writable
local msleep = require('nanosleep.msleep')
local isa = require('isa')
local is_uint = isa.uint
local is_function = isa.Function

--- @class Poller
local DEFAULT_POLLER = {}

--- wait_readable
--- @param fd integer
--- @param duration integer
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
function DEFAULT_POLLER.wait_readable(fd, duration)
    return io_wait_readable(fd, duration)
end

--- wait_writable
--- @param fd integer
--- @param duration integer
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
function DEFAULT_POLLER.wait_writable(fd, duration)
    return io_wait_writable(fd, duration)
end

--- unwait
--- @param fd
--- @return boolean? ok
--- @return error? err
function DEFAULT_POLLER.unwait(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- unwait_readable
--- @param fd integer
--- @return boolean ok
--- @return error? err
function DEFAULT_POLLER.unwait_readable(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- unwait_writable
--- @param fd integer
--- @return boolean? ok
--- @return error? err
function DEFAULT_POLLER.unwait_writable(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- read_lock
--- @param fd integer
--- @param duration integer
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
function DEFAULT_POLLER.read_lock(fd, duration)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- write_lock
--- @param fd integer
--- @param duration integer
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
function DEFAULT_POLLER.write_lock(fd, duration)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- read_unlock
--- @param fd integer
--- @return boolean ok
--- @return error? err
function DEFAULT_POLLER.read_unlock(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- write_unlock
--- @param fd integer
--- @return boolean ok
--- @return error? err
function DEFAULT_POLLER.write_unlock(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- sleep
--- @param msec integer
--- @return rem integer
--- @return error? err
function DEFAULT_POLLER.sleep(msec)
    return msleep(msec)
end

--- poll_pollable
--- @return boolean ok
function DEFAULT_POLLER.pollable()
    return false
end

local POLLABLEFN = DEFAULT_POLLER.pollable
local WAITFN = {
    wait_readable = DEFAULT_POLLER.wait_readable,
    wait_writable = DEFAULT_POLLER.wait_writable,
}
local UNWAITFN = {
    unwait = DEFAULT_POLLER.unwait,
    unwait_readable = DEFAULT_POLLER.unwait_readable,
    unwait_writable = DEFAULT_POLLER.unwait_writable,
}
local LOCKFN = {
    read_lock = DEFAULT_POLLER.read_lock,
    write_lock = DEFAULT_POLLER.write_lock,
}
local UNLOCKFN = {
    read_unlock = DEFAULT_POLLER.read_unlock,
    write_unlock = DEFAULT_POLLER.write_unlock,
}
local SLEEPFN = DEFAULT_POLLER.sleep

-- assign to local
local type = type
local format = string.format

--- set_poller replace the internal polling functions
--- @param poller? Poller
local function set_poller(poller)
    if poller == nil then
        poller = DEFAULT_POLLER
    else
        for _, k in ipairs({
            'pollable',
            'wait_readable',
            'unwait_readable',
            'wait_writable',
            'unwait_writable',
            'unwait',
            'read_lock',
            'read_unlock',
            'write_lock',
            'write_unlock',
            'sleep',
        }) do
            local f = poller[k]
            if type(f) ~= 'function' then
                error(format('%q is not function: %q', k, type(f)), 2)
            end
        end
    end

    --- replace poll functions
    POLLABLEFN = poller.pollable
    WAITFN = {
        wait_readable = poller.wait_readable,
        wait_writable = poller.wait_writable,
    }
    UNWAITFN = {
        unwait = poller.unwait,
        unwait_readable = poller.unwait_readable,
        unwait_writable = poller.unwait_writable,
    }
    LOCKFN = {
        read_lock = poller.read_lock,
        write_lock = poller.write_lock,
    }
    UNLOCKFN = {
        read_unlock = poller.read_unlock,
        write_unlock = poller.write_unlock,
    }
    SLEEPFN = poller.sleep
end

--- pollable
--- @return boolean ok
local function pollable()
    return POLLABLEFN()
end

--- do_wait
--- @param fname string
--- @param fd integer
--- @param duration? integer
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
local function do_wait(fname, fd, duration, hookfn, ctx)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    elseif duration ~= nil and not is_uint(duration) then
        error('duration must be uint', 2)
    end

    -- call hook function before wait
    if hookfn then
        if not is_function(hookfn) then
            error('hookfn must be function', 2)
        end

        local ok, err, timeout = hookfn(ctx, duration)
        if not ok then
            if err then
                return false, toerror(err), timeout
            elseif timeout then
                return false, nil, true
            end
            error('hookfn returned false|nil with neither error nor timeout')
        end
    end

    local ok, err, timeout = WAITFN[fname](fd, duration)
    if ok then
        return true
    elseif err then
        return false, toerror(err), timeout
    elseif timeout then
        return false, nil, true
    end
    error(fname .. ' returned false|nil with neither error nor timeout')
end

--- do_unwait
--- @param fname string
--- @param fd integer
--- @return boolean ok
--- @return error? err
local function do_unwait(fname, fd)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    end

    local ok, err = UNWAITFN[fname](fd)
    if ok then
        return true
    elseif err then
        return false, toerror(err)
    end
    error(fname .. ' returned false|nil without an error')
end

--- do_lock waits until a lock is acquired
--- @param fname string
--- @param fd integer
--- @param duration? integer
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
local function do_lock(fname, fd, duration)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    elseif duration ~= nil and not is_uint(duration) then
        error('duration must be uint', 2)
    end

    local ok, err, timeout = LOCKFN[fname](fd, duration)
    if ok then
        return true
    elseif err then
        return false, toerror(err), timeout
    elseif timeout then
        return false, nil, true
    end
    error(fname .. ' returned false|nil with neither error nor timeout')
end

--- do_unlock releases a lock
--- @param fname string
--- @param fd integer
--- @return boolean ok
--- @return error? err
local function do_unlock(fname, fd)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    end

    local ok, err = UNLOCKFN[fname](fd)
    if ok then
        return true
    elseif err == nil then
        error(fname .. ' returned false|nil without an error')
    end
    return false, toerror(err)
end

--- wait_readable
--- @param fd integer
--- @param duration? integer
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
local function wait_readable(fd, duration, hookfn, ctx)
    return do_wait('wait_readable', fd, duration, hookfn, ctx)
end

--- wait_writable
--- @param fd integer
--- @param duration? integer
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
local function wait_writable(fd, duration, hookfn, ctx)
    return do_wait('wait_writable', fd, duration, hookfn, ctx)
end

--- unwait
--- @param fd integer
local function unwait(fd)
    return do_unwait('unwait', fd)
end

--- unwait_readable
--- @param fd integer
local function unwait_readable(fd)
    return do_unwait('unwait_readable', fd)
end

--- unwait_writable
--- @param fd integer
local function unwait_writable(fd)
    return do_unwait('unwait_writable', fd)
end

--- read_lock waits until a read lock is acquired
--- @param fd integer
--- @param duration? integer
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
local function read_lock(fd, duration)
    return do_lock('read_lock', fd, duration)
end

--- write_lock waits until a write lock is acquired
--- @param fd integer
--- @param duration? integer
--- @return boolean ok
--- @return error? err
--- @return boolean? timeout
local function write_lock(fd, duration)
    return do_lock('write_lock', fd, duration)
end

--- read_unlock releases a read lock
--- @param fd integer
--- @return boolean ok
--- @return error? err
local function read_unlock(fd)
    return do_unlock('read_unlock', fd)
end

--- write_unlock releases a write lock
--- @param fd integer
--- @return boolean ok
--- @return error? err
local function write_unlock(fd)
    return do_unlock('write_unlock', fd)
end

--- sleep until timer time elapsed
--- @param msec number
--- @return rem number
--- @return error? err
local function sleep(msec)
    if not is_uint(msec) then
        error('msec must be uint', 2)
    end

    local rem, err = SLEEPFN(msec)
    if rem then
        if not is_uint(rem) then
            error('sleep returned non-uint value')
        end
        return rem
    elseif err then
        return nil, toerror(err)
    end
    error('sleep returned nil without an error')
end

return {
    set_poller = set_poller,
    pollable = pollable,
    wait_readable = wait_readable,
    wait_writable = wait_writable,
    unwait = unwait,
    unwait_readable = unwait_readable,
    unwait_writable = unwait_writable,
    read_lock = read_lock,
    write_lock = write_lock,
    read_unlock = read_unlock,
    write_unlock = write_unlock,
    sleep = sleep,
}
