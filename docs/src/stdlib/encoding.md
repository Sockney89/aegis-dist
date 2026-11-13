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
| `url_decode(s)` | `Str` | `+` becomes space; invalid `%XX` sequences are kept verbatim |
| `base64url_encode(s)` | `Str` | URL-safe base64 (no padding) |
| `base64url_decode(s)` | `Str` | URL-safe base64 decode |

```aegis
let e = Encoding {}
let encoded = e.base64_encode("hello")
println(e.base64_decode(encoded))
let url = e.base64url_encode("hello")
println(e.base64url_decode(url))
println(e.url_decode("a%20b+c")) // a b c
```

The decoders are permissive runtime helpers rather than validating parsers:
malformed Base64 or hex characters are treated as zero-valued digits and
incomplete groups may be ignored. `url_decode` preserves malformed `%XX`
sequences verbatim. Validate untrusted encoded input before relying on its
decoded content.
