# Sandbox

`Sandbox` provides convenience checks around `Os.exec` and `Os.shell`. It is
not an operating-system sandbox and does not make arbitrary shell input safe.

```aegis
let s = Sandbox {}
let result = s.run("echo", ["hello"])
match result {
    ok(output) => { println(output.stdout) }
    err(message) => { println(message) }
}
```

`run(program, args)` rejects an empty program name and program names containing
`;`, `|`, or `&`, then executes the program directly with argument separation.
Arguments are not shell-parsed.

`shell_safe(command)` rejects `;`, `|`, `&`, and backticks before passing the
command to the host shell. This is only a basic guard. Do not use it as a
security boundary for untrusted commands; use `run` with explicit arguments or
an OS/container sandbox instead.

## Example

```aegis
let s = Sandbox {}
let result = s.run("echo", ["hello"])
match result {
    ok(output) => { println(output.stdout) }
    err(message) => { println(message) }
}
```