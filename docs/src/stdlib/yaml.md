# YAML

`Yaml` parses a small configuration-oriented YAML subset into a flat
`Map[Str, Str]`. It accepts `key: value` entries, nested maps represented by
space indentation, quoted scalar values, and full-line comments. Nested keys
are joined with dots.

```aegis
let text = "server:\n  host: localhost\n  port: 8080\n"
let y = Yaml {}
let values = y.parse(text)
println(y.get(values, "server.host"))
println(y.get(values, "server.port"))
```

| Method | Returns | Notes |
| --- | --- | --- |
| `parse(text)` | `Map[Str, Str]` | Parses flat and indented map entries. |
| `get(values, key)` | `Str` | Returns `""` when absent. |

This is not a general YAML parser. Sequences, anchors, aliases, tags, block
scalars, and YAML type conversion are not provided. Values remain strings.
