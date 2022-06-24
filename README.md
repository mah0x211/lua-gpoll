# lua-gpoll

[![test](https://github.com/mah0x211/lua-gpoll/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-gpoll/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-gpoll/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-gpoll)

A generic interface module for synchronous I/O multiplexing processing.


## Installation

```
luarocks install gpoll
```

***

this module provides only a generic API interfaces for synchronous I/O multiplexing processing. therefore, you must be set the poller for the actual processing.


## set_poller( [poller] )

set the `poller` to the polling driver. the `poller` object must have the Polling API Interfaces described below, except `set_poller` function. if `poller` is `nil`, the default poller will be set.

```lua
local gpoll = require('gpoll')
gpoll.set_poller({
    -- pollable = ...,
    -- wait_readable = ...,
    -- unwait_readable = ...,
    -- wait_writable = ...,
    -- unwait_writable = ...,
    -- unwait = ...,
    -- read_lock = ...,
    -- read_unlock = ...,
    -- write_lock = ...,
    -- write_unlock = ...,
})
```


# Polling API Interfaces


## ok = pollable()

determine the availability of the polling mechanism.

**Returns**

- `ok:boolean`: `true` on the polling mechanism is available.


## ok, err, timeout = wait_readable( fd [, duration [, hook [, ctx]]] )

wait until the file descriptor is readable.

**Parameters**

- `fd:integer`: a file descriptor.
- `duration:integer`: specify a duration `milliseconds` as unsigned integer.
- `hook:function`: a hook function that calls before polling a status of file descriptor.
- `ctx:any: any value for hook function.

**Returns**

- `ok:boolean`: `true` on readable. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)
- `timeout:boolean`: `true` if operation has timed out.


## ok, err, timeout = wait_writable( fd [, duration [, hook [, ctx]]] )

wait until the file descriptor is writable.

**Parameters**

- `fd:integer`: a file descriptor.
- `duration:integer`: specify a duration `milliseconds` as unsigned integer.
- `hook:function`: a hook function that calls before polling a status of file descriptor.
- `ctx:any: any value for hook function.

**Returns**

- `ok:boolean`: `true` on writable. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)
- `timeout:boolean`: `true` if operation has timed out.


## ok, err = unwait_readable( fd )

cancel waiting for file descriptor to be readable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)


## ok, err = unwait_writable( fd )

cancel waiting for file descriptor to be writable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)


## ok, err = unwait( fd )

cancels waiting for file descriptor to be readable/writable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)


## ok, err, timeout = read_lock( fd [, duration] )

waits until a read lock is acquired.

**Parameters**

- `fd:integer`: a file descriptor.
- `duration:integer`: a duration `milliseconds` as unsigned integer.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)
- `timeout:boolean`: `true` if operation has timed out.


## ok, err = read_unlock( fd )

releases a read lock.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)


## ok, err, timeout = write_lock( fd [, duration] )

waits until a write lock is acquired.

**Parameters**

- `fd:integer`: a file descriptor.
- `duration:integer`: a duration `milliseconds` as unsigned integer.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)
- `timeout:boolean`: `true` if operation has timed out.


## ok, err = write_unlock( fd )

releases a write lock.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)

