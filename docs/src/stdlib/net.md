# Net

Minimal blocking TCP for backend servers, over the runtime's WinSock/POSIX helpers
(`aegis_tcp_*` in `compiler/runtime/runtime.c`). Connections and listeners are
opaque `Handle[T]` values created by externs; user code only ever passes them
back to the `Net` methods.

Aegis has no free functions, so TCP hangs off one instance:

```aegis
let net = Net {}
if net.init() != 0 {
    println("winsock init failed")
}
let l = net.listen("127.0.0.1", 8080)
if l == null { /* bind/listen failed */ }
let conn = net.accept(l)   // blocking accept
```

| Method | Returns | Notes |
| --- | --- | --- |
| `init()` | `Int` | WSACleanup-safe WSAStartup once; 0 on success. Call before any other method. |
| `listen(host, port)` | `Handle[TcpListener]` | bind + listen; `null` on failure; empty host binds `INADDR_ANY` |
| `port(listener)` | `Int` | the actual bound port (needed after port 0) |
| `accept(listener)` | `Handle[TcpConn]` | blocking; `null` when the listener died |
| `connect(host, port)` | `Handle[TcpConn]` | dial out; `null` on failure |
| `recv(conn, max)` | `Str` | up to `max` bytes; `""` means EOF or error |
| `send(conn, data)` | `Int` | bytes written; short count or `-1` means the peer went away |
| `close_conn(conn)` | | release a connection handle |
| `close_listener(listener)` | | release a listener handle |

## Hostnames and DNS

`host` is either a numeric IPv4 or a hostname. Resolution inside the runtime
tries `inet_pton` first (no resolver round trip for `127.0.0.1`) and falls back
to `getaddrinfo(AF_INET, SOCK_STREAM)`, so `net.connect("api.example.com", 80)`
works like `net.connect("127.0.0.1", 80)`. IPv6 is not handled yet; the
resolver asks for `AF_INET` only.

## Port 0

`listen(host, 0)` asks the OS for an ephemeral port; read it back with
`port(listener)` before blocking in `accept`. This is what makes a one-process
smoke test deterministic: the caller can print the real port for a client to
dial.

## Blocking and ownership

Everything is synchronous - one connection at a time, no threads. Handles are
opaque: they must not be stored in containers crossing the FFI boundary, and are
closed explicitly. `recv` returning `""` is the caller's stop signal (EOF and
error share the channel). The externs are declared at the top of
`stdlib/net.aegis`; the module compiles standalone with compiler builtins only.