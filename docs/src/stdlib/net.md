# Net

Minimal blocking TCP for backend servers, over the runtime's socket helpers
(Windows Winsock / POSIX). Connections and listeners are
opaque `Handle[T]` values; user code only ever passes them back to the `Net`
methods.

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
error share the channel). ## TLS / HTTPS

A TLS connection is still a socket underneath, so `recv`, `send`,
`close_conn`, `poll` and `peer_name` route through the session unchanged:
every helper written against plain TCP (including `http.aegis`) works over TLS
without modification.

```aegis
let net = Net {}
if net.init() != 0 { /* ... */ }
if !net.tls_available() {
    println("TLS unavailable: " + net.tls_last_error())
}
let l = net.listen_tls("127.0.0.1", 0, "server.pem", "server-key.pem")
let port = net.port(l)
let conn = net.connect_tls("127.0.0.1", port, "localhost", "ca.pem")
println("negotiated: " + net.tls_version(conn))
```

| Method | Returns | Notes |
| --- | --- | --- |
| `tls_available()` | `Bool` | `true` when a backend is usable (SChannel on Windows; OpenSSL 1.1/3.x on POSIX) |
| `tls_last_error()` | `Str` | last TLS error message, empty when nothing failed |
| `tls_version(conn)` | `Str` | `"TLSv1.2"` etc. for a live connection |
| `connect_tls(host, port, server_name, ca_path)` | `Handle[TcpConn]` | verified client; `""` `ca_path` uses the system trust store; `null` on failure |
| `connect_tls_insecure(host, port, server_name)` | `Handle[TcpConn]` | no certificate or hostname verification (tests only) |
| `listen_tls(host, port, cert_path, key_path)` | `Handle[TcpListener]` | TLS listener; accepted connections are handshaken before `accept` returns |

Notes:

- `server_name` drives SNI and hostname verification, so it may differ from
  the dial address (`connect_tls("127.0.0.1", port, "localhost", ca)`).
- On POSIX the backend is `libssl`/`libcrypto` 1.1 or 3.x, loaded with
  `dlopen` on first use: a plain-TCP program never gains a link-time `libssl`
  dependency. TLS 1.2 is the floor (`SSL_CTX_ctrl(..., 123, 0x0303)`).
- On Windows the backend is SChannel + Crypt32; the server certificate must
  be a PKCS#12 bundle (`.pfx`) and `key_path` is ignored.
- `ca_path == ""` means system roots. A separate `connect_tls_insecure` exists
  for tests and local pinning; do not use it in production code.
- A wrong root or hostname mismatch makes `connect_tls` return `null` and
  stores the reason in `tls_last_error()`.
- TLS renegotiation initiated by the peer is attempted via SChannel's
  ApplyControlToken/InitializeSecurityContext handshake; on failure the read
  returns an error and 	ls_last_error() reports the reason.

## UDP

Connectionless datagrams use a separate `Handle[UdpSocket]`:

```aegis
let net = Net {}
if net.init() != 0 { /* ... */ }
let s = net.udp_socket()
net.udp_bind(s, "127.0.0.1", 0)
net.udp_sendto(s, "ping", "127.0.0.1", 9000)
let pkt = net.udp_recvfrom(s, 1024)   // UdpPacket { data, host, port }
net.udp_close(s)
```

| Method | Returns | Notes |
| --- | --- | --- |
| `udp_socket()` | `Handle[UdpSocket]` | create a datagram socket |
| `udp_bind(sock, host, port)` | `Int` | bind to a local address/port; `0` on success |
| `udp_sendto(sock, data, host, port)` | `Int` | bytes sent; `-1` on error |
| `udp_recvfrom(sock, max)` | `UdpPacket` | datagram up to `max` bytes plus sender address |
| `udp_set_nonblocking(sock, mode)` | `Int` | toggle non-blocking mode |
| `udp_set_timeout(sock, recv_ms, send_ms)` | `Int` | set receive/send timeouts in milliseconds |
| `udp_poll(sock, events, timeout_ms)` | `Int` | poll for readability/writability |
| `udp_close(sock)` | | release the socket handle |

`UdpPacket` has fields `data: Str`, `host: Str`, `port: Int`. Polling uses the
same event bitmask as TCP (`1` = readable, `2` = writable).
