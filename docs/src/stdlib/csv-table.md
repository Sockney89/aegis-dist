# CSV & tables

`stdlib/csv.aegis` and `stdlib/table.aegis` are self-contained text-formatting
modules written in Aegis on top of compiler builtins (no C). Both compile
standalone and are covered by their self-test suites.

## CSV (`stdlib/csv.aegis`)

`Csv` encodes and decodes an RFC 4180 subset. A table is a `List[List[Str]]` —
rows of fields — which needs no new runtime support (`List` of `List` of `Str`
is an ordinary nested container).

| Method | Returns | Notes |
| --- | --- | --- |
| `parse(text)` | `List[List[Str]]` | split into records and fields |
| `encode(rows)` | `Str` | serialize, quoting only fields that need it |

```aegis
let csv = Csv {}
let rows = csv.parse("name,note\nalice,\"x, y\"\n")
let back = csv.encode(rows)   // "name,note\nalice,\"x, y\"\n"
```

`parse` follows the small RFC:

- a field may be double-quoted to embed a comma, a quote, or a newline;
- a doubled quote (`""`) decodes to a literal `"`;
- records end at `\n` or `\r\n` (a lone `\r` is dropped);
- a trailing newline does not create an empty final record, and blank input
  yields no rows.

`encode` quotes a field only when it contains a comma, quote, CR, or LF, and
doubles any embedded quote. For canonical input, `encode(parse(t)) == t`.

## Tables (`stdlib/table.aegis`)

`Table.render(headers, rows)` turns a header `List[Str]` and a `List[List[Str]]`
into a fixed-width text table: each column is padded to the widest of its header
and cells, the header is underlined with a dash rule, and short rows pad their
missing trailing cells.

```aegis
let t = Table {}
let table = t.render(["Name", "Age"], [["Al", "7"], ["Bea", "12"]])
// Name | Age
// -----+----
// Al   | 7
// Bea  | 12
```

Padding is built from `String.repeat` (`s + " ".repeat(width - s.length())`),
so the module stays standalone and does not depend on `stdlib/mathstr.aegis`.

## Round-trip

The self-test suites exercise quoted fields, CRLF and LF records, the
trailing-newline rule, blank input, encode round-trips, and table alignment.
