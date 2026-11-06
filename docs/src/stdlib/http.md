# HTTP

A minimal HTTP/1.1 server built on `stdlib/net.aegis`. `serve` blocks in an
accept loop and dispatches each connection to a `fn(Request) -> Response`
handler, so routing is ordinary Aegis code (match on `req.path`).

```aegis
let http = Http {}
fn handler(self) -> fn(Request) -> Response {
    return |req: Request| -> Response {
        let h = Http {}
        if req.path == "/" {
            return h.respond_ok("webapp ok")
        }
        return h.respond_404()
    }
}
let rc = http.serve(8080, handler())
```

| Type | Fields |
| --- | --- |
| `Request` | `method: Str`, `path: Str`, `headers: Map[Str, Str]`, `body: Str` |
| `Response` | `status: Int`, `headers: Map[Str, Str]`, `body: Str` |

| Method | Returns | Notes |
| --- | --- | --- |
| `respond_ok(body)` | `Response` | status 200, empty headers |
| `respond_404()` | `Response` | status 404, `"not found"` |
| `respond_400()` | `Response` | status 400, `"bad request"` |
| `with_header(r, name, value)` | `Response` | copy `r` with one more header |
| `respond_json(body)` | `Response` | status 200 with `Content-Type: application/json; charset=utf-8` |
| `json_escape(s)` | `Str` | escape a string for safe inclusion in a JSON string literal |
| `serve_on(net, listener, handler)` | `Int` | answer exactly one connection on a pre-bound listener, then release it |
| `serve(port, handler)` | `Int` | listen on `127.0.0.1` and answer connections until the listener dies |
| `serve_on_tls(net, listener, handler)` | `Int` | TLS variant of `serve_on` (TLS is transparent to the handler) |
| `serve_tls(port, cert_path, key_path, handler)` | `Int` | TLS server; POSIX takes a PEM chain + PEM key, Windows a PKCS#12 (`.pfx`) bundle |

`serve_on` splits out the bind so the caller can pick an ephemeral port, read it
back with `net.port(l)`, and publish it before blocking in `accept` - the shape
The router is exercised for deterministic behavior.

## Response headers

`response_text` serializes the custom `headers` map first (hash-bucket order),
then emits `Content-Type: text/plain; charset=utf-8` only when no
`content-type` key is present (matched case-insensitively), and finally forces
`Content-Length` (computed from the body) and `Connection: close`. Header names
keep their case; lookups on `Request.headers` are case-sensitive, and a
duplicate request header collapses to the last value. Custom
`Content-Length`/`Connection` entries cannot be overridden.

## Request parsing

`parse_request` splits the raw bytes on the first blank line
(`"\r\n\r\n"`), parses the header lines into `Request.headers` (a
`Map[Str, Str]`), and sets `path` to include the query string (split on `?`
yourself). Reads stop at the header terminator or the 64 KiB cap
(`read_request`), which covers GET and POST-with-body; there is no chunked
encoding. Keep-alive is supported: `response_text_ex(r, true)` emits
`Connection: keep-alive` and `serve`/`serve_on` reuse the connection for
subsequent requests until the peer closes. A
malformed request is reported as a `Request` whose `method` is `""` (check with
`is_valid`) - v1 cannot carry a struct inside `Option[...]`, so the empty
sentinel is the error channel rather than `none`.

## TLS clients

`client_request_tls` (plus `client_get_tls` / `client_post_tls`) mirror the
plain-HTTP helpers but dial with `net.connect_tls`. The `server_name` argument
is put in SNI and checked against the peer certificate; `ca_path` is a PEM
bundle of trusted roots (`""` means the system trust store). A failed
handshake or verification returns a `Response` with status `0` and the reason
in `body`.

```aegis
let http = Http {}
let r = http.client_get_tls("127.0.0.1", port, "localhost", "ca.pem", "/hello")
```

## Stateful handlers, path patterns and serving notes

A handler is a closure, so state that must survive between requests lives in a
captured container rather than a scalar local:

```aegis
let mut counts: Map[Str, Int] = {}
let handler = |req: Request| -> Response {
    let c = counts.get_or(req.path, 0) + 1
    counts.insert(req.path, c)
    return Http {}.respond_ok(str(c))
}
```

Since 0.1.0, closures may capture named structs and enum constructors in
addition to scalars, strings, handles and containers, so a parsed `JsonParser`
or a `Json::Num`/`Json::Str` variant can be referenced inside a handler without
instantiating it on every request. Capturing `self` (the method receiver) is
still rejected.

Route patterns such as `"/contacts/{id}"` contain literal braces, but Aegis
interpolates `{...}` inside string literals, so escape them: `"/contacts/\{id\}"`.
`path_matches` and `match_path` (and `HttpRouter`) work on the escaped form.

`serve`/`serve_tls` handle one connection to completion before the next
`accept`. They suit a minimal API or a smoke test; production servers that
need concurrency should run behind a separate process or a future threaded
runtime.

## Client helpers

In addition to `client_request`/`client_get`/`client_post` and their `_tls`
variants, the module ships a URL parser and convenience wrappers:

| Method | Returns | Notes |
| --- | --- | --- |
| `parse_url(url)` | `Url` | parse `http://`/`https://` URLs; defaults port 80/443 and path `/` |
| `client_get_url(url)` | `Response` | GET against a full URL string |
| `client_post_url(url, body)` | `Response` | POST against a full URL string |

`Url` has fields `host: Str`, `port: Int`, `path: Str`, `tls: Bool`.

## WebSocket upgrade

`ws_is_upgrade`, `ws_accept` and `ws_upgrade_response` implement the HTTP
upgrade handshake; `ws_send`/`ws_recv` wrap the runtime's framed text helpers:

| Method | Returns | Notes |
| --- | --- | --- |
| `ws_is_upgrade(req)` | `Bool` | whether `req` is a WebSocket upgrade request |
| `ws_accept(req)` | `Str` | `Sec-WebSocket-Accept` value for the request key |
| `ws_upgrade_response(req)` | `Response` | 101 Switching Protocols response |
| `ws_send(conn, text)` | `Int` | send a text frame |
| `ws_recv(conn, max)` | `Str` | receive a text frame (up to `max` bytes) |
| `ws_ping(conn, text)` | `Int` | send a ping frame |
| `ws_pong(conn, text)` | `Int` | send a pong frame |
| `ws_close(conn, code)` | `Int` | send a close frame |

## Constraints

Single-threaded: one connection is handled to completion before the next
`accept`. `serve` binds `127.0.0.1` (use `net.listen` + `serve_on` for other
bind addresses). Since 0.1.0 the seed modules are auto-loaded by the compiler
prelude, so `Http` and `Net` are available without listing files; use
`--no-prelude` to disable or `--stdlib DIR` to override.

## Threaded serving (MT8)

`serve_threaded(port, handler)` accepts connections in the main thread and
handles each on a worker thread (via `thread_spawn`), so requests no longer
serialize behind a single `accept` loop. Each connection keeps its own
keep-alive loop. Mutable globals are rejected under `--threads`, so shared
state must use `SharedList`/`SharedMap` or actor state.


## New in 0.1.4

- Http.mime_type(path) - extension to MIME type.
- Http.static_file now sets Content-Type.
- Http.ws_send_binary(conn, data) - binary WebSocket frames.
