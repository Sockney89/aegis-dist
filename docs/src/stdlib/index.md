# Standard library

The Aegis standard library has two layers:

1. **Compiler builtins** - methods the compiler lowers directly to LLVM and to
   C helpers in `compiler/runtime/runtime.c`. These are "sealed": you cannot
   redefine `String.length`, and the compiler type-checks their arguments.
2. **Aegis seed modules** - ordinary `struct`/`impl` files under `stdlib/`
   that implement collections and numeric string helpers on top of builtins.
   Each ships with a self-checking suite under `tests/e2e/` that must print a
   specific "suite OK" banner. A seed module is only in scope when its file
   is listed among the compiler inputs — the stdlib is not auto-loaded.

The compiler also exposes value-level builtins: `print(...)`, `println(...)`,
`str(v)` (stringify), and `argc` / `arg(i)` for program arguments.

- [Int & Float math](math.md)
- [String operations](string.md)
- [List operations](list.md)
- [Collections](collections.md)
- [JSON](json.md)
- [File IO & stdin](io.md)
- [Time & randomness](time-rand.md)