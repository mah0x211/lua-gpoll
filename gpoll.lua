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
-- assign to local
local type = type
local rawequal = rawequal
local floor = math.floor
local format = string.format
local toerror = require('error').toerror
local new_errno = require('errno').new

local INF_POS = math.huge
local INF_NEG = -INF_POS

--- is_int returns true if x is integer
--- @param x number
--- @return boolean
local function is_int(x)
    return type(x) == 'number' and (x < INF_POS and x > INF_NEG) and
               rawequal(floor(x), x)
end

--- is_uint returns true if x is unsigned integer
--- @param x number
--- @return boolean
local function is_uint(x)
    return type(x) == 'number' and (x < INF_POS and x >= 0) and
               rawequal(floor(x), x)
end

--- is_unsigned returns true if x is unsigned number
--- @param x number
--- @return boolean
local function is_unsigned(x)
    return type(x) == 'number' and (x < INF_POS and x >= 0)
end

--- @class Poller
local DEFAULT_POLLER = {}

--- wait_readable
--- @param fd integer
--- @param sec number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.wait_readable(fd, sec)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- wait_writable
--- @param fd integer
--- @param sec number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.wait_writable(fd, sec)
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
--- @param sec number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.read_lock(fd, sec)
    return false, new_errno('ENOTSUP', 'not pollable')
end

--- write_lock
--- @param fd integer
--- @param sec number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.write_lock(fd, sec)
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
--- @param sec number
--- @return number rem
--- @return any err
function DEFAULT_POLLER.sleep(sec)
    return nil, new_errno('ENOTSUP', 'not pollable')
end

--- sigwait
--- @param sec number
--- @param ... integer signal-number
--- @return integer? signo
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.sigwait(sec, ...)
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

local Poller = DEFAULT_POLLER

--- set_poller replace the internal polling functions
--- @param poller? Poller
local function set_poller(poller)
    local newpoller
    if poller == nil then
        newpoller = DEFAULT_POLLER
    else
        newpoller = {}
        for fname, default_func in pairs(DEFAULT_POLLER) do
            local func = poller[fname]
            if func == nil then
                func = default_func
            elseif type(func) ~= 'function' then
                error(format('%q is not function: %q', fname, type(func)), 2)
            end
            newpoller[fname] = func
        end
    end

    -- set new poller
    Poller = newpoller
end

--- pollable
--- @return boolean ok
local function pollable()
    return Poller.pollable()
end

--- later
--- @return boolean ok
local function later()
    return Poller.later()
end

--- do_wait
--- @param fname string
--- @param fd integer
--- @param sec? number
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function do_wait(fname, fd, sec, hookfn, ctx)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    elseif sec ~= nil and not is_unsigned(sec) then
        error('sec must be unsigned number', 2)
    end

    -- call hook function before wait
    if hookfn then
        if type(hookfn) ~= 'function' then
            error('hookfn must be function', 2)
        end

        local ok, err, timeout = hookfn(ctx, sec)
        if not ok then
            if err then
                return false, toerror(err), timeout
            elseif timeout then
                return false, nil, true
            end
            error('hookfn returned false|nil with neither error nor timeout')
        end
    end

    local ok, err, timeout = Poller[fname](fd, sec)
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

    local ok, err = Poller[fname](fd)
    if ok then
        return true
    elseif err then
        return false, toerror(err)
    end
    return false
end

--- do_lock waits until a lock is acquired
--- @param fname string
--- @param fd integer
--- @param sec? number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function do_lock(fname, fd, sec)
    if not is_uint(fd) then
        error('fd must be uint', 2)
    elseif sec ~= nil and not is_unsigned(sec) then
        error('sec must be unsigned number', 2)
    end

    local ok, err, timeout = Poller[fname](fd, sec)
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

    local ok, err = Poller[fname](fd)
    if ok then
        return true
    elseif err == nil then
        error(fname .. ' returned false|nil without an error')
    end
    return false, toerror(err)
end

--- wait_readable
--- @param fd integer
--- @param sec? integer
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function wait_readable(fd, sec, hookfn, ctx)
    return do_wait('wait_readable', fd, sec, hookfn, ctx)
end

--- wait_writable
--- @param fd integer
--- @param sec? number
--- @param hookfn? function
--- @param ctx? any
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function wait_writable(fd, sec, hookfn, ctx)
    return do_wait('wait_writable', fd, sec, hookfn, ctx)
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
--- @param sec? number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function read_lock(fd, sec)
    return do_lock('read_lock', fd, sec)
end

--- write_lock waits until a write lock is acquired
--- @param fd integer
--- @param sec? number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
local function write_lock(fd, sec)
    return do_lock('write_lock', fd, sec)
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
--- @param sec number
--- @return number rem
--- @return any err
local function sleep(sec)
    if not is_unsigned(sec) then
        error('sec must be unsigned number', 2)
    end

    local rem, err = Poller.sleep(sec)
    if rem then
        if not is_unsigned(rem) then
            error('sleep returned non-unsigned value')
        end
        return rem
    elseif err then
        return nil, toerror(err)
    end
    error('sleep returned nil without an error')
end

--- sigwait
--- @param sec number
--- @param ... integer signal-number
--- @return integer signo
--- @return any err
--- @return boolean? timeout
local function sigwait(sec, ...)
    if not is_unsigned(sec) then
        error('sec must be unsigned number', 2)
    end

    local signo, err, timeout = Poller.sigwait(sec, ...)
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
}
