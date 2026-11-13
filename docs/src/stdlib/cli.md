# CLI argument parsing

`Cli` (stdlib/cli.aegis) parses `argc()`/`arg()` into flags, options and
positionals.

```aegis
struct Cli {}

impl Cli {
    fn raw(self) -> List[Str]
    fn has_flag(self, name: Str) -> Bool
    fn get_option(self, name: Str) -> Str
    fn positionals(self) -> List[Str]
    fn usage(self, program: Str, desc: Str) -> Str
}
```

```aegis
let cli = Cli {}
if cli.has_flag("verbose") {
    println("verbose mode")
}
let output = cli.get_option("output")
let files = cli.positionals()
```

`has_flag("verbose")` recognizes `verbose`, `--verbose`, and `-verbose`.
`get_option("output")` recognizes `--output value`, `-output value`, and
`--output=value`; it returns `""` when the option is absent or has no following
value. `positionals()` returns arguments that do not begin with `-`.

`usage` only builds a short usage string; it does not print it or validate a
complete command-line schema.
