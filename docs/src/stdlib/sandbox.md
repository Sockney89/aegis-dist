# Sandbox

`Sandbox` (stdlib/sandbox.aegis) provides safe subprocess execution wrappers.

```aegis
struct Sandbox {}

impl Sandbox {
    fn run(self, program: Str, args: List[Str]) -> Result[Output, Str]
    fn shell_safe(self, command: Str) -> Result[Output, Str]
}
```
PY