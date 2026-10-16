# Control flow

## Branches

```aegis
if cond { ... } else { ... }
```

`else if` chains are supported and are printed back canonically:

```aegis
if n >= 90 {
    grade = "A"
} else if n >= 80 {
    grade = "B"
} else {
    grade = "F"
}
```

The parser desugars `else if` into a nested `else { if ... }`; the deterministic
formatter recognises that shape and emits `else if` again, so formatting stays
idempotent.

Conditions must be `Bool`; a non-`Bool` condition is a type error.

## Block scope

Every block — an `if`/`else` branch, a `loop` body, and a `match` arm — is its
own scope. A `let` declared inside a block is visible only within that block:

```aegis
if ready {
    let batch = [1, 2, 3]
    println(str(batch.length()))   // ok: 3
}
println(str(batch.length()))       // semantic error [name]: undefined variable 'batch'
```

A block may re-declare (shadow) a name from an enclosing scope. The inner
binding is used inside the block and the outer binding is restored after it:

```aegis
let xs = [1, 2]
if flag {
    let xs = [1, 2, 3, 4]
    // xs.length() == 4 here
}
// xs.length() == 2 again
```

Container locals (`List`, `Map`, closures) declared in a block are released at
the end of that block — and on `break`, `continue`, or `return` out of it — so
per-iteration allocations inside a loop or branch do not leak.

## The single loop

There are no `for(i=0;...)` loops. Iteration and repetition use the keyword
`loop`:

```aegis
loop item in items { ... }   // iteration
loop { ... }                 // infinite; requires break
```

`break` and `continue` are available.

`loop c in s` also walks a `Str` one character at a time, binding `c` to a
fresh single-character `Str` each iteration:

```aegis
loop c in "a b" {
    if c == " " {
        // space
    }
}
```

Individual characters are also reachable with `s[i]`, which yields a
single-character `Str`. The loop pairs naturally with `match` on the
single-char binding (`"0" => ...`, `_ => ...`).

### Map iteration (L8)

`loop (k, v) in m` iterates a map's entries, binding the key to `k` and the
value to `v` each iteration:

```aegis
let scores = {"alice": 10, "bob": 7}
let mut total = 0
loop (name, score) in scores {
    total = total + score
}
```

`k` gets the map's key type and `v` its value type. Iterating something that
is not a `Map` is a type error (`loop (k, v) iterates a Map, got List(Int)`).
Entries arrive in hash-bucket order, which is unspecified — check aggregate
properties or key membership, not any particular sequence.

### Pair views over lists (L8b)

`loop (k, v) in xs.enumerate()` walks a list in order, binding `k` to the
running index (`Int`) and `v` to each element:

```aegis
let xs = ["a", "b", "c"]
let mut out = ""
loop (i, x) in xs.enumerate() {
    out = out + str(i) + x
}
```

`loop (k, v) in xs.zip(ys)` walks two lists in lockstep, binding `k` to `xs[i]`
and `v` to `ys[i]`, stopping at the shorter list:

```aegis
loop (a, b) in xs.zip(ys) {
    // a from xs, b from ys
}
```

`enumerate()`/`zip()` are pair *views*, not first-class values — they are only
valid as the direct iterable of a `loop (k, v) in`; anywhere else they are
unknown methods (`no method 'enumerate' on type List(Int)`). Using them over a
non-list is a type error (`enumerate() requires a List`, `zip() requires two
Lists`).

### User iteration protocol (L8e)

Any struct with a `next(mut self) -> Option[T]` method can be the iterable of
`loop item in x`. The method shape is the protocol, whether `next` is declared
directly or via a trait:

```aegis
struct Range2 {
    mut lo: Int,
    hi: Int,
}

impl Range2 {
    fn next(mut self) -> Option[Int] {
        self.lo = self.lo + 1
        if self.lo >= self.hi {
            return none
        }
        return some(self.lo)
    }
}

let mut r = Range2 { lo: 0, hi: 4 }
let mut total = 0
loop x in r {
    total = total + x
}
```

The loop materializes the iterable into a mutable slot and calls `next()` each
iteration, binding the `some` payload to the item and exiting on `none`.
`break`/`continue` work normally. Iterating a type without `next` is a type
error (`loop item in requires a List, String, or a type with a next() ->
Option[T]`).

## match

Sum types destructure with `match`. Every arm is `pattern => { ... }` — the
body is a statement block and there are no commas between arms:

```aegis
match r {
    ok(v) => {
        println(str(v))
    }
    err(e) => {
        println("failed")
    }
}
```

`|` joins alternative patterns in one arm (`1 | 2 | 3 => { ... }`). `_` is
the catch-all wildcard, usable only as the whole pattern of an arm — it
cannot appear inside a constructor pattern (`err(_)` is not accepted; bind
the field as `err(e)` and ignore `e`). Patterns cover the error
constructors: `ok(v)` / `err(e)` for `Result[T, E]` and `some(v)` / `none`
for `Option[T]`. The compiler rejects unhandled `Result`/`Option`
scrutinees; `?` propagates them.

### Pattern depth (L7)

An arm may carry a **guard** — a Bool expression evaluated after the pattern
matches, with the arm's bindings in scope; a failed guard falls through to the
next arm:

```aegis
match n {
    x if x < 0 => { return "neg" }
    x if x == 0 => { return "zero" }
    _ => { return "other" }
}
```

**Range patterns** match a half-open interval over an `Int` scrutinee:

```aegis
match n {
    0..10 => { /* 0 <= n < 10 */ }
    10..20 => { /* 10 <= n < 20 */ }
    _ => { }
}
```

`|` alternatives may each carry their own payload bindings, dispatched into a
shared body — every alternative's variant counts toward the exhaustiveness
check:

```aegis
match k {
    Kind::Int(n) | Kind::Nil => { return 5 }
    Kind::Str(s) => { return s.length() }
}
```

### Nested enum patterns (L7)

A variant payload that is itself an enum can be matched directly — the inner
payload binds through the two discriminants:

```aegis
match k {
    Kind::Pair(Kind::Int(m)) => { return m }        // inner payload binds m
    Kind::Pair(Kind::Nil) => { return 0 }           // nested unit variant
    Kind::Pair(_) => { return 1 }                   // `_` wildcard payload
    Kind::Int(n) => { return n }
    Kind::Nil => { return -1 }
}
```

A plain-name payload bind (`Kind::Pair(inner)`) still binds the whole inner
enum, which can then be matched separately. Guards can reference nested payload
names (`Kind::Pair(Kind::Int(m)) if m > 10 =>`). Exhaustiveness extends one
level: when a payload is broken out into nested variants, all of its variants
must be covered too — `Kind::Pair(Kind::Int(n))` alone reports
`non-exhaustive match on 'Kind': missing Pair, Nil inside Pair::Kind`. A `_` or
plain-name payload bind counts as a catch-all for the inner enum.

## Errors as values

Functions signal failure by returning `Result[T, Error]` (or `Option`). A
`?` propagates the error out of the enclosing function; otherwise a returned
`Result`/`Option` must be destructured before the program is accepted.

`ok`, `err`, `some`, and `none` are expressions (a payload is optional, so a
bare `ok` is valid). A method that returns nothing — no return type, or an
explicit `-> Empty` — must use a bare `return`; `return ok` is only valid when
the method's return type is a `Result`.