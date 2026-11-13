# Platform Detection

`Platform` reports the host platform and common user directories. The current
implementation distinguishes Windows from non-Windows hosts; `is_linux()` is
the inverse of `is_windows()` and `os_name()` returns either `"windows"` or
`"linux"`.

```aegis
let p = Platform {}
println(p.os_name())
println(p.home_dir())
println(p.config_dir())
println(p.cache_dir())
println(p.temp_dir())
```

`home_dir`, `config_dir`, and `cache_dir` return an empty string when the
relevant environment variables are unavailable. `temp_dir` delegates to
`Path.temp_dir`, using `TEMP`, `TMP`, or `/tmp` according to the host.

## Example

```aegis
let p = Platform {}
println(p.os_name())
println(p.home_dir())
println(p.config_dir())
println(p.cache_dir())
println(p.temp_dir())
```