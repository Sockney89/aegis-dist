# Introduction

Aegis is a systems-oriented programming language under active development. It
targets a specific contradiction in modern tooling: LLM-assisted programming
benefits from fluent, invisible abstractions, while systems programming demands
explicit control. Aegis responds with a **deliberately tiny grammar** so that
both humans and models can hold the entire language in one context window.

## Principles

- **Stack-by-default memory.** The compiler allocates on the stack and only
  introduces automatic reference counting (ARC) where data provably escapes
  the current frame. No `Box`/`Rc` spellings: escape is inferred.
- **Errors are values.** There is no `try`/`catch`/`throw`. Functions return
  `Result[T, E]`; the compiler rejects code that ignores an unhandled
  `Result` or `Option`.
- **Design by contract.** `requires` / `ensures` / `old(...)` annotate the
  edges of every function and check them at runtime; the state machine support
  turns "which state is this domain object in" into a compile-checked fact.
- **Concurrency as actors.** No mutexes. Structs communicate via `emit` events
  and `on` handlers. Values are never silently shared between execution
  contexts.
- **Composition, not inheritance.** Data lives in `struct`, behavior in
  `impl`. No `class`, no `extends`.

## Status

Aegis is a working compiler today: you can write structs, contracts, state
machines, event loops, closures, and higher-order list operations, and compile
them to native executables. See [Quickstart](quickstart.md) to install Aegis
and run your first program, and [Roadmap](roadmap.md) for where it is heading.