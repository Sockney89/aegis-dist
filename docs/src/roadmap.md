# Roadmap

This page summarizes the language feature axis and current status.

## L1 - Observable programs (done)

`print`/`println`, `str(...)`, String `+` concatenation and `{expr}` interpolation,
`argc()`/`arg(i)`, and `--emit-exe` (one command to a native executable).

## L2 - Completed core (done)

`if`/`else if`, `while`, `loop` (bare / range / list / string), `match`, sum-type
destructuring (`ok`/`err`/`some`/`none`), `?` propagation, short-circuit `&&`/`||`,
compound assignment, `const` globals.

## L3 - Abstraction & stdlib (done)

- **L3a** closures + higher-order list methods (`map`/`filter`/`fold`/`sort`).
- **L3b** sealed builtin `impl Int`/`Float`/`String`; `floor`/`sqrt`; math seed.
- **L3c** allocation-returning string builtins (`trim`/`split`/`join`), `Stack`.
- **L3d** `Set` / `Queue`; native `Map.remove`.
- **L3e** traits (static dispatch), trait objects (dynamic dispatch), and
  contract-strength subsumption.
- **L3f** `List.contains/index_of/reverse`, `String.to_upper/to_lower/repeat`.
- **L3g** string interpolation with str()-able holes.

## L4 - Reuse, isolation & escape hatches (done)

- **L4a** user generics (structs, methods, traits, bounds) with monomorphization.
- **L4b** real modules: multi-file compilation, `pub` visibility enforcement, and
  archive linking (`--emit-archive`).
- **L4c** FFI: `extern "C"` declarations.

## L5 - Scale (done)

Timers (`emit ... after`), actors (`spawn`/`send`/`on`), and optional static contract
verification (`--verify`).

## M1-M7 - Standard library (in progress)

- **M1-M6 (done):** numeric conversions + math/transcendentals; string deepening;
  file IO + stdin; time + randomness; map enumeration + `List.slice`; and the
  dungeon-adventure flagship.
- **M7 (in progress):** data packages. Done: JSON parse/serialize (M6/L7b),
  `Deque` (two-stack double-ended queue), `List.dedupe`, the `hash(x)` FNV-1a
  builtin (Int/Bool/String -> non-negative Int), map iteration
  (`loop (k, v) in m`, L8), CSV + fixed-width tables
  (`stdlib/csv.aegis`, `stdlib/table.aegis`), and directory listing
  (`list_dir(path)` -> `Result[List[Str], Str]`). Struct-keyed maps are
  deliberately out of scope (mutable keys would invalidate their hash slots;
  encode composite keys as a `String` instead). Planned: JSON pretty-printing.

## L6-L9 - Surface & depth

- **L6** ergonomics & formatting: **multi-line struct/collection literals (done, L6a)**,
  **format specifiers `"{x:.3f}"` + `Float.format`/`Int.pad` (done)**, **`main -> Result[Empty, E]`
  with explicit exit codes (done)**, **`**` power sugar (done, desugars to `.pow()`)**.
- **L7** sum types & pattern depth: **user-defined enums with payloads + exhaustive
  match (done)**, **guards / range patterns / `|` alternatives with bindings
  (done)**, **nested patterns — a variant payload that is itself an enum matches
  directly, e.g. `Outer::A(Inner::B(x))`, with one-level exhaustive inner
  coverage (done)**.
- **L8** iteration & capture: **`loop (k, v) in map` (done, L8a)**, **`enumerate()` /
  `zip` pair views over lists (done, L8b)**, **container-capturing closures (done,
  L8c)**, **nested closures (done, L8d)**, **user iteration protocol (done, L8e)** —
  any struct with `next(mut self) -> Option[T]` is loopable.
- **L9** numeric widths & casts: `i8`..`u64` / `f32` with explicit conversions.

## I-track - Interop & Foreign Code (traction priority)

First-class C interop so Aegis reaches real libraries (SQLite as the proving
ground) and, via C ABI, the Rust/Zig/C++/Go ecosystems. `extern "C"` now spans
the C scalar widths, `Handle`, `Str`/`char*`, out-params, callbacks, `extern
struct`, and struct returns by value, and a single `--emit-exe` command links
sources with C/objects/archives.

- **I1** sized integer widths (pulls L9 forward).
- **I2** opaque `Handle` type (`sqlite3*`, `FILE*`) — done: `Handle[Tag]` is one
  pointer wide and never dereferenceable, `null` is the null pointer, and
  `==`/`!=` compare identity.
- **I3** out-params / address-of in extern signatures (`sqlite3_open(path, out db)`)
  — done: `out name: T` is `T*`, the call passes an address the callee writes and
  binds as a fresh local.
- **I4** automatic `Str` ↔ `char*` marshaling (`aegis_str_cstr`/`aegis_str_from_cstr`)
  — done: `-> Str` extern results and out-Str readbacks are copied into owned
  Aegis Strings (NULL C strings read back as `""`), so transient C buffers stay
  valid as locals.
- **I5** function-pointer params: Aegis closures as C callbacks and UDFs — done:
  a cb-signature param `fn(...) -> R` marshals each closure literal to a real
  C-ABI thunk (`aegis.cb.N`) whose captured env is looked up in a program-lifetime
  registry, so captures outlive the C call. Signatures are C-scalar/Str-only.
- **I6** struct ABI (`#[repr(C)]` equivalent) for system headers — done:
  `extern struct Name { f: T, ... }` declares a C-layout struct (C scalars /
  `Handle[T]` / nested extern structs only) that crosses the extern boundary by
  value as a param, by pointer through `out name: T`, and by value as a return
  (I9).
- **I7** single-command FFI linking — done: `--emit-exe` mixes `.aegis` sources with
  object/archive/C inputs and `-l`/`-L` (with `AEGIS_LIBRARY_PATH` as extra `-L`).
- **I8** Aegis as a callable C library — done: `export fn` entry points over scalar
  params, `--emit-lib` (static `.lib`/`.a`) and `--emit-dylib` (`.dll` + import lib on
  Windows, `.so` on Linux, with the runtime linked in).
- **I9** C-struct returns by value — done: an `extern "C"` fn may return an `extern
  struct` (registers when it fits, else the hidden struct-return pointer), closing the
  I6 deferral; a non-extern Aegis struct return is still rejected.
- Gate: **SQLite milestone** — open a DB, create a table, insert and read rows back
  from Aegis in one command with no hand-written C.

Rust interop rides the I-track: `#[no_mangle] extern "C"` + `#[repr(C)]` already
speak C ABI, so the extra work is per-crate shims (`CString`/slice conversion,
`panic=abort` at the boundary) and a `staticlib` link recipe — no new compiler
machinery.

## S-track - toolchain

Phases 0-4 and S1-S6 are done (formatter, C-WAL, wire schema, materialization, live
symbols, daemon + WS); `aegis-mcp`, `aegis-ws` and packaging sit on top. **S8**
(session continuity across `eos`) and **S10** (project reopen from the C-WAL) are
done. **S9** (single-command FFI linking) shipped under the I-track as **I7**, and
**I8** (`--emit-lib`/`--emit-dylib` for hosting) is now done too. S7
(compiler-as-a-service) remains optional and undecided.

## X-track - Cross compilation (done)

Modeled on rustc: `--target <triple>` makes codegen emit target-specific objects
(COFF/ELF per the effective target, CLI > `AEGIS_TARGET` > host), the runtime
ships as **prebuilt per-target objects** so Aegis can be distributed without its
source, and `--emit-exe` links through the host `clang` driver with
`--target=` + `-fuse-ld=lld` so the target-appropriate linker is picked
(`lld-link`/mingw/`ld.lld`; `AEGIS_CC` overrides). MCP sessions carry a target end
to end. First pair: `x86_64-pc-windows-msvc` + `x86_64-unknown-linux-gnu`.
