# Regex

`stdlib/regex.aegis` provides a recursive regex matcher backed by the runtime
regex engine.

| Method | Notes |
| --- | --- |
| `is_match(pattern, text)` | supports `.`, `*`, `+`, `?`, character classes `[a-z]`, anchors `^`/`$`, alternation `\|`, and escapes `\d \w \s` |

```aegis
let r = Regex {}
println(str(r.is_match("a*b", "aaab")))     // true
println(str(r.is_match("[a-z]+", "abc")))   // true
println(str(r.is_match("^abc$", "abc")))    // true
println(str(r.is_match("a|b", "b")))        // true
```

Patterns are matched against the whole input unless anchored; an unanchored
pattern matches if it occurs anywhere in the text.
EOF
path:
D:\dev\opencode\aegis\public-docs\src\stdlib\regex.md