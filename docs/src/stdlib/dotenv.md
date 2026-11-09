# Dotenv

`Dotenv` (stdlib/dotenv.aegis) loads a `.env` file into the process environment.

```aegis
struct Dotenv {}

impl Dotenv {
    fn load(self, path: Str) -> Result[Empty, Str]
}

Notes:
- `load` accepts lines prefixed with `export `.
- Keys must be non-empty; malformed lines are skipped.
```
PY