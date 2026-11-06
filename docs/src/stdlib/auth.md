# Auth

`stdlib/auth.aegis` provides basic auth and cookie helpers.

```aegis
let a = Auth {}
let token = a.basic_encode("user", "pass")
let decoded = a.basic_decode("Basic " + token)
let v = a.cookie_get("a=1; b=2", "b")

let token = a.jwt_sign(`{"sub":"123"}`, "secret")
let payload = a.jwt_verify(token, "secret")
```

## New in 0.1.4

- const_time_eq(a, b) - constant-time string equality.
