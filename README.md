# lua-gpoll

[![test](https://github.com/mah0x211/lua-gpoll/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-gpoll/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-gpoll/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-gpoll)

A generic interface module for synchronous I/O multiplexing processing.


## Installation

```
luarocks install gpoll
```

***

# Polling API's

this module provides only a generic API for synchronous I/O multiplexing processing. therefore, you must be set the poller for the actual processing.


## set_poller( [poller] )

set the `poller` to the polling driver. the `poller` object must have the Polling API Interface except `set_poller` function. if `poller` is `nil`, the default poller will be set.


## ok = pollable()

determine the availability of the polling mechanism.

**Returns**

- `ok:boolean`: `true` on the polling mechanism is available.


## ok, err, timeout = wait_readable( fd [, timeout [, hook [, ctx]]] )

wait until the file descriptor is readable.

**Parameters**

- `fd:integer`: a file descriptor.
- `timeout:integer`: specify a timeout `milliseconds` as unsigned integer.
- `hook:function`: a hook function that calls before polling a status of file descriptor.
- `ctx:any: any value for hook function.

**Returns**

- `ok:boolean`: `true` on readable. (default: `false`)
- `err:error`: error object. (default: `errno.ENOTSUP`)
- `timeout:boolean`: `true` if operation has timed out.


## ok, err, timeout = wait_writable( fd [, timeout [, hook [, ctx]]] )

wait until the file descriptor is writable.

**Parameters**

- `fd:integer`: a file descriptor.
- `timeout:integer`: specify a timeout `milliseconds` as unsigned integer.
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


## ok, err, timeout = read_lock( fd [, timeout] )

waits until a read lock is acquired.

**Parameters**

- `fd:integer`: a file descriptor.
- `timeout:integer`: a timeout `milliseconds` as unsigned integer.

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


## ok, err, timeout = write_lock( fd [, timeout] )

waits until a write lock is acquired.

**Parameters**

- `fd:integer`: a file descriptor.
- `timeout:integer`: a timeout `milliseconds` as unsigned integer.

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

