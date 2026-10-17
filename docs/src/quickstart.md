# Quickstart

Aegis ships as a self-contained compiler toolchain. You install a release,
point it at a C compiler for the final link step, and compile `.aegis` programs
to native executables.

## Install

**Windows (x64):**

```powershell
irm https://raw.githubusercontent.com/Sockney89/aegis-dist/main/install.ps1 | iex
```

**Linux (x86_64):**

```sh
curl -fsSL https://raw.githubusercontent.com/Sockney89/aegis-dist/main/install.sh | sh
```

Both installers download the latest release, verify its SHA-256 checksum, and
install to a per-user directory (`%LOCALAPPDATA%\Aegis` on Windows, `~/.aegis`
on Linux), adding the `bin/` to your `PATH`. Pin a version with `-Version 0.1.0`
(PowerShell) or `--version 0.1.0` (shell). On Windows you can also use Scoop:

```
scoop bucket add aegis https://github.com/Sockney89/aegis-dist
scoop install aegis
```

## Link step: a C compiler

Producing a standalone executable (`--emit-exe`) drives a `clang`-compatible C
compiler at the final link to build the runtime. Point the compiler at it once:

```powershell
[Environment]::SetEnvironmentVariable('AEGIS_CC','C:\LLVM\bin\clang.exe','User')
```

```sh
export AEGIS_CC=/usr/bin/clang
```

Formatting and the other non-linking outputs need no C compiler. The Aegis
runtime is bundled with the toolchain, so you never build it.

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

compiler hello.aegis --main Greeter::greet --emit-exe hello
./hello
# -> hello, aegis
```

`--emit-exe` produces a standalone executable (`.exe` suffix is appended on
Windows). Without an explicit filename the executable is written next to the
first input file under that file's basename; pass a path (`--emit-exe app.exe`)
to control it. `--emit-obj` emits an object file and `--fmt` prints the
canonical formatted source.

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
open a session, stream the source item by item, then link and run. Register it
with one command from your project root:

```sh
aegis init --tool opencode    # also: claude, cursor, vscode, windsurf, codex, all
```

Then restart the host. See [the `aegis` CLI](tooling.md) for the flags, the
per-host config files, and the
`create_session` → `stream_source` → `eos` → `link_object` → `run_object` loop.

## Standard library

The "stdlib" has two layers:

1. **Compiler builtins** - methods the compiler provides directly
   (`String.length`, `String.split/join/trim`, `String.to_upper/to_lower/
   repeat`, `List.map/filter/fold/sort/append/pop/length/contains/index_of/
   reverse`, `Map.length/contains/insert`,
   `Float.floor/sqrt`). See [stdlib](stdlib/index.md).
2. **Aegis seed modules** - ordinary `struct`/`impl` code in `stdlib/`
   (`mathstr.aegis`: `Int.min/max/abs`, `starts_with/ends_with/contains`,
   `String.to_int`; `stack.aegis`: `Stack.push/pop/peek/len`).

Seed modules are **not auto-loaded**: to use their methods, list the module
files among the compiler inputs, e.g.
`compiler stdlib/mathstr.aegis app.aegis --emit-exe app.exe`. Compiler
builtins (layer 1) need no file — they are always in scope.
