# Types & memory

## Value types

Primitives are single-slot machine values on the stack.

| Type | Example | Notes |
| --- | --- | --- |
| `Int` | `42` | 64-bit signed |
| `Float` | `3.5` | f64 |
| `Bool` | `true` | |
| `Str` | `"hi"` | ARC-copyable, `+` concatenates; `String` is a synonym |
| `Empty` | - | unit type, used for side-effecting methods |
| `List[T]` | `[1, 2, 3]` | runtime-allocated buffer, ARC reference counted |
| `Map[K, V]` | `{ "a": 1 }` | keyed buffer |
| `Func(params -> result)` | `\|x: Int\| x + 1` | closure, capture-by-value |
| `Option[T]` | `some(5)` / `none` | sum type |
| `Result[T, E]` | `ok` / `err(e)` | sum type |

`String` and `Str` name the same type; both spellings are accepted in type
annotations (`List[Str]` and `List[String]` are identical).

## Opaque handles (I2)

`Handle[Tag]` is a C pointer that Aegis can hold and pass but never look
through. It is one pointer wide, like `Str`, and carries a phantom tag.

| Type | Example | Notes |
| --- | --- | --- |
| `Handle[Tag]` | `Handle[FILE]` | opaque C pointer; tag is phantom, never declared |

The tag exists for type safety only: `Handle[FILE]` and `Handle[sqlite3]` are
different types, so the compiler rejects passing one where the other is
expected, or comparing them with each other. It is not resolved, not declared,
and carries no runtime cost - two handles with the same tag are the same type,
and the tag is erased on the way to LLVM (both are `ptr`).

What a handle supports is deliberately tiny, because the C side owns the
memory: pass it to an `extern "C"` call, return it, store it in a local or a
struct field, compare it with `==` / `!=` (pointer identity), and test it
against `null`. Everything a raw pointer has and a safe language should not
expose is gone: `h.field` is an `opaque` error, and ordering (`h1 < h2`) is
rejected because pointers have no meaningful order.

```aegis
extern "C" fn sqlite3_open(path: Handle[CStr], db: Handle[Db]) -> Empty

struct Db { }

impl Db {
    fn close(self, h: Handle[Db]) -> Empty {
        if h == null {
            return
        }
        // ... hand h back to the C library
    }
}
```

`null` is the null pointer. Because it has no tag, it only fits where a handle
is expected, and it must be annotated to bind: `let h: Handle[Db] = null` is
fine, `let h = null` is an error. That is what keeps an untyped null from
being passed to a function expecting a different handle.

## Out params (I3)

An `extern "C"` parameter can be declared `out name: T`. It stands for `T*` on
the C side — the C callee writes a result through it — so Aegis must pass an
address, not a value. At the call site that address comes from `out name`:

```aegis
extern "C" fn sqlite3_open(path: Handle[CStr], out db: Handle[Db]) -> Int

fn open(path: Handle[CStr]) -> Handle[Db] {
    let rc = sqlite3_open(path, out db)
    if rc != 0 {
        return null
    }
    return db          // db: Handle[Db], bound by the call above
}
```

The compiler allocates a slot big enough for `T`, passes its address to the C
callee, and after the call binds `db` as a fresh local whose value is whatever
the callee wrote. `db` becomes visible to the statements *following* the call
(statement-level binding — reading it in the same statement is rejected).

Holds for any type whose slot has a known width at the I16-boundary: scalars
(the I1 widths bind `uint32_t*` etc. exactly), `Str` (`char**` — a C
fetch-last-error getter writes the message Aegis opens as `Str`), and
`Handle[Tag]` (`sqlite3**`). `let seven: u32 = 7` is a valid annotated literal.

`out` is a context-sensitive marker, never a reserved word: `let mut out = ""`,
`return out`, and a method param named `out` all still parse as identifiers.
Rules enforced by the checker: a plain value cannot fill an out param, `out x`
is rejected on non-out params and on method/export-fn params, a stray `out x`
outside an extern call is rejected, out params cannot be aggregates
(`out xs: List[Int]`), and an out variable cannot be read before its call.

## C-string marshaling (I4)

A `-> Str` extern return is a C `char*` that is at best transient — valid only
until the callee's *next* call (`sqlite3_column_text` is invalidated by the next
`step`/`column_*`; `sqlite3_errmsg` by the next sqlite3 call). The compiler
copies it into an owned Aegis String the moment the call returns, and an
`out msg: Str` readback is copied the same way:

```aegis
extern "C" fn sqlite3_column_text(stmt: Handle[Stmt], i: Int) -> Str
extern "C" fn sqlite3_errmsg(db: Handle[Db]) -> Str

let title = sqlite3_column_text(stmt, 0)   // snapshot, safe after the next call
let err = sqlite3_errmsg(db)               // NULL from C reads back as ""
```

A NULL C string reads back as the empty string, so a getter that returns NULL
when there is nothing to say composes (`if err == "" { ... }`) instead of
crashing the string machinery. On the way out nothing changes: `Str` params
still cross zero-copy, because Aegis strings are already NUL-terminated heap
buffers. When a callee may *retain* the pointer past the call or scribble on
the buffer, hand it a copy with the declared intrinsic:

```aegis
extern "C" fn aegis_str_cstr(s: Str) -> Str   // owned NUL-terminated copy
```

The two intrinsics `aegis_str_cstr` / `aegis_str_from_cstr` are the marshaling
primitives; their own returns are already owned, so they are exempt from the
automatic copy. Strings are heap buffers never freed individually, so each
marshaled snapshot is one leak per crossing — identical to every other runtime
string, and the price of making C's transient buffers durable.

## Function-pointer callbacks (I5)

An extern signature may declare a parameter of type `fn(...) -> R`, which is a
C function pointer. Aegis closures marshal to a real `cdecl` thunk with the
declared signature, so callback-holding C APIs are reachable directly:

```aegis
extern "C" fn watch_path(interval_ms: Int, on_change: fn(Str) -> Int) -> Int
extern "C" fn drive_board(
    cols: Int, rows: Int, cell: fn(Int, Int, Int) -> Int, ticks: Int) -> Int
```

Callback parameter and return types must be C-scalars (`Int`, `Float`, `Bool`,
the I1 widths, `f32`; `Empty` return maps to `void`), or `Str`. `Str` callback
params are C `char*` values the thunk snapshots into owned Aegis Strings
(runtime `aegis_str_from_cstr`), so the closure sees a durable owned copy.
Containers and `Handle[Tag]` are not yet allowed as callback payloads.

A callback argument must be a closure literal, and its signature must match the
declared `fn(...) -> R` exactly:

```aegis
// 0-finger closure: close over nothing
let watcher = watch_path(250, |s: Str| 0)
// captures a local; the env block rides in the registry, so later ticks see it
let ticks = 0
let done = drive_board(8, 8, |x: Int, y: Int, state: Int| ticks + state, 3)
```

(The motivating sqlite shape — `sqlite3_exec(db, sql, row_cb, arg, out err)`
with `row_cb: fn(Handle[Void], Int, Str, Str) -> Int` — needs `Handle[` and
`char**` callback payloads, which land with the struct-ABI work (I6); scalar
and `Str` payloads already work.)

Each call site that passes a closure generates a pair of functions: the closure
`aegis.lambda.N` (its env block, slot 0 = fn pointer) and the C-facing thunk
`aegis.cb.N` with the exact declared C signature. Before the extern call the
codegen stores the env block in the callback registry keyed by the thunk's own
code address (`aegis_registry_set`); the thunk looks it up again on entry
(`aegis_registry_get`), pulls the closure fn pointer from env slot 0, converts
the C arguments into i64 slots, calls the closure through the slot ABI, and
converts the slot result back (a `void` thunk returns nothing). A thunk whose
env is never unregistered keeps the captures alive for the whole program, so a
callback may fire *after* its calling statement returns — `sqlite3_exec` row
callbacks and UDFs invoked later are safe.

At the callsite the compiled extern call passes the thunk's address where the
signature declares the function pointer; the C side just sees a plain callback.
Signatures are checked precisely — mismatches produce
`callback param N of '...': closure signature ... does not match declared ...`,
non-closure arguments are rejected (`needs a closure literal, got a value`),
and non-scalar/Str callback signatures are rejected at the declaration
(`C callback parameter types must be scalars ... or Str, got ...`).

## C-layout extern structs (I6/I9)

`extern struct` declares a struct whose layout is dictated by C, not by Aegis —
the shape from a C header (`struct stat`, win32 structs), usable directly across
the extern boundary:

```aegis
extern struct Point { x: Int, y: Int }
extern struct Node { data: Int, next: Handle[Node] }
extern struct Stats { size: Int, mode: u32, mtime: Int }
```

Fields are limited to C-as-Aegis data: the C scalars (`Int`, `Float`, `Bool`,
`i8..u64`, `f32`), `Handle[T]`, and nested extern structs. Owned containers and
non-extern Aegis structs are rejected, as are `mut`/`pub` on fields (raw C
memory is always writable). Layout follows the host C compiler's natural packing
so the Aegis declaration and the C struct agree byte-for-byte; on Windows `long`
is 32-bit, so host code should use `long long` for Aegis `Int` fields.

An extern struct crosses the boundary **by value** as a parameter. Codegen picks
the host ABI per target — on Windows x64 aggregates larger than 8 bytes pass by
reference (`ptr`), on SysV up-to-16-byte aggregates pass by value — and
**by pointer** through an `out` slot, which is the `Point*`/`struct stat*` the C
callee writes:

```aegis
extern "C" fn pnt_sum(a: Point, b: Point) -> Int
extern "C" fn pnt_mul(out p: Point, k: Int) -> Empty
// p is a fresh Point*; C fills it, and p.x/p.y read back from the struct
pnt_mul(out p, 10)
```

An extern function may also **return** an extern struct by value (I9), which
mirrors the param ABI: the aggregate returns in registers when it fits the
target's rule (≤8 bytes on Windows x64, ≤16 on SysV) and otherwise through the
C callee's hidden struct-return pointer, which codegen reproduces by passing a
caller-allocated slot as the first argument. The result binds like any struct
local:

```aegis
extern "C" fn pnt_make(x: Int, y: Int) -> Point
let p = pnt_make(30, 4)   // p.x == 30, p.y == 4
```

A non-extern Aegis struct may **not** be returned by value (its layout is
compiler-defined); give the extern function an `out` param instead — the
diagnostic says which type and why. Pointer fields from real headers (e.g.
`struct _Node* next`) are declared as `Handle[Tag]` fields, which ride raw in the
struct and let `null` stand for C `NULL`.

## Sized numeric widths (I1)

Beyond the i64 `Int` / f64 `Float` defaults, the compiler provides the sized
widths used at FFI and systems boundaries:

| Type | LLVM | Notes |
| --- | --- | --- |
| `i8` / `i16` / `i32` | i8 / i16 / i32 | signed, wraps on overflow |
| `u8` / `u16` / `u32` / `u64` | i8 / i16 / i32 / i64 | unsigned; `<`/`<=`/`>`/`>=` and `/`/`%` use unsigned semantics |
| `f32` | f32 | single-precision float |

Sized values are native widths at struct fields, method parameters/returns, and
`extern "C"` signatures — so a C function taking `uint32_t` binds exactly, with
no widening shim. Inside containers (List/Map) and event payloads they ride the
i64/f64 slot ABI, sign- or zero-extending on write and truncating on read.

Literals coerce ergonomically: `let x: u32 = 5` and `c + 1` (a bare integer
literal adopts the other operand's width). Between sized types and the i64/f64
defaults, conversion is explicit via the numeric conversion methods on any
numeric receiver:

```aegis
let a: i8 = 127
let b: i16 = -300
let c: u32 = 4000000000
let d: f32 = 1.5
let narrow = b.to_i8()      // truncates: -300 -> -44 (wraps)
let widen   = a.to_i64()    // 127
let u       = c.to_u64()    // 4000000000
let f64     = d.to_f64()    // 1.5 as f64
let f32     = f64.to_f32()  // back to f32
```

`to_int`/`to_float` (with `to_i64`/`to_f64` aliases) convert to the i64/f64
defaults; `to_i8()..to_u64()/to_f32()` convert to a sized width. Arithmetic
between two different widths is an error unless one side is a bare literal —
convert explicitly otherwise.

## User sum types (enums, L7)

`enum` declares a first-class sum type with named variants; each variant may
carry up to four payload fields (or none):

```aegis
enum Shape {
    Circle(Float),
    Rect(Float, Float),
    Empty,
}
```

Values are built with the variant path, exactly like a `State::Variant`:

```aegis
let c = Shape::Circle(2.0)
let r = Shape::Rect(3.0, 4.0)
let e = Shape::Empty
```

A `match` dispatches on the discriminant and binds payloads; the compiler
**proves coverage** — every variant must be handled (or a `_` catch-all arm
must exist):

```aegis
match s {
    Shape::Circle(radius) => { /* radius: Float */ }
    Shape::Rect(w, h)      => { /* w, h: Float */ }
    Shape::Empty           => { }
}
```

Missing a variant is a compile error: `non-exhaustive match on 'Shape':
missing Rect`. Variant arity and payload types are checked at construction
(`variant 'Shape::Circle' expects 1 payload argument, got 2`).

An enum-typed payload can itself be matched directly in the pattern — a nested
variant chain (`Outer::A(Inner::B(x))`) binds the inner payload and dispatches
on both discriminants; `_` in a payload slot is a wildcard, and a plain-name
bind (`Kind::Pair(inner)`) binds the whole inner enum. Coverage extends one
level: breaking a payload into nested variants requires covering all of them
(see *Nested enum patterns* in the control-flow docs).

## Container ABI

A `List[T]` value is a two-field struct `{ i64 len, ptr handle }`; the handle
points at a `runtime::aegis_list` (`len`, `cap`, `data`, `rc`). The compiler
keeps the logical length mirrored in the value struct so reads do not need a
runtime call; mutations resync it. Strings and maps use the same
pointer-encoded scheme. All containers are reference counted; aliases are
tracked by the compiler and copied where the semantics require it.

## Memory & aliasing

- Stack-by-default: locals are alloca'd in the frame.
- Escape is inferred: values the compiler cannot keep on the stack become
  ARC pointers automatically. There is no `Box` or `Rc` spelling.
- There are **no nulls**. Optionality is modeled with `Option[T]`; the
  compiler tracks unhandled `Option`/`Result` values as an error.
- `mut` is visible to the compiler: assigning through an immutable binding is
  a compile error, as is mutating a list through an immutable binding
  (`xs.pop()` requires a `mut` list).