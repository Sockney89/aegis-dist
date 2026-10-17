# Events & state machines

## Actor-style events

Concurrency is the actor model; there are no mutexes or semaphores. Structs
communicate by emitting and receiving events:

```aegis
emit DomainEvent.Action(payload)
```

```aegis
on DomainEvent.Action(payload) {
    // handle payload
}
```

The runtime event loop dispatches emitted events to `on` handlers; emit/on
round-trips are exercised by the test suite.

## Native state machines

`state` declares a set of named variants; an `impl` can be pinned to a state
with `impl X @ State::Variant`. Transition methods are only legal in the
guarded context, and `self.transition(State::Next)` moves the instance.

```aegis
state OrderState { Pending, Paid, Shipped }

struct Order { }

impl Order @ OrderState::Pending {
    fn process_payment(mut self) {
        // ... logic ...
        self.transition(OrderState::Paid)
    }
}
```

This is Aegis's answer to temporal bugs: "which state is this object in?" is a
compile-time fact, not a field the developer can forget to maintain.