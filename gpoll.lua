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
local pairs = pairs
local rawequal = rawequal
local floor = math.floor
local select = select
local unpack = unpack or table.unpack
local toerror = require('error').toerror
local fatalf = require('error').fatalf
local new_errno = require('errno').new
local io_wait_readable = require('io.wait').readable
local io_wait_writable = require('io.wait').writable
local time_sleep = require('time.sleep')
local signal_wait = require('signal').wait
-- constants
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
--- @param ... integer
--- @return integer fd
--- @return any err
--- @return boolean? timeout
--- @return boolean? hup
function DEFAULT_POLLER.wait_readable(fd, sec, ...)
    return io_wait_readable(fd, sec, ...)
end

--- wait_writable
--- @param fd integer
--- @param sec number
--- @param ... integer
--- @return integer fd
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.wait_writable(fd, sec, ...)
    return io_wait_writable(fd, sec, ...)
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
    return time_sleep(sec)
end

--- sigwait
--- @param sec number
--- @param ... integer signal-number
--- @return integer? signo
--- @return any err
--- @return boolean? timeout
function DEFAULT_POLLER.sigwait(sec, ...)
    return signal_wait(sec, ...)
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
--- @param ctx? any
local function set_poller(poller, ctx)
    if poller == nil then
        Poller = DEFAULT_POLLER
        return
    end

    local newpoller = {}
    for fname, default_func in pairs(DEFAULT_POLLER) do
        local func = poller[fname]
        if func == nil then
            newpoller[fname] = default_func
        elseif type(func) ~= 'function' then
            fatalf(2, '%q is not function: %q', fname, type(func))
        elseif ctx == nil then
            newpoller[fname] = func
        else
            -- wrap function to pass ctx as first argument
            newpoller[fname] = function(...)
                return func(ctx, ...)
            end
        end
    end
    -- set new poller
    Poller = newpoller
end

--- use_module
--- @param modname string
local function use_module(modname)
    local mod = require(modname)
    if type(mod) ~= 'table' then
        fatalf(2, 'module %q must return table', modname)
    end
    set_poller(mod)
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
--- @param fd integer?
--- @param sec? number
--- @param ... integer
--- @return integer? fd
--- @return any err
--- @return boolean? timeout
--- @return boolean? hup
local function do_wait(fname, fd, sec, ...)
    if sec ~= nil and not is_unsigned(sec) then
        error('sec must be unsigned number', 2)
    end

    local evfd, err, timeout, hup = Poller[fname](fd, sec, ...)
    if evfd then
        if not is_uint(evfd) then
            error(fname .. ' returned non-uint fd')
        end
        return evfd, nil, nil, hup and true
    elseif err then
        return nil, toerror(err), timeout
    elseif timeout then
        return nil, nil, true
    end
    -- if no fd arguments are given, do_wait returns nothing
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
--- @param fd integer?
--- @param sec? integer
--- @param ... integer
--- @return integer fd
--- @return any err
--- @return boolean? timeout
--- @return boolean? hup
local function wait_readable(fd, sec, ...)
    return do_wait('wait_readable', fd, sec, ...)
end

--- wait_writable
--- @param fd integer?
--- @param sec? number
--- @param ... integer
--- @return integer fd
--- @return any err
--- @return boolean? timeout
--- @return boolean? hup
local function wait_writable(fd, sec, ...)
    return do_wait('wait_writable', fd, sec, ...)
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

--- @type table<string, integer>
local SIGNAME2NO = {}
for k, v in pairs(require('signal')) do
    if string.find(k, '^SIG') then
        SIGNAME2NO[k] = v
    end
end

--- sigwait
--- @param sec number
--- @param ... integer|string signal-number or signal-name
--- @return integer|string? signo
--- @return any err
--- @return boolean? timeout
local function sigwait(sec, ...)
    if not is_unsigned(sec) then
        error('sec must be unsigned number', 2)
    end

    local args = {
        ...,
    }
    local narg = select('#', ...)
    local retsig = {}
    for i = 1, narg do
        local sig = args[i]
        if type(sig) == 'string' then
            local signo = SIGNAME2NO[sig]
            if not signo then
                fatalf(2, 'unsupported signal name: %q', sig)
            end
            args[i] = signo
            retsig[signo] = sig
        elseif not is_uint(sig) then
            fatalf(2, 'signal number must be uint: %q', tostring(sig))
        else
            retsig[sig] = sig
        end
    end

    local signo, err, timeout = Poller.sigwait(sec, unpack(args, 1, narg))
    if signo then
        if not is_int(signo) then
            error('sigwait returned non-int value')
        end

        local sig = retsig[signo]
        if not sig then
            fatalf(2, 'sigwait returned unrequested signal number %d', signo)
        end
        return sig
    elseif err then
        return nil, toerror(err), timeout
    elseif timeout then
        return nil, nil, true
    end
    -- if no signal arguments are given, sigwait returns nothing
end

return {
    use = use_module,
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
