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
