# Path & filesystem helpers

`Path` (stdlib/path.aegis) provides path manipulation and recursive
filesystem operations built on `Os`.

```aegis
struct Path {}

impl Path {
    fn separator(self) -> Str
    fn join(self, a: Str, b: Str) -> Str
    fn basename(self, p: Str) -> Str
    fn dirname(self, p: Str) -> Str
    fn ext(self, p: Str) -> Str
    fn normalize(self, p: Str) -> Str
    fn mkdir_all(self, p: Str) -> Result[Empty, Str]
    fn remove_all(self, p: Str) -> Result[Empty, Str]
    fn glob(self, dir: Str, pattern: Str) -> Result[List[Str], Str]
    fn temp_dir(self) -> Str
    fn temp_file(self, prefix: Str) -> Str
}

Notes:
- `mkdir_all` now returns `err` when a directory cannot be created
  (previously it always returned `ok`).
- `temp_file` appends a cryptographically random suffix to avoid
  predictable temporary file names.
- `remove_all` uses host filesystem predicates and has no explicit symlink
  protection; do not pass an untrusted path.
