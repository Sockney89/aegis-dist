# Real project: wordfreq CLI

The **wordfreq** project is a complete, two-module console application. It
exercises the same surface a normal CLI needs: cross-module visibility, a
`Map[String, Int]` accumulator, `List` iteration, `argc()`/`arg(i)` argv
parsing, and output formatting by string concatenation (`str(v)` + `+`).

## Layout

| File         | Role                                                                    |
|--------------|-------------------------------------------------------------------------|
| `lib.aegis`  | `@module wordfreq`; `pub struct Frequencies` + `add` + `order_by_count` |
| `main.aegis` | `@module wordfreq_main`; `import @wordfreq`; `App::main` entry (default) |

## Build

One compiler command for the whole project, no hand-written C:

```text
aegis main.aegis lib.aegis --emit-exe wordfreq.exe
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

## Notes on working around today's limits

The v1 closure rule (scalar captures only) means a `sort` comparator cannot
read the counts map, and index assignment targets are not yet supported, so
`order_by_count` is an explicit selection-sort over first-seen words
(`taken: Map[String, Bool]` guards extraction). The app reads via
`self.counts[w]` and appends into fresh lists — no index writes required.

# Flagship: the dungeon adventure

`examples/dungeon.aegis` is a stress test for the standard library: a
deterministic, argv-driven text adventure. Compiled alongside the seed modules
(`stdlib/mathstr.aegis`, `stdlib/stack.aegis`, `stdlib/set.aegis`), it runs a
fixed command script:

```text
aegis stdlib/mathstr.aegis stdlib/stack.aegis stdlib/set.aegis \
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

Two language rules worth knowing when writing similar programs:

- command dispatch is a `match` on the verb string,
- struct literals must be single-line (statements are newline-terminated);
  nested literals are fine as long as the whole literal stays on one line.

## SQLite FFI (example)

See `examples/ffi` for a minimal SQLite FFI example using `extern "C"`,
prepared statements, integer widths, and error handling. It includes a C helper
and notes for Windows (`winsqlite3.dll`).
