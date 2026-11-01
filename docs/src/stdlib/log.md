# Logging

`stdlib/log.aegis` provides a small structured logger.

```aegis
let log = Log {}
log.set_level(1)
log.info("started")
log.warn("low disk")
```

| Method | Notes |
| --- | --- |
| `set_level(n)` | 0=debug,1=info,2=warn,3=error |
| `set_file(path)` | write to file instead of stdout |
| `debug/info/warn/error(msg)` | emit if level allows |