# Standard library

The Aegis standard library has two layers:

1. **Compiler builtins** - methods the compiler provides directly. These are "sealed": you cannot
   redefine `String.length`, and the compiler type-checks their arguments.
2. **Aegis seed modules** - ordinary `struct`/`impl` files under `stdlib/`
   that implement collections and numeric string helpers on top of builtins. Each
   ships with a self-checking suite; a seed module is only in scope when its file
   is listed among the compiler inputs — the stdlib is not auto-loaded.

The compiler also exposes value-level builtins: `print(...)`, `println(...)`,
`str(v)` (stringify), and `argc` / `arg(i)` for program arguments.

- [Int & Float math](math.md)
- [String operations](string.md)
- [List operations](list.md)
- [Collections](collections.md)
- [JSON](json.md)
- [File IO & stdin](io.md)
- [OS & processes](os.md)
- [Time & randomness](time-rand.md)

## Seed modules vs builtins (provenance)

| Capability | Where |
|---|---|
| `String.length()`, indexing `s[i]`, concatenation `+`, equality/comparison | Builtin |
| `List.length()`, `xs[i]`, `.append(v)`, `.pop()`, `.contains(x)`, `.index_of(x)`, `.reverse()`, `.slice(a,b)`, `.dedupe()` | Builtin |
| `Map.length()`, `m[k]`, `.contains(k)`, `.insert(k,v)`, `.remove(k)`, `.get_or(k,d)`, `.keys()`, `.values()` | Builtin |
| `Int.to_float()`, `Float.to_int()`, `Float.round()`/`ceil()`/`trunc()`/`pow`/`sin`/`cos`/`tan`/`log`/`log10`/`exp()` | Builtin |
| `Int.pow(Int)`, `Float.format(digits)`, `Int.pad(width)` | Seed / sealed impl |
| `String.split`/`delim?`, `trim()`, `join(sep)` (List[Str]), `to_upper()`/`to_lower()`, `repeat(n)`, `substring()`, `replace()`, `index_of`/`contains` variants, char predicates, `pad_left`/`right()` | Seed module (`stdlib/mathstr.aegis`) |
| Collections: `Stack[T]`, `Set[T]`, `Queue[T]`, `Deque[T]` | Seed modules (`stdlib/stack.aegis`, `set.aegis`, `queue.aegis`, `deque.aegis`) |
| JSON parsing/serialization | Seed module (`stdlib/json.aegis`) |
| OS access: env, cwd, mkdir/rmdir/remove/rename/copy, stat, pid/time, exec/shell | Seed module (`stdlib/os.aegis`) |
| CSV/Table helpers | Seed modules (`stdlib/csv.aegis`, `table.aegis`) |
