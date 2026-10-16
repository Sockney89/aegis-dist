# Backend HTTP Server (net + http) Roadmap & Design

Backend-first: add minimal cross-platform TCP in C Runtime, wrap in
`stdlib/net.aegis`, build a tiny `stdlib/http.aegis` (HTTP/1.1) on top. Treat
Rust interop as cdylib + `extern "C"` (no deep language binding generator
required).

## 1) Runtime (C) — cross-platform TCP

Add to `compiler/runtime/runtime.c` (guarded by `#ifdef _WIN32` / `#else` POSIX):

- `int aegis_tcp_init(void)` — WSAStartup on Windows, once; return 0 on success.
- `void* aegis_tcp_listen(const char *host, int port)` — bind/listen, return listener handle or NULL.
- `void* aegis_tcp_accept(void *listener)` — blocking accept, return conn handle or NULL.
- `int64_t aegis_tcp_recv(void *conn, char *buf, int64_t len)` — bytes read, -1 on error, 0 on EOF.
- `int64_t aegis_tcp_send(void *conn, const char *buf, int64_t len)` — bytes sent, -1 on error.
- `void aegis_tcp_close_conn(void *conn)`
- `void aegis_tcp_close_listener(void *listener)`

Design: opaque `void*` handles; blocking first (deterministic for smoke
tests). No extra dependencies. Ephemeral port 0 supported by letting the OS
assign (listener can report via `getsockname` later if needed, but not required
for 1-request smoke).

### Hostname resolution

`host` may be a numeric IPv4 or a hostname. A shared `aegis_tcp_resolve` helper
tries `inet_pton` first (no resolver round trip for numeric addresses), then
falls back to `getaddrinfo(AF_INET, SOCK_STREAM)`. Both `listen` and `connect`
route through it, so `net.connect("api.example.com", 80)` works. IPv6 is not
handled yet (AF_INET only).

## 2) Stdlib (Aegis) — net + http

- `stdlib/net.aegis` — Listener, Conn, `listen(host, port) -> Option[Listener]`,
  `accept(l: Listener) -> Option[Conn]`, `recv(c: Conn, n: Int) -> Str`,
  `send(c: Conn, s: Str) -> Int`, `close_conn(c: Conn)`, `close_listener(l: Listener)`.
  Thin wrappers over `extern "C"` runtime fns (declared at top). Keep
  mutable/ownership simple (handles closed after close).

- `stdlib/http.aegis` — minimal HTTP/1.1 server: `Request { method: Str, path:
  Str, headers: Map[Str,Str], body: Str }`, `Response { status: Int, headers:
  Map[Str,Str], body: Str }`, `Server { routes: List[Route], ... }` or just
  closures; `route(method, path, handler)`;
  `serve(host, port, handler_or_server)` blocking loop (accept, read request
  line + headers, read body if Content-Length, dispatch, write response, close
  conn; handle 1 request in smoke mode if desired). Keep small and testable.

> **Status (http headers):** `Request`/`Response` now carry
> `headers: Map[Str, Str]`. `respond_json` sets a JSON content-type,
> `with_header` adds one header, `response_text` emits the custom lines then a
> default `text/plain` Content-Type only when unset, forcing Content-Length +
> Connection last; request headers parse into `Request.headers` (case
> preserved, last duplicate wins). Stored as a `Map` rather than the
> `List[(Str,Str)]` sketched above because pairs are loop-only views (L8b),
> not first-class values - so a `Map` (hash iteration order) is the v1 shape,
> and multi-value headers (e.g. two `Set-Cookie`) wait until pairs are
> first-class.

## 3) Interop (Rust libs)

Workflow: build Rust crate as cdylib with `#[no_mangle] extern "C"` API (C
types only). Link via existing modes (`--link-object`, `.a`/`.lib`, or
`--emit-dylib` consumer). No language changes; manual extern declarations in
Aegis + thin wrappers. This matches current FFI (I1-I6).

## 4) Tests/E2E

- Semantic/typecheck stdlib (no spin).
- `tests/e2e/http_smoke.aegis`: bind `127.0.0.1:0` (or fixed ephemeral), serve
  one request (GET / -> "hello"), client checks, server exits (deterministic,
  <1s). Windows/Unix portable.

## 5) Implementation order (incremental)

1. Runtime TCP + WSA/POSIX ifdefs. `cargo build` green.
2. `net.aegis` stdlib + compile smoke.
3. `http.aegis` minimal router/request/response.
4. `http_smoke` e2e (ephemeral, exits). `cargo test` + `e2e.ps1` green.
5. Docs (`stdlib/net.md`, `stdlib/http.md`), SUMMARY update, regen
   `llms.txt`/`llms-full.txt`.