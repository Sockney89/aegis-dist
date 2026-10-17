# JSON

`stdlib/json.aegis` is a self-contained RFC 8259 JSON implementation written
in Aegis on top of compiler builtins (no C). It features a recursive-descent
parser with precise error messages, a compact serializer, and typed accessors
that return `Option`/`Result` instead of aborting.

A parsed document is a `Json` enum value:

```aegis
enum Json {
    Null,
    Bool(Bool),
    Num(Float),
    Str(String),
    Arr(List[Json]),
    Obj(Map[String, Json]),
}
```

`Null`, `Bool`, `Num`, `Str` are scalars; `Arr`/`Obj` carry container payloads.
Because a container can hold enum values, a `List[Json]` or
`Map[String, Json]` can store *any* JSON value, including nested arrays and
objects.

## Parsing

`JsonParser` is stateless; construct one and call `parse`:

```aegis
let jp = JsonParser {}
match jp.parse(text) {
    ok(j)  => { /* use j */ }
    err(m) => { println(m) }
}
```

`parse` returns `Result[Json, Str]`. The parser:

- skips whitespace between tokens;
- decodes the literal escapes `\" \\ \/ \n \t \r` plus `\uXXXX` for those same
  code points (`\u0022 \u005c \u002f \u000a \u0009 \u000d`) and `\u0000`;
- rejects anything else: a `\uXXXX` for an unsupported code point, an unknown
  escape (`\b`, `\f` ...), a leading zero, a mangled number, a trailing
  non-whitespace character, or a structural mistake — each with a message that
  names the offending construct.

```aegis
let jp = JsonParser {}
let r = jp.parse("{\"a\":[1,2.5,null],\"b\":\"hi\\nthere\"}")
```

## Inspection

`type_of(j)` names the variant (`"null"`, `"bool"`, `"num"`, `"str"`, `"arr"`,
`"obj"`). The typed accessors return `Option` and yield `none` on a variant
mismatch instead of aborting:

| Method | Returns | Notes |
| --- | --- | --- |
| `is_null(j)` | `Bool` | true for `Json::Null` |
| `as_bool(j)` | `Option[Bool]` | |
| `as_float(j)` | `Option[Float]` | |
| `as_int(j)` | `Option[Int]` | whole `Num`s only (`f == f.floor()`) |
| `as_str(j)` | `Option[String]` | decoded string value |
| `as_arr(j)` | `Option[List[Json]]` | |
| `as_obj(j)` | `Option[Map[String, Json]]` | |
| `get(j, key)` | `Option[Json]` | `Obj` member by key (no abort on missing) |
| `at(j, i)` | `Option[Json]` | `Arr` element by index (bounds-checked) |

```aegis
match jp.as_int(item) {
    some(n) => { total = total + n }
    none    => { /* not a whole number */ }
}
let name = jp.get(person, "name")
```

## Serialization

`to_string(j)` produces compact JSON (`{"a":[1,2],"b":null}` — no whitespace).
`quote(s)` renders a `String` as a `"..."` literal with `\"`, `\\`, `\n`,
`\t`, `\r` escapes, so object keys and string values round-trip. `Num` values
are written with `str(f)`.

```aegis
let s = jp.to_string(doc)     // "{\"y\":true,\"z\":null,\"s\":\"hi\n\"}"
```

## Round-trip

The self-test suite exercises parse/stringify round-trips, error paths, and
container typed accessors. Because a `Map` iterates in hash order, only
*same-key-set* round-trips are asserted to be deterministic.

## Roadmap

The parser intentionally targets the RFC 8259 core. The roadmap calls for
indentation control in `to_string`, full `\uXXXX` code point decoding, and a
`parse_file` convenience over the IO stdlib. See [Roadmap](../roadmap.md).