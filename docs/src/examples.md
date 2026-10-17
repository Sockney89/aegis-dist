# Real project: wordfreq CLI

The **wordfreq** project is a complete, two-module console application —
the first "real project" built start-to-finish with the Aegis compiler. It
exercises the same surface a normal CLI needs: cross-module visibility, a
`Map[String, Int]` accumulator, `List` iteration, `argc()`/`arg(i)` argv
parsing, and output formatting by string concatenation (`str(v)` + `+`).

The app was written to run on the compiler as-is. Along the way it surfaced
two real compiler bugs that are now fixed:

- an empty-map literal in a typed `let` (`let mut taken: Map[String, Bool] = {}`)
  was silently typed `Map[Any, Any]`, so later `counts[w]` reads type-checked
  against `Any`; the annotated type is now honored,
- nested short-circuit conditions (`a || (b && c)`) mis-lowered the join phi
  so the emitted IR failed LLVM verification; the RHS result is now attributed
  to the block it is actually produced in.

## Layout

| File                | Role                                                        |
|---------------------|-------------------------------------------------------------|
| `lib.aegis`         | `@module wordfreq`; `pub struct Frequencies` + `add` + `order_by_count` |
| `main.aegis`        | `@module wordfreq_main`; `import @wordfreq`; `App::main` entry (default) |
| `wordfreq_ref.c`    | a C reference with the same algorithm, for size/speed comparison |

## Build

One compiler command for the whole project, no hand-written C:

```text
compiler main.aegis lib.aegis --emit-exe wordfreq.exe
```

The entry point is `App::main`, found automatically as the default entry.
Running it:

```text
> wordfreq.exe the quick brown fox the lazy dog the
the: 3
brown: 1
dog: 1
fox: 1
lazy: 1
quick: 1
----
tokens=8 unique=6
```

## Measurements (Windows, x86_64-pc-windows-msvc)

A whole-project build (both files, codegen + link):

```text
full project build (--emit-exe):   ~1.2 s
aegis object file:                 3,564 B   (text 1,434 + data 143)
```

Executable sizes (static CRT, runtime always linked):

```text
wordfreq.app (aegis)          172,544 B
wordfreq_ref.c, clang -O0     148,480 B
wordfreq_ref.c, clang -O2     150,016 B
```

The Aegis exe is dominated by a constant floor shared with every `--emit-exe`
program — hello/fizzbuzz/wordcount are all 171,008 B — from the statically
linked CRT plus the full runtime compiled at `-O0` and linked without section
GC. It is currently ~23 KB over the C reference and ~22 KB under the constant
floor plus app code; closing the gap means opting the runtime compile and the
object emit into real optimization (an ongoing area — see the roadmap).

Runtime performance:

```text
wordfreq, 1,000-token argv        aegis 13.1 ms | C -O0 12.4 ms | C -O2 12.5 ms
compute loop, 10 M iterations     aegis 36.2 ms | C -O0 35.1 ms | C -O2 12.3 ms
```

The CLI is process-startup bound (all three within noise). The compute loop is
the interesting number: emitted Aegis code runs at clang `-O0` speed — LLVM's
instruction selection already matches the baseline — and is ~3× off `-O2`,
which is exactly the optimizer gap the pass pipeline will close. The reference
is kept in the tree so the numbers can be re-derived.

## Notes on working around today's limits

The v1 closure rule (scalar captures only) means a `sort` comparator cannot
read the counts map, and index assignment targets are not yet supported, so
`order_by_count` is an explicit selection-sort over first-seen words
(`taken: Map[String, Bool]` guards extraction). The app reads via
`self.counts[w]` and appends into fresh lists — no index writes required.

# Flagship: the dungeon adventure

`examples/dungeon.aegis` is the flagship stress test for the standard library:
a deterministic, argv-driven text adventure. Compiled alongside the seed
modules (`stdlib/mathstr.aegis`, `stdlib/stack.aegis`, `stdlib/set.aegis`), it
runs a fixed command script:

```text
compiler stdlib/mathstr.aegis stdlib/stack.aegis stdlib/set.aegis \
         examples/dungeon.aegis --main Dungeon::run --emit-exe dungeon.exe
dungeon.exe "go north" "go north" "take" "go south" "go east" "attack" "go north" "open" "look"
```

A single run exercises a native **state machine** (the treasure gate,
`Gate @ GateState::Locked` → `Unlocked`), **contracts**
(`requires self.room == 3` on `attack`), `Map`/`List` builtins, the
`Stack`/`Set` seed collections (the action history is a `Stack[String]`, visited
rooms a `Set[Int]`), **string parsing** (`trim` / `to_lower` / `split`), seeded
**randomness** (combat), and **file IO** (the run summary is written and read
back). The transcript ends `gold=100 hp=26 rooms=5 steps=9`.

Writing it pinned three language limits worth knowing:

- **`else if` was missing** at the time — command dispatch is a `match` on the
  verb string (this has since been implemented),
- struct literals must be single-line (statements are newline-terminated);
  nested literals are fine as long as the whole literal stays on one line.