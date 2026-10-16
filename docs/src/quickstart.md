# Quickstart

The compiler lives in `compiler/` as a Rust crate. It generates LLVM IR and
links against the C runtime in `compiler/runtime/runtime.c`.

## Prerequisites

- Rust (stable) + Cargo
- LLVM 22 (`LLVM_SYS_221_PREFIX` must point at the LLVM install)
- A C compiler exposed as `AEGIS_CC` (the runtime is compiled with clang)
- On Linux: clang + lld + libc dev headers (the emitted targets are
  `x86_64-pc-windows-msvc`/COFF on Windows and
  `x86_64-unknown-linux-gnu`/ELF on Linux)
- `mdbook` for the docs (see [internals/pipeline.md](internals/pipeline.md))

## Build

```sh
cd compiler
cargo build --release
```

## Run your first program

```sh
cat > hello.aegis <<'EOF'
struct Greeter { }
impl Greeter {
    fn greet(self) {
        println("hello, aegis")
    }
}
EOF

./target/release/compiler hello.aegis --main Greeter::greet --emit-exe hello
./hello
# -> hello, aegis
```

`--emit-exe` produces a standalone executable (`.exe` suffix is appended on
Windows). Without an explicit filename the executable is written next to the
first input file under that file's basename; pass a path (`--emit-exe app.exe`)
to control it. `--emit-obj` emits an object file, `--ir` prints the LLVM
IR, and `--fmt` prints the canonical formatted source.

The entry point defaults to the method named `main` (an `impl X { fn main(self) }`)
and can be overridden with `--main X::y`. `main` may return `Int` (the exit
code), nothing (exit 0), or `Result[Empty, E]`: `return ok` exits 0, and
`return err(n)` exits with `n` when the error payload is an `Int` (any other
payload exits 1), giving CLIs an explicit non-zero exit-code path with `?`
propagation. There is no `args: List[String]` parameter — programs read
`argc()` and `arg(i)`, where `arg(0)` is the program path and real arguments
start at `arg(1)` (see [wordfreq CLI](examples.md) for a full argv-driven
program).

## Driving the compiler from an agent (MCP)

`aegis-mcp` exposes the same streaming pipeline as MCP tools and resources, so
an agent host (opencode and other MCP clients) can compile without a shell:
open a session, stream the source item by item, then link and run. See
[internals/mcp.md](internals/mcp.md) for the tool list and the
`create_session` → `stream_source` → `eos` → `link_object` → `run_object` loop.

## Tests

```sh
cd compiler
cargo test            # 338 unit/integration tests
cd ../tests
powershell -File e2e.ps1   # Windows end-to-end: positive, negative, features, events
bash e2e.sh            # Linux end-to-end (needs clang + lld)
```

## Standard library

The "stdlib" has two layers:

1. **Compiler builtins** - methods the compiler lowers directly to LLVM
   (`String.length`, `String.split/join/trim`, `String.to_upper/to_lower/
   repeat`, `List.map/filter/fold/sort/append/pop/length/contains/index_of/
   reverse`, `Map.length/contains/insert`,
   `Float.floor/sqrt`). See [stdlib](stdlib/index.md).
2. **Aegis seed modules** - ordinary `struct`/`impl` code in `stdlib/`
   (`mathstr.aegis`: `Int.min/max/abs`, `starts_with/ends_with/contains`,
   `String.to_int`; `stack.aegis`: `Stack.push/pop/peek/len`). Each ships with a self-checks
   suite under `tests/e2e/`.

Seed modules are **not auto-loaded**: to use their methods, list the module
files among the compiler inputs, e.g.
`compiler stdlib/mathstr.aegis app.aegis --emit-exe app.exe`. Compiler
builtins (layer 1) need no file — they are always in scope.