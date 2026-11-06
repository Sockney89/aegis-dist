# StrBuf (string builder)

`StrBuf` (stdlib/strbuf.aegis) accumulates string chunks in a `List[String]`
and materialises the final `String` once, avoiding O(n^2) repeated
concatenation.

```aegis
struct StrBuf { mut parts: List[String] }

impl StrBuf {
    fn append(mut self, s: String) -> Empty
    fn append_int(mut self, n: Int) -> Empty
    fn append_float(mut self, f: Float) -> Empty
    fn append_char(mut self, c: String) -> Empty
    fn clear(mut self) -> Empty
    fn len(self) -> Int
    fn reserve(mut self, n: Int) -> Empty
    fn to_string(self) -> String
    fn write_file(self, path: String) -> Result[Int, String]
}
```

Construct with `StrBuf { parts: [] }`.
PY