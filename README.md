# Aegis

Aegis is a contract-aware, event-driven systems language: a deliberately tiny
grammar with stack-by-default memory and a compiler that treats AI as a
first-class authoring mode.

This repository hosts the **public distribution** for Aegis: the documentation
site, the installers, and the prebuilt release binaries. The compiler source is
maintained privately; the binaries here are closed-source (proprietary), shipped
under the `LICENSE` and `NOTICE` included in every release archive.

## Install

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/Sockney89/aegis-dist/main/install.ps1 | iex
```

**Linux (x86_64):**

```sh
curl -fsSL https://raw.githubusercontent.com/Sockney89/aegis-dist/main/install.sh | sh
```

Both installers download the latest release, verify its SHA-256 checksum, and
install to a per-user directory (`%LOCALAPPDATA%\Aegis` on Windows, `~/.aegis`
on Linux). Pin a version with `-Version 0.1.0` (PowerShell) or
`--version 0.1.0` (shell).

> Building a standalone executable (`compiler --emit-exe`) needs a
> clang-compatible C compiler at runtime, selected via the `AEGIS_CC`
> environment variable (e.g. `C:\LLVM\bin\clang.exe`). The compiler itself has
> no other external dependencies.

## What you get

- `compiler` — the Aegis compiler (`--emit-obj`, `--emit-exe`, `--emit-lib`).
- `aegis-mcp` — a Model Context Protocol server exposing sessions and the
  language spec to AI agents.
- `aegis-daemon` / `aegis-ws` — the streaming server and its client.
- `runtime/prebuilt/` — the per-target runtime objects the compiler links.
- `stdlib/` and `docs/` — the seed standard library and the language reference.

## Scoop (Windows)

```
scoop bucket add aegis https://github.com/Sockney89/aegis-dist
scoop install aegis
```

## Documentation

The human-readable book lives at
<https://sockney89.github.io/aegis-dist/> (source mirrored from the private
project under `docs/`). Two AI-oriented corpora, `llms.txt` and
`llms-full.txt`, are published at the repository root.

## License

- Installer scripts and site configuration: MIT (see `LICENSE`).
- Documentation content: CC BY 4.0 (see `LICENSE-DOCS`).
- Released binaries: proprietary (`LicenseRef-Proprietary`); see the `LICENSE`
  and `NOTICE` files inside each release archive, including the third-party
  attribution for the statically linked LLVM and its runtimes.
