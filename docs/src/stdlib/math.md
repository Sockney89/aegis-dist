# Int & Float math

## Numeric conversions

There is no implicit cast (and no `as` operator) between numeric types.
Conversion is an explicit method on the sealed builtin:

| Receiver | Method | Returns | Notes |
| --- | --- | --- | --- |
| `Int` | `to_float()` | `Float` | exact for values in range |
| `Float` | `to_int()` | `Int` | truncates toward zero |

```aegis
let f = 3.to_float()     // 3.0
let n = 3.9.to_int()     // 3
let m = (-3.9).to_int()  // -3
```

## Compiler builtins

These dispatch to `libm` wrappers in `compiler/runtime/runtime.c`, because the
operation has no source-level expression:

| Receiver | Method | Returns | Notes |
| --- | --- | --- | --- |
| `Float` | `floor()` | `Float` | largest integer `<= self` |
| `Float` | `ceil()` | `Float` | smallest integer `>= self` |
| `Float` | `trunc()` | `Float` | round toward zero |
| `Float` | `round()` | `Float` | nearest integer, halves away from zero |
| `Float` | `sqrt()` | `Float` | |
| `Float` | `pow(e)` | `Float` | `self` raised to `e`; `e` must be a `Float` |
| `Float` | `sin()` / `cos()` / `tan()` | `Float` | argument in radians |
| `Float` | `log()` / `log10()` / `exp()` | `Float` | natural / base-10 / `e^x` |
| `Float` | `format(digits)` | `Str` | fixed-decimal (`%.*f`) with `digits` places |
| `Int` | `pad(width)` | `Str` | zero-padded decimal, right-aligned to `width` |

```aegis
let a = 16.0.sqrt()     // 4.0
let b = 2.75.floor()    // 2.0
let c = 2.5.round()     // 3.0
let d = 2.0.pow(10.0)   // 1024.0
let e = (1.0).log()     // 0.0
let g = 3.14159.format(2) // "3.14"
let h = 42.pad(5)         // "00042"
```

`format`/`pad` produce text; use them where a value must be printed with
fixed decimals or zero-padded width (interpolation format specifiers —
`"{x:.2f}"`, `"{i:05d}"` — cover the same need inline).

Argument types are checked like any other method, so `(2.0).pow(3)` (an `Int`
exponent) is rejected with `pow exponent must be a Float, got Int`. Use
`3.to_float()` when the exponent is an integer value. The `**` operator is
sugar for these: `a ** b` desugars to `a.pow(b)` (right-associative, so
`2 ** 3 ** 2` is `2 ** (3 ** 2)`).

`String.to_float()` (see [string](string.md)) is the parsing counterpart: it
returns `Result[Float, Str]` and, together with `Float.to_int()`, gives a full
text -> number -> text path now that no C shim is needed.

## Aegis seed methods (`stdlib/mathstr.aegis`)

`impl Float`, `impl Int`, and `impl String` are **sealed builtins**: they may
only be implemented in the standard library, and by-value semantics apply
(`self` is not a reference).

```aegis
impl Int {
    fn min(self, o: Int) -> Int { if self < o { return self } return o }
    fn max(self, o: Int) -> Int { if self > o { return self } return o }
    fn abs(self) -> Int         { if self < 0 { return -self } return self }
    requires e >= 0
    fn pow(self, e: Int) -> Int { let mut r = 1; loop k in 0..e { r = r * self }; return r }
}
impl Float {
    fn min(self, o: Float) -> Float { if self < o { return self } return o }
    fn max(self, o: Float) -> Float { if self > o { return self } return o }
    fn abs(self) -> Float           { if self < 0.0 { return -self } return self }
}
impl String {
    fn starts_with(self, p: String) -> Bool { ... }
    fn ends_with(self, p: String) -> Bool   { ... }
    fn contains(self, sub: String) -> Bool  { ... }
}
```

Because these are ordinary methods on the sealed targets, the compiler
type-checks each argument the same way it checks any method:
`5.min("boom")` fails with `arg 0 of min: expected Int, got Str`.
Calling them on temporaries is supported: `5.min(9)`, `16.0.sqrt()`.

Integer `Int.pow` is a real Aegis method (it needs no runtime helper), unlike
`Float.pow` which must go through `libm`. The seed module is only in scope when
`stdlib/mathstr.aegis` is among the compiler inputs — the stdlib is not
auto-loaded.
