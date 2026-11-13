# Tooling: the `aegis` CLI

Every release ships a single front-end, `aegis`, next to the compiler and the
services. It is the recommended entry point:

```
aegis init        register the MCP server with your agent host
aegis mcp         run the MCP stdio server
aegis daemon      run the streaming WebSocket server
aegis ws          run the WebSocket client
aegis version     print the version
aegis <args...>   forward to the compiler
```

The last form forwards everything after `aegis` to the compiler, so
`aegis hello.aegis --main Greeter::greet --emit-exe hello` is exactly
`compiler hello.aegis --main Greeter::greet --emit-exe hello`.

## Project workflow

For multi-file projects, Aegis supports a manifest (`aegis.toml` or
`aegis.json`) plus a small set of project commands:

```
aegis new myapp        # scaffold aegis.toml + src/main.aegis + src/lib.aegis
aegis build            # compile per manifest (auto-detects aegis.toml)
aegis check            # parse + type-check only (no binary emission)
aegis run              # build, then run the resulting binary
aegis update            # check and update the installed toolchain
```

`aegis.toml` schema:

```toml
name = "myapp"
version = "0.1.0"
sources = ["src/**/*.aegis"]   # globs, relative to the manifest
main = "App::main"             # optional; defaults to App::main / Main::run / any `main(self)`
stdlib = "stdlib"              # optional path to stdlib
target = "x86_64-pc-windows-msvc"  # optional
```

`aegis build` expands the source globs, compiles all files into one program,
and (by default) emits `<name>.exe`. `aegis check` stops after semantic
analysis for fast agent feedback. Ad-hoc compiles without a manifest still work
via positional files: `aegis foo.aegis bar.aegis --emit-exe app`.

`aegis update` (also available as `aegis upgrade`) downloads the latest stable
platform release, verifies its SHA-256 checksum, stages the archive, and updates
the installed toolchain. Use `--check` to avoid installation, `--dry-run` to
show the selected release, `--version V` to pin a release, and `--force` to
reinstall the current version. The update does not modify project files, agent
configuration, PATH, or `AEGIS_CC`.

The compiler also accepts `--manifest PATH`, `--check`, and a directory
positional (expands to its top-level `.aegis` files).

## Registering an agent: `aegis init`

`aegis init` writes the `aegis-mcp` server into the config file of an agent host,
merging into any existing file so other servers are preserved:

```
aegis init --tool opencode     # also: claude, cursor, vscode, windsurf, codex, all
```

| Flag | Meaning |
| --- | --- |
| `--tool <name>` | Which host to configure (`opencode`, `claude`, `cursor`, `vscode`, `windsurf`, `codex`, or `all`) |
| `--global` | Write the user-level config instead of the project one |
| `--cc <path>` | Set `AEGIS_CC` (the C compiler used for the final link step) |
| `--force` | Accepted for symmetry; the `aegis` entry is always refreshed |

With no `--tool`, `init` detects the host from the current directory (an existing
`opencode.json`, `.cursor/`, `.vscode/`, `.mcp.json`, `mcp_config.json`, or
`.codex/`) and defaults to opencode when nothing is found. The registered
command is the absolute path to `aegis-mcp`, so the server needs no arguments.

| Host | Config file (project) | `--global` location |
| --- | --- | --- |
| opencode | `opencode.json` | `~/.config/opencode/opencode.json` |
| Claude Code | `.mcp.json` | `~/.claude.json` |
| Cursor | `.cursor/mcp.json` | `~/.cursor/mcp.json` |
| VS Code | `.vscode/mcp.json` | (project only) |
| Windsurf | `mcp_config.json` | `~/.codeium/windsurf/mcp_config.json` |
| Codex | `.codex/config.toml` | `~/.codex/config.toml` |

Restart the host after `init` so it picks up the server.

One environment variable matters to the server:

- `AEGIS_CC` names a `clang`-compatible C compiler. It is needed only to produce
  a standalone executable (`--emit-exe`) or to link and run an object over MCP
  (for example `C:\LLVM\bin\clang.exe` on Windows or `/usr/bin/clang` on Linux).
  `aegis init` records it in the server's environment; when it is unset, the
  tools that build executables report a clear error. Streaming, object emission,
  and formatting need no C compiler at all.

## What the agent gets

Once registered, the host sees the Aegis streaming pipeline as MCP tools and
the language corpus as MCP resources. The canonical loop is:

```
create_session  ->  stream_source  ->  eos  ->  link_object  ->  run_object
```

`create_session` opens an isolated compile session (optionally `--target` and a
workspace for C-WAL reopen); `stream_source` pushes source item by item with live
unresolved warnings; `eos` runs the end-of-stream gate and the full semantic
pass; `link_object` produces an executable; `run_object` executes it. The corpus
is served as `aegis://docs/<page>` and `aegis://stdlib/<module>`, plus
`aegis://llms.txt` and `aegis://llms-full.txt` for a one-shot bootstrap.

## Hot-swap (experimental)

`Module` and `actor_hot_swap` provide *state migration*, not in-place code
replacement: a new module is loaded, its migrate entry point runs on the
actor's current state, and the module is then unloaded. Event handlers stay
compiled into the host program, and `export fn` is scalar-only (no `Str`), so
formatting logic cannot live in a swappable module. On Windows, build
replacement modules under versioned filenames (`module_v2.dll`) because a
loaded DLL cannot be overwritten.

## Stripping symbols

Pass `--strip` to `--emit-exe`/`--emit-dylib`/`--emit-lib` to strip the
linked output (`-s` to the C driver). Useful for release builds where debug
symbols and internal names should not ship.

## Rebuilds, WAL reopen, and file locks

`create_session` reopens a workspace's project WAL when one exists, so a
session created in a directory that already has a `.aegis/wal.log` starts
with the previously streamed items. To rebuild from scratch, pass
`"reset": true` (which clears `wal.log` and `snapshot.json`) or stream only
the changed items into the reopened session. Re-streaming a whole file into
a session that already contains it produces duplicate-definition errors.

On Windows a running executable or a loaded DLL cannot be overwritten:
`link_object` then fails with `permission denied`. Link test builds to a new
path (`app_v2.exe`, `module_v2.dll`) or stop the running process first.
`run_object` waits for the process to exit; pass `background: true` (or launch
out of band) for a long-running app. It returns a pid and does not capture
output.

## Manual registration

`aegis init` is a convenience; the config is plain JSON (or TOML for Codex). For
opencode, for example:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "aegis": {
      "type": "local",
      "command": ["C:/Aegis/bin/aegis-mcp.exe"],
      "enabled": true,
      "environment": { "AEGIS_CC": "C:/LLVM/bin/clang.exe" }
    }
  }
}
```

For Claude Code or Cursor, the same server goes under `mcpServers` with
`command`, `args`, and `env`. On Windows, `register-opencode.ps1` (shipped in the
archive) remains available for opencode-only setups.

## One installation, one compiler

The agent host talks to exactly one aegis-mcp server, which resolves its corpus and
stdlib relative to its own executable. Keep a single Aegis install on the machine:
leftover copies (for example under `C:\Users\<you>\AppData\Local\Aegis`) are
older builds that the agent may discover and prefer over the registered one.
Remove them after upgrading. The compiler prints its build identity on every run
(`Parsed N top-level items` is followed by the binary's own version in verbose
mode), and `aegis version` reports the toolchain version.

## MCP resources (the language corpus)

The MCP server exposes the entire language corpus as resources. `resources/list`
returns one entry per page/module plus the two aggregate corpora:

| URI pattern | Content |
| --- | --- |
| `aegis://docs/<page>` | A markdown page from `docs/src/` (e.g. `aegis://docs/stdlib/http.md`) |
| `aegis://stdlib/<module>` | A seed module (e.g. `aegis://stdlib/http.aegis`) |
| `aegis://llms.txt` | Compact table of contents of the whole corpus |
| `aegis://llms-full.txt` | The entire corpus concatenated (~65 KB) |

The server must be initialized (the host sends `initialize` then
`resources/list`) before resources are readable; a "method not found" on
`resources/list` usually means the host has not finished initialization or the
server was started without `--docs`/`--stdlib`. Restart the host after
`aegis init`.
