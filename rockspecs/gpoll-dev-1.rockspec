package = "gpoll"
version = "dev-1"
source = {
    url = "git+https://github.com/mah0x211/lua-gpoll.git",
}
description = {
    summary = "A generic interface module for synchronous I/O multiplexing processing.",
    homepage = "https://github.com/mah0x211/lua-gpoll",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "errno >= 0.3.0",
    "io-wait >= 0.4.0",
    "time-sleep >= 0.2.1",
}
build = {
    type = "builtin",
    modules = {
        gpoll = "gpoll.lua",
    },
}
