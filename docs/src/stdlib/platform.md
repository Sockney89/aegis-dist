# Platform detection

`Platform` (stdlib/platform.aegis) reports the host OS and well-known dirs.

```aegis
struct Platform {}

impl Platform {
    fn is_windows(self) -> Bool
    fn is_linux(self) -> Bool
    fn os_name(self) -> Str
    fn home_dir(self) -> Str
    fn config_dir(self) -> Str
    fn cache_dir(self) -> Str
    fn temp_dir(self) -> Str
}
```
PY