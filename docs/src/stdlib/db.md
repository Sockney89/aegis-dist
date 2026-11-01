# Database interface (experimental)

`stdlib/db.aegis` defines Go-style traits for database drivers:

- `DbDriver`: `open(path) -> DbConn`
- `DbConn`: `exec(sql) -> Int`, `close()`
- `DbRows`: `next()`, `get_str(i)`, `get_int(i)`, `get_float(i)`

Drivers implement these traits; application code depends only on the traits.
A SQLite driver is not auto-loaded (it requires linking SQLite); see the
e2e SQLite suite for a concrete FFI example.