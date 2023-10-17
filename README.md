# lua-gpoll

[![test](https://github.com/mah0x211/lua-gpoll/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-gpoll/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-gpoll/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-gpoll)

A generic interface module for synchronous I/O multiplexing processing.


## Installation

```
luarocks install gpoll
```

***

This module provides a generic interface for synchronous I/O multiplexing processing. therefore, you must be set polling fuctions with `set_poller` function for the actual processing.


## set_poller( [poller] )

set the polling functions. if the `poller` table is `nil` or not contains the polling functions, then the default polling functions are set.

**Parameters**

- `poller:table`: a poller object.

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

# Polling API Interfaces

## ok = pollable()

determine the availability of the polling mechanism.

**Returns**

- `ok:boolean`: `true` on the polling mechanism is available.


## ok, err = later()

execute the next line later.

**Returns**

- `ok:boolean`: `true` when a process comes back.
- `err:any`: error message.


## fd, err, timeout, hup = wait_readable( fd [, sec [, ...]] )

wait until the file descriptor is readable.

**NOTE:** 

this function calls the `readable` function of the [lua-io-wait](https://github.com/mah0x211/lua-io-wait) module by default.

**Parameters**

- `fd:integer`: a file descriptor.
- `sec:number`: specify a sec `seconds` as unsigned number.
- `...:integer`: additional file descriptors.

**Returns**

- `fd:integer`: a file descriptor on readable.
- `err:any`: error object.
- `timeout:boolean`: `true` if operation has timed out.
- `hup:boolean`: `true` if the device or socket has been disconnected.


## fd, err, timeout, hup = wait_writable( fd [, sec [, ...]] )

wait until the file descriptor is writable.

**NOTE:** 

this function calls the `writable` function of the [lua-io-wait](https://github.com/mah0x211/lua-io-wait) module by default.

**Parameters**

- `fd:integer`: a file descriptor.
- `sec:number`: specify a sec `seconds` as unsigned number.
- `...:integer`: additional file descriptors.

**Returns**

- `fd:integer`: a file descriptor on writable.
- `err:any`: error object.
- `timeout:boolean`: `true` if operation has timed out.
- `hup:boolean`: `true` if the device or socket has been disconnected.


## ok, err = unwait_readable( fd )

cancel waiting for file descriptor to be readable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:any`: error object. (default: `errno.ENOTSUP`)


## ok, err = unwait_writable( fd )

cancel waiting for file descriptor to be writable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:any`: error object. (default: `errno.ENOTSUP`)


## ok, err = unwait( fd )

cancels waiting for file descriptor to be readable/writable.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:any`: error object. (default: `errno.ENOTSUP`)


## ok, err, timeout = read_lock( fd [, sec] )

waits until a read lock is acquired.

**Parameters**

- `fd:integer`: a file descriptor.
- `sec:number`: a sec `seconds` as unsigned number.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:any`: error object. (default: `errno.ENOTSUP`)
- `timeout:boolean`: `true` if operation has timed out.


## ok, err = read_unlock( fd )

releases a read lock.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:any`: error object. (default: `errno.ENOTSUP`)


## ok, err, timeout = write_lock( fd [, sec] )

waits until a write lock is acquired.

**Parameters**

- `fd:integer`: a file descriptor.
- `sec:number`: a sec `seconds` as unsigned number.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:any`: error object. (default: `errno.ENOTSUP`)
- `timeout:boolean`: `true` if operation has timed out.


## ok, err = write_unlock( fd )

releases a write lock.

**Parameters**

- `fd:integer`: a file descriptor.

**Returns**

- `ok:boolean`: `true` on success. (default: `false`)
- `err:any`: error object. (default: `errno.ENOTSUP`)


## rem, err = sleep( sec )

waits until `sec` seconds have elapsed.

**NOTE:** 

this function calls the `sleep` function of the [lua-time-sleep](https://github.com/mah0x211/lua-time-sleep) module by default.

**Parameters**

- `sec:number`: specify a wait `seconds` as unsigned number.

**Returns**

- `rem:number`: remaining seconds, or `nil` if an error occurs.
- `err:any`: error object. (default: `errno.ENOTSUP`)


## signo, err, timeout = sigwait( sec, signo, ... )

waits for interrupt by the specified signals until the specified time.

**NOTE:** 

this function calls the `wait` function of the [lua-signal](https://github.com/mah0x211/lua-signal) module by default.

**Parameters**

- `sec:number`: specify a wait `seconds` as unsigned number.
- `signo:integer`: valid signal numbers.

**Returns**

- `signo:integer`: received signal number, or `nil` if an error occurs or timed out.
- `err:error`: error object.
- `timeout:boolean`: `true` if operation has timed out.

