# A self-contained lit + FileCheck example (CMake)

A tiny, **standalone** project that demonstrates the standard LLVM/MLIR testing
setup — `lit` + `FileCheck` driven by CMake — using the conventional file names
`lit.cfg.py` and `lit.site.cfg.py.in`. It does **not** depend on the rest of
this tutorial repo's passes or build system; the only requirement is a prebuilt
LLVM/MLIR (it reuses the prebuilt `mlir-opt` and `FileCheck`).

```
example/
├── CMakeLists.txt              # standalone: find_package(MLIR) + lit wiring
├── run.sh                      # one command: configure + build + run tests
└── test/
    ├── lit.cfg.py              # main lit config (hand-written, standard name)
    ├── lit.site.cfg.py.in      # site config template (CMake fills paths in)
    ├── cse.mlir                # CHECK-LABEL, CHECK-NEXT, captured variable
    ├── canonicalize.mlir       # CHECK-NOT + plain CHECK
    └── invalid.mlir            # diagnostic test (-verify-diagnostics)
```

## Quick start — just run it

```bash
cd tutorials/lit-and-filecheck/example
./run.sh
```

Expected output (3/3 passing):

```
>> Configuring (MLIR_DIR=.../llvm-project/build/lib/cmake/mlir, generator=Ninja)
>> Building + running the 'check' target (this invokes llvm-lit)
-- Testing: 3 tests, 3 workers --
...
Total Discovered Tests: 3
  Passed: 3 (100.00%)
```

`./run.sh clean` removes the build directory.

### Using a different LLVM/MLIR

`run.sh` defaults to the LLVM build bundled in this repo
(`../../../externals/llvm-project/build`). Point it anywhere else with:

```bash
MLIR_DIR=/path/to/your/llvm-build/lib/cmake/mlir ./run.sh
```

That is the only external dependency — there is nothing else repo-specific here.

## How it works (the standard CMake + lit wiring)

This is the canonical pattern you'll find in real LLVM/MLIR projects:

1. **`CMakeLists.txt`** calls `find_package(MLIR REQUIRED CONFIG)`, then
   `include(AddLLVM)` to get the helper functions, then:
   - `configure_lit_site_cfg(...)` — turns `test/lit.site.cfg.py.in` into
     `build/test/lit.site.cfg.py`, substituting absolute paths
     (`@LLVM_TOOLS_DIR@`, etc.).
   - `add_lit_testsuite(check ...)` — creates a `check` target that runs
     `llvm-lit` over the generated config.

2. **`test/lit.site.cfg.py.in`** (the *template*, in source) holds `@PLACEHOLDER@`
   tokens. After configuration it becomes the *generated* `lit.site.cfg.py` in
   the build tree, which bakes in the tool paths and then hands off to the main
   config:
   ```python
   lit_config.load_config(config, ".../test/lit.cfg.py")
   ```

3. **`test/lit.cfg.py`** (the *main* config, hand-written) declares the suite
   name, that `.mlir` files are tests (`config.suffixes`), the `ShTest` format,
   and registers tool substitutions so `mlir-opt`/`FileCheck` in RUN lines
   resolve to the prebuilt binaries.

```
build/test/lit.site.cfg.py   (generated: absolute paths)
        └── load_config ──►  test/lit.cfg.py   (the real, hand-written config)
```

This **main-config + generated-site-config** split is the part that is truly
standard across LLVM/MLIR — the names `lit.cfg.py` and `lit.site.cfg.py` are the
conventional ones lit looks for.

## The three tests, explained

| File | RUN line | Teaches |
|------|----------|---------|
| `cse.mlir` | `mlir-opt %s -cse \| FileCheck %s` | `CHECK-LABEL`, `CHECK-NEXT`, captured variable `%[[RESULT:.*]]` reused to prove both returns share one value after CSE |
| `canonicalize.mlir` | `mlir-opt %s -canonicalize \| FileCheck %s` | `CHECK-NOT` (the `arith.addi` must vanish when folding `x+0`) + a plain `CHECK` |
| `invalid.mlir` | `mlir-opt %s -split-input-file -verify-diagnostics` | diagnostic testing with `expected-error @+1 {{...}}` and `// -----` sub-test separators — no FileCheck involved |

## Try it yourself — three exercises

After `./run.sh` once, the tools are easiest to drive directly. Put them on PATH:

```bash
export PATH="$PWD/../../../externals/llvm-project/build/bin:$PATH"
```

**1. Watch one test run by hand** (exactly what the RUN line does):

```bash
mlir-opt test/cse.mlir -cse              # see the transformed IR
mlir-opt test/cse.mlir -cse | FileCheck test/cse.mlir && echo PASS
```

**2. Make it fail and read the diagnostic.** Edit `test/cse.mlir`, change the
second `%[[RESULT]]` to `%[[OTHER]]`, rerun `./run.sh`. FileCheck reports an
*undefined variable* — proving the two uses are genuinely tied to the capture.
Revert when done.

**3. Add your own test.** Drop a new `.mlir` into `test/` and rerun `./run.sh`.
Because `add_lit_testsuite` discovers tests by the `.mlir` suffix, no CMake edit
is needed — just re-run. Example:

```bash
cat > test/negate.mlir <<'EOF'
// RUN: mlir-opt %s -canonicalize | FileCheck %s
// CHECK-LABEL: func.func @double_negate
// CHECK-NOT: arith.subi
// CHECK: return %arg0
func.func @double_negate(%arg0: i32) -> i32 {
  %c0 = arith.constant 0 : i32
  %0 = arith.subi %c0, %arg0 : i32   // -x
  %1 = arith.subi %c0, %0 : i32      // -(-x) == x
  return %1 : i32
}
EOF
./run.sh
```

## Turning this into a *real* project

The only shortcut here is reusing the prebuilt `mlir-opt` as the "tool under
test." In a real out-of-tree MLIR project you would build your own driver
(say `my-opt`) and wire it in:

- add `add_subdirectory(tool)` in `CMakeLists.txt` to build `my-opt`,
- list it as a dependency so tests rebuild it first:
  ```cmake
  add_lit_testsuite(check "..." ${CMAKE_CURRENT_BINARY_DIR}/test
                    DEPENDS my-opt FileCheck)
  ```
- register `my-opt` (instead of `mlir-opt`) in `lit.cfg.py`'s
  `add_tool_substitutions(...)`,
- write RUN lines as `// RUN: my-opt %s --your-pass | FileCheck %s`.

Everything else — the two-config split, the `.mlir` tests, the directives —
stays exactly the same.
