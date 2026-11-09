# Time & randomness

Value-level compiler builtins (like `print` / `argc`).

| Function | Returns | Notes |
| --- | --- | --- |
| `now_ms()` | `Int` | monotonic milliseconds since an arbitrary epoch (for elapsed time, not wall-clock dates) |
| `rand_seed(n)` | `Empty` | seed the PRNG; `0` restores the built-in default seed |
| `rand_int(lo, hi)` | `Int` | uniform in the half-open range `[lo, hi)`; returns `lo` when `hi <= lo` |
| `rand_float()` | `Float` | uniform in `[0.0, 1.0)` |
| `sleep(ms)` | `Empty` | pause the current thread for `ms` milliseconds |

```aegis
rand_seed(42)
let die = rand_int(1, 7)          // 1..=6
let p = rand_float()              // 0.0 <= p < 1.0

let t0 = now_ms()
// ... work ...
let elapsed = now_ms() - t0
```

The generator is a deterministic `xorshift64*`: seeding with the same value
reproduces the same sequence, which is what makes tests (and save/replay
scenarios) stable. `now_ms` reuses the same monotonic clock the event-timer
queue already uses, so it never jumps backwards on a clock adjustment.

Argument types are checked: `rand_int("a", 3)` fails with
`rand_int bounds must be Ints, got Str`. Verified by
The test suite verifies reproducibility, range invariants, and clock
monotonicity.


## New in 0.1.4

- Time.parse_utc(s) - parse YYYY-MM-DDTHH:MM:SSZ to Unix seconds.
  Validates separators and field ranges; returns `err` on malformed input.
- secure_rand() builtin - CSPRNG 64-bit integer.
