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
PY