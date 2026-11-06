# Metrics

`Metrics` (stdlib/metrics.aegis) is a tiny in-process metrics registry
(counters and gauges).

```aegis
struct Metrics {}

impl Metrics {
    fn counter(self, name: Str, value: Int) -> Map[Str, Int]
    fn inc(self, mut m: Map[Str, Int], name: Str, delta: Int) -> Map[Str, Int]
    fn get(self, m: Map[Str, Int], name: Str) -> Int
    fn gauge(self, name: Str, value: Int) -> Map[Str, Int]
    fn set(self, mut m: Map[Str, Int], name: Str, value: Int) -> Map[Str, Int]
}
```
PY