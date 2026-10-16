# List operations

`List[T]` is a grow-only runtime buffer with ARC reference counting. A list
value (`{ i64 len, ptr handle }`) stays small; the handle owns the storage.

## Compiler builtins

| Method | Requires | Returns | Notes |
| --- | --- | --- | --- |
| `length()` | - | `Int` | current logical length |
| `append(v)` | `mut` list | `Int` | append, returns new length |
| `insert(idx, v)` | `mut` list | - | insert at index |
| `get(idx)` | - | element | `xs[idx]` indexing is equivalent |
| `pop()` | `mut` list | element | remove + return the last element |
| `contains(x)` | - | `Bool` | whether an element equal to `x` is present |
| `index_of(x)` | - | `Int` | index of first match, `-1` when absent |
| `reverse()` | - | `List[T]` | fresh reversed copy (original untouched) |
| `dedupe()` | - | `List[T]` | fresh copy with duplicates removed, keeping the first occurrence |
| `slice(a, b)` | - | `List[T]` | fresh copy of the half-open range `[a, b)`, clamped to `[0, len]` |
| `map(f)` | - | `List[U]` | see [closures](../language/closures.md) |
| `filter(p)` | - | `List[T]` | predicates must be `Func(T -> Bool)` |
| `fold(init, f)` | - | `B` | left fold |
| `sort(lt)` | - | `List[T]` | new sorted list |
| `join(sep)` | `T = Str` | `Str` | join string elements |

`append` and `pop` require a **mutable** receiver (a `mut` binding). Calling
`pop()` on an immutable list is a compile error:
`pop requires mutable list 'xs'`.

`dedupe()` compares elements by slot, so it removes duplicate `Int`/`Bool`/
`Handle` values by value and `String` elements by identity (two distinct but
equal strings are both kept). It returns a fresh list and leaves the receiver
untouched.

## Composite receivers

`map`/`filter`/`fold`/`sort` (and any list-valued method result) must be
bound to a named variable before further method calls - the receiver of a
chain like `xs.map(f).length()` must be a plain identifier, matching the
"temp receivers are scalars only" rule. Bind intermediates instead:

```aegis
let ys = xs.map(|x| x * 2)
let n = ys.length()
```

## Empty lists

`[]` type-checks as `List[Any]` and is assignable to any `List[T]` field or
binding, so collection structs can start from `mut items: List[Int]` with an
empty initializer - the `types_compatible` rule recurses into element types.