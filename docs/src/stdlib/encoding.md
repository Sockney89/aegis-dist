# Encoding

`stdlib/encoding.aegis` provides base64, hex, and URL percent-encoding helpers.

```aegis
let e = Encoding {}
let b64 = e.base64_encode("hello")
let hex = e.hex_encode("hi")
let url = e.url_encode("a b")
```

| Method | Returns | Notes |
| --- | --- | --- |
| `base64_encode(s)` | `Str` | standard base64 |
| `base64_decode(s)` | `Str` | returns `""` on invalid input |
| `hex_encode(s)` | `Str` | lowercase hex |
| `hex_decode(s)` | `Str` | returns `""` on invalid input |
| `url_encode(s)` | `Str` | RFC 3986 unreserved set |
| `url_decode(s)` | `Str` | `+` becomes space |
| `base64url_encode(s)` | `Str` | URL-safe base64 (no padding) |
| `base64url_decode(s)` | `Str` | URL-safe base64 decode |