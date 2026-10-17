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
- **Enums** - user-defined sum types with payloads and exhaustive `match`.
- **Sized numeric widths** - `i8`..`u64` and `f32`, with explicit conversions.
- **Interop** - `extern "C"` (opaque handles, out params, C-string marshaling,
  function-pointer callbacks, and C-layout structs) and `export fn` for hosting
  Aegis code inside a C program.

## Standard library

- Math and transcendental functions, string operations, and `List`/`Map`
  builtins.
- In-Aegis collections: `Stack`, `Set`, `Queue`, and `Deque`.
- JSON parse/serialize, CSV encode/decode, and fixed-width tables.
- File IO and stdin; time and a seeded PRNG; `hash(x)`.
- Blocking TCP networking and a minimal HTTP/1.1 server.

## Tooling

- The `aegis` CLI: compile, format, and register the MCP server with your agent
  host.
- `aegis-mcp` serves the language corpus and build tools to agents over MCP;
  `aegis-daemon` / `aegis-ws` expose the streaming protocol.
- Installers and packaging for Windows (x64) and Linux (x86_64), including
  Scoop.

## On the way

- Cross-compilation between the supported targets.
- More standard-library depth: JSON pretty-printing and richer string and
  formatting helpers.
