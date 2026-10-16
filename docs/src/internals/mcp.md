# aegis-mcp: the compiler as MCP tools & resources

`aegis-mcp` is a Model Context Protocol server that exposes the streaming
compiler to AI coding agents. Where `aegis-daemon` is a network service for
shell clients, `aegis-mcp` runs **in-process, on stdio**: an agent host such as
opencode spawns it, makes JSON-RPC calls, and gets back tool results and spec
documents. Sessions live inside the server process and persist across calls.

```
opencode (agent)  <--stdio JSON-RPC 2.0-->  aegis-mcp  (in-process StreamCompiler sessions)
                      tools, resources
```

## Running it

```powershell
aegis-mcp [--docs DIR] [--stdlib DIR] [--llms PATH] [--llms-full PATH] [--compiler EXE]
```

- `--docs`/`--stdlib`/`--llms`/`--llms-full` point the **resource** surface at
  the language corpus. When a flag is omitted, the server resolves that path
  relative to its own executable (an installed layout of
  `<root>/bin/aegis-mcp.exe` with `<root>/docs/src`, `<root>/stdlib` and
  `<root>/llms*` next to it works with **no flags**), then falls back to the
  working directory. Pass absolute paths to point anywhere explicitly.
- `--compiler` locates the batch compiler used by `link_object`; default: the
  `compiler` binary next to `aegis-mcp`. `link_object` also needs `AEGIS_CC`
  and `AEGIS_RUNTIME` in the server environment.

## Distributing & installing

`tools/package.ps1` stamps the whole toolchain into a relocatable
`dist/Aegis-<version>.zip`:

```powershell
& .\tools\package.ps1 [-Build] [-Version 0.1.0]
```

The bundle is a folder that works from anywhere — `bin/` (all four binaries),
`runtime/runtime.c`, `stdlib/`, `docs/src/`, `llms.txt`, `llms-full.txt`,
`README.txt` and `register-opencode.ps1`. The binaries statically embed LLVM
and the CRT, so there is nothing else to install; the only external
requirement, clang for the final `--emit-exe` link, is selected through
`AEGIS_CC`.

`register-opencode.ps1` wires the installed server into opencode with the
minimal command (the server self-discovers its corpus), per project or
globally:

```powershell
.\register-opencode.ps1                          # <pwd>\opencode.json
.\register-opencode.ps1 -Global                  # ~/.config/opencode/opencode.json
.\register-opencode.ps1 -Global -Cc C:\LLVM\bin\clang.exe -Runtime C:\aegis\runtime\runtime.c
```

## Transport & protocol

One JSON document per line on stdin, one JSON document per line on stdout
(newline-delimited JSON-RPC 2.0; no HTTP or WebSocket framing).

Lifecycle: `initialize` (server advertises `tools` + `resources` capabilities),
`notifications/initialized`, then `tools/*`, `resources/*`, `ping` calls;
`shutdown` request, then the `exit` notification or stdin EOF. The server never
initiates messages, so a client can talk lockstep — write a request, read one
response.

Unknown methods answer JSON-RPC `-32601`; malformed tool input answers
`-32602`; a failed tool call still returns a `result` whose `content` text is
the report and whose `isError` is `true`.

## Tools

Tool names are advertised unqualified (`create_session`, `stream_source`, ...).
Hosts may namespace them under the server name: opencode, for instance, exposes
`aegis_create_session`, `aegis_stream_source`, `aegis_eos`, `aegis_link_object`,
`aegis_run_object`, and so on.

| Tool | Purpose |
| --- | --- |
| `create_session` | open an isolated live session (`workspace`, `emit_obj`, `main S::m`, optional `stdlib`) → `session_id`. `emit_obj` resolves against `workspace` when relative. When the workspace has a project C-WAL (`<workspace>/.aegis/wal.log`), its recorded chunks replay first so an existing program is live immediately (`reopened from wal (N items)`) and only new changes need streaming. |
| `stream_source` | stream **one** top-level item as Aegis source (parsed in the server); returns the live `stream` report |
| `chunk_source` | split a `.aegis` file into wire chunks (one JSON line per top-level item) |
| `eos` | close the stream, run full analysis; on a gate failure the session **stays live** |
| `sync` | freeze to `<workspace>/.aegis/snapshot.json` |
| `rollback` | restore from the last snapshot; compacts the project C-WAL to the restored item set |
| `link_object` | `compiler <object> [extra C sources] --emit-exe <exe>`; with `session_id`, relative `object`/`exe` resolve against the session workspace. Optional `sources` (array of `.c` paths, an FFI helper) are compiled by clang alongside the object and runtime |
| `run_object` | run a linked executable, capture stdout+stderr (`args` is a space-separated string; stdin is closed); with `session_id`, a relative `exe` resolves against the workspace and runs there |
| `read_corpus` | read a byte window of a corpus resource (`uri`, optional `offset`/`length`) to page a large document |
| `close_session` | drop the session |

A session behaves exactly like a daemon connection: streaming a chunk that
references a missing symbol returns a live `stream` report with a warning that
clears the moment the defining chunk arrives; `eos` with unresolved references
returns `"ok": false` and keeps the session open so the fix can be streamed and
the stream re-closed. Generic structs/methods are monomorphized at `eos`
(matching the batch pipeline), so `Box[Int]` streamed over MCP resolves
correctly. `link_object` emits the executable with the same batch
linking path as the CLI (`compiler app.o --emit-exe app.exe`); extra `.c` FFI
sources are passed to the linker and compiled with the runtime. The `sources`
parameter tolerates a JSON array or a JSON-encoded string (some hosts
serialize array params as strings); each path resolves against the session
workspace. Any other shape (e.g. a `{"item": ...}` wrapper) is rejected with
an explicit error rather than silently dropped, so a mistyped FFI source
cannot masquerade as undefined symbols at link time. Without `create_session`'s
`main`, the object has no `aegis_main`
and will not link.

`stream_source` accepts raw Aegis for a single top-level item
(`struct`, `impl`, `state`, `on`, ...); pass multiple items separately. Raw
wire chunks (`{"schema":4,"item":...}`) from a `chunk_source` call or a file
can be streamed too, since the wire schema is shared.

### Stdlib preload

Seed modules are not auto-loaded. Pass `stdlib` to `create_session` to have the
server stream their items into the session up front: a comma-separated list
(`"mathstr,stack"`) or `"all"`. The session note reports what was loaded
(`preloaded stdlib [mathstr, stack]`), so a streaming agent gets
`String.is_digit`, `Stack`, `Set` and `Queue` without streaming the module by
hand.

### Project reopen (C-WAL quick load)

Every top-level item streamed through `stream_source`/`stream_item` is written
to the project C-WAL (`<workspace>/.aegis/wal.log`, the S2 write-ahead log) as a
`chunk` record carrying its S3 wire encoding, fsync'd before the item is taken
in. Opening a session on a workspace that already has a WAL replays those
records first, so an existing program is live immediately — its items are in the
session, its symbol table is populated, and only *new* changes need streaming.
The session note reports `reopened from wal (N items)`.

- **Stdlib is not part of the WAL.** Preloads are re-applied from disk per
  session, so a crash mid-preload can never duplicate items in the log.
- **`rollback` compacts the WAL.** Restoring a snapshot rewrites the log
  atomically (`Wal::rewrite`, tmp+rename, fresh monotonic tx ids) to exactly the
  restored item set, so a rolled-back chunk never resurrects on the next reopen.
- A session closed without `eos` still leaves its chunks durable in the WAL;
  nothing needs re-streaming to reopen it.

### Corpus paging

`resources/read` caps a body at 12 KB and appends a pointer to `read_corpus`
when it truncates. The full corpus (`aegis://llms-full.txt`) is ~65 KB and
should be paged: `read_corpus` takes `offset` and an optional `length` (default
window 8 KB) and returns a header line
`[corpus <uri> bytes <a>..<b> of <total> | next_offset=<b>]` (or `| end`),
followed by the text. Read `aegis://llms.txt` for the table of contents, then
either per-page docs (`aegis://docs/<path>`) or a paged `llms-full.txt`.

## Resources

The language corpus is served as read-only resources so a fresh agent session
can bootstrap by reading the specs instead of needing them copied into place:

| URI | Content |
| --- | --- |
| `aegis://docs/<relpath>` | markdown pages from `docs/src` (e.g. `aegis://docs/language/types.md`) |
| `aegis://stdlib/<relpath>` | stdlib sources from `stdlib` |
| `aegis://llms.txt` | the corpus TOC |
| `aegis://llms-full.txt` | the entire corpus in one document |

`resources/read` resolves paths against the configured roots and rejects paths
that escape them.

## Registering with opencode

Add to the project's `opencode.json` (prefixed with the repo root — the server
needs absolute paths for the corpus):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "aegis": {
      "type": "local",
      "command": ["compiler\\target\\release\\aegis-mcp.exe", "--docs", "C:\\opencode\\aegis\\docs\\src", "--stdlib", "C:\\opencode\\aegis\\stdlib", "--llms", "C:\\opencode\\aegis\\llms.txt", "--llms-full", "C:\\opencode\\aegis\\llms-full.txt"],
      "enabled": true,
      "environment": {
        "AEGIS_CC": "C:\\LLVM\\bin\\clang.exe",
        "AEGIS_RUNTIME": "C:\\opencode\\aegis\\compiler\\runtime\\runtime.c"
      }
    }
  }
}
```

opencode reads MCP config once at startup — restart the editor/session after
editing the file.

## Authoring flow through the agent

1. `resources/read aegis://llms.txt` for the table of contents, then read the
   parts you need — per-page `aegis://docs/*`, or `read_corpus` to page
   `llms-full.txt` (it is too large for one read).
2. `create_session` with a workspace, `emit_obj` (`main` if the program has a
   non-top-level entry), and `stdlib` when the program uses seed methods. Use
   relative paths; the server resolves them against the workspace.
3. `stream_source` each chunk with live reports; fix the warnings by streaming
   the missing implementations.
4. `eos` — if it fails, stream the fix and `eos` again in the **same** session.
5. `link_object` the emitted object, then `run_object` the executable — the
   compile → link → run loop stays inside MCP, so a confined agent never needs
   a shell.

## Sandboxed / relocatable operation

With a packaged layout (`bin/aegis-mcp.exe` beside `docs/src`, `stdlib`,
`llms*` and `runtime/runtime.c`) the server resolves its corpus from its own
path, so an agent can work in a scratch directory with **no Aegis sources
visible**. The compiler runs in-process inside the server and the produced
executable is launched by `run_object`, so the only thing the agent needs is
the MCP server — no shell and no repo checkout.

That path is validated end to end: from an empty workspace, read
`aegis://llms-full.txt`, `create_session`, stream a `struct` + an `impl` that
calls a method defined in a later chunk (a live `unresolved method 'App.greet()'`
warning), `eos` (fails, session stays open), stream the missing `impl`, `eos`
(clean, emits `app.o`), `link_object` (`app.exe`), and `run_object` printing the
program's output.