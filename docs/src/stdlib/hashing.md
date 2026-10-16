# Hashing

`hash(x)` is a value-level compiler builtin (like `now_ms` / `argc`) backed by
`compiler/runtime/runtime.c`. It maps a scalar or string to a deterministic,
non-negative `Int` using FNV-1a (64-bit) — the same family the `Map` uses for
its string keys.

| Function | Returns | Notes |
| --- | --- | --- |
| `hash(s)` | `Int` | FNV-1a over the string's bytes; `hash("")` is defined |
| `hash(n)` | `Int` | FNV-1a over the 8 little-endian bytes of the `Int` |
| `hash(b)` | `Int` | `hash(true)` / `hash(false)`, i.e. `hash` of `1` / `0` |

```aegis
let a = hash("hello")     // deterministic across runs
let b = hash(42)
let c = hash(true)
```

Properties:

- **Deterministic.** The same input always yields the same value, across runs
  and machines — no per-process seed.
- **Non-negative.** The 64-bit result is masked to 63 bits, so it is safe to
  use directly as `hash(x) % n` without sign pitfalls.
- **Not cryptographic.** This is a fast content hash for buckets, tables and
  fingerprints, not a password or integrity primitive.

Argument types are checked: `hash([1, 2])` fails with
`hash argument must be an Int, Bool, or String, got List(Int)`. Verified by the
`hash` checks in `tests/e2e/builtin_suite.aegis` and the
`hash_builtin_type_checks_and_rejects_bad_args` unit test.
