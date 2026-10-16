# String operations

`String` (spelled `Str` in type annotations) is an ARC-copied immutable
string. `+` concatenates; `==` / `!=` compare by content. Individual
characters are reached with a `loop c in s` iteration, which binds `c` to a
single-character `Str` (see [control flow](../language/control-flow.md)).

## Interpolation

A string literal can embed `{expr}` holes that are evaluated and stringified
at run time:

```aegis
let n = 42
let msg = "score: {n} of {n + 1}"   // "score: 42 of 43"
let who = "world"
println("hello {who}")              // "hello world"
```

Only str()-able scalar holes are allowed — `Int`, `Float`, `Bool`, and
`String`. Containers are rejected with
`interpolated values must be str()-able scalars or String, got List(Int)`.
Literal braces are written `\{` and `\}` (an unescaped `{` always starts a
hole). Interpolation is a first-class AST node (`Expr::Interp`), so it
round-trips through the S3 wire schema (`--ast-json`) and the deterministic
formatter (`--fmt`).

### Format specifiers (L6)

A hole may carry a format specifier after a `:`:

```
{expr:[[fill]align][width][.precision][type]}
```

- `align`: `<` (left), `>` (right), `^` (center). Numbers default right,
  strings left.
- `fill`: a single character before the align mark (e.g. `0>8`); a `0`-prefixed
  width (`05`) is zero-padding shorthand for right-aligned numbers.
- `width`: minimum field width in characters.
- `.precision`: decimal places for a Float (`f`), or significant digits for `g`.
- `type`: `f` fixed-point Float (`%f`), `d` decimal Int, `s` String, `g` the
  general `str(Float)` form (the default).

```aegis
let x = 3.14159
let i = 42
"{x:.2f}"      // "3.14"
"{x:>10.2f}"   // "      3.14"
"{i:05d}"      // "00042"
"{i:>6}"       // "    42"
```

The type must match the value: `"{i:.2f}"` on an `Int` is a semantic error
(`format spec type 'f' requires a Float, got Int`). The spec is stored
verbatim in the AST (`FormatSpec`), so it round-trips `--ast-json` and `--fmt`.
For fixed-decimal or padded output outside interpolation, `Float.format(digits)`
and `Int.pad(width)` are compiler builtins:

## Compiler builtins

| Method | Returns | Notes |
| --- | --- | --- |
| `length()` | `Int` | byte length |
| `trim()` | `Str` | new string with leading/trailing ASCII whitespace removed |
| `split(delim)` | `List[Str]` | split on a delimiter; empty delim => one whole-string piece; `""` => one empty piece |
| `to_upper()` | `Str` | ASCII uppercase mapping (fresh copy) |
| `to_lower()` | `Str` | ASCII lowercase mapping (fresh copy) |
| `repeat(n)` | `Str` | the string repeated `n` times; empty when `n <= 0` |
| `to_float()` | `Result[Float, Str]` | parse a full float literal; `err` on empty/junk/overflow |

```aegis
let s = "  a,b,c  "
let t = s.trim()            // "a,b,c"
let parts = t.split(",")    // List[Str] ["a","b","c"]
let joined = parts.join("|") // "a|b|c"
let up = "abc".to_upper()   // "ABC"
let bang = "ha".repeat(3)   // "hahaha"
```

`trim`/`split` allocate: `trim` returns a `Str`, `split` returns a
`List[Str]`. Both are compiler builtins because they need substring
construction there is no source primitive for. They validate their arguments
semantically: `s.split(42)` reports
`split delimiter must be a String, got Int`.

## Sealed `impl String` methods

`starts_with` / `ends_with` / `contains` are defined as ordinary methods on
the sealed builtin target in `stdlib/mathstr.aegis` and compose with the
builtins above. `List[Str].join(separator)` produces a string from the
elements; the separator must be a `String`.

`String.to_int()` is also a sealed `impl String` method in
`stdlib/mathstr.aegis`. It parses a signed decimal integer and returns
`Result[Int, String]`: `"42".to_int()` is `ok(42)`, `"-17".to_int()` is
`ok(-17)`, and empty input or a non-digit character yields `err(...)`. This
is the primitive for argv parsing with `argc()` / `arg(i)`.

### Slicing, search and padding (M2)

| Method | Returns | Notes |
| --- | --- | --- |
| `index_of(sub)` | `Int` | first index of `sub`, or `-1` when absent; `""` yields `0` |
| `substring(start, end)` | `Str` | half-open `[start, end)`; `requires 0 <= start <= end <= length` |
| `replace(from, to)` | `Str` | every non-overlapping `from`; empty `from` returns self |
| `is_digit()` | `Bool` | one-char `"0"`..`"9"` |
| `is_alpha()` | `Bool` | one-char ASCII letter |
| `is_space()` | `Bool` | space, `\t`, `\n`, or `\r` |
| `pad_left(width, fill)` | `Str` | left-pad with `fill` toward `width` (no-op once wide enough) |
| `pad_right(width, fill)` | `Str` | right-pad with `fill` toward `width` |

```aegis
let w = "hello world"
w.index_of("world")       // 6
w.substring(0, 5)         // "hello"
w.replace("o", "0")       // "hell0 w0rld"
"7".pad_left(3, "0")      // "007"
"7".is_digit()            // true
```

These are ordinary Aegis methods built from char indexing and `+`. There is
still no source-level substring primitive, so `substring` concatenates one
character at a time.

## Map operations

`Map` is a native hash container with the following builtins:

| Method | Requires | Returns | Notes |
| --- | --- | --- | --- |
| `length()` | - | `Int` | |
| `contains(k)` | - | `Bool` | |
| `insert(k, v)` | `mut` map | `Int` | upserts, returns new length |
| `remove(k)` | `mut` map | `Bool` | `true` if key was present, `false` if absent |