# Testing Helpers

`Test` provides lightweight assertion and reporting helpers for executable
test suites. It does not discover tests or change the process exit code by
itself; a suite normally tracks its own pass/fail count and returns it from
`main`.

```aegis
struct App {}

impl App {
    fn main(self) {
        let t = Test {}
        let mut passed = 0
        let mut failed = 0
        if t.assert_eq_int(2 + 2, 4, "addition") {
            passed = passed + 1
        } else {
            failed = failed + 1
        }
        t.run("basic checks", failed == 0)
        t.summary(passed, failed)
    }
}
```

| Method | Returns | Purpose |
| --- | --- | --- |
| `assert_true(condition, message)` | `Bool` | Reports a failed Boolean assertion. |
| `assert_eq_int(actual, expected, message)` | `Bool` | Compares two `Int` values. |
| `assert_eq_str(actual, expected, message)` | `Bool` | Compares two strings. |
| `run(name, passed)` | `Empty` | Prints `PASS` or `FAIL` for a named group. |
| `summary(passed, failed)` | `Empty` | Prints aggregate counts. |

Assertions print failure details and return `false`; they do not abort the
program. This makes the helper suitable for accumulating several failures.
