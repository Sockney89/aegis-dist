# Metrics

`Metrics` is a small in-process helper for counters and gauges. It is not a
global registry or an exporter: maps are passed explicitly and returned after
each update.

```aegis
let metrics = Metrics {}
let mut counts = metrics.counter("requests", 0)
counts = metrics.inc(counts, "requests", 1)
println(str(metrics.get(counts, "requests"))) // 1

let mut gauges = metrics.gauge("workers", 2)
gauges = metrics.set(gauges, "workers", 3)
```

| Method | Returns | Behavior |
| --- | --- | --- |
| `counter(name, value)` | `Map[Str, Int]` | Creates a one-entry counter map. |
| `inc(map, name, delta)` | `Map[Str, Int]` | Adds `delta`, treating a missing key as zero. |
| `get(map, name)` | `Int` | Returns zero when the key is absent. |
| `gauge(name, value)` | `Map[Str, Int]` | Creates a one-entry gauge map. |
| `set(map, name, value)` | `Map[Str, Int]` | Replaces the value for a key. |

Use a shared map or a struct containing maps when an application needs a
long-lived registry.
