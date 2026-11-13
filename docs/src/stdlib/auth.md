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

`basic_decode` returns the decoded `user:password` string or `""` when the
header is malformed. `cookie_get` returns `""` when the named cookie is not
present. `jwt_sign` creates an HS256 token from the supplied JSON payload text;
`jwt_verify` returns the payload text or `""` when the token has the wrong shape
or signature. The caller is responsible for validating payload claims such as
expiry and issuer.
