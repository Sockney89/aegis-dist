# Tracing

`Tracer` provides minimal elapsed-time spans using the monotonic `now_ms()`
clock.

```aegis
let tracer = Tracer {}
let span = tracer.start("load-config")
// work being measured
let elapsed = tracer.end(span)
println(str(elapsed) + " ms")
```

`start(name)` records the span name and start time. `end(span)` prints
`span <name> took <n> ms` and returns the elapsed milliseconds. The helper is
intended for lightweight diagnostics, not a distributed tracing protocol.

## Example

```aegis
let tracer = Tracer {}
let span = tracer.start("load-config")
// work being measured
let elapsed = tracer.end(span)
println(str(elapsed) + " ms")
```