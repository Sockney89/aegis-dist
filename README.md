# Aegis

Aegis is a contract-aware, event-driven systems language: a deliberately tiny
grammar with stack-by-default memory, inferred automatic reference counting,
and a compiler that treats AI as a first-class authoring mode. It ships a full
toolchain (compiler, MCP server, streaming daemon) plus a growing standard
library, all in one self-contained archive.

This repository hosts the **public distribution** for Aegis: the documentation
site, the installers, and the prebuilt release binaries. The compiler source is
maintained privately; the binaries here are closed-source (proprietary), shipped
under the `LICENSE` and `NOTICE` included in every release archive.

## Install

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/Sockney89/aegis-dist/main/install.ps1 | iex
```

**Linux (x86_64):**

```sh
curl -fsSL https://raw.githubusercontent.com/Sockney89/aegis-dist/main/install.sh | sh
```

Both installers download the latest release, verify its SHA-256 checksum, and
install to a per-user directory (`%LOCALAPPDATA%\Aegis` on Windows, `~/.aegis`
on Linux). Pin a version with `-Version 0.1.3` (PowerShell) or
`--version 0.1.3` (shell).

> Building a standalone executable (`compiler --emit-exe`) needs a
> clang-compatible C compiler at runtime, selected via the `AEGIS_CC`
> environment variable (e.g. `C:\LLVM\bin\clang.exe`). The compiler itself has
> no other external dependencies. Run `aegis init` to register the MCP server
> with your agent host.

## What you get

- `aegis` — the toolchain front-end (`init`, `mcp`, `daemon`, `ws`,
  `version`, or any compiler flag forwarded verbatim).
- `compiler` — the Aegis compiler (`--emit-obj`, `--emit-exe`, `--emit-lib`,
  `--emit-dylib`).
- `aegis-mcp` — a Model Context Protocol server exposing sessions and the
  language spec to AI agents.
- `aegis-daemon` / `aegis-ws` — the streaming server and its client.
- `runtime/prebuilt/` — the per-target runtime objects the compiler links.
- `stdlib/` and `docs/` — the seed standard library and the language reference.

## Language at a glance

- **Core values** `Int`, `Float`, `Bool`, `Str`/`String`, `Empty`; stack-by-default
  memory with inferred ARC for escaping values.
- **Control flow** `if`/`else`, `while`, `loop` (bare, range, list, string, map),
  `match` with guards, ranges, `|` alternatives, and nested enum patterns.
- **Errors as values** `Result[T, E]` / `Option[T]` with `?` propagation.
- **Contracts** `requires` / `ensures` / `old(...)`, checked at runtime.
- **State machines & events** `state`/`transition`, actor-style `emit`/`on`,
  `spawn`/`send`, timers (`emit ... after`).
- **Abstraction** `struct`/`impl`, traits (static + dynamic dispatch), generics
  with bounds, closures with `map`/`filter`/`fold`/`sort`.
- **Modules** multi-file compilation, `pub` visibility, archive linking.
- **Globals** top-level `let` / `let mut` (rejected under `--threads`).
- **Enums** sum types with payloads and exhaustive `match`.
- **Sized widths** `i8`..`u64`, `f32`, with explicit conversions.
- **Interop** `extern "C"` (handles, out params, C strings, callbacks,
  C-layout structs) and `export fn`.
- **Multithreading** `--threads N` thread pool, `thread_spawn`, mutex-backed
  `SharedList`/`SharedMap`, and `serve_threaded` for HTTP. Mutable globals and
  mutable closure captures are rejected at compile time in threaded builds.

## Standard library

Math and transcendental functions, string operations, `List`/`Map` builtins;
in-Aegis collections (`Stack`, `Set`, `Queue`, `Deque`, `SharedList`,
`SharedMap`); JSON, CSV, fixed-width tables; file IO and stdin; time, a seeded
PRNG, `sleep`; `hash`, SHA-256, HMAC-SHA256, AES-256-GCM; encoding
(base64/hex/URL/base64url); logging; auth (basic, cookies, JWT); regex;
database interface traits (Go-style drivers); blocking TCP/UDP, socket
polling/timeouts; an HTTP/1.1 server with keep-alive, WebSocket upgrade and
framing, and threaded serving; TLS/HTTPS end to end (SChannel on Windows,
dlopen'd OpenSSL on POSIX).

## Scoop (Windows)

```
scoop bucket add aegis https://github.com/Sockney89/aegis-dist
scoop install aegis
```

## Documentation

The human-readable book lives at
<https://sockney89.github.io/aegis-dist/> (source mirrored from the private
project under `docs/`). Two AI-oriented corpora, `llms.txt` and
`llms-full.txt`, are published at the repository root.

## License

- Installer scripts and site configuration: MIT (see `LICENSE`).
- Documentation content: CC BY 4.0 (see `LICENSE-DOCS`).
- Released binaries: proprietary (`LicenseRef-Proprietary`); see the `LICENSE`
  and `NOTICE` files inside each release archive, including the third-party
  attribution for the statically linked LLVM and its runtimes.
EOF
path:
D:\dev\opencode\aegis\dist-repo/README.md