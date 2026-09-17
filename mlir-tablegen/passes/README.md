# Passes — declaring passes with `--gen-pass-decls`

MLIR's third TableGen workflow. [ODS](../ods) *defines* ops, [DRR](../drr)
*rewrites* them, and a **pass** is the unit the pass manager schedules to run a
transformation over the IR. Declaring passes in TableGen generates the
boilerplate every pass needs — command-line argument, name, description,
options, statistics, dependent dialects, factory function, registration — and
leaves exactly one thing to hand-write in C++: `runOnOperation()`.

> The C++ half (the `runOnOperation()` body, an opt-style tool that exposes the
> pass on the command line, and lit tests that drive it) is in the
> [`../capstone-toy/`](../capstone-toy) build. These lessons only *generate*.
> Required include: `mlir/Pass/PassBase.td`.

Unlike the other `mlir-tblgen` backends, this one needs a **group name**:

```bash
MLIR=/opt/homebrew/opt/llvm@20
$MLIR/bin/mlir-tblgen --gen-pass-decls -name Toy -I $MLIR/include 1-basics/01_pass.td
#                                      ^^^^^^^^^ required: becomes registerToyPasses()
$MLIR/bin/mlir-tblgen --gen-pass-doc         -I $MLIR/include 2-options-and-statistics/02_options_statistics.td
```

`../gen-all.sh` runs both for every lesson here (output under
`../generated/passes/`).

## Table of Contents

- 1 — [A first Pass, and what gets generated](#lesson-1--a-first-pass-and-what-gets-generated) · `1-basics/`
- 2 — [Options and statistics](#lesson-2--options-and-statistics) · `2-options-and-statistics/`
- 3 — [Anchors, dependent dialects, custom constructors](#lesson-3--anchors-dependent-dialects-custom-constructors) · `3-anchors-and-dialects/`
- [From generated code to a running pass](#from-generated-code-to-a-running-pass)

The record you write is always one of two classes from `PassBase.td`:

```tablegen
class Pass<string argument, string anchorOp = "">          // OperationPass<anchorOp>
class InterfacePass<string argument, string interface>     // InterfacePass<interface>
```

with fields `summary`, `description`, `options`, `statistics`,
`dependentDialects`, and `constructor`.

---

## Lesson 1 — A first Pass, and what gets generated

*Source: `1-basics/01_pass.td`*

```tablegen
include "mlir/Pass/PassBase.td"

def ToyFold : Pass<"toy-fold", "::mlir::ModuleOp"> {
  let summary = "Constant-fold toy.add(constant, constant)";
  let description = [{ ... used by --gen-pass-doc ... }];
}
```

This one record produces three families of names:

| You wrote | Generated |
|---|---|
| `"toy-fold"` (argument) | what you type: `toy-opt file.mlir -toy-fold` |
| `"::mlir::ModuleOp"` (anchor) | the base class `::mlir::OperationPass<::mlir::ModuleOp>`; `getOperation()` returns a `ModuleOp` |
| `ToyFold` (record name) | `ToyFoldBase`, `createToyFold()`, `registerToyFold()`, `GEN_PASS_DEF_TOYFOLD` |

The output is a single `.h.inc` organised in **macro-guarded sections**, so one
generated file serves both the public header and the implementation `.cpp`.
You `#define` a guard, `#include` the file, and get only that section:

```cpp
// --- in the public header (ToyPasses.h) --------------------------------------
#define GEN_PASS_DECL                     // every pass: factories + options structs
#include "Toy/ToyPasses.h.inc"
//   std::unique_ptr<::mlir::Pass> createToyFold();

#define GEN_PASS_REGISTRATION             // registerToyFold(), registerToyPasses()
#include "Toy/ToyPasses.h.inc"

// --- in the implementation (ToyPasses.cpp) ------------------------------------
#define GEN_PASS_DEF_TOYFOLD              // ONE pass: its CRTP base class
#include "Toy/ToyPasses.h.inc"
```

The `GEN_PASS_DEF_TOYFOLD` section is the heart of it — a CRTP base class that
already implements every virtual the pass manager needs except the body:

```cpp
namespace impl {
template <typename DerivedT>
class ToyFoldBase : public ::mlir::OperationPass<::mlir::ModuleOp> {
public:
  using Base = ToyFoldBase;

  static constexpr ::llvm::StringLiteral getArgumentName() { return "toy-fold"; }
  ::llvm::StringRef getArgument() const override { return "toy-fold"; }
  ::llvm::StringRef getDescription() const override { return "Constant-fold toy.add(constant, constant)"; }
  static constexpr ::llvm::StringLiteral getPassName() { return "ToyFold"; }
  ::llvm::StringRef getName() const override { return "ToyFold"; }

  static bool classof(const ::mlir::Pass *pass) { /* TypeID compare */ }
  std::unique_ptr<::mlir::Pass> clonePass() const override { /* copy DerivedT */ }
  void getDependentDialects(::mlir::DialectRegistry &registry) const override { }

  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(ToyFoldBase<DerivedT>)
private:
  friend std::unique_ptr<::mlir::Pass> createToyFold() {
    return std::make_unique<DerivedT>();
  }
};
} // namespace impl
```

and the `GEN_PASS_REGISTRATION` section:

```cpp
inline void registerToyFold() {
  ::mlir::registerPass([]() -> std::unique_ptr<::mlir::Pass> { return createToyFold(); });
}
inline void registerToyPasses() {   // the group named by `-name Toy`
  registerToyFold();
}
```

`registerPass` is what makes `-toy-fold` appear in an opt tool's `--help` and
in `-pass-pipeline` strings. Your part is a class deriving from the base:

```cpp
struct ToyFoldPass : public toy::impl::ToyFoldBase<ToyFoldPass> {
  void runOnOperation() override { ModuleOp m = getOperation(); /* ... */ }
};
```

> The file ends with a `GEN_PASS_CLASSES` section that emits *all* base classes
> at once. It is the pre-2022 scheme, kept for backwards compatibility; new code
> uses the per-pass `GEN_PASS_DEF_*` guards so a library can spread its passes
> across several `.cpp` files.

## Lesson 2 — Options and statistics

*Source: `2-options-and-statistics/02_options_statistics.td`*

Options parameterise a pass from the command line or from C++; statistics count
things for `--mlir-pass-statistics`. (This lesson shows every option flavour;
the capstone's real pass uses only the first two.)

```tablegen
def ToyFold : Pass<"toy-fold", "::mlir::ModuleOp"> {
  let options = [
    //     cppName          cli-name          C++ type   default  description
    Option<"maxIterations", "max-iterations", "int64_t", "10",    "Maximum number of greedy rewrite iterations">,
    Option<"report",        "report",         "bool",    "false", "Emit a remark with the number of folded ops">,
    // enum-valued: pass the llvm::cl::values(...) clause as the extra argument
    Option<"strategy", "strategy", "::toy::FoldStrategy", "::toy::FoldStrategy::Greedy",
           "Which rewrite driver to use",
           [{::llvm::cl::values(
               clEnumValN(::toy::FoldStrategy::Greedy, "greedy", "greedy worklist driver"),
               clEnumValN(::toy::FoldStrategy::Walk,   "walk",   "single top-down walk"))}]>,
    ListOption<"skipFuncs", "skip-funcs", "std::string", "Functions to leave untouched">,
  ];
  let statistics = [
    Statistic<"numFolded", "num-folded", "Number of toy.add ops folded away">,
  ];
}
```

Each `Option` shows up in **three** places in the generated code:

```cpp
// 1. GEN_PASS_DECL: a plain struct for constructing the pass from C++ ...
struct ToyFoldOptions {
  int64_t maxIterations = 10;
  bool report = false;
  ::toy::FoldStrategy strategy = ::toy::FoldStrategy::Greedy;
  ::llvm::SmallVector<std::string> skipFuncs;
};
std::unique_ptr<::mlir::Pass> createToyFold();
std::unique_ptr<::mlir::Pass> createToyFold(ToyFoldOptions options);   // ... via this overload

// 2. GEN_PASS_DEF_TOYFOLD: protected members of the base class, so the body can
//    just read `maxIterations` (they convert implicitly to the value type) ...
protected:
  ::mlir::Pass::Option<int64_t> maxIterations{*this, "max-iterations", ::llvm::cl::desc("..."), ::llvm::cl::init(10)};
  ::mlir::Pass::Option<bool> report{*this, "report", ::llvm::cl::desc("..."), ::llvm::cl::init(false)};
  ::mlir::Pass::Option<::toy::FoldStrategy> strategy{*this, "strategy", ..., ::llvm::cl::values(...)};
  ::mlir::Pass::ListOption<std::string> skipFuncs{*this, "skip-funcs", ::llvm::cl::desc("...")};
  ::mlir::Pass::Statistic numFolded{this, "num-folded", "Number of toy.add ops folded away"};

// 3. ... and a constructor that copies the struct into them.
  ToyFoldBase(ToyFoldOptions options) : ToyFoldBase() {
    maxIterations = std::move(options.maxIterations);
    /* ... */
  }
```

Because the members are `Pass::Option`s, the pass manager can also parse them
from text. The two command-line spellings:

```bash
toy-opt in.mlir -pass-pipeline='builtin.module(toy-fold{max-iterations=3 report=true skip-funcs=main,helper})'
toy-opt in.mlir -toy-fold='max-iterations=3 report=true'     # plain-flag form: ONE quoted value
```

Note the plain-flag form: options are space-separated inside a single quoted
value. They are *not* standalone flags — `--help` lists them indented under
`--toy-fold`, but `-toy-fold --max-iterations=3` is rejected as an unknown
argument.

`--gen-pass-doc` renders the same record as Markdown — this is how the pass
reference pages on mlir.llvm.org are produced:

```markdown
### `-toy-fold`
_Constant-fold toy.add(constant, constant)_
#### Options
-max-iterations : Maximum number of greedy rewrite iterations
-report         : Emit a remark with the number of folded ops
-strategy       : Which rewrite driver to use
-skip-funcs     : Functions to leave untouched
#### Statistics
num-folded : Number of toy.add ops folded away
```

> **Statistics and release builds.** `Pass::Statistic` is an `llvm::Statistic`,
> which is compiled to a no-op unless LLVM was built with assertions or
> `-DLLVM_FORCE_ENABLE_STATS=ON`. On a stock release install (Homebrew's
> `llvm@20` included) `--mlir-pass-statistics` prints an empty report — for
> every pass, including upstream ones like `-cse`. Statistics are for
> development builds; if a count must be observable in production or in tests,
> emit a remark instead (the capstone's `report` option does exactly that).
> [`../../mlir-debugging/`](../../mlir-debugging/README.md) Section 7 lists what
> else needs an assertions build.

## Lesson 3 — Anchors, dependent dialects, custom constructors

*Source: `3-anchors-and-dialects/03_anchors_dialects.td`*

**Anchors.** The second template argument decides *what the pass runs on*, and
therefore how the pass manager schedules it:

```tablegen
def ToyFoldModule  : Pass<"toy-fold-module", "::mlir::ModuleOp"> { ... }        // once per module
def ToyFoldFunc    : Pass<"toy-fold-func",   "::mlir::func::FuncOp"> { ... }    // once per function, in parallel
def ToyFoldAny     : Pass<"toy-fold-any"> { ... }                                // no anchor: any op
def ToyFoldAnyFunc : InterfacePass<"toy-fold-any-func", "::mlir::FunctionOpInterface"> { ... }
```

```cpp
class ToyFoldModuleBase  : public ::mlir::OperationPass<::mlir::ModuleOp> { ... };
class ToyFoldFuncBase    : public ::mlir::OperationPass<::mlir::func::FuncOp> { ... };
class ToyFoldAnyBase     : public ::mlir::OperationPass<> { ... };                 // getOperation() -> Operation*
class ToyFoldAnyFuncBase : public ::mlir::InterfacePass<::mlir::FunctionOpInterface> { ... };
```

| Anchor | Runs | Use when |
|---|---|---|
| `ModuleOp` | once, whole module | the pass needs a global view (symbols, cross-function) |
| `func::FuncOp` | once **per function, in parallel** | the transformation is local to a function — the common case |
| *(none)* | on whatever op it is scheduled on | utility passes (`-canonicalize`, `-cse` are like this) |
| `InterfacePass<I>` | on every op implementing `I` | function-like ops from *any* dialect, not just `func.func` |

The anchor also fixes the pipeline spelling: an anchored pass must be nested
under its anchor, `builtin.module(func.func(toy-fold-func))`, and a pass may
only modify IR inside its anchor op (the pass manager verifies this).

**Dependent dialects.** If a pass may *create* ops, types, or attributes of a
dialect, that dialect must already be loaded in the `MLIRContext` — passes run
in parallel and must not race dialect loading. List them and the backend
generates the `getDependentDialects()` override:

```tablegen
def ToyLowerToArith : Pass<"toy-lower-to-arith", "::mlir::func::FuncOp"> {
  let dependentDialects = ["::mlir::arith::ArithDialect"];
}
```

```cpp
void getDependentDialects(::mlir::DialectRegistry &registry) const override {
  registry.insert<::mlir::arith::ArithDialect>();
}
```

Dialects the pass only *reads* need not be listed; the parser loaded them. The
class named must be declared where the generated code is included (so the
`.cpp` that defines `GEN_PASS_DEF_*` must include `arith`'s header).

**Custom constructor.** By default the backend emits the `createToyFold()`
factory (and the options overload). Set `constructor` when the pass needs
arguments an `Option` can't express — a callback, a pointer to shared data:

```tablegen
def ToyFoldCustom : Pass<"toy-fold-custom", "::mlir::ModuleOp"> {
  let constructor = "::toy::createToyFoldCustomPass()";
}
```

No factory is generated; instead registration calls your expression verbatim,
and you declare/define `createToyFoldCustomPass()` yourself:

```cpp
inline void registerToyFoldCustom() {
  ::mlir::registerPass([]() -> std::unique_ptr<::mlir::Pass> {
    return ::toy::createToyFoldCustomPass();
  });
}
```

Finally, every pass in the file lands in the group registration:

```cpp
inline void registerToyPasses() {
  registerToyFoldAny();  registerToyFoldAnyFunc();  registerToyFoldCustom();
  registerToyFoldFunc(); registerToyFoldModule();   registerToyLowerToArith();
}
```

## From generated code to a running pass

Everything above is header-only boilerplate. The remaining three pieces are C++
and CMake, and the [`../capstone-toy/`](../capstone-toy/README.md) build shows
them working:

1. **The body.** `lib/ToyPasses.cpp` defines `GEN_PASS_DEF_TOYFOLD`, derives
   `ToyFoldPass` from `impl::ToyFoldBase<ToyFoldPass>`, and implements
   `runOnOperation()` — it runs the DRR patterns from the `drr/` track with
   the greedy rewrite driver and reads the `maxIterations` / `report` options.
2. **The tool.** `tools/toy-opt.cpp` is a 20-line `mlir-opt`: a
   `DialectRegistry`, a call to the generated `toy::registerToyPasses()`, and
   `MlirOptMain`. That is what makes `toy-opt in.mlir -toy-fold` work.
3. **The build.** In CMake the pass `.td` gets its own
   `set(LLVM_TARGET_DEFINITIONS ...)` + `mlir_tablegen(... -gen-pass-decls -name Toy)`,
   and `toy-opt` links `MLIROptLib`. The `test/` lit suite then drives
   `toy-opt` with `RUN:` lines exactly as the
   [`lit-and-filecheck/`](../../lit-and-filecheck) track teaches.

## References

- Pass infrastructure — <https://mlir.llvm.org/docs/PassManagement/>
  (section *Declarative Pass Specification*)
- `PassBase.td` — `mlir/Pass/PassBase.td` in your MLIR include directory
- Upstream example — `mlir/include/mlir/Transforms/Passes.td` (the stock
  `-canonicalize`, `-cse`, … passes are declared this way)
