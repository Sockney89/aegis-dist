# Tracing

`Tracer`/`Span` (stdlib/tracing.aegis) provide minimal span timing.

```aegis
struct Span { name: Str, start_ms: Int }
struct Tracer {}

impl Tracer {
    fn start(self, name: Str) -> Span
    fn end(self, span: Span) -> Int
}
```
PY