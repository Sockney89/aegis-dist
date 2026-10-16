# Compilation targets & cross compilation

Aegis lowers to LLVM and emits native objects. Compilation is
*target-parameterized*: `--target <triple>` (or the `AEGIS_TARGET` env var)
selects the triple, and the emitted object follows that target's format
(COFF/ELF) and ABI. When the target equals the host, behavior is unchanged.

## Resolution order

The effective target is resolved once per compilation, highest priority first:

1. an explicit target — CLI `--target`, or the `target` argument on the MCP
   `create_session` / `link_object` tools;
2. the `AEGIS_TARGET` environment variable;
3. the host triple (see `codegen::host_triple`).

The resolved triple is threaded into `Backend::new`, which calls
`LLVMModule::set_triple`, so both codegen and every host-conditional ABI branch
agree on the effective target rather than the build host.

Supported triples (`x86_64` only for now):

| Triple | Object format | Host that builds/link it |
| --- | --- | --- |
| `x86_64-pc-windows-msvc` | COFF `.obj` | Windows (MSVC or clang-cl) |
| `x86_64-unknown-linux-gnu` | ELF `.o` | Linux / WSL (clang + lld) |

## Prebuilt runtime

The C runtime (`compiler/runtime/runtime.c`) normally compiles at link time.
So the compiler can be *distributed as a binary* — without shipping C source —
the runtime also ships as prebuilt per-target objects:

```
compiler/runtime/prebuilt/runtime-<triple>.obj   # COFF
compiler/runtime/prebuilt/runtime-<triple>.o     # ELF
```

Build them in each native environment with:

- `tools/build-runtime-objects.ps1` (Windows host -> MSVC triple)
- `tools/build-runtime-objects.sh` (Linux/WSL host -> ELF triple)

At link time the runtime is resolved in this order:

1. `AEGIS_RUNTIME` — an explicit override, kept for testing a modified
   `runtime.c`;
2. the prebuilt object matching the effective target;
3. `runtime.c` beside the crate, or `./runtime/runtime.c`, compiled with the
   target-aware C driver (the pre-X-track behavior; keeps ad-hoc triples working).

## Linking

`--emit-exe` links through the host `clang`-compatible driver (override with
`AEGIS_CC`) using `--target=<triple> -fuse-ld=lld`. clang then picks the
target-appropriate linker — `lld-link` for `-pc-windows-msvc`, mingw/lld for
`-pc-windows-gnu`, `ld.lld` for `-unknown-linux-gnu`. Per-target system
libraries follow the target too (`-lws2_32` on Windows, `-lm` on POSIX). FFI
`.c` inputs still compile at link time with the same target-aware driver.

Emitting an object for a foreign triple needs no foreign sysroot: the object
format simply follows the requested target. Linking a *foreign* executable, by
contrast, needs that target's libc/sysroot on the host — a toolchain
provisioning concern rather than a codegen one. In practice, build each
platform's executable on that platform (or in a container/WSL with its
toolchain).
