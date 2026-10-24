# OS & processes

The `os` module is a seed module (`stdlib/os.aegis`): a thin, safe wrapper over
the platform's file, environment, and process APIs. Like
the other seed modules it is **not auto-loaded** — list `stdlib/os.aegis` among
the compiler inputs.

```aegis
let os = Os {}
```

Every entry point hangs off one namespace struct (`Os`), because Aegis has no
free functions. Failure is a value, never an abort: mutating calls return
`Result[Empty, Str]`, queries return `Result[T, Str]` or a plain `Bool`/`Int`.

## Environment

| Method | Returns | Notes |
| --- | --- | --- |
| `os.env(name)` | `Str` | value, or `""` when the variable is unset |
| `os.has_env(name)` | `Bool` | true when set and non-empty |
| `os.set_env(name, value)` | `Result[Empty, Str]` | visible to this process and its children |
| `os.unset_env(name)` | `Result[Empty, Str]` | |

## Working directory

| Method | Returns | Notes |
| --- | --- | --- |
| `os.cwd()` | `Result[Str, Str]` | current working directory |
| `os.chdir(path)` | `Result[Empty, Str]` | |

## Filesystem

| Method | Returns | Notes |
| --- | --- | --- |
| `os.mkdir(path)` | `Result[Empty, Str]` | one level; parent must exist |
| `os.rmdir(path)` | `Result[Empty, Str]` | directory must be empty |
| `os.remove(path)` | `Result[Empty, Str]` | deletes a file |
| `os.rename(old, new)` | `Result[Empty, Str]` | rename or move |
| `os.copy(src, dst)` | `Result[Empty, Str]` | byte-for-byte |
| `os.is_dir(path)` | `Bool` | |
| `os.is_file(path)` | `Bool` | |
| `os.file_size(path)` | `Result[Int, Str]` | bytes |
| `os.modified_at(path)` | `Result[Int, Str]` | Unix epoch seconds |

## Process & time

| Method | Returns | Notes |
| --- | --- | --- |
| `os.pid()` | `Int` | process id |
| `os.unix_time()` | `Int` | wall-clock seconds since the epoch |
| `os.separator()` | `Str` | `"\"` on Windows, `"/"` on POSIX |

## Running programs

`exec` runs a program directly; `shell` runs a command through the platform
shell (`cmd.exe /c`, `/bin/sh -c`). Both capture stdout/stderr and report the
exit status. A program that exits non-zero is still `ok` (with its `status`); a
program that cannot be *started* (missing, not executable) is `err`.

```aegis
struct Output { status: Int, stdout: Str, stderr: Str }

match os.exec("git", ["rev-parse", "HEAD"]) {
    ok(out) => {
        if out.status == 0 {
            println(out.stdout.trim())
        } else {
            println("git failed: " + out.stderr)
        }
    }
    err(why) => { println("could not run git: " + why) }
}

match os.shell("echo hello | tr a-z A-Z") {
    ok(out) => { println(out.stdout.trim()) }   // HELLO
    err(why) => { println(why) }
}
```

`args` is a `List[Str]`; the module joins it into a newline-separated blob.
**An argument may not contain a newline**, and empty arguments are
dropped. Each captured stream is capped at 1 MiB.

## Paths

The separator is **not** abstracted (the same rule as `read_file`): pass
`"C:/tmp/a"` on Windows and `"/tmp/a"` on Linux. When a program needs to build a
path at runtime, use `os.separator()`.

## Example

```aegis
let os = Os {}

match os.mkdir("scratch") {
    ok(v) => {}
    err(why) => { println(why) }
}
match write_file("scratch/a.txt", "data") {
    ok(n) => { println(str(n) + " bytes") }
    err(why) => { println(why) }
}
println(os.is_file("scratch/a.txt"))          // true
match os.copy("scratch/a.txt", "scratch/b.txt") {
    ok(v) => {}
    err(why) => { println(why) }
}
match os.remove("scratch/a.txt") {
    ok(v) => {}
    err(why) => { println(why) }
}
match os.rmdir("scratch_empty") {
    ok(v) => {}
    err(why) => { println(why) }
}
```

The module ships with a self-checking suite (`tests/e2e/os_suite.aegis`) that
exercises every method against a scratch directory, including the error paths.
