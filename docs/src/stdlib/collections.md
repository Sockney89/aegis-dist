# Collections

Beyond the builtin containers, the standard library ships seed collections
written in Aegis itself under `stdlib/`. Each is generic: `Stack[T]`, `Set[T]`,
`Queue[T]`, `Deque[T]` are monomorphized into one concrete struct per element
type used (`Stack[Int]`, `Stack[String]`, ...) so a single stdlib definition
serves every element type.

## Stack (`stdlib/stack.aegis`)

```aegis
struct Stack[T] { mut items: List[T] }

impl Stack[T] {
    fn push(mut self, v: T) -> Empty
    requires !self.is_empty()
    fn pop(mut self) -> T
    requires !self.is_empty()
    fn peek(self) -> T
    fn is_empty(self) -> Bool
    fn len(self) -> Int
}
```

`push`/`pop` are O(1) over the list-backed buffer (`pop` uses the native
`List.pop()`). `peek` and `pop` are guarded by a `requires` contract, so a
program that pops an empty stack aborts with the requires diagnostic at
runtime.

```aegis
let s = Stack[Int] { items: [] }
s.push(10)
s.push(20)
let top = s.pop()        // 20
let n = s.len()          // 1

let names = Stack[String] { items: [] }
names.push("aegis")
names.pop()              // "aegis"
```

## Set (`stdlib/set.aegis`)

A `Map`-backed set of elements. `Map.remove` is a native builtin (see
[String operations](string.md)), so `remove` on a missing key returns `false`
rather than aborting. v1 `Map` keys support `Int`, `Bool`, and `String`, so
`Set[T]` instantiates for those element types only.

```aegis
struct Set[T] { mut data: Map[T, Int] }

impl Set[T] {
    fn add(mut self, v: T) -> Empty
    fn remove(mut self, v: T) -> Bool  // false if absent
    fn contains(self, v: T) -> Bool
    fn is_empty(self) -> Bool
    fn len(self) -> Int
}
```

```aegis
let s = Set[Int] { data: {} }
s.add(10)
s.add(10)          // no-op, still length 1
s.contains(10)     // true
```

## Queue (`stdlib/queue.aegis`)

A FIFO queue backed by a grow-only `List` with a `head` index. `pop`/`peek`
are guarded by `requires !self.is_empty()`.

```aegis
struct Queue[T] { mut items: List[T], mut head: Int, mut len: Int }

impl Queue[T] {
    fn push(mut self, v: T) -> Empty
    requires !self.is_empty()
    fn pop(mut self) -> T
    requires !self.is_empty()
    fn peek(self) -> T
    fn is_empty(self) -> Bool
    fn len(self) -> Int
}
```

```aegis
let q = Queue[Int] { items: [], head: 0, len: 0 }
q.push(5)
q.push(6)
q.pop()            // 5 (FIFO order)
```

## Deque (`stdlib/deque.aegis`)

A double-ended queue implemented as two grow-only `List` stacks: `front` holds
its elements reversed (live element at the end) and `back` holds them in order.
`push`/`pop` at either end are amortized O(1) — when one side empties, the other
is reversed into it (`List.reverse()` is a native builtin). `peek` never mutates:
it reads the far element of whichever side is populated. All four end operations
are guarded by `requires !self.is_empty()`.

```aegis
struct Deque[T] { mut front: List[T], mut back: List[T] }

impl Deque[T] {
    fn push_front(mut self, v: T) -> Empty
    fn push_back(mut self, v: T) -> Empty
    requires !self.is_empty()
    fn pop_front(mut self) -> T
    requires !self.is_empty()
    fn pop_back(mut self) -> T
    requires !self.is_empty()
    fn peek_front(self) -> T
    requires !self.is_empty()
    fn peek_back(self) -> T
    fn is_empty(self) -> Bool
    fn len(self) -> Int
}
```

```aegis
let d = Deque[Int] { front: [], back: [] }
d.push_back(2)
d.push_front(1)
d.peek_front()     // 1
d.peek_back()      // 2
d.pop_front()      // 1
d.pop_back()       // 2
```

## Map enumeration (`keys` / `values` / `get_or`)

The native `Map[K, V]` gained (M5) a non-aborting lookup and entry
enumeration, so maps can be traversed without knowing the keys in advance:

| Method | Returns | Notes |
| --- | --- | --- |
| `get_or(k, default)` | `V` | the value, or `default` when `k` is absent (unlike `m[k]`, which aborts) |
| `keys()` | `List[K]` | fresh list of the live keys (hash order) |
| `values()` | `List[V]` | fresh list of the live values, matching `keys()` order |

```aegis
let mut m = {"a": 1, "b": 2, "c": 3}
let ks = m.keys()
let vs = m.values()
let mut total = 0
loop v in vs {
    total = total + v
}
let hit = m.get_or("a", 0)      // 1
let miss = m.get_or("z", -1)    // -1
```

`keys()` / `values()` allocate, so (like other list-valued results) bind the
result to a name before calling further methods on it.

## Generic impls

The `impl Stack[T]` blocks above are templates: the compiler expands one
concrete impl per used instantiation (`Stack[Int]`, `Stack[String]`, ...),
substituting the struct's type parameters in the method signatures and bodies.
The type arguments in the impl must be the struct's own parameter names
(`impl Stack[T]` for `struct Stack[T]`); an impl pinning concrete types
(`impl Container[Int]`) remains a hand-written impl on that one instantiation.
An arity mismatch (`impl Stack[Int, String]`) is a compile error.

## Roadmap

The M7 continuation still calls for JSON pretty-printing and a richer L6 string
formatter. Struct-keyed maps are deliberately out of scope: structs are
mutable, so a mutated key would invalidate its hash slot — encode composite
keys as a `String` instead. See [Roadmap](../roadmap.md).
in the repo root.