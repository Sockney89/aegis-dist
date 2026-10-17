# File IO & stdin

These are value-level compiler builtins (like `print` / `argc`). Failures are values: `read_file`, `read_line`, and
`list_dir` return `Result[String, String]` / `Result[List[String], String]`, and
`write_file` returns `Result[Int, String]` (bytes written). Files are
read/written as raw bytes; `read_line` is the only operation that strips a
newline.

| Function | Returns | Notes |
| --- | --- | --- |
| `read_file(path)` | `Result[Str, Str]` | whole file; `err` when it cannot be opened/read |
| `write_file(path, content)` | `Result[Int, Str]` | bytes written; `err` on failure |
| `file_exists(path)` | `Bool` | |
| `read_line()` | `Result[Str, Str]` | one line from stdin, trailing newline stripped; `err` at EOF |
| `list_dir(path)` | `Result[List[Str], Str]` | entry names of a directory (unsorted, `.`/`..` omitted); `err` when it cannot be opened |

```aegis
match read_file("notes.txt") {
    ok(text) => { println(text) }
    err(why) => { println("read failed: " + why) }
}
match write_file("out.txt", "hello\n") {
    ok(n) => { println(str(n) + " bytes") }
    err(why) => { println(why) }
}
match list_dir("src") {
    ok(entries) => {
        let mut i = 0
        while i < entries.length() {
            println(entries[i])
            i = i + 1
        }
    }
    err(why) => { println(why) }
}
```

Paths are ordinary `String`s; the separator is not abstracted
(`"C:/tmp/a.txt"` and `"dir/file"` both work). The argument type is checked:
`read_file(42)` fails with `read_file path must be a String, got Int`, and
`list_dir(42)` fails with `list_dir path must be a String, got Int`.

`list_dir` returns leaf entry names (not full paths) and does not distinguish
files from subdirectories; inspecting an entry further is a job for
`file_exists` or a subsequent `list_dir`. It is implemented per-platform in the
runtime (`FindFirstFileA` on Windows, `readdir` elsewhere).

A `match` on a `Result` binds its payload by reference, so a bound `String`
supports the full string surface. This needed a codegen fix (a match-bound
payload was treated as an lvalue slot); it is exercised by
The test suite verifies these behaviors against scratch files and directories,
including the `err` path on a missing file.

The stdlib is not auto-loaded: these IO builtins need no `import`, but
seed-module methods (for example `String.replace`) require
`stdlib/mathstr.aegis` among the compiler inputs.
