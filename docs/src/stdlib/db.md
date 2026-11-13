# Database interface (experimental)

`stdlib/db.aegis` defines Go-style traits for database drivers:

- `DbDriver`: `open(path) -> DbConn`
- `DbConn`: `exec(sql) -> Int`, `close()`
- `DbRows`: `next()`, `get_str(i)`, `get_int(i)`, `get_float(i)`

Drivers implement these traits; application code depends only on the traits.
A SQLite driver is not auto-loaded (it requires linking SQLite); see the
e2e SQLite suite for a concrete FFI example.

The traits are intentionally small and do not define transactions, parameter
binding, or row ownership. A concrete driver can expose those capabilities
through additional methods while keeping application code dependent on the
common operations. `DbRows.next()` reports whether another row is available;
the typed getters read the current row by zero-based column index. Error
conventions are left to the concrete driver because the original trait returns
simple scalar values.
