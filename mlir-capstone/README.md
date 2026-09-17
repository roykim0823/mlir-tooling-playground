# Capstone — a complete, buildable out-of-tree Toy dialect

This ties the [ODS](../mlir-tablegen/ods), [DRR](../mlir-patterns/drr), [PDLL](../mlir-patterns/pdll),
[passes](../mlir-tablegen/passes), and [interfaces](../mlir-tablegen/interfaces) lessons together into a
real, compilable MLIR project: it **defines** ops, a type and an attribute
(ODS), gives them **interfaces** (`OpInterface`/`TypeInterface`), **rewrites**
them (one pattern in DRR, three in PDLL, one in C++ generic over the
interface), wraps the rewrites in a **pass** (`--gen-pass-decls`), exposes it
through its own **`toy-opt`** tool *and* as a **plugin** for the stock
`mlir-opt`, and **tests** it with a lit suite — the same shape as an upstream MLIR dialect, or
the [`lit-and-filecheck/`](../lit-and-filecheck) track with the stock
`mlir-opt` swapped for your own binary.

Unlike the rest of the tutorial (which only *generates* C++), this directory
compiles and links against `libMLIR` — so it needs an LLVM/MLIR install with
development files.

## Layout

```
mlir-capstone/
├── CMakeLists.txt              # find_package(MLIR) + mlir_tablegen() + targets + lit suite
├── include/Toy/
│   ├── ToyInterfaces.td        # source of truth #1: BinaryArithOpInterface + ContainerTypeInterface
│   ├── ToyOps.td               # source of truth #2: dialect + ops + type + attr + DRR fold pattern
│   ├── ToyPasses.td            # source of truth #3: the -toy-fold pass (argument, options, statistic)
│   ├── ToyPatterns.pdll        # source of truth #4: PDLL fold patterns (mul) — not TableGen
│   ├── ToyDialect.h            # includes the generated dialect declaration
│   ├── ToyInterfaces.h         # includes the generated interface classes (before ops/types!)
│   ├── ToyOps.h                # includes the generated op / type / attr declarations
│   └── ToyPasses.h             # includes the generated pass factories + registration
├── lib/
│   ├── ToyDialect.cpp          # glue: initialize() registers ops + types + attrs
│   ├── ToyInterfaces.cpp       # interface dispatch + AddOp::evaluate() etc. that the ops owe the interface
│   ├── ToyPatterns.cpp         # DRR NativeCodeCall helper + PDLL C++ + a C++ pattern over the interface
│   ├── ToyPasses.cpp           # the pass body: runOnOperation() around all the patterns
│   ├── ToyTranslate.cpp        # --mlir-to-toytext / --toytext-to-mlir translations (export + import)
│   └── ToyPlugin.cpp           # mlirGetDialectPluginInfo / mlirGetPassPluginInfo -> ToyPlugin.dylib for stock mlir-opt
├── tools/
│   ├── toy-capstone.cpp        # driver: print type/attr, build IR -> print -> fold -> print
│   ├── toy-opt.cpp             # our mlir-opt: DialectRegistry + registerToyPasses() + MlirOptMain
│   ├── toy-reduce.cpp          # our mlir-reduce: same registry + MlirReduceMain
│   ├── toy-translate.cpp       # our mlir-translate: registerToyTranslations() + mlirTranslateMain
│   └── toy-lsp-server.cpp      # our mlir-lsp-server: same registry + MlirLspServerMain
├── build/docs/Toy/             # (generated) ToyDialect.md, ToyPasses.md, Toy*Interfaces.md — cmake --build build --target mlir-doc
└── test/                       # lit suite driving toy-opt (cmake --build build --target check-toy)
    ├── lit.cfg.py              # main config: toy-opt substitution -> the built binary
    ├── lit.site.cfg.py.in      # CMake fills in the build paths
    ├── fold.mlir               # -toy-fold end to end, options via -pass-pipeline
    ├── roundtrip.mlir          # custom type/attr + assemblyFormat parse -> print
    ├── invalid.mlir            # -verify-diagnostics against the ODS verifiers
    ├── plugin.mlir             # the same dialect + pass inside STOCK mlir-opt via the plugin
    ├── reduce.mlir             # toy-reduce shrinks an input while Inputs/interesting.sh says "still interesting"
    ├── lsp.test                # a JSON-RPC session for toy-lsp-server, FileChecked (hover + a Toy diagnostic)
    ├── translate.mlir          # toy-translate export + round trip + export error
    ├── translate-import.toytext # toy-translate import, locations, import error (lit runs .toytext too)
    └── Inputs/                 # helper files, excluded from discovery: interesting.sh, bad.toytext, unexportable.mlir
```

Three `.td` files and one `.pdll`. `ToyInterfaces.td` defines the two
interfaces; `ToyOps.td` (which includes it) holds the dialect, ops, a custom
type (`!toy.array<N x T>`), a custom attribute (`#toy.shape<R x C>`), and the
DRR fold pattern; `ToyPasses.td` holds the pass (it includes `PassBase.td`
rather than `OpBase.td`, so it is a separate TableGen input);
`ToyPatterns.pdll` holds the PDLL patterns and is compiled by `mlir-pdll`, not
`mlir-tblgen`. The build runs **fourteen** `mlir-tblgen` backends plus
`mlir-pdll`:

| Backend | Generated file | Consumed by |
|---|---|---|
| `--gen-op-decls` | `ToyOps.h.inc` | `ToyOps.h` (op classes) |
| `--gen-op-defs` | `ToyOps.cpp.inc` | `ToyDialect.cpp` (op methods + `GET_OP_LIST`) |
| `--gen-dialect-decls -dialect=toy` | `ToyDialect.h.inc` | `ToyDialect.h` (`class ToyDialect`) |
| `--gen-dialect-defs -dialect=toy` | `ToyDialect.cpp.inc` | `ToyDialect.cpp` |
| `--gen-typedef-decls/-defs -typedefs-dialect=toy` | `ToyTypes.{h,cpp}.inc` | `ToyOps.h` / `ToyDialect.cpp` (`ArrayType`) |
| `--gen-attrdef-decls/-defs -attrdefs-dialect=toy` | `ToyAttrs.{h,cpp}.inc` | `ToyOps.h` / `ToyDialect.cpp` (`ShapeAttr`) |
| `--gen-rewriters` | `ToyPatterns.inc` | `ToyPatterns.cpp` (`populateWithGenerated`) |
| `--gen-pass-decls -name Toy` | `ToyPasses.h.inc` | `ToyPasses.h` (factories, `registerToyPasses`) / `ToyPasses.cpp` (`ToyFoldBase`) |
| `--gen-op-interface-decls/-defs` | `ToyOpInterfaces.{h,cpp}.inc` | `ToyInterfaces.h` / `ToyInterfaces.cpp` (`BinaryArithOpInterface`) |
| `--gen-type-interface-decls/-defs` | `ToyTypeInterfaces.{h,cpp}.inc` | `ToyInterfaces.h` / `ToyInterfaces.cpp` (`ContainerTypeInterface`) |
| `mlir-pdll -x=cpp` (not tblgen) | `ToyPdllPatterns.h.inc` | `ToyPatterns.cpp` (`populateGeneratedPDLLPatterns`) |

These are the same flags the top-level `gen-all.sh` runs ad hoc; here MLIR's
`mlir_tablegen()` CMake macro plugs them into the build graph (the
[`mlir-tools/cmake/`](../mlir-tools/cmake/README.md) chapter explains every helper this
`CMakeLists.txt` uses and compares its flat layout with upstream's
per-directory template) (via
`add_public_tablegen_target`) so they re-run whenever a `.td` changes, and
`add_mlir_pdll_library()` does the same for the `.pdll`. The
type and attribute are registered in `ToyDialect::initialize()` with
`addTypes<>()` / `addAttributes<>()`, and parsed/printed via the dialect's
`useDefault{Type,Attribute}PrinterParser` hooks.

## Build & run

```bash
cmake -S . -B build -DMLIR_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/mlir
cmake --build build
./build/toy-capstone                        # 1. the standalone driver
./build/toy-opt test/fold.mlir -toy-fold    # 2. our own mlir-opt
cmake --build build --target check-toy      # 3. the lit test suite
mlir-opt --load-dialect-plugin=build/ToyPlugin.dylib --load-pass-plugin=build/ToyPlugin.dylib \
         test/fold.mlir -pass-pipeline='builtin.module(toy-fold)'      # 4. stock mlir-opt, our dialect
cmake --build build --target mlir-doc       # 5. reference docs -> build/docs/Toy/*.md
```

> The `check-toy` target needs a `lit` runner. CMake picks up `llvm-lit` or
> `lit` from `PATH` (an installed LLVM ships neither; `pip install lit`
> provides one), or pass `-DLLVM_EXTERNAL_LIT=/path/to/lit` explicitly.

### 1. The driver

Expected output of `./build/toy-capstone`:

```
=== custom type & attribute ===
type : !toy.array<3 x f64>
attr : #toy.shape<3 x 4>

=== interfaces ===
toy.add: symbol '+', commutative=yes, evaluate(6, 3)=9.000000e+00
toy.mul: symbol '*', commutative=yes, evaluate(6, 3)=1.800000e+01
toy.sub: symbol '-', commutative=no, evaluate(6, 3)=3.000000e+00
!toy.array<3 x f64>: 3 x f64

=== before ===
module {
  %0 = toy.constant 1.000000e+00
  %1 = toy.constant 2.000000e+00
  %2 = toy.add %0, %1
  toy.print %2
  %3 = toy.constant 2.000000e+00
  %4 = toy.constant 3.000000e+00
  %5 = toy.mul %3, %4
  toy.print %5
  %6 = toy.constant 5.000000e+00
  %7 = toy.constant 3.000000e+00
  %8 = toy.sub %6, %7
  toy.print %8
}

=== after folding (DRR: add, PDLL: mul, C++ via interface: sub) ===
module {
  %0 = toy.constant 3.000000e+00
  toy.print %0
  %1 = toy.constant 6.000000e+00
  toy.print %1
  %2 = toy.constant 2.000000e+00
  toy.print %2
}
```

The `=== interfaces ===` block is produced by walking the module with
`module.walk([](toy::BinaryArithOpInterface arith) { ... })` and by
`dyn_cast<toy::ContainerTypeInterface>` on the array type — no concrete op or
type class is named (see 1c below).

Three fold rules fire, one from each pattern language. `add(constant a, constant b)
-> constant (a+b)` is DRR (declared in `ToyOps.td`, arithmetic in
`foldAddF64` in `ToyPatterns.cpp`); `mul(constant a, constant b) -> constant
(a*b)` is PDLL (declared *with* its arithmetic in `ToyPatterns.pdll`); `sub` is
folded by the C++ pattern that is generic over `BinaryArithOpInterface` (and
would fold add and mul too — the driver simply applies whichever pattern
matches first). All land in the same `RewritePatternSet`. The now-unused input
constants are dead `Pure` ops and the driver removes them.

### 1b. The PDLL patterns

`ToyPatterns.pdll` puts the [`mlir-patterns/pdll/`](../mlir-patterns/pdll/README.md)
lessons to work:

```pdll
#include "Toy/ToyOps.td"                       // names + F64Attr constraint from ODS

Rewrite FoldMulF64(a: Attr, b: Attr) -> Attr [{   // native body lives IN the .pdll
  double lhs = llvm::cast<::mlir::FloatAttr>(a).getValueAsDouble();
  double rhs = llvm::cast<::mlir::FloatAttr>(b).getValueAsDouble();
  return rewriter.getF64FloatAttr(lhs * rhs);
}];

Pattern FoldMulConstants {
  let root = op<toy.mul>(op<toy.constant> {value = a: F64Attr},
                         op<toy.constant> {value = b: F64Attr});
  replace root with op<toy.constant> {value = FoldMulF64(a, b)};   // result type taken from root
}
Pattern MulByOneRight { let root = op<toy.mul>(x: Value, op<toy.constant> {value = attr<"1.0 : f64">}); replace root with x; }
Pattern MulByOneLeft  { let root = op<toy.mul>(op<toy.constant> {value = attr<"1.0 : f64">}, x: Value); replace root with x; }
```

`add_mlir_pdll_library` (CMake) runs `mlir-pdll -x=cpp` over it, producing
`ToyPdllPatterns.h.inc`: one `struct : PDLPatternModule` per `Pattern`, the
native body as a static function, and `populateGeneratedPDLLPatterns()`.
`ToyPatterns.cpp` includes that next to the DRR output and calls both populate
functions. Two consequences show up elsewhere in the project:

- The PDL IR is parsed (`pdl` dialect) and compiled when the pattern set is
  frozen (`pdl_interp` dialect), so `ToyPasses.td` lists both in
  `dependentDialects`, the library links `MLIRPDLDialect`,
  `MLIRPDLInterpDialect`, `MLIRRewrite` and `MLIRParser`, and the hand-rolled
  driver loads the two dialects explicitly.
- Nothing else changes: `toy-opt`, the pass body, and the tests are unaware of
  which language a pattern was written in.

### 1c. The interfaces

`ToyInterfaces.td` puts the [`../interfaces/`](../mlir-tablegen/interfaces/README.md)
lessons to work:

```tablegen
def BinaryArithOpInterface : OpInterface<"BinaryArithOpInterface"> {
  let cppNamespace = "::toy";
  let methods = [
    InterfaceMethod<"...", "double", "evaluate", (ins "double":$lhs, "double":$rhs)>,   // per op
    InterfaceMethod<"...", "::llvm::StringRef", "getSymbol", (ins)>,                    // per op
    InterfaceMethod<"...", "bool", "isCommutative", (ins), "", [{ return false; }]>,   // default
    InterfaceMethod<"...", "::mlir::Value", "getLhsValue", (ins), [{ return $_op->getOperand(0); }]>, // shared
    InterfaceMethod<"...", "::mlir::Value", "getRhsValue", (ins), [{ return $_op->getOperand(1); }]>,
  ];
}
def ContainerTypeInterface : TypeInterface<"ContainerTypeInterface"> { /* getNumElements, getContainedType */ }
```

```tablegen
// ToyOps.td — add/mul override the isCommutative default, sub keeps it
def AddOp : Toy_Op<"add", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface, ["isCommutative"]>]> ...
def SubOp : Toy_Op<"sub", [Pure, DeclareOpInterfaceMethods<BinaryArithOpInterface>]> ...
def Toy_ArrayType : Toy_Type<"Array", [DeclareTypeInterfaceMethods<ContainerTypeInterface>]> ...
```

```cpp
// ToyInterfaces.cpp — what the ops and the type owe the interfaces
double AddOp::evaluate(double lhs, double rhs) { return lhs + rhs; }
llvm::StringRef AddOp::getSymbol() { return "+"; }
bool AddOp::isCommutative() { return true; }
double SubOp::evaluate(double lhs, double rhs) { return lhs - rhs; }
llvm::StringRef SubOp::getSymbol() { return "-"; }               // isCommutative(): default false
int64_t ArrayType::getNumElements() const { return getSize(); }  // type-interface methods are const
```

This is where the interface pays off. Nothing below names `AddOp`, `MulOp` or `SubOp`:

```cpp
// ToyPatterns.cpp — one C++ pattern for every implementer, present and future
struct FoldBinaryArithConstants : OpInterfaceRewritePattern<toy::BinaryArithOpInterface> {
  LogicalResult matchAndRewrite(toy::BinaryArithOpInterface op, PatternRewriter &rewriter) const override {
    auto lhs = op.getLhsValue().getDefiningOp<toy::ConstantOp>();
    auto rhs = op.getRhsValue().getDefiningOp<toy::ConstantOp>();
    if (!lhs || !rhs) return failure();
    rewriter.replaceOpWithNewOp<toy::ConstantOp>(
        op, op.evaluate(lhs.getValue().convertToDouble(), rhs.getValue().convertToDouble()));
    return success();
  }
};
// ToyPasses.cpp — "how many foldable ops" without a list of op classes
module.walk([&](toy::BinaryArithOpInterface) { ++n; });
```

`toy.sub` has no DRR or PDLL pattern; it is folded purely because it
implements the interface (`test/fold.mlir`, `@sub_fold_interface`). The one
build rule: `ToyInterfaces.h` must be included *before* the generated op and
type classes, because their base-class lists name
`::toy::BinaryArithOpInterface::Trait` / `::toy::ContainerTypeInterface::Trait`.

### 2. The pass and `toy-opt`

The driver calls `applyPatternsGreedily` by hand. Real projects wrap that in a
**pass** so the pass manager can schedule it, and expose it through an
opt-style tool. The pass is declared in TableGen (see the
[`../passes/`](../mlir-tablegen/passes/README.md) lessons for the generated code):

```tablegen
// include/Toy/ToyPasses.td
def ToyFold : Pass<"toy-fold", "::mlir::ModuleOp"> {
  let summary = "Constant-fold BinaryArithOpInterface ops (add/mul/sub) using the DRR, PDLL and C++ patterns";
  let dependentDialects = ["::toy::ToyDialect", "::mlir::pdl::PDLDialect", "::mlir::pdl_interp::PDLInterpDialect"];
  let options = [
    Option<"maxIterations", "max-iterations", "int64_t", "10", "Maximum number of greedy rewrite iterations ...">,
    Option<"report",        "report",         "bool",    "false", "Emit a remark on the module with the number of folded ops">,
  ];
  let statistics = [Statistic<"numFolded", "num-folded", "Number of BinaryArithOpInterface ops folded away">];
}
```

`mlir-tblgen --gen-pass-decls -name Toy` turns that into `ToyPasses.h.inc`,
which two files include with different guards:

```cpp
// include/Toy/ToyPasses.h — the public surface
#define GEN_PASS_DECL              // struct ToyFoldOptions; createToyFold(); createToyFold(ToyFoldOptions)
#include "Toy/ToyPasses.h.inc"
#define GEN_PASS_REGISTRATION      // registerToyFold(); registerToyPasses()
#include "Toy/ToyPasses.h.inc"

// lib/ToyPasses.cpp — the body
#define GEN_PASS_DEF_TOYFOLD       // template <class D> class impl::ToyFoldBase : OperationPass<ModuleOp>
#include "Toy/ToyPasses.h.inc"

struct ToyFoldPass : public toy::impl::ToyFoldBase<ToyFoldPass> {
  using Base::Base;
  void runOnOperation() override {
    RewritePatternSet patterns(&getContext());
    toy::populateToyFoldPatterns(patterns);
    GreedyRewriteConfig config;
    config.maxIterations = maxIterations;            // generated Pass::Option<int64_t>
    bool converged = succeeded(applyPatternsGreedily(getOperation(), std::move(patterns), config));
    numFolded += /* foldable ops before - after */;  // generated Pass::Statistic
    if (report) emitRemark(getOperation().getLoc()) << "toy-fold: folded ...";
  }
};
```

Everything the pass manager needs besides `runOnOperation()` — argument name,
description, `clonePass`, `getDependentDialects`, the option/statistic members,
the `createToyFold()` factories — comes from the generated base class.

`tools/toy-opt.cpp` is then an `mlir-opt` for this dialect in ~15 lines:

```cpp
mlir::DialectRegistry registry;
registry.insert<toy::ToyDialect, mlir::func::FuncDialect>();  // Func so tests can use func.func
toy::registerToyPasses();            // generated: -toy-fold
mlir::registerTransformsPasses();    // stock: -canonicalize, -cse, ...
return mlir::asMainReturnCode(mlir::MlirOptMain(argc, argv, "Toy dialect optimizer driver\n", registry));
```

`MlirOptMain` (from `MLIROptLib`) supplies everything else mlir-opt does:
`-pass-pipeline`, `-split-input-file`, `-verify-diagnostics`,
`--mlir-print-ir-after-all`, `--help` — the whole debugging toolkit in
[`../mlir-tools/debugging/`](../mlir-tools/debugging/README.md) applies to `toy-opt`
unchanged. Try it:

```bash
./build/toy-opt --help | grep -A2 toy-fold
./build/toy-opt test/fold.mlir -toy-fold
./build/toy-opt test/fold.mlir -toy-fold='report=true' -o /dev/null
#   test/fold.mlir:0:0: remark: toy-fold: folded 10 op(s)
./build/toy-opt test/fold.mlir -pass-pipeline='builtin.module(toy-fold{max-iterations=1 report=true})' -o /dev/null
#   test/fold.mlir:0:0: remark: toy-fold: folded 10 op(s); stopped at max-iterations without confirming a fixpoint
./build/toy-opt test/fold.mlir -toy-fold --mlir-print-ir-after-all 2>&1 | head
```

> **`--mlir-pass-statistics` prints an empty report here.** `Pass::Statistic`
> is an `llvm::Statistic`, which release LLVM builds (Homebrew included) compile
> out; stock `mlir-opt -cse --mlir-pass-statistics` is empty too. The `report`
> option exists so the count is observable regardless — diagnostics are never
> compiled out.

### 3. Testing with lit

`test/` is a standard lit suite, wired exactly like
[`lit-and-filecheck/example/`](../lit-and-filecheck/example): a
`lit.site.cfg.py.in` that CMake fills with build paths, a hand-written
`lit.cfg.py`, and `add_lit_testsuite(check-toy ... DEPENDS toy-opt)` so the
tests rebuild the tool first. The one line that differs from testing stock
`mlir-opt` is the tool substitution:

```python
# test/lit.cfg.py
llvm_config.add_tool_substitutions(["toy-opt"], [config.toy_tools_dir])
```

so `toy-opt` in a `RUN:` line resolves to `build/toy-opt`:

```mlir
// test/fold.mlir
// RUN: toy-opt %s -toy-fold | FileCheck %s

// CHECK-LABEL: func.func @single_fold
func.func @single_fold() -> f64 {
  // CHECK-NEXT: %[[C:.*]] = toy.constant 3.000000e+00
  // CHECK-NEXT: return %[[C]]
  %0 = toy.constant 1.0
  %1 = toy.constant 2.0
  %2 = toy.add %0, %1
  return %2 : f64
}
```

The tests cover the things a dialect ships: `fold.mlir` runs the
pass (plain, with options through `-pass-pipeline`, and checks the `report`
remark on stderr; its `@mul_fold_pdll` / `@mul_by_one_pdll` / `@mixed_drr_pdll`
functions exercise the PDLL patterns and a PDLL fold feeding a DRR fold, and
`@sub_fold_interface` the C++ pattern generic over the interface), `roundtrip.mlir` parses and prints the custom type,
attribute, and op `assemblyFormat`s, and `invalid.mlir` uses
`-split-input-file -verify-diagnostics` to pin the ODS verifier and parser
error messages.

`plugin.mlir` (Section 4) does the fold again inside stock `mlir-opt`,
`reduce.mlir` runs `toy-reduce` (Section 5), `lsp.test` drives
`toy-lsp-server` over JSON-RPC (Section 6), and `translate.mlir` /
`translate-import.toytext` exercise both directions of `toy-translate`
(Section 8).

```
$ cmake --build build --target check-toy
-- Testing: 8 tests, 8 workers --
Total Discovered Tests: 8
  Passed: 8 (100.00%)
```

### 4. Plugins: Toy inside the stock `mlir-opt`

A custom `toy-opt` is not the only way to get a dialect into a tool. Stock
`mlir-opt` (and anything built on `MlirOptMain`) can **load dialects and
passes from a shared library** at run time:

```bash
mlir-opt --load-dialect-plugin=build/ToyPlugin.dylib --show-dialects | tr ',' '\n' | grep toy
# toy
mlir-opt --load-pass-plugin=build/ToyPlugin.dylib --list-passes | grep -A1 -- '--toy-fold'
#   --toy-fold   -   Constant-fold BinaryArithOpInterface ops (add/mul/sub) ...
mlir-opt --load-dialect-plugin=build/ToyPlugin.dylib --load-pass-plugin=build/ToyPlugin.dylib \
         test/fold.mlir -pass-pipeline='builtin.module(toy-fold{report=true})'
# test/fold.mlir:0:0: remark: toy-fold: folded 10 op(s)
# module { ... }
```

(`.so` on Linux. LLVM `MODULE` libraries have no `lib` prefix.)

The plugin is 20 lines (`lib/ToyPlugin.cpp`): two `extern "C"` functions
returning a struct with an API version, a name, and a callback. `mlir-opt`
`dlopen`s the file, looks each symbol up by name, checks `apiVersion`, and
calls the callback — one to fill the `DialectRegistry`, one to register passes.
One library may export both, as here:

```cpp
extern "C" LLVM_ATTRIBUTE_WEAK ::mlir::DialectPluginLibraryInfo mlirGetDialectPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "Toy", LLVM_VERSION_STRING,
          [](::mlir::DialectRegistry *registry) { registry->insert<toy::ToyDialect>(); }};
}
extern "C" LLVM_ATTRIBUTE_WEAK ::mlir::PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "ToyPasses", LLVM_VERSION_STRING,
          []() { toy::registerToyPasses(); }};
}
```

A plugin works only if two rules are followed:

1. **Link the host's MLIR, and nothing else of MLIR.** `mlir-opt` links
   `libMLIR.dylib`; the plugin must resolve every MLIR symbol from that same
   library. Linking `MLIRToy` would drag in its `PUBLIC` static `MLIRIR`,
   `MLIRPass`, … and every `TypeID` would exist twice — `isa<toy::AddOp>`
   across the boundary would silently fail. So the CMake target reuses the Toy
   *object files* and links only the `MLIR` dylib target:
   ```cmake
   if(TARGET MLIR)                       # only installs that ship libMLIR.dylib/.so can host plugins
     add_llvm_library(ToyPlugin MODULE lib/ToyPlugin.cpp $<TARGET_OBJECTS:obj.MLIRToy>
                      DEPENDS ToyInterfacesIncGen ToyIncGen ToyPassIncGen ToyPdllIncGen
                      LINK_LIBS MLIR)
   endif()
   ```
   `otool -L build/ToyPlugin.dylib` (or `ldd`) should list `libMLIR` and
   `libLLVM` and no static MLIR pieces. The same reasoning is why `toy-opt`
   and `toy-capstone` are fine linking statically: they *are* the host.
2. **Run plugin passes through `-pass-pipeline`, not a `-toy-fold` flag.**
   `mlir-opt` parses its command line *before* loading plugins, so the
   per-pass flags that registration would create never exist:
   ```
   $ mlir-opt --load-pass-plugin=build/ToyPlugin.dylib test/fold.mlir -toy-fold
   mlir-opt: Unknown command line argument '-toy-fold'.
   ```
   The `-pass-pipeline` string is parsed after loading, so
   `-pass-pipeline='builtin.module(toy-fold{report=true})'` works, options
   included.

`test/plugin.mlir` pins all of this with lit: the fold through stock
`mlir-opt`, parse-only with just the dialect plugin, and the exact error
without any plugin. Its `REQUIRES: toy-plugin` line makes it `UNSUPPORTED`
(not failing) on an LLVM install without the MLIR shared library; the
`%toy_plugin` substitution is filled in by CMake with the built path.

### 5. Reducing a failing input: `toy-reduce`

Stock `mlir-reduce` cannot parse Toy and has no plugin flags, so the capstone
builds its own reducer the same way it builds `toy-opt`: `tools/toy-reduce.cpp`
is `MlirReduceMain` plus the registry and pass registrations. Usage, the
interestingness-script contract, and the lit test in `test/reduce.mlir` are
covered in the [`mlir-tools/reduce/`](../mlir-tools/reduce/README.md) track, Section 5.

```bash
./build/toy-reduce test/reduce.mlir -reduction-tree='traversal-mode=0 test=test/Inputs/interesting.sh' -o reduced.mlir
```

### 6. Editor support: `toy-lsp-server`

The stock `mlir-lsp-server` marks every Toy op as `Dialect 'toy' not found`,
so the capstone builds its own language server, `tools/toy-lsp-server.cpp`:
`MlirLspServerMain` plus the registry, linked against `MLIRLspServerLib`.
Point VS Code's `mlir.server_path` at `build/toy-lsp-server` (the repo's
`.vscode/settings.json` shows where) and Toy files get diagnostics from the
ODS verifiers, hover, and go-to-definition. `test/lsp.test` pins that with a
JSON-RPC session run through lit. The [`mlir-tools/lsp/`](../mlir-tools/lsp/README.md)
track explains the protocol, the sessions, and the TableGen/PDLL compilation
databases this build also writes (`build/tablegen_compile_commands.yml`,
`build/pdll_compile_commands.yml`).

```bash
./build/toy-lsp-server --lit-test < ../mlir-tools/lsp/sessions/toy.session 2>/dev/null | ../mlir-tools/lsp/summarize.py
```

### 7. Reference documentation: `mlir-doc`

The `summary` and `description` fields in the three `.td` files, plus the
structure ODS can derive (operands, results, syntax, traits, parameters, pass
options), render to Markdown with the doc backends:

```bash
cmake --build build --target mlir-doc
find build/docs -type f
# build/docs/Toy/ToyDialect.md         --gen-dialect-doc -dialect=toy   (ops, attribute, type)
# build/docs/Toy/ToyPasses.md          --gen-pass-doc
# build/docs/Toy/ToyOpInterfaces.md    --gen-op-interface-docs
# build/docs/Toy/ToyTypeInterfaces.md  --gen-type-interface-docs
```

The CMake side is `add_mlir_doc(...)`, one call per page, with the
out-of-tree fix of setting `MLIR_BINARY_DIR` to the build directory (the
helper copies its output under it). The [`../docs/`](../mlir-tablegen/docs/README.md) track
explains what renders where — in particular why the attribute and type
parameters here are spelled `AttrParameter<"int64_t", "number of rows">`
rather than the bare `"int64_t"`: only the former fills the Description
column of the generated Parameters table.

### 8. Translation: `toy-translate`

`lib/ToyTranslate.cpp` registers two translations — export to and import from
**toytext**, a one-op-per-line text format — and `tools/toy-translate.cpp`
wraps them in `mlirTranslateMain`. The exporter is written against
`BinaryArithOpInterface`, the importer attaches toytext line numbers as
locations, and both report ordinary MLIR diagnostics:

```bash
./build/toy-translate --mlir-to-toytext test/translate.mlir
./build/toy-translate --mlir-to-toytext test/translate.mlir | ./build/toy-translate --toytext-to-mlir
./build/toy-translate --toytext-to-mlir test/translate-import.toytext --mlir-print-debuginfo
```

The [`mlir-tools/translate/`](../mlir-tools/translate/README.md) track walks through
the registration structs and the importer/exporter code.

When to prefer which: a **plugin** when you want to test or use a dialect with
the `mlir-opt` you already have (in LLVM 20 it is the only stock tool with the
`--load-*-plugin` flags) or ship it to users of a shared MLIR; a **custom
`toy-opt`** when you need to control the exact set of dialects and passes,
link statically, or run on an LLVM without the shared library.

## What each lesson contributes

- **ODS** (`ToyOps.td`): the `Dialect`, the five ops, fixed-type operands/results
  (`F64`), the `Pure` trait, a custom `OpBuilder` for `toy.constant`, and the
  `assemblyFormat` that gives each op its clean textual form.
- **Attributes & types** (`ToyOps.td`): `Toy_ArrayType` / `Toy_ShapeAttr` with
  parameters and `assemblyFormat`, registered in `initialize()`.
- **Interfaces** (`ToyInterfaces.td`): an `OpInterface` with per-op, default
  and shared methods and a `TypeInterface`; `DeclareOpInterfaceMethods` /
  `DeclareTypeInterfaceMethods` on the implementers; an
  `OpInterfaceRewritePattern` and an interface-typed `walk` in the pass.
- **DRR** (`ToyOps.td`): the `Pat` + `NativeCodeCall` fold pattern.
- **PDLL** (`ToyPatterns.pdll`): three `Pattern`s with an inline native
  `Rewrite`, compiled by `add_mlir_pdll_library`, sharing the pattern set with
  DRR; the `pdl` / `pdl_interp` dependent dialects.
- **Passes** (`ToyPasses.td`): the `Pass` record with options, a statistic and a
  dependent dialect; `GEN_PASS_DECL` / `GEN_PASS_DEF_*` / `GEN_PASS_REGISTRATION`.
- **Hand-written glue** (the part TableGen can't do): `ToyDialect::initialize()`
  registering the ops, the `foldAddF64` C++ helper, and `runOnOperation()`.
- **The driver**: uses the generated builders (`create<ConstantOp>(loc, 1.0)`),
  the verifier (`mlir::verify`), and the greedy rewrite driver
  (`applyPatternsGreedily`).
- **Documentation** (`--gen-dialect-doc`, `--gen-pass-doc`, `--gen-*-interface-docs`):
  the `description` fields and `AttrParameter`/`TypeParameter` descriptions,
  rendered by the `mlir-doc` target.
- **The tool**: `MlirOptMain` + `registerToyPasses()`.
- **Translation**: `TranslateFromMLIRRegistration` / `TranslateToMLIRRegistration`
  + `mlirTranslateMain`, with locations and diagnostics on both sides.
- **The plugin**: `mlirGetDialectPluginInfo` / `mlirGetPassPluginInfo`
  exported from a `MODULE` library linked against the `MLIR` dylib only.
- **lit & FileCheck** (`test/`): the two-file lit config with a tool
  substitution for our binary, `RUN:`/`CHECK:` tests, `-verify-diagnostics`.
