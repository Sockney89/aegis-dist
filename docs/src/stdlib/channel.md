# Channels

`Channel[T]` is a small FIFO container for passing values between parts of an
application. Its current API is non-blocking: `try_recv` returns immediately
with `none` when the channel is empty. It does not wait for another thread and
does not provide a blocking receive operation.

```aegis
let mut ch = Channel[Int] { items: [], closed: false }
ch.send(10)
ch.send(20)

match ch.try_recv() {
    some(n) => { println(str(n)) } // 10
    none => { println("empty") }
}
println(str(ch.len())) // 1
ch.close()
println(str(ch.is_closed())) // true
```

| Method | Returns | Behavior |
| --- | --- | --- |
| `send(value)` | `Empty` | Appends a value to the FIFO queue. |
| `try_recv()` | `Option[T]` | Removes and returns the oldest value, or `none`. |
| `close()` | `Empty` | Marks the channel closed; existing values remain readable. |
| `is_closed()` | `Bool` | Reports the closed flag. |
| `len()` | `Int` | Number of queued values. |

The implementation is a simple list-backed queue. Repeated receives copy the
remaining list, so it is best suited to small control-message queues until a
runtime-backed blocking channel is added.
