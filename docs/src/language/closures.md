# Closures & higher-order methods

Lambdas are the expression form `|param: T| expr` and the block form
`|x: T| { ... }`. They are annotated as `Func(params -> result)` where stored
in a typed binding:

```aegis
let inc = |n: Int| n + 1          // Func(Int -> Int)
```

Closures **capture by value** from the enclosing scope: scalars (`Int`, `Float`,
`Bool`) and, since L8, containers — `List`, `Map`, `String`. One-pointer values
capture like scalars too: an `I2` `Handle[T]`, or another closure value (`Func`),
whose nested environment is retained by the capturing env and ARC-released when
the closure is freed. A captured
container is ARC-retained into the closure's environment block and released when
the closure is freed, so captured data stays alive for the closure's lifetime
and is cleaned up after. Capturing a `self` or a `Named` struct is a semantic
error.

A closure body may call anything the surrounding function can: methods on
captured or constructed values, compiler builtins (`print`, `str`, ...), and
`extern "C"` functions. Function names are lowered to direct calls — they are
never captured, so a closure that uses `println` or an extern fn needs no extra
slots.

```aegis
let reader = |x: Int| h_counter_get(c) + x   // captures the handle, calls an extern
let twice = |x: Int| step(step(x))           // captures the closure value `step`
```

```aegis
let rank = {"a": 3, "b": 1, "c": 2}
let names = ["a", "b", "c"]
let ordered = names.sort(|x, y| rank.get_or(x, 0) - rank.get_or(y, 0))
```

A sort comparator (or any `map`/`filter`/`fold` predicate) may read a captured
map or list — the L8 gate pipeline is a filter -> map -> fold over a captured
map with no index bookkeeping.

## Nested closures (L8d)

A lambda may be defined inside another lambda's body. The inner closure reads
the outer closure's params, locals, and captures out of the enclosing scope at
definition time; what it needs that neither binder set covers becomes a
*transitive* capture of the outer closure. Currying works directly:

```aegis
let add = |a: Int| |b: Int| a + b
let add5 = add(5)         // a closure
let r = add5(3)           // 8
add(5)(3)                 // also 8 — any Func-typed expression is callable
```

A block-bodied closure with no `-> Ret` annotation infers its return type from
its `return <expr>`, so a closure that returns a closure types correctly:

```aegis
let mk = |offset: Int| {
    let inner = |x: Int| offset + x
    return inner
}
mk(10)(2)                 // 12
```

## Higher-order list methods

`List[T]` has first-class HOFs, lowered to C-runtime callbacks:

| Method | Signature | Description |
| --- | --- | --- |
| `map(f)` | `List[T].map(Func(T -> U)) -> List[U]` | transform each element |
| `filter(p)` | `List[T].filter(Func(T -> Bool)) -> List[T]` | keep where true |
| `fold(init, f)` | `fold(Func(B -> T -> B)) -> B` | left fold |
| `sort(lt)` | `List[T].sort(Func(T -> Bool)) -> List[T]` | stable sort by predicate |

```aegis
let evens = xs.filter(|x| x % 2 == 0)
let doubled = evens.map(|x| x * 2)
let total = doubled.fold(0, |acc: Int, x| acc + x)
```

`map`/`filter`/`fold`/`sort` return new lists; the input list is not mutated.
HOF predicates must return `Bool` and match the closure arity, both enforced
semantically.