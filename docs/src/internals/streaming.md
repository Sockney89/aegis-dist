# Streaming & the compiler daemon

The compiler can be driven two ways: compiling a source **file** (batch), or
feeding it **wire chunks** one at a time (streaming). Streaming is what powers
IDE-style and agentic coding flows: a partial program is legal mid-stream,
missing symbols are reported as live, non-fatal warnings, and end-of-source
(EoS) promotes whatever is still unresolved to a fatal gate.

## Wire chunks

One wire chunk is one JSON line. `{"schema":4,"item":<top-level item>}` carries
a single parsed top-level item (a `struct`, `impl`, `state`, `on`, ...). The
`{"schema":4,"item":null}` line is the **end-of-source (EoS) marker**.

Items are serde-serialized AST nodes; do not hand-author them. A source file is
split into chunks by the compiler itself:

```powershell
compiler draft.aegis --ast-json > chunks.jsonl
```

`--ast-json` emits one chunk per top-level item. Append the EoS marker when the
full program has been written.

## compiler --stream

The batch binary also has a streaming harness:

```powershell
compiler --stream --json < chunks.jsonl
compiler --stream --json --input-file chunks.jsonl --emit-obj app.o
```

- one live `stream` report per chunk (unresolved references as warnings),
- EOF without an explicit EoS marker is treated as EoS (noted on stderr),
- a clean EoS runs the full compile (`--emit-obj` writes the object),
- `--emit-exe` is **batch-only**: streaming has no source filename.

The CLI harness is single-shot: an EoS that fails prints the errors and exits 1.

## aegis-daemon

`aegis-daemon` is the long-lived streaming server: one WebSocket connection =
one isolated compile session, framed as JSON text documents over RFC 6455.

```powershell
aegis-daemon [--port N] [--workspace DIR] [--emit-obj PATH] [--main S::m]
```

- default port `8787`; `--port 0` binds an ephemeral port and prints
  `aegis-daemon listening on 127.0.0.1:PORT` on stdout,
- `DIR/.aegis/snapshot.json` is where `sync` freezes the session,
- one connection per session: dropping the connection drops the session state
  (unless it was synced).
- `--main S::m` mirrors the batch compiler's entry flag. Without it the emitted
  object has no `aegis_main` and cannot be linked into an executable later:
  `compiler app.o --emit-exe app.exe` would fail with `undefined symbol: aegis_main`.
  Pass it to match the program's default entry (e.g. `--main SumArgs::main`).

### Protocol

Each inbound text frame is one JSON document:

| Frame | Meaning |
| --- | --- |
| `{"schema":4,"item":{...}}` | stream one top-level item |
| `{"schema":4,"item":null}` or `{"verb":"eos"}` | close the stream, run the full analysis |
| `{"verb":"sync"}` | freeze the session to `DIR/.aegis/snapshot.json` |
| `{"verb":"rollback"}` | restore the session from that snapshot |

The server answers every request with one report frame:

- after a chunk: a `stream` report (`"ok": true`, no errors; unresolved
  references come back as warnings and clear the moment the definition chunk
  arrives),
- after EoS: either an `eos` report (`"ok": false`, unresolved references as
  errors — the session **stays live**, so a fix can be streamed and the stream
  closed again), or the full analysis, finishing with a `done` report
  (`"ok": true`, `"artifact"` set) followed by a WS close from the server.

A report is a single JSON document:

```json
{
  "ok": true,
  "phase": "done",
  "input": "<daemon>",
  "diagnostics": [],
  "stats": { "items": 3, "checks": 4 },
  "artifact": { "path": "session\\app.o", "bytes": 340 }
}
```

Diagnostics carry `code`, `severity`, `message`, `line`, `col`, `node`, and an
optional `suggestedFix`.

The daemon can emit an object file only (`--emit-exe` is batch-only, since the
session has no source filename). Link the object afterwards:

```powershell
compiler app.o --emit-exe app.exe
```

That puts the object through the same linking path AEGIS_CC uses for batch
builds (link mode takes only `--emit-exe`).

## aegis-ws

`aegis-ws` is the thin WebSocket client for talking to a daemon from a shell:

```powershell
aegis-ws 127.0.0.1:8787 < chunks.jsonl
aegis-ws 127.0.0.1:8787 chunks.jsonl
```

One stdin line = one masked text frame; every report frame the server sends is
printed to stdout (status goes to stderr). The connection is kept open across
EoS failures, so a **single** stream can carry a whole authoring cycle:

```text
draft chunks ... { "schema":4, "item": null }   # EoS fails: list of the missing
fix chunks ..... { "schema":4, "item": null }   # EoS compiles, object written
```

`aegis-ws` exits when the server closes (successful EoS) or after it closes the
connection itself when stdin ends.

## Writing a program through the daemon

End to end (PowerShell):

```powershell
# 1. draft the program
@'
struct Program { argc: Int }
impl Program {
  fn all(self) -> Int { return self.size() }
}
'@ | Set-Content draft.aegis

# 2. split it into wire chunks
compiler draft.aegis --ast-json > part1.jsonl

# 3. start an isolated session on an ephemeral port
Start-Process aegis-daemon -ArgumentList "--port","0","--workspace","session","--emit-obj","app.o" `
  -RedirectStandardOutput daemon.out -RedirectStandardError daemon.err -NoNewWindow
$addr = (Get-Content daemon.out | Select-Object -First 1).Trim() -replace '.*listening on *',''

# 4. stream the draft, hit EoS, stream the missing impl, EoS again
@'
impl Program { fn size(self) -> Int { return 42 } }
'@ | Set-Content fix.aegis
compiler fix.aegis --ast-json > fix.jsonl

(Get-Content part1.jsonl; '{"schema":4,"item":null}'; Get-Content fix.jsonl; '{"schema":4,"item":null}') |
  aegis-ws $addr

# 5. link the object and run
compiler app.o --emit-exe app.exe
.\app.exe
```

The live transcript shows the unresolved `Program.size()` warning mid-stream,
the failed EoS ("referenced but never defined"), and finally the `done` report
once `size()` arrives — all inside one client connection.