# Standard library

The Aegis standard library has two layers:

1. **Compiler builtins** - methods the compiler provides directly. These are "sealed": you cannot
   redefine `String.length`, and the compiler type-checks their arguments.
2. **Aegis seed modules** - ordinary `struct`/`impl` files under `stdlib/`
   that implement collections and numeric string helpers on top of builtins. Each
   ships with a self-checking suite. Since 0.1.0 the seed modules are auto-loaded
   by the compiler prelude, so `Http`, `JsonParser`, `Stack[T]` and friends are
   available without listing files. Use `--no-prelude` to disable or `--stdlib DIR`
   to override the directory. The MCP pipeline mirrors this via `stdlib "all"`.

The compiler also exposes value-level builtins: `print(...)`, `println(...)`,
`str(v)` (stringify), and `argc` / `arg(i)` for program arguments.

- [Int & Float math](math.md)
- [String operations](string.md)
- [List operations](list.md)
- [Collections](collections.md)
- [JSON](json.md)
- [File IO & stdin](io.md)
- [OS & processes](os.md)
- [Time & randomness](time-rand.md)
- [Encoding](encoding.md)
- [Database interface](db.md)
- [Regex (minimal)](regex.md)
- [Logging](log.md)
- [Auth](auth.md)
- [TOML](toml.md)
- [YAML](yaml.md)
- [Metrics](metrics.md)
- [Testing](test.md)
- [Channels](channel.md)
- [StrBuf](strbuf.md)
- [Path](path.md)
- [CLI](cli.md)
- [Platform](platform.md)
- [Tracing](tracing.md)
- [Dotenv](dotenv.md)
- [Sandbox](sandbox.md)
- [StrBuf (string builder)](#strbuf)
- [Path & filesystem helpers](#path)
- [CLI argument parsing](#cli)
- [Platform detection](#platform)
- [Heap / priority queue](#heap)
- [Sorted set / sorted map](#sorted-collections)
- [LRU cache](#lru)
- [Trie](#trie)
- [Tracing](#tracing)
- [Dotenv](#dotenv)
- [Sandbox / safe subprocess](#sandbox)

## Seed modules vs builtins (provenance)
|---|---|
| `String.length()`, indexing `s[i]`, concatenation `+`, equality/comparison | Builtin |
| `List.length()`, `xs[i]`, `.append(v)`, `.pop()`, `.contains(x)`, `.index_of(x)`, `.reverse()`, `.slice(a,b)`, `.dedupe()` | Builtin |
| `Map.length()`, `m[k]`, `.contains(k)`, `.insert(k,v)`, `.remove(k)`, `.get_or(k,d)`, `.keys()`, `.values()` | Builtin |
| `Int.to_float()`, `Float.to_int()`, `Float.round()`/`ceil()`/`trunc()`/`pow`/`sin`/`cos`/`tan`/`log`/`log10`/`exp()` | Builtin |
| `Int.pow(Int)`, `Float.format(digits)`, `Int.pad(width)` | Seed / sealed impl |
| `String.split`/`trim()`, `join(sep)` (List[Str]), `to_upper()`/`to_lower()`, `repeat(n)`, `substring()`, `replace()`, `index_of`/`contains` variants, char predicates, `pad_left`/`right()` | Seed module (`stdlib/mathstr.aegis`) |
| Collections: `Stack[T]`, `Set[T]`, `Queue[T]`, `Deque[T]` | Seed modules (`stdlib/stack.aegis`, `set.aegis`, `queue.aegis`, `deque.aegis`) |
| JSON parsing/serialization | Seed module (`stdlib/json.aegis`) |
| OS access: env, cwd, mkdir/rmdir/remove/rename/copy, stat, pid/time, exec/shell | Seed module (`stdlib/os.aegis`) |
| CSV/Table helpers | Seed modules (`stdlib/csv.aegis`, `table.aegis`) |


## New modules (0.1.4)

- **StrBuf** (stdlib/strbuf.aegis): growable string builder; append/append_int/append_float/append_char/clear/len/to_string/write_file/reserve. Avoids O(n^2) concat.
- **Path** (stdlib/path.aegis): join, normalize, basename, dirname, ext, mkdir_all, remove_all, glob, temp_dir, temp_file.
- **Cli** (stdlib/cli.aegis): has_flag, get_option, positionals, raw, usage.
- **Platform** (stdlib/platform.aegis): is_windows/is_linux/os_name, home_dir/config_dir/cache_dir/temp_dir.
- **Heap** (stdlib/heap.aegis): binary min-heap priority queue (push/pop/peek/len/is_empty).
- **SortedSet / SortedMap** (stdlib/sortedset.aegis, sortedmap.aegis): sorted collections with contains/insert/remove.
- **Lru** (stdlib/lru.aegis): least-recently-used cache (get/put/len).
- **Trie** (stdlib/trie.aegis): prefix tree (insert/contains/starts_with).
- **Tracing** (stdlib/tracing.aegis): span start/end with timing.
- **Dotenv** (stdlib/dotenv.aegis): load .env into environment.
- **Sandbox** (stdlib/sandbox.aegis): safe subprocess execution.
- **Auth**: const_time_eq added.
- **Log**: JSON mode (set_json), size-based rotation (set_max_bytes).
- **Csv**: configurable delimiters (parse_delim/encode_delim, append_file).
- **Table**: alignment helpers (pad_cell_right/center/aligned).
- **Json**: to_string_pretty, parse_lines/encode_lines, pointer.
- **Time**: parse_utc.
- **Os**: atomic_write, walk, join_path.
- **Http**: mime_type, ws_send_binary, static_file sets Content-Type.
- **Builtins**: str_to_int, secure_rand, str_from_chars.
