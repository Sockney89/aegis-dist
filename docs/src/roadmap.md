# Language status

Aegis is a working compiler today. This page summarizes what the language and
standard library support, and what is still on the way.

## Language

- **Core values** - `Int`, `Float`, `Bool`, `Str`/`String`, and `Empty`, with
  stack-by-default memory and inferred automatic reference counting (ARC) for
  values that escape the current frame.
- **Control flow** - `if`/`else if`, `while`, the single `loop` form (bare,
  range, list, string, map), and `match` with guards, range patterns, `|`
  alternatives, and nested enum patterns.
- **Errors as values** - `Result[T, E]` / `Option[T]` with `ok`/`err`/`some`/
  `none` and `?` propagation.
- **Design by contract** - `requires` / `ensures` / `old(...)`, checked at
  runtime.
- **State machines and events** - `state`/`transition`, actor-style `emit`/`on`,
  `spawn`/`send`, and timers (`emit ... after`).
- **Abstraction** - `struct`/`impl`, traits (static and dynamic dispatch), user
  generics with bounds, and closures with the higher-order list methods
  (`map`/`filter`/`fold`/`sort`).
- **Modules** - multi-file compilation, `pub` visibility, and archive linking.
- **Global variables** - top-level `let` / `let mut` bindings shared across a
  file.
- **Raw strings** - backtick literals with literal braces (only
  backslash-backtick escapes).
- **Enums** - user-defined sum types with payloads and exhaustive `match`.
- **Sized numeric widths** - `i8`..`u64` and `f32`, with explicit conversions.
- **Interop** - `extern "C"` (opaque handles, out params, C-string marshaling,
  function-pointer callbacks, and C-layout structs) and `export fn` for hosting
  Aegis code inside a C program.

## Standard library

- Math and transcendental functions, string operations, and `List`/`Map`
  builtins; `ord`/`chr` and `sleep`.
- In-Aegis collections: `Stack`, `Set`, `Queue`, and `Deque`; mutex-backed
  `SharedList`/`SharedMap` for threaded builds.
- JSON parse/serialize, CSV encode/decode, and fixed-width tables.
- File IO and stdin; time and a seeded PRNG; `hash(x)`; `Encoding`,
  `Log`, and `Auth` (basic, cookies, JWT) helpers.
- SHA-256, HMAC-SHA256, and AES-256-GCM crypto builtins.
- Regex matcher with `.`, `*`, `+`, `?`, classes, anchors, alternation,
  and escapes.
- Database interface traits (Go-style `DbDriver`/`DbConn`/`DbRows`).
- Blocking TCP and UDP networking, socket polling/timeouts, and an
  HTTP/1.1 server with keep-alive, WebSocket upgrade handshake and
  framing, and threaded serving (`serve_threaded`).
- TLS/HTTPS end to end (SChannel on Windows, dlopen'd OpenSSL on POSIX).

## Tooling

- The `aegis` CLI: compile, format, and register the MCP server with your agent
  host.
- `aegis-mcp` serves the language corpus and build tools to agents over MCP;
  `aegis-daemon` / `aegis-ws` expose the streaming protocol.
- Installers and packaging for Windows (x64) and Linux (x86_64), including
  Scoop.
- Optional threaded builds (`--threads N`) with mutex-backed shared
  collections; mutable globals and mutable closure captures are rejected at
  compile time. Single-threaded hot-swap of actor modules (`--hot-swap`).
- Threaded HTTP serving is available via `serve_threaded` (MT8); `serve`
  remains single-threaded for minimal setups.

## On the way

- Cross-compilation between the supported targets.
- Multi-threaded hot-swap (MT6): stop-the-world + per-thread migration.
- True in-place code replacement for hot-swap (currently state migration only)
  and richer `export fn` marshaling (e.g. `Str`) for swappable modules.
- Stdlib depth: JSON pretty-printing, richer string/formatting helpers, and
  a SQLite driver implementing the db traits.
- HTTP client maturity: cookies, multipart, and streaming request/response
  bodies are still pending.
