# Grammar & keywords

## Keywords

Aegis keeps its keyword list small on purpose (context efficiency). The full
set is:

```
struct  impl  fn  loop  while  break  continue
if  else  match  in  state
trait  for  pub  extern  after
let  mut  const  import
requires  ensures  old
emit  on  transition
return  ok  err  some  none
enum
true  false
```

`@module` tags attach a domain namespace to a file (used by the cross-file
`import` path of the spec). Programs without module tags are simple: parse a
file, validate it, emit it.

## Identifiers

An identifier is a letter or `_`, followed by letters, digits, or `_`
(`[A-Za-z_][A-Za-z0-9_]*`). `state` and `transition` are recognized
contextually rather than lexed as keywords, but avoid reusing them as names.

## Operators

Highest precedence to lowest:

| Level | Operators |
| --- | --- |
| unary | `-` (numeric negate), `!` (Bool not), `~` (bitwise not) |
| power | `**` (right-associative) |
| multiplicative | `*` `/` `%` |
| additive | `+` `-` |
| shift | `<<` `>>` |
| comparison | `<` `<=` `>` `>=` |
| equality | `==` `!=` |
| bitwise and | `&` |
| bitwise xor | `^` |
| bitwise or | `\|` |
| logical and (short-circuit) | `&&` |
| logical or (short-circuit) | `\|\|` |

The `&` `|` `^` `~` `<<` `>>` operators are integer-only (natively sized
`i8..u64` or `Int`) and width-exact: bare literals adopt the other operand's
width (same rule as arithmetic), and mixed widths without an explicit
conversion are rejected. Precedence follows C/Rust, so equality binds looser
than `&` — a mask comparison needs parentheses, as in C: `(attrs & 3) == 1`.
A prefix `|` in expression position opens a lambda head (`|x: Int| x * 2`),
never bitwise-or; a match-arm `|` still forms alternatives
(`Kind::Int(n) | Kind::Str(s) => ...`).

`+` also concatenates `Str`, and `==`/`!=` compare strings by content. `**`
is the power operator (`a ** b` desugars to `a.pow(b)`; right-associative,
so `2 ** 3 ** 2` is `2 ** (3 ** 2)`, and `-2 ** 2` is `-(2 ** 2)`). There is
no `++`/`--` (use `+= 1`). Compound assignment `+= -= *= /= %= <<= >>= &= ^=
|=` is supported, each desugaring to a read-modify-write of the same target.

## Top-level items

A source file is a sequence of top-level items:

```
state OrderState { Pending, Paid, Shipped }   // state machine
struct BankAccount { owner: String, mut balance: Int }
struct Box[T] { mut value: T }                // generic struct with type parameter
trait Greeter {                                // method set + contract spec
    requires self.energy > 0
    fn greet(self, name: String) -> String     // declaration, no body
}
impl Greeter for Loud {                        // trait impl
    requires self.energy > 0
    fn greet(self, name: String) -> String { ... }
}
impl BankAccount {
    fn deposit(mut self, amount: Int) -> Empty { ... }
}
struct Order { }
impl Order @ OrderState::Pending {             // state-guarded impl
    fn process_payment(mut self) { ... }
}
```

## Generic structs

Structs can have type parameters, enabling reusable data structures:

```
struct Box[T] {
    mut value: T
}

struct Pair[A, B] {
    first: A,
    second: B
}
```

Instantiate generic structs with concrete type arguments:

```
let int_box = Box[Int] { value: 42 }
let str_box = Box[String] { value: "hello" }
let pair = Pair[Int, String] { first: 1, second: "one" }
```

Generics are instantiated per concrete type: `Box[Int]` is a struct with
`value: Int`, and `Box[String]` is a separate struct with `value: String`.

## Generic methods

Methods can declare their own type parameters, independent of the receiver:

```
impl Util {
    fn identity[T](self, x: T) -> T {
        return x
    }
    fn first[T](self, xs: List[T]) -> T {
        return xs[0]
    }
}
```

Call them with explicit type arguments that ride inside the method name:

```
let v = u.identity[Int](42)
let head = u.first[String](["a", "b", "c"])
let nested = u.identity[List[Int]](xs)
```

A generic method is instantiated per distinct call-site type instantiation,
substituting the type parameters in the parameters, return type, and `let`
annotations. Calling with the wrong number of type arguments (or none at all)
errors with `no method '<name>' on type <Receiver>`.

## Multi-line literals

Struct, list and map literals may span lines. Newlines are allowed between
elements, after commas (a trailing comma before the closing delimiter is fine),
and right after the opening delimiter:

```
let p = Point {
    x: 3,
    y: 4,
}
let xs = [
    1,
    2,
    3,
]
let m = {
    "a": 1,
    "b": 2,
}
```

The block-vs-literal disambiguation is unaffected: `if flag { ... }` still opens
a block (never a struct initializer), because control-flow heads are parsed with
struct-init suppressed. The canonical formatter still prints literals on a
single line.

## Visibility

Structs and fields can be marked as `pub` (public) or left private (default):

```
pub struct PublicBox {
    pub mut value: Int
}

struct PrivateBox {
    mut value: Int
}
```

Public items are accessible from other modules. Private items are only
accessible within their own module. Visibility is enforced at compile time:

- A struct is usable from another module only if declared `pub struct`. Private
  structs can be named, constructed (`Struct { ... }`), field-accessed and
  method-called only inside their own module.
- Inside a `pub` struct, a field is readable/writable from another module only
  if declared `pub` (or `pub mut`). Private fields stay within their module.
- Methods inherit the receiver struct's visibility: a `pub` struct's methods
  are callable cross-module; a private struct's methods are not.
- Same-module access never requires `pub`.

A module is the namespace introduced by the nearest preceding `@module <name>`
tag; items before any tag belong to the root module. `import @<name>` records a
dependency on a module that must exist somewhere in the compiled files.

## Multi-file compilation

The compiler accepts multiple source files and builds a single program from
them:

```bash
aegis lib.aegis main.aegis --main Main::run --emit-exe main
```

All items from all input files are available to each other. This enables
building programs from multiple modules without explicit import statements.

## Archive linking

A compiled program can be packaged into a library archive and later linked into
an executable, so builds can split into a library step and an app link step:

```bash
aegis lib.aegis app.aegis --main App::run --emit-archive app.a
aegis app.a --emit-exe app
```

Object and archive files (`*.o`, `*.obj`, `*.a`, `*.lib`) can be passed directly
to `--emit-exe`: when every input is a compiled artifact the compiler links them
with the runtime. Like `--emit-exe`, `--emit-archive` resolves the entry point
from `--main` or the default `impl X { fn main(self) }` method, so an archive
produced this way links into a running executable.

## Single-command FFI linking

Sources and compiled artifacts can be mixed in one invocation, so FFI builds
never need a manual clang step:

```bash
aegis app.aegis helper.c --main App::run --emit-exe app
aegis app.aegis helper.o libapp.a --emit-exe app
```

The compiler parses the `.aegis` files and passes the object/archive/C inputs
straight to the final link, where a `.c` input is compiled at the link step.
Mixing is only allowed with `--emit-exe`; compiling objects alone (or on their
own with `--emit-obj`) is a usage error. `-l <name>`/`-l<name>` and
`-L <dir>`/`-L<dir>` pass through to the link (as clang `-l`/`-L`):

```bash
aegis app.aegis --main App::run -L lib/generated -l helpers --emit-exe app
```

Archives are found by name (`-l helpers` locates `helpers.lib` on COFF or
`libhelpers.a` on ELF). A search dir alone does not link anything — archives
are only pulled in when named by a `-l`, exactly like gcc/clang.

## Foreign Function Interface (FFI)

Aegis can call C functions using `extern "C"` declarations:

```
extern "C" fn add_numbers(a: Int, b: Int) -> Int
extern "C" fn multiply(a: Int, b: Int) -> Int

struct Suite { }

impl Suite {
    fn run(self) -> Int {
        let sum = add_numbers(10, 20)
        let product = multiply(5, 7)
        return 0
    }
}
```

The extern function must be implemented in C and linked at compile time.
Parameters and return types must be primitive types (Int, Float, Bool, String)
or sized widths or [opaque handles](#opaque-handles). A parameter may instead be
declared `out name: T` — `T*` on the C side: the callee writes a result into a
slot Aegis allocates, and a call passes `out name` to claim it (see
[Out params](../language/types.md#out-params-i3)).

A `-> Str` return is a C `char*` that is at best transient - valid only until
the callee's next call. Aegis copies it into an owned String the moment the
call returns, and a NULL C string reads back as `""`; an `out msg: Str`
readback is copied the same way (see [C-string marshaling](../language/types.md#c-string-marshaling-i4)).

### Opaque handles

A C library that hands back a pointer it owns - a `FILE*`, a `sqlite3*`, a
`HWND` - is declared with `Handle[Tag]`. The tag is a phantom name: nothing
declares it, and it exists only so two handle types cannot be mixed up.

```
extern "C" fn fopen(path: Handle[CStr], mode: Handle[CStr]) -> Handle[FILE]
extern "C" fn fgetc(f: Handle[FILE]) -> Int
extern "C" fn fclose(f: Handle[FILE]) -> Empty

struct Suite { }

impl Suite {
    fn run(self, f: Handle[FILE]) -> Int {
        if f == null {
            return 1
        }
        let c = fgetc(f)
        fclose(f)
        return c
    }
}
```

A handle is exactly one pointer wide and is never dereferenced from Aegis:
`f.value` is rejected with an `opaque` diagnostic, because the C side owns both
the memory and the layout. The only things you can do with one are hand it back
to an extern function, store it, test it against `null`, and compare it for
identity with `==` / `!=`. Ordering (`<`) is rejected - pointers have no order.

`null` is the null pointer. It is only meaningful where a handle is expected, so
it needs an annotation to bind:

```
let f: Handle[FILE] = null     // fine - the tag is known
let f = null                   // rejected: null needs a handle annotation
if f == null { ... }           // fine
```

Because the tag on a bare `null` is unknown, mixing is checked everywhere a
handle travels: passing a `Handle[Db]` where a `Handle[File]` is expected is a
type error, and so is `db == file`.

An extern parameter declared `out name: T` is `T*` and is filled with an
`out name` argument:

```
extern "C" fn sqlite3_open(path: Handle[CStr], out db: Handle[Db]) -> Int

let rc = sqlite3_open(path, out db)   // db: Handle[Db], bound by this call
```

The compiler allocates the slot, passes its address, and binds the callee's
write as a fresh local for the following statements. Only scalar, `Str`, and
`Handle[Tag]` out types are allowed, so the slot width is always known — plus
`out name: CStruct` for C-layout structs (the address of a fresh struct the
callee fills in).

## C-layout extern structs (`extern struct`)

`extern struct Name { f: T, ... }` declares a struct whose layout is owned by
the host C compiler — the shape from a header, not an Aegis-conceived layout:

```
extern struct Point { x: Int, y: Int }
extern struct Box { origin: Point, w: Int, h: Int }
extern struct Node { data: Int, next: Handle[Node] }
extern struct Stats { size: Int, mode: u32, mtime: Int }
```

Fields admit the C scalars (`Int`, `Float`, `Bool`, `i8..u64`, `f32`),
`Handle[T]` (raw pointers from the header, `null` for C `NULL`), and nested
extern structs; owned containers, non-extern structs, and `mut`/`pub` on fields
are compile errors. An extern struct passes **by value** as a param, **by
pointer** through `out name: T` (needed for the `struct stat*` shape), and may be
returned **by value** (a non-extern struct return is still rejected). See
[types: C-layout extern structs](types.md#c-layout-extern-structs).

An extern parameter typed `fn(A, B) -> R` is a C function pointer, and the
argument must be a closure literal whose signature matches exactly:

```
extern "C" fn watch_path(interval_ms: Int, on_change: fn(Str) -> Int) -> Int

let watcher = watch_path(250, |s: Str| 0)          // no capture
let off = 1
let board = drive_board(8, 8, |x: Int, y: Int, s: Int| off + s, 3)  // captures offset
```

Callback payloads are limited to C scalars and `Str`, and `Empty` return maps
to `void`; containers, `Handle[Tag]`, and structs in callback signatures are
rejected (the sqlite row-callback shape `fn(Handle[Void], Int, Str, Str)` needs
`Handle`/`char**` payloads, which are not yet supported). A closure passed as a
callback keeps its captures alive, so the C side can invoke it later.

## Calling Aegis from C (`export fn`)

The other direction is `export fn`: a top-level function whose name becomes a
C-callable symbol with no mangling.

```
extern "C" fn simple_multiply(a: Int, b: Int) -> Int

export fn aegis_add(a: Int, b: Int) -> Int {
    return a + b
}

export fn aegis_scale(x: Int) -> Int {
    return simple_multiply(x, 2)
}
```

Exports are restricted to C-marshalable scalars: `Int`, `Float`, `Bool`, the
sized widths `i8`..`u64` and `f32`, and `void` (a body with no `-> T` arrow).
A `String`, list, or struct parameter is a compile error — C-layout `extern
struct`s cross the *extern* boundary by value/out-param, but `export fn`
signatures stay scalar-only in v1; a struct export is still open.

Export bodies are ordinary Aegis: they may call methods and `extern "C"`
functions. Export functions are host-callable in v1, not Aegis-callable, so an
export cannot recurse into Aegis code that calls it back.

Emit a library with `--emit-lib` (static) or `--emit-dylib` (shared):

```
aegis exports.aegis --emit-lib libaegis.lib      # or libaegis.a on Linux
aegis exports.aegis --emit-dylib aegis.dll       # or libaegis.so on Linux
```

`--emit-lib` writes the Aegis object alone, so the host supplies `main` and
must also link the Aegis runtime that ships with the toolchain.

`--emit-dylib` links the runtime into the shared library itself and, on
Windows, writes the matching import library next to it (`aegis.dll` →
`aegis.lib`), so a host links against the `.lib` and loads the DLL. Neither
mode invents a default `aegis_main`; pass `--main App::run` explicitly if the
host wants a library entry point.

Both flags accept object/C inputs alongside `.aegis` sources (`-l`/`-L` apply
to `--emit-dylib`, not to a static archive, which has no link step).

## Timers and Scheduled Events

Events can be scheduled to fire after a delay using the `after` keyword:

```
struct Timer {
    mut count: Int
}

impl Timer {
    fn start(mut self) -> Int {
        emit Tick(1) after 100
        emit Tick(2) after 200
        emit Tick(3) after 300
        
        on Tick(n: Int) {
            println("tick " + str(n))
            if n >= 3 {
                println("timer suite OK")
            }
        }
        
        return 0
    }
}
```

The delay is specified in milliseconds. The runtime maintains a timer queue
and checks it on each event loop iteration. When a timer expires, the event
is moved to the main event queue for processing.

## Actors

Actors are structs whose instances run independently, driven only by message
events. Declare one with `actor`, create an instance with `spawn`, and deliver
a message with `send`. An `on` handler declared inside an actor's impl captures
the targeted instance as a mutable `self`:

```
actor Counter {
    mut value: Int
}

impl Counter {
    fn create() -> Int {
        on Bump(amount: Int) {
            self.value = self.value + amount
        }
        return 0
    }
}

struct Harness {
    mut seen: Int
}

impl Harness {
    fn run(mut self) -> Int {
        let alpha = spawn Counter { value: 0 }
        let beta = spawn Counter { value: 10 }

        send(alpha, Bump(1))
        send(beta, Bump(3))

        return 0
    }
}
```

- `spawn Name { fields }` builds an actor instance and returns an opaque
  `Actor[Name]` handle; the runtime keeps a private heap copy per instance.
- `send(handle, Event(args))` delivers the event to that exact instance; its
  payload must match the `on` handler's signature.
- A message event can only be delivered with `send`; emitting it plainly is a
  semantic error. Plain events are still emitted with `emit` (target `-1`).
- Actor handles support `==` / `!=`, and the compiler rejects `emit` of a
  message, `send` of a non-message, sending a message to the wrong actor type,
  and spawning a non-actor struct.

## Receivers

Methods take an explicit `self`. Use `mut self` to mutate fields, `self` to
read. Methods are called on values: `account.deposit(100)`. Scalar receivers
may be temporaries (`5.min(9)`, `16.0.sqrt()`, `"hi".is_hi()`); container
receivers (`List`, `Map`) must be named bindings.

A method with no return type (or an explicit `-> Empty`) returns `Empty` and
can be called as a statement: `self.skip_ws()`. To call a `mut self` method the
receiver must be a **mutable binding** — declare it `let mut c = ...`; calling
`c.mutating_method()` on a plain `let` binding is a compile error.

## Reserved words

The keyword set above is reserved: those names are always lexed as keywords and
cannot be used as identifiers (struct names, field names, variable names). For
example a field named `err` is a parse error —
`expected field name, found reserved keyword 'err'` — so spell it `error`.
(This is distinct from `state`/`transition`, which are recognized
contextually, but prefer not to reuse them either.)

## Name resolution & diagnostics

Semantic failures are reported as structured diagnostics with a category,
location, and message, e.g.:

```
semantic error [type] at 17:13: arg 0 of min: expected Int, got Str
```