# TOML

`Toml` reads and writes a deliberately small TOML subset. It supports scalar
key/value pairs, section headers, quoted strings, integers, and Boolean values.
Parsing returns a flat `Map[Str, Str]`; `[server.http]` followed by `port = 8080`
is stored under `server.http.port`.

```aegis
let source = "[server]\nname = \"api\"\nport = 8080\nenabled = true\n"
let t = Toml {}
let values = t.parse(source)
println(t.get(values, "server.name"))
println(str(t.get_int(values, "server.port")))
println(str(t.get_bool(values, "server.enabled")))

let output = t.stringify(values)
```

| Method | Returns | Notes |
| --- | --- | --- |
| `parse(text)` | `Map[Str, Str]` | Parses supported keys and sections; unsupported lines are skipped. |
| `stringify(values)` | `Str` | Writes every map entry as a quoted string value. |
| `get(values, key)` | `Str` | Returns `""` when absent. |
| `get_int(values, key)` | `Int` | Parses the value; returns `0` on failure or absence. |
| `get_bool(values, key)` | `Bool` | Returns `true` only when the value is exactly `"true"`. |

This is not a complete TOML implementation: arrays, inline tables, dates,
multiline strings, and full TOML escaping are outside the module's subset.
