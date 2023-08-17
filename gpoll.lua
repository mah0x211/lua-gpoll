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
local isa = require('isa')
local is_int = isa.int
local is_uint = isa.uint
local is_function = isa.Function

--- @class Poller
local DEFAULT_POLLER = {}

--- new_readable_event
--- @param fd integer
--- @return string evid
--- @return any err
function DEFAULT_POLLER.new_readable_event(fd)
    return nil, new_errno('ENOTSUP', 'not pollable')
end

--- new_writable_event
--- @param fd integer
--- @return string evid
--- @return any err
function DEFAULT_POLLER.new_writable_event(fd)
    return nil, new_errno('ENOTSUP', 'not pollable')
end

--- dispose_event
--- @param evid string
--- @return boolean ok
--- @return any err
function DEFAULT_POLLER.dispose_event(evid)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- wait_event
--- @param evid string
--- @param msec integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.wait_event(evid, msec)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- wait_readable
--- @param fd integer
--- @param msec integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.wait_readable(fd, msec)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- wait_writable
--- @param fd integer
--- @param msec integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.wait_writable(fd, msec)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- unwait
--- @param fd integer
--- @return boolean? ok
--- @return any err
function DEFAULT_POLLER.unwait(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- unwait_readable
--- @param fd integer
--- @return boolean ok
--- @return any err
function DEFAULT_POLLER.unwait_readable(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- unwait_writable
--- @param fd integer
--- @return boolean? ok
--- @return any err
function DEFAULT_POLLER.unwait_writable(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- read_lock
--- @param fd integer
--- @param msec integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.read_lock(fd, msec)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- write_lock
--- @param fd integer
--- @param msec integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.write_lock(fd, msec)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- read_unlock
--- @param fd integer
--- @return boolean ok
--- @return any err
function DEFAULT_POLLER.read_unlock(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- write_unlock
--- @param fd integer
--- @return boolean ok
--- @return any err
function DEFAULT_POLLER.write_unlock(fd)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- sleep
--- @param msec integer
--- @return integer rem
--- @return any err
function DEFAULT_POLLER.sleep(msec)
    return nil, new_errno('ENOTSUP', 'not pollable')
end

--- sigwait
--- @param msec integer
--- @param ... integer signal-number
--- @return integer? signo
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.sigwait(msec, ...)
    return nil, new_errno('ENOTSUP', 'not pollable')
end

--- later
--- @return boolean ok
--- @return any err
function DEFAULT_POLLER.later()
    return true
end

--- poll_pollable
--- @return boolean ok
function DEFAULT_POLLER.pollable()
    return false
end

local POLLABLEFN = DEFAULT_POLLER.pollable
local LATERFN = DEFAULT_POLLER.later
local NEW_READABLE_EVENTFN = DEFAULT_POLLER.new_readable_event
local NEW_WRITABLE_EVENTFN = DEFAULT_POLLER.new_writable_event
local WAIT_EVENTFN = DEFAULT_POLLER.wait_event
local DISPOSE_EVENTFN = DEFAULT_POLLER.dispose_event
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
local SIGWAITFN = DEFAULT_POLLER.sigwait

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
            'later',
            'new_readable_event',
            'new_writable_event',
            'wait_event',
            'dispose_event',
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
            'sigwait',
        }) do
            local f = poller[k]
            if type(f) ~= 'function' then
                error(format('%q is not function: %q', k, type(f)), 2)
            end
        end
    end

    --- replace poll functions
    POLLABLEFN = poller.pollable
    LATERFN = poller.later
    NEW_READABLE_EVENTFN = poller.new_readable_event
    NEW_WRITABLE_EVENTFN = poller.new_writable_event
    WAIT_EVENTFN = poller.wait_event
    DISPOSE_EVENTFN = poller.dispose_event
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
    SIGWAITFN = poller.sigwait
end

--- pollable
--- @return boolean ok
local function pollable()
    return POLLABLEFN()
end

--- later
--- @return boolean ok
local function later()
    return LATERFN()
end

--- do_wait
--- @param fname string
--- @param fd integer
--- @param msec? integer
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function do_wait(fname, fd, msec, hookfn, ctx)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    elseif msec ~= nil and not is_uint(msec) then
        error('msec must be uint', 2)
    end

    -- call hook function before wait
    if hookfn then
        if not is_function(hookfn) then
            error('hookfn must be function', 2)
        end

        local ok, err, timeout = hookfn(ctx, msec)
        if not ok then
            if err then
                return false, toerror(err), timeout
            elseif timeout then
                return false, nil, true
            end
            error('hookfn returned false|nil with neither error nor timeout')
        end
    end

    local ok, err, timeout = WAITFN[fname](fd, msec)
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
--- @return any err
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
--- @param msec? integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function do_lock(fname, fd, msec)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    elseif msec ~= nil and not is_uint(msec) then
        error('msec must be uint', 2)
    end

    local ok, err, timeout = LOCKFN[fname](fd, msec)
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
--- @return any err
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
--- @param msec? integer
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function wait_readable(fd, msec, hookfn, ctx)
    return do_wait('wait_readable', fd, msec, hookfn, ctx)
end

--- wait_writable
--- @param fd integer
--- @param msec? integer
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function wait_writable(fd, msec, hookfn, ctx)
    return do_wait('wait_writable', fd, msec, hookfn, ctx)
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
--- @param msec? integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function read_lock(fd, msec)
    return do_lock('read_lock', fd, msec)
end

--- write_lock waits until a write lock is acquired
--- @param fd integer
--- @param msec? integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function write_lock(fd, msec)
    return do_lock('write_lock', fd, msec)
end

--- read_unlock releases a read lock
--- @param fd integer
--- @return boolean ok
--- @return any err
local function read_unlock(fd)
    return do_unlock('read_unlock', fd)
end

--- write_unlock releases a write lock
--- @param fd integer
--- @return boolean ok
--- @return any err
local function write_unlock(fd)
    return do_unlock('write_unlock', fd)
end

--- sleep until timer time elapsed
--- @param msec number
--- @return number rem
--- @return any err
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

--- sigwait
--- @param msec integer
--- @param ... integer signal-number
--- @return integer signo
--- @return any err
--- @return boolean? timeout
local function sigwait(msec, ...)
    if not is_uint(msec) then
        error('msec must be uint', 2)
    end

    local signo, err, timeout = SIGWAITFN(msec, ...)
    if signo then
        if not is_int(signo) then
            error('sigwait returned non-int value')
        end
        return signo
    elseif err then
        return nil, toerror(err), timeout
    elseif timeout then
        return nil, nil, true
    end
    error('sigwait returned nil with neither error nor timeout')
end

--- new_readable_event
--- @param fd integer
--- @return any evid
--- @return any err
local function new_readable_event(fd)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    end

    local evid, err = NEW_READABLE_EVENTFN(fd)
    if evid ~= nil then
        return evid
    elseif err then
        return nil, toerror(err)
    end
    error('new_readable_event returned nil with no error')
end

--- new_writable_event
--- @param fd integer
--- @return any evid
--- @return any err
local function new_writable_event(fd)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    end

    local evid, err = NEW_WRITABLE_EVENTFN(fd)
    if evid ~= nil then
        return evid
    elseif err then
        return nil, toerror(err)
    end
    error('new_writable_event returned nil with no error')
end

--- dispose_event
--- @param evid any
--- @return boolean ok
--- @return any err
local function dispose_event(evid)
    if evid == nil then
        error('evid must not be nil', 2)
    end

    local ok, err = DISPOSE_EVENTFN(evid)
    if ok then
        return true
    elseif err then
        return false, toerror(err)
    end
    error('dispose_event returned nil with no error')
end

--- wait_event
--- @param evid any
--- @param msec? integer
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function wait_event(evid, msec, hookfn, ctx)
    if evid == nil then
        error('evid must not be nil', 2)
    elseif msec ~= nil and not is_uint(msec) then
        error('msec must be uint', 2)
    end

    -- call hook function before wait
    if hookfn ~= nil then
        if not is_function(hookfn) then
            error('hookfn must be function', 2)
        end

        local ok, err, timeout = hookfn(ctx, msec)
        if not ok then
            if err then
                return false, toerror(err), timeout
            elseif timeout then
                return false, nil, true
            end
            error('hookfn returned false|nil with neither error nor timeout')
        end
    end

    local ok, err, timeout = WAIT_EVENTFN(evid, msec)
    if ok then
        return true
    elseif err then
        return false, toerror(err), timeout
    elseif timeout then
        return false, nil, true
    end
    error('wait_event returned false|nil with neither error nor timeout')
end

return {
    set_poller = set_poller,
    pollable = pollable,
    later = later,
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
    sigwait = sigwait,
    new_readable_event = new_readable_event,
    new_writable_event = new_writable_event,
    dispose_event = dispose_event,
    wait_event = wait_event,
}
