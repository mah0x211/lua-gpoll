# lua-gpoll

[![test](https://github.com/mah0x211/lua-gpoll/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-gpoll/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-gpoll/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-gpoll)

A generic interface module for synchronous I/O multiplexing processing.


## Installation

```
luarocks install gpoll
```

***

This module provides a generic interface for synchronous I/O multiplexing. Therefore, you must set the polling functions using either the `set_poller` or `use` function to perform actual processing.


## set_poller( [poller] [, ctx] )

Sets the polling functions. If the `poller` table is `nil` or does not contain the necessary polling functions, the default ones are used.

**Parameters**

- `poller:table`: a poller object.
- `ctx:any`: an optional context object (except `nil`) to be passed to the poller functions as the first argument when called.  
  **NOTE:** the context object `ctx` is not passed to the default poller functions.

**Example**

```lua
local gpoll = require('gpoll')
gpoll.set_poller({
    later = function()
        -- do something
        return false, 'error: not implemented'
    end,
})
```


## use( modname )

Loads the module specified by `modname` and sets its polling functions.

**Parameters**

- `modname:string`: a module name.

**Example**

```lua
local gpoll = require('gpoll')
gpoll.use('mypoller') -- loads the module 'mypoller' and sets the polling functions
```

The above example is equivalent to the following code:

```lua
local gpoll = require('gpoll')
local poller = require('mypoller')
gpoll.set_poller(poller)
```


# Polling API Interfaces

## ok = pollable()

Checks whether a polling mechanism is available

**Returns**

- `ok:boolean`: `true` if a polling mechanism is available; otherwise, `false`.

**Example**

```lua
local gpoll = require('gpoll')
local ok = gpoll.pollable()
if ok then
    print('polling mechanism is available')
else
    print('polling mechanism is not available')
end
```


## ok, err = later()

Suspends the current coroutine and reschedules it to the end of the current run queue. When the coroutine is resumed from the run queue, the function returns `true`.

This function is typically used to yield control and defer execution to other tasks in the queue, ensuring fair scheduling.


**Returns**

- `ok:boolean`: `true` when the coroutine is resumed from the run queue.
- `err:any`: an error message if the task could not be rescheduled.

**Example**

```lua
local gpoll = require('gpoll')
local ok, err = gpoll.later()
if not ok then
    print('error: ' .. err)
end
```


## fd, err, timeout, hup = wait_readable( [fd [, sec [, ...]]] )

Waits until one of the specified file descriptors becomes readable.

**NOTE:** 

By default, this function calls the `readable` function from the [lua-io-wait](https://github.com/mah0x211/lua-io-wait) module.

**Parameters**

- `fd:integer`: a file descriptor.
- `sec:number`: optional timeout in seconds, specified as an unsigned number.
- `...:integer`: additional file descriptors to wait for.

**Returns**

- `fd:integer`: a file descriptor that became readable.
- `err:any`: error object, or `nil` if no error occurred.
- `timeout:boolean`: `true` if operation timed out.
- `hup:boolean`: `true` if the device or socket has been disconnected.


## fd, err, timeout, hup = wait_writable( [fd [, sec [, ...]]] )

Waits until one of the specified file descriptors becomes writable.

**NOTE:** 

By default, this function calls the `writable` function from the [lua-io-wait](https://github.com/mah0x211/lua-io-wait) module.

**Parameters**

- `fd:integer`: a file descriptor.
- `sec:number`: optional timeout in seconds, specified as an unsigned number.
- `...:integer`: additional file descriptors to wait for.

**Returns**

- `fd:integer`: a file descriptor that became readable.
- `err:any`: error object, or `nil` if no error occurred.
- `timeout:boolean`: `true` if operation timed out.
- `hup:boolean`: `true` if the device or socket has been disconnected.


## ok, err = unwait_readable( fd )

Cancels a pending wait operation for the specified file descriptor to become readable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` if the operation was successful; otherwise, `false`.  
- `err:any`: error object. by default, `errno.ENOTSUP` is returned if the operation is not supported.


## ok, err = unwait_writable( fd )

Cancels a pending wait operation for the specified file descriptor to become writable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` if the operation was successful; otherwise, `false`.  
- `err:any`: error object. by default, `errno.ENOTSUP` is returned if the operation is not supported.


## ok, err = unwait( fd )

Cancels any pending wait operation for the specified file descriptor to become readable or writable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` if the operation was successful; otherwise, `false`.  
- `err:any`: error object. by default, `errno.ENOTSUP` is returned if the operation is not supported.


## ok, err, timeout = read_lock( fd [, sec] )

Waits until a read lock is successfully acquired on the specified file descriptor.


**Parameters**

- `fd:integer`: a file descriptor.
- `sec:number`: optional timeout in seconds, specified as an unsigned number.

**Returns**

- `ok:boolean`: `true` if the lock was successfully acquired; otherwise, `false`.
- `err:any`: an error object. by default, `errno.ENOTSUP` is returned if the operation is not supported.
- `timeout:boolean`: `true` if the operation timed out before acquiring the lock.


## ok, err = read_unlock( fd )

Releases a previously acquired read lock on the specified file descriptor.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` if the lock was successfully released; otherwise, `false`.  
- `err:any`: an error object. by default, `errno.ENOTSUP` is returned if the operation is not supported.


## ok, err, timeout = write_lock( fd [, sec] )

Waits until a write lock is successfully acquired on the specified file descriptor.

**Parameters**

- `fd:integer`: a file descriptor.
- `sec:number`: optional timeout in seconds, specified as an unsigned number.

**Returns**

- `ok:boolean`: `true` if the lock was successfully acquired; otherwise, `false`.
- `err:any`: an error object. by default, `errno.ENOTSUP` is returned if the operation is not supported.
- `timeout:boolean`: `true` if the operation timed out before acquiring the lock.


## ok, err = write_unlock( fd )

Releases a previously acquired write lock on the specified file descriptor.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` if the lock was successfully released; otherwise, `false`.  
- `err:any`: an error object. by default, `errno.ENOTSUP` is returned if the operation is not supported.


## rem, err = sleep( sec )

Waits until the specified number of seconds has elapsed.

**NOTE:** 

By default, this function calls the `sleep` function from the [lua-time-sleep](https://github.com/mah0x211/lua-time-sleep) module.


**Parameters**

- `sec:number`: the duration to wait, specified in seconds as an unsigned number.

**Returns**

- `rem:number`: the number of remaining seconds if interrupted; otherwise `0`. returns `nil` if an error occurs.
- `err:any`: an error object. by default, `errno.ENOTSUP` is returned if the operation is not supported.


## sig, err, timeout = sigwait( sec, ... )

Waits for an interrupt signal matching one of the specified signals, or until the timeout expires.

**NOTE:**

By default, this function calls the `wait` function from the [lua-signal](https://github.com/mah0x211/lua-signal) module.

**Parameters**

- `sec:number`: the maximum time to wait, specified in seconds as an unsigned number.
- `...:integer|string`: One or more signal numbers or signal names.
    - If a signal name is specified, it will be converted to its corresponding signal number. When the received signal matches a signal name, the name is returned instead of the number.

**Returns**

- `sig:integer|string`: the received signal number or signal name, or `nil` if an error occurred or the operation timed out.
- `err:any`: an error object.
- `timeout:boolean`: `true` if the operation timed out before a signal was received.

