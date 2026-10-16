# Runtime ABI

The C runtime (`compiler/runtime/runtime.c`) provides storage management and
the operations too far from source to be worth generating inline.

## Containers

A `List[T]` value is a two-field struct:

```c
struct aegis_list {
    int64_t len;      // logical length
    int64_t cap;      // allocated capacity
    int64_t *data;    // element slots (i64 for scalars, pointers for refs)
    int64_t rc;       // reference count
};
```

The Aegis value is `{ i64 len, ptr handle }`. The compiler keeps the length
mirror in the value struct so `length()` is a load, not a call; mutating ops
resynchronize it (`list_resync`). The handle is a pointer to the struct above.

| Helper | Signature | Role |
| --- | --- | --- |
| `aegis_list_alloc(cap)` | -> i64 ptr | new list |
| `aegis_list_append(list, v)` | -> i64 | grow + store, return len |
| `aegis_list_pop(list)` | -> i64 | truncate + return last element |
| `aegis_list_len(list)` | -> i64 | authoritative length |
| `aegis_list_get/set` | (list, idx) | element access |
| `aegis_env_alloc/get/set/retain/release` | | closure environment slots |

## String / list / map allocation helpers (L3c)

Modifying or allocating strings needs C-level work:

| Helper | Signature | Role |
| --- | --- | --- |
| `aegis_str_trim(str)` | -> char* | allocate trimmed copy |
| `aegis_str_split(str, delim)` | -> list handle | split into `List[Str]` |
| `aegis_list_join(list, sep)` | -> char* | join elements into a string |
| `aegis_str_to_upper(str)` | -> char* | ASCII uppercase copy |
| `aegis_str_to_lower(str)` | -> char* | ASCII lowercase copy |
| `aegis_str_repeat(str, n)` | -> char* | repeated string (fresh) |
| `aegis_list_contains(list, v)` | -> i64 0/1 | membership probe |
| `aegis_list_index_of(list, v)` | -> i64 | first match index, -1 absent |
| `aegis_list_reverse(list)` | -> list handle | fresh reversed copy |

`aegis_str_split` reuses the container helpers (`aegis_list_alloc(0)` +
`aegis_list_append`), and the compiler wraps the returned handle back into an
Aegis list value with `aegis_list_len` + `make_list_value`.

## Closures (L3a)

Closures are `i64(i64 env, args...) -> i64` function pointers paired with a
heap environment slot block. Environments are capture-by-value and scalar
only; the runtime retains/releases them for the closure's lifetime, and the
compiler emits saved/stored body closures so the environment is restored
around every indirect call.
## Opaque handles (I2)

A `Handle[Tag]` needs nothing from the runtime: it is a bare LLVM `ptr`, and
`null` is LLVM's null pointer. `==` / `!=` lower to `icmp eq`/`icmp ne` on the
two pointers, so identity comparison is a single instruction with no runtime
call. There is deliberately no refcount, no free, and no destructor path: a
handle is only as valid as the C library that issued it, and freeing it is a
call into that library (`fclose`, `sqlite3_close`) like any other extern call.

A pointer handle still rides the i64 *slot* ABI when it is stored in a
container, exactly like `Str`: `to_slot64` is a `ptrtoint` and `from_slot64`
an `inttoptr`, so a `List[Handle[Db]]` round-trips without widening shims.

## Out params (I3)

An extern out param `out name: T` is declared in the module as a plain pointer
argument (`ptr`); the C callee sees `T*`. At the call site the compiler emits an
`alloca` of `basic_ty(T)` (a pointer for `Handle`/`Str`, the I1 width for
scalars), zero-invisible — it passes the allocation's address and, after the
call, `define_var(name, slot, T, is_ref: false)` binds the local to that slot.
Reads of `name` are ordinary loads from the slot, and a later `name = x` is an
ordinary store (out locals are mutable). The `is_ref: false` slot means the i64
container path (`to_slot64`/`from_slot64`) applies if an out value is stored in
a `List`, with no widening shim needed.

## C-string marshaling (I4)

The runtime already models a string as a NUL-terminated heap buffer (`i8*`),
so the outbound half of the boundary is zero-copy: `Str` params hand C the
pointer directly. Inbound, codegen wraps every `-> Str` extern result and every
`out name: Str` readback: `load the raw char*`, `call aegis_str_from_cstr`
(`strlen` + `malloc` + copy, NULL maps to the empty string), and use the copy
as the Str value — storing it back into the out slot so the bound local reads
the snapshot. The intrinsic declarations `aegis_str_cstr`/`aegis_str_from_cstr`
are exempt from the wrap (`is_str_marshal_intrinsic`), so calling them never
double-copies. Because strings are never freed (there is no string `free`
path in the runtime), the snapshot is as durable as any other string produced
by `aegis_str_cat` / `aegis_str_of_int`.

## Callbacks (I5)

An extern signature declaring a param of type `fn(A, B) -> R` describes a C
function pointer with that exact C signature (`void` when `R` is `Empty`; the
cb signature only admits C-scalar and `Str` params — no containers, no
`Handle[Tag]`). Codegen lowers each closure argument at an extern call site in
two pieces:

1. **The closure itself** (`aegis.lambda.N`) — the normal L3 slot-function
   `i64 @aegis.lambda.N(i64 %env, i64 %a, ...)`, plus its env block whose slot 0
   stores the fn pointer.
2. **The thunk** (`aegis.cb.N`) — a real C-ABI function
   `{ret_ty} @aegis.cb.N({c_param_ty} %0, ...)` whose body:
   - looks its *own code address* up in the callback registry
     (`call ptr @aegis_registry_get(ptr @aegis.cb.N)`) to recover the env;
   - loads the closure fn pointer from env slot 0
     (`call i64 @aegis_env_get(ptr %cb.env, i64 0)`);
   - converts each C argument into an i64 slot (`cb_arg_to_slot` — bitcast for
     Float/Bool/sized widths, no-op for Int, `aegis_str_from_cstr` + slot for
     Str) and, when the slot fn returns a value, converts the slot result back
     (`cb_slot_to_ret` — bitcast to the C return type);

   then `inttoptr`s the slot fn to `i64(i64, i64, ...)` and calls it
   indirectly, returning the marshaled result (a `void` thunk calls and `ret`s
   nothing).

The callsite that owns the closure records the pairing
(`call void @aegis_registry_set(ptr @aegis.cb.N, ptr %cb.env)`) right before
the extern call and passes the thunk address where C expects the callback. The
registry is a fixed 256-slot runtime table (runtime.c, next to `aegis_env_set`),
keyed by thunk address, and entries are never removed: an env block stays
retrievable for the whole program, so the C side may invoke the callback after
the calling statement has returned (e.g. a UDF or a callback that only fires
during a later call), and the captures it closes over are still live. Per-call
sites create fresh thunk+closure pairs, so a callback registered in a loop
captures per-iteration state correctly.

## C-layout extern structs (I6/I9)

`extern struct Name { f: T, ... }` is a `repr(C)`-equivalent: the C compiler
owns layout, Aegis never reorders or pads fields. Semantic analysis computes a
`c_size`/`c_align` per struct from the field set (scalars, `Handle[Tag]`, nested
extern structs) and rejects anything C cannot represent as raw data — owned
containers, Aegis structs, and `mut`/`pub` fields. A C-layout struct may be
returned by value (I9); a non-extern Aegis struct return is rejected.

Codegen declares each extern fn's struct params behind the host C ABI
(`codegen::is_c_struct`):

- **Windows x64 (COFF):** clang passes aggregates ≤8 bytes by value and anything
  larger **by reference**, so a >8-byte struct param is declared `ptr` and the
  callsite passes a pointer. A struct-typed local is an aggregate; the callsite
  passes that pointer directly when it already has one (a local/field backing
  def), or does `alloca` + `store` a literal copy and passes the alloca.
- **SysV (ELF):** up-to-16-byte aggregates pass by value, so the param is a
  `{ i64, i64 }`-style aggregate `param_ty`. The callsite builds a `StructValue`
  for literals or `load`s from the local's `PointerValue`.
- **`out name: T`** is `T*` on every target — the `ptr` param is the address of
  the fresh slot (I3), the C callee writes through it, and field reads pull from
  the backing store. `nil`/`null` `Handle[Tag]` fields ride as `i64 0`.

Struct **returns** by value (I9) mirror the param rules. When the aggregate does
not fit the target's register-return rule (**>8 bytes on Windows x64**, **>16 on
SysV**) the C callee returns through the hidden struct-return pointer, which the
front-end reproduces explicitly: the extern fn is declared `void` with a leading
`ptr` param, and the callsite allocates a slot in its entry block, passes the
slot's address as the first argument, and loads the aggregate back out. Smaller
aggregates return in registers and are bound directly; either way the result is
an ordinary struct value.

The IR snapshot asserts the param split literally (`declare i64 @pnt_sum(ptr,
ptr)` win64 vs `{ i64, i64 }, { i64, i64 }` SysV); the e2e suite links
`struct_host.c` so a clang-compiled host and the Aegis side agree on the same
structs (`struct stat`-shaped `Stats`, handle-chain `Node`, nested `Box`,
register- and sret-sized returns via `pnt_make`/`box_make`/`stats_make`).