# Pipeline

The compiler is a Rust crate in `compiler/` with a classic single-pass chain:

```
source file
  -> lexer.rs        (tokens; keywords -> single-token kinds)
  -> parser.rs       (AST: struct/impl/state/on/loop/match/expr/stmt)
  -> semantic.rs     (symbol resolve, types, contracts, events, struct init)
  -> codegen.rs      (LLVM IR via inkwell)
  -> optimize.rs     (IR passes)
  -> runtime.c       (linked C runtime, compiled with AEGIS_CC)
  -> obj / exe / ll
```

## Driving the compiler

`compiler` (the main binary) reads a file, parses, runs semantic analysis,
and lowers to LLVM IR. Flags:

| Flag | Effect |
| --- | --- |
| `--fmt` | print canonical formatted source, exit |
| `--emit-obj FILE` | emit an object file |
| `--emit-exe FILE` | emit a linked executable (`--main X::y` sets the entry) |
| `--emit-archive FILE` | wrap the object in a static archive via `llvm-ar rcs` |
| `--emit-lib FILE` | emit a static library (`.lib`/`.a`) of the `export fn` surface |
| `--emit-dylib FILE` | link the object + `runtime.c` into a shared library (`.dll`/`.so`) |
| `--ir` | print LLVM IR |
| `--main  Struct::method` | choose the entry point |
| `-l <name>` / `-l<name>` | pass `-l<name>` to the final clang/lld link |
| `-L <dir>` / `-L<dir>` | add a library search dir for the final link |

The link accepts object/archive/C inputs either alone or mixed with `.aegis`
sources (mixing needs `--emit-exe`, `--emit-lib`, or `--emit-dylib`);
`AEGIS_LIBRARY_PATH` dirs are appended as extra `-L` search dirs, and `-l`/`-L`
apply to `--emit-exe`/`--emit-dylib` only. See
[Single-command FFI linking](../../language/grammar.md#single-command-ffi-linking)
and [Calling Aegis from C](../../language/grammar.md#calling-aegis-from-c-export-fn).

`--emit-dylib` on Windows also writes an import library next to the DLL
(`aegis.dll` → `aegis.lib`) with `llvm-dlltool -m <machine> -d exports.def`,
because lld cannot link a raw DLL; `LLVM_SYS_221_PREFIX`/`LLVM_DIR` or
`PATH` locate the tool. `export fn` symbols are emitted verbatim (no `aegis_`
prefix) with the C calling convention, and carry `dllexport` in dylib mode.

The `aegis-daemon` / `aegis-ws` pair expose the same front-end over the
streaming WebSocket protocol (live unresolved-reference reports, EoS gating,
sync/rollback snapshots) for IDE-style and agentic integration. See
[Streaming & the compiler daemon](streaming.md).

## How the source-of-truth doc set is produced

- `docs/src/` Markdown is the only docs source.
- `mdbook build docs` renders the HTML book (`docs/book/`).
- `tools/gen-llms-txt.ps1` concatenates the same sources into the AI corpus
  (`llms.txt` + `llms-full.txt`). No doc content is duplicated by hand.