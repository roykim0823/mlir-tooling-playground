# Capstone — a complete, buildable out-of-tree Toy dialect

This ties the [ODS](../ods) and [DRR](../drr) lessons together into a real,
compilable MLIR dialect: it **defines** ops (ODS), **rewrites** them (DRR), and
links into a standalone program that builds IR, prints it, applies the rewrite,
and prints again.

Unlike the rest of the tutorial (which only *generates* C++), this directory
compiles and links against `libMLIR` — so it needs an LLVM/MLIR install with
development files.

## Layout

```
capstone-toy/
├── CMakeLists.txt              # find_package(MLIR) + mlir_tablegen() + targets
├── include/Toy/
│   ├── ToyOps.td               # SINGLE source of truth: dialect + ops + type + attr + fold pattern
│   ├── ToyDialect.h            # includes the generated dialect declaration
│   └── ToyOps.h                # includes the generated op / type / attr declarations
├── lib/
│   ├── ToyDialect.cpp          # glue: initialize() registers ops + types + attrs
│   └── ToyPatterns.cpp         # NativeCodeCall helper + populate wrapper
└── tools/
    └── toy-capstone.cpp        # driver: print type/attr, build IR -> print -> fold -> print
```

`ToyOps.td` is the one `.td` file — dialect, ops, a custom type
(`!toy.array<N x T>`), a custom attribute (`#toy.shape<R x C>`), and the fold
pattern. The build runs **nine** `mlir-tblgen` backends over it:

| Backend | Generated file | Consumed by |
|---|---|---|
| `--gen-op-decls` | `ToyOps.h.inc` | `ToyOps.h` (op classes) |
| `--gen-op-defs` | `ToyOps.cpp.inc` | `ToyDialect.cpp` (op methods + `GET_OP_LIST`) |
| `--gen-dialect-decls -dialect=toy` | `ToyDialect.h.inc` | `ToyDialect.h` (`class ToyDialect`) |
| `--gen-dialect-defs -dialect=toy` | `ToyDialect.cpp.inc` | `ToyDialect.cpp` |
| `--gen-typedef-decls/-defs -typedefs-dialect=toy` | `ToyTypes.{h,cpp}.inc` | `ToyOps.h` / `ToyDialect.cpp` (`ArrayType`) |
| `--gen-attrdef-decls/-defs -attrdefs-dialect=toy` | `ToyAttrs.{h,cpp}.inc` | `ToyOps.h` / `ToyDialect.cpp` (`ShapeAttr`) |
| `--gen-rewriters` | `ToyPatterns.inc` | `ToyPatterns.cpp` (`populateWithGenerated`) |

These are the same flags the top-level `gen-all.sh` runs ad hoc; here MLIR's
`mlir_tablegen()` CMake macro plugs them into the build graph (via
`add_public_tablegen_target`) so they re-run whenever `ToyOps.td` changes. The
type and attribute are registered in `ToyDialect::initialize()` with
`addTypes<>()` / `addAttributes<>()`, and parsed/printed via the dialect's
`useDefault{Type,Attribute}PrinterParser` hooks.

## Build & run

```bash
cmake -S . -B build -DMLIR_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/mlir
cmake --build build
./build/toy-capstone
```

Expected output:

```
=== custom type & attribute ===
type : !toy.array<3 x f64>
attr : #toy.shape<3 x 4>

=== before ===
module {
  %0 = toy.constant 1.000000e+00
  %1 = toy.constant 2.000000e+00
  %2 = toy.add %0, %1
  toy.print %2
}

=== after folding add(constant, constant) ===
module {
  %0 = toy.constant 3.000000e+00
  toy.print %0
}
```

The fold rule `add(constant a, constant b) -> constant (a+b)` (declared in
`ToyOps.td`, arithmetic done in `foldAddF64` in `ToyPatterns.cpp`) rewrites the
add; the now-unused input constants are dead `Pure` ops and the greedy driver
removes them, leaving a single `toy.constant 3.0` feeding the side-effecting
`toy.print`.

## What each lesson contributes

- **ODS** (`ToyOps.td`): the `Dialect`, the four ops, fixed-type operands/results
  (`F64`), the `Pure` trait, a custom `OpBuilder` for `toy.constant`, and the
  `assemblyFormat` that gives each op its clean textual form.
- **DRR** (`ToyOps.td`): the `Pat` + `NativeCodeCall` fold pattern.
- **Hand-written glue** (the part TableGen can't do): `ToyDialect::initialize()`
  registering the ops, and the `foldAddF64` C++ helper.
- **The driver**: uses the generated builders (`create<ConstantOp>(loc, 1.0)`),
  the verifier (`mlir::verify`), and the greedy rewrite driver
  (`applyPatternsGreedily`).
