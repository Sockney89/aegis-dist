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
| `serve_on(net, listener, handler)` | `Int` | answer exactly one connection on a pre-bound listener, then release it |
| `serve(port, handler)` | `Int` | listen on `127.0.0.1` and answer connections until the listener dies |

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
encoding or keep-alive, and every response sets `Connection: close`. A
malformed request is reported as a `Request` whose `method` is `""` (check with
`is_valid`) - v1 cannot carry a struct inside `Option[...]`, so the empty
sentinel is the error channel rather than `none`.

## Constraints

Single-threaded: one connection is handled to completion before the next
`accept`. `serve` binds `127.0.0.1` (use `net.listen` + `serve_on` for other
bind addresses). The stdlib is not auto-loaded: splice `http.aegis` (and
`net.aegis`) into the compilation ahead of your program.