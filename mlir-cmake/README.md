# Out-of-tree CMake — `add_mlir_dialect`, `add_mlir_dialect_library`, `mlir_tablegen`, and the `standalone` template

Every out-of-tree MLIR project is built with the same handful of CMake helpers
that MLIR itself uses. They are not documented in one place, and their
behaviour out of tree differs in small ways from in tree. This chapter reads
them off the installed `AddMLIR.cmake`, shows each one in a **minimal project
you can copy** ([`skeleton/`](skeleton)), maps that to the two other layouts
you will meet — this repo's [capstone](../mlir-tablegen/capstone-toy) and
upstream's `mlir/examples/standalone` — and ends with how to inspect a build.

```bash
./try.sh          # builds skeleton/ from scratch in a temp dir, then inspects builds
./try.sh 2        # one section
```

Needs a prebuilt LLVM/MLIR with CMake files (`brew install llvm@20`); `try.sh`
finds it via `llvm-config` or `MLIR_DIR`. Section 3 inspects the capstone's
`build/` and is skipped with a hint until it exists.

| # | Section |
|---|---|
| 1 | [The skeleton, file by file](#1-the-skeleton-file-by-file) |
| 2 | [The helpers, what they expand to](#2-the-helpers-what-they-expand-to) |
| 3 | [Three layouts: skeleton, capstone, upstream standalone](#3-three-layouts-skeleton-capstone-upstream-standalone) |
| 4 | [Inspecting a build](#4-inspecting-a-build) |
| 5 | [Starting your own project](#5-starting-your-own-project) |

---

## 1. The skeleton, file by file

[`skeleton/`](skeleton) is a one-op dialect (`hello.world`) with an opt tool
and a lit test, in the upstream layout of one `CMakeLists.txt` per directory:

```
skeleton/
├── CMakeLists.txt              # find_package(MLIR), include the helpers, include dirs, add_subdirectory ×4
├── include/Hello/
│   ├── CMakeLists.txt          # add_mlir_dialect(HelloOps hello) + add_mlir_doc(...)
│   ├── HelloOps.td             # dialect + one op
│   ├── HelloDialect.h          # includes the generated HelloOpsDialect.h.inc
│   └── HelloOps.h              # includes the generated HelloOps.h.inc
├── lib/Hello/
│   ├── CMakeLists.txt          # add_mlir_dialect_library(MLIRHello ... DEPENDS MLIRHelloOpsIncGen LINK_LIBS PUBLIC MLIRIR)
│   └── HelloDialect.cpp        # initialize() + the generated .cpp.inc files
├── hello-opt/
│   ├── CMakeLists.txt          # add_llvm_executable + the MLIR_DIALECT_LIBS global property
│   └── hello-opt.cpp           # MlirOptMain
└── test/
    ├── CMakeLists.txt          # configure_lit_site_cfg + add_lit_testsuite(check-hello)
    ├── lit.cfg.py / lit.site.cfg.py.in
    └── roundtrip.mlir
```

```bash
cmake -G Ninja -S skeleton -B /tmp/hello -DMLIR_DIR=$(brew --prefix llvm@20)/lib/cmake/mlir
cmake --build /tmp/hello --target check-hello
# -- Testing: 1 tests, 1 workers --
#   Passed: 1 (100.00%)
```

**The top-level `CMakeLists.txt`** is the part every project shares. Four
blocks, in this order:

```cmake
find_package(MLIR REQUIRED CONFIG)                        # 1. finds MLIR, which finds LLVM
list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}" "${LLVM_CMAKE_DIR}")
include(TableGen)          # tablegen(), add_public_tablegen_target()
include(AddLLVM)           # add_llvm_executable(), add_llvm_library(), add_lit_testsuite()
include(AddMLIR)           # add_mlir_dialect(), add_mlir_dialect_library(), add_mlir_doc(), ...
include(HandleLLVMOptions) # compiler flags matching the LLVM build (RTTI off, warnings, ...)

set(MLIR_BINARY_DIR ${CMAKE_BINARY_DIR})                  # 2. in-tree variables an install lacks
set(LLVM_RUNTIME_OUTPUT_INTDIR ${CMAKE_BINARY_DIR}/bin)   #    tools -> build/bin
set(LLVM_LIBRARY_OUTPUT_INTDIR ${CMAKE_BINARY_DIR}/lib)   #    libraries -> build/lib

include_directories(${LLVM_INCLUDE_DIRS} ${MLIR_INCLUDE_DIRS})   # 3. headers: theirs, ours, GENERATED
include_directories(${PROJECT_SOURCE_DIR}/include)
include_directories(${PROJECT_BINARY_DIR}/include)               #    <- where the .inc files land
add_definitions(${LLVM_DEFINITIONS})

add_subdirectory(include)  # 4. one directory per concern
add_subdirectory(lib)
add_subdirectory(hello-opt)
add_subdirectory(test)
```

Most "the upstream template works and mine does not" problems trace back to
two of those lines. `include_directories(${PROJECT_BINARY_DIR}/include)`: the
generated `.inc` files are written *under the build tree*, mirroring the
source path, so `#include "Hello/HelloOps.h.inc"` only resolves with the build
tree on the include path. And `HandleLLVMOptions`: without it your code is
compiled with RTTI while LLVM was built without, and the first `dyn_cast`
gives an undefined-typeinfo link error.

## 2. The helpers, what they expand to

Read straight from `lib/cmake/mlir/AddMLIR.cmake` in the LLVM 20 install.

**`mlir_tablegen(<out.inc> <backend flags...>)`** is one `mlir-tblgen` run on
the file named by the `LLVM_TARGET_DEFINITIONS` variable, with the directory's
include paths as `-I`. It also appends the file and its include paths to
`build/tablegen_compile_commands.yml` — the database
[`tblgen-lsp-server`](../mlir-lsp/README.md) reads. Outputs accumulate in
`TABLEGEN_OUTPUT`; **`add_public_tablegen_target(<name>)`** turns that list
into a target the library can `DEPENDS` on, then clears it.

**`add_mlir_dialect(<Td> <namespace>)`** is six `mlir_tablegen` calls and one
target, with fixed names:

```cmake
function(add_mlir_dialect dialect dialect_namespace)
  set(LLVM_TARGET_DEFINITIONS ${dialect}.td)
  mlir_tablegen(${dialect}.h.inc -gen-op-decls)
  mlir_tablegen(${dialect}.cpp.inc -gen-op-defs)
  mlir_tablegen(${dialect}Types.h.inc -gen-typedef-decls -typedefs-dialect=${dialect_namespace})
  mlir_tablegen(${dialect}Types.cpp.inc -gen-typedef-defs -typedefs-dialect=${dialect_namespace})
  mlir_tablegen(${dialect}Dialect.h.inc -gen-dialect-decls -dialect=${dialect_namespace})
  mlir_tablegen(${dialect}Dialect.cpp.inc -gen-dialect-defs -dialect=${dialect_namespace})
  add_public_tablegen_target(MLIR${dialect}IncGen)
  add_dependencies(mlir-headers MLIR${dialect}IncGen)
endfunction()
```

So `add_mlir_dialect(HelloOps hello)` yields `HelloOps.h.inc`,
`HelloOpsTypes.h.inc`, `HelloOpsDialect.h.inc` (note: `<Td>Dialect`, not
`<Dialect>`) and the target `MLIRHelloOpsIncGen`. What it does **not** cover:
attributes (`-gen-attrdef-*`), enums, DRR patterns, passes, interfaces — for
those you write `mlir_tablegen` calls yourself, which is exactly what the
capstone does for its 14 backends. `add_mlir_interface(<Td>)` is the same
idea for `-gen-op-interface-decls/-defs` (op interfaces only).
`add_mlir_pdll_library` and `add_mlir_doc` were covered in the
[PDLL](../mlir-pdll/README.md) and [docs](../mlir-tablegen/docs/README.md)
tracks.

**`add_mlir_dialect_library(<name> <sources> DEPENDS <IncGen targets> LINK_LIBS PUBLIC <MLIR libs>)`**
goes `add_mlir_dialect_library` → `add_mlir_library` → `llvm_add_library` and adds four things over a plain `add_library`:

| Effect | Why you care |
|---|---|
| `DEPENDS` on the IncGen targets | the `.inc` files exist before the first `.cpp` compiles — forget it and the build races |
| `LINK_LIBS PUBLIC MLIRIR ...` | consumers of your library get MLIR's libraries transitively; the standalone template lists `MLIRIR MLIRInferTypeOpInterface MLIRFuncDialect` |
| an `obj.<name>` object library | the same objects reusable without the static-library link (the capstone's plugin uses `$<TARGET_OBJECTS:obj.MLIRToy>`) |
| the global property `MLIR_DIALECT_LIBS` | `get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)` in a tool's CMakeLists links every dialect library you defined — the upstream idiom |

Siblings: `add_mlir_conversion_library`, `add_mlir_translation_library`,
`add_mlir_extension_library` do the same with their own global properties
(`MLIR_CONVERSION_LIBS`, `MLIR_TRANSLATION_LIBS`). Static by default; `SHARED`
or `BUILD_SHARED_LIBS=ON` switch. `mlir_target_link_libraries(tgt type libs)`
is the dylib-aware `target_link_libraries`: with `-DMLIR_LINK_MLIR_DYLIB=ON`
it links `libMLIR.dylib` instead of the listed static pieces.

**Tools** are plain LLVM executables. The three lines you see everywhere:

```cmake
add_llvm_executable(hello-opt hello-opt.cpp)
llvm_update_compile_flags(hello-opt)            # same flags as the LLVM build
target_link_libraries(hello-opt PRIVATE ${dialect_libs} MLIROptLib MLIRFuncDialect)
mlir_check_all_link_libraries(hello-opt)        # configure-time error on a misspelt MLIR* library
```

`MLIROptLib`, `MLIRReduceLib`, `MLIRTranslateLib`, `MLIRLspServerLib` are the
"tool minus `main()`" libraries the capstone links for `toy-opt`,
`toy-reduce`, `toy-translate`, `toy-lsp-server`. `LLVM_RUNTIME_OUTPUT_INTDIR`
decides whether the binary lands in `build/bin/` (skeleton, upstream) or in
`build/` (capstone, which does not set it) — your `lit.cfg.py` tool
substitution must agree.

**Plugins**: `add_llvm_library(<name> MODULE ...)`. Two spellings exist: upstream's
`PLUGIN_TOOL mlir-opt`, which relies on in-tree knowledge of the host, and the
capstone's `LINK_LIBS MLIR` (the shared library the host itself links). See
the capstone README, Section 4. LLVM `MODULE` libraries have no `lib` prefix.

**Tests**: `configure_lit_site_cfg(<in> <out> MAIN_CONFIG <lit.cfg.py>)`
bakes build paths into `lit.site.cfg.py`, and `add_lit_testsuite(check-X
"..." <dir> DEPENDS <tools>)` creates the target. `LLVM_EXTERNAL_LIT` names
the runner; an installed LLVM ships none, hence the
`find_program(LLVM_EXTERNAL_LIT NAMES llvm-lit lit)` fallback in both the
skeleton and the capstone. `add_lit_testsuites(PREFIX <dir> ...)` additionally
creates one `check-PREFIX-<subdir>` target per test subdirectory.

## 3. Three layouts: skeleton, capstone, upstream standalone

| | `skeleton/` | capstone | `mlir/examples/standalone` (LLVM 20) |
|---|---|---|---|
| CMake files | one per directory | **one** flat `CMakeLists.txt`, sectioned | one per directory + `include/`, `lib/` forwarders |
| Code generation | `add_mlir_dialect(HelloOps hello)` | 14 explicit `mlir_tablegen` calls in three `LLVM_TARGET_DEFINITIONS` groups + `add_mlir_pdll_library` | `add_mlir_dialect(StandaloneOps standalone)` + explicit `mlir_tablegen(... --gen-pass-decls)` for passes |
| IncGen target name | `MLIRHelloOpsIncGen` (fixed by the helper) | `ToyIncGen`, `ToyPassIncGen`, `ToyInterfacesIncGen` (chosen) | `MLIRStandaloneOpsIncGen`, `MLIRStandalonePassesIncGen` |
| Library | `MLIRHello` | `MLIRToy` | `MLIRStandalone` |
| Tools | `hello-opt` | `toy-capstone`, `toy-opt`, `toy-reduce`, `toy-translate`, `toy-lsp-server` | `standalone-opt`, `standalone-translate`, `standalone-capi-test`, Python bindings |
| Tool linkage | `${dialect_libs}` global property | libraries named explicitly | global properties (`MLIR_DIALECT_LIBS`, `MLIR_CONVERSION_LIBS`, `MLIR_TRANSLATION_LIBS`) |
| Plugin | — | `ToyPlugin` linking the `MLIR` dylib | `StandalonePlugin` with `PLUGIN_TOOL mlir-opt`, `BUILDTREE_ONLY` |
| Output dirs | `build/bin`, `build/lib` | `build/` | `build/bin`, `build/lib` |
| Docs | `add_mlir_doc` → `mlir-doc` | four `add_mlir_doc` → `mlir-doc` | two `add_mlir_doc` |
| Tests | `check-hello` | `check-toy` (`.mlir`, `.test`, `.toytext`) | `check-standalone` + `add_lit_testsuites` + CAPI tests |

Which layout to copy depends on what you are building:

- **Flat** (capstone): everything visible in one screen; every generated file
  named explicitly; no helper magic. Good for learning and for a dialect that
  needs backends `add_mlir_dialect` does not run (attributes, DRR, interfaces).
- **Per-directory** (skeleton, upstream): scales to several dialects and
  tools, matches what MLIR contributors expect, and the global-property trick
  means adding a dialect never touches the tool's CMake.

Before copying the upstream template, know two things about it. Its
top-level file has an `if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)`
branch: the `find_package` path is for building *against an install*, the
`else` branch is for being built *inside* the LLVM tree via
`LLVM_EXTERNAL_PROJECTS` — you can drop the latter. And its `lit.cfg.py` adds
`%shlibext`, `%standalone_libs`, `PYTHONPATH` and CAPI tools; strip what you
do not build.

## 4. Inspecting a build

Questions a CMake user asks about an MLIR build, and the command that answers
them (`try.sh` runs these against the capstone):

```bash
# What did configure decide? (which LLVM, which lit runner, which build type)
cmake -LA -N build | grep -E '^(LLVM_DIR|LLVM_EXTERNAL_LIT|CMAKE_BUILD_TYPE|CMAKE_GENERATOR)'

# Which targets exist?  (Makefiles)                    (Ninja)
cmake --build build --target help | grep -i toy        ninja -C build -t targets all | grep -i toy

# What exactly does an IncGen target run?  (Ninja; Makefiles: cmake --build build -- VERBOSE=1)
ninja -C build -t commands ToyIncGen | grep mlir-tblgen

# Which .td files does the tablegen LSP know about?
grep filepath build/tablegen_compile_commands.yml | sort | uniq -c

# Is a binary linked statically or against libMLIR.dylib?
otool -L build/toy-opt | grep libMLIR          # macOS; `ldd` on Linux
```

Expect every `.td` to be listed **twice per `mlir_tablegen()` call**: both the
generic `tablegen()` and MLIR's wrapper append to the file (13 lines for the
skeleton's 6 calls plus one `add_mlir_doc`). It is harmless — the language
server takes the first match — and the file is truncated when `TableGen.cmake`
is included, so it does not grow across reconfigures.

Add `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` at configure time and clangd gets a
`compile_commands.json` with the same include paths and flags as the build —
the C++ counterpart of the `.yml` databases the MLIR language servers use.

## 5. Starting your own project

1. Copy `skeleton/` (or upstream `mlir/examples/standalone`) and rename
   `Hello`/`hello` throughout: the directory, the `.td`, the C++ namespace
   (`cppNamespace`), the CMake target names. The IncGen name follows the `.td`
   name automatically.
2. Configure against your install:
   `cmake -G Ninja -S . -B build -DMLIR_DIR=$(brew --prefix llvm@20)/lib/cmake/mlir`
   (add `-DLLVM_EXTERNAL_LIT=$(which lit)` if `lit` is not on `PATH`).
3. Grow it the way the capstone did: attributes/types → add `mlir_tablegen`
   lines for `-gen-attrdef-*`/`-gen-typedef-*` next to `add_mlir_dialect`;
   passes → a `Passes.td` with `--gen-pass-decls -name X`; patterns →
   `-gen-rewriters` or `add_mlir_pdll_library`; interfaces → their own `.td`
   and IncGen target. Each is a few lines you can lift from
   [`capstone-toy/CMakeLists.txt`](../mlir-tablegen/capstone-toy/CMakeLists.txt).
4. Keep `check-<name>` green from the first op: it is the cheapest way to find
   a missing `DEPENDS` or include path.

## References

- Creating a dialect (upstream) — <https://mlir.llvm.org/docs/Tutorials/CreatingADialect/>
- The standalone template — <https://github.com/llvm/llvm-project/tree/llvmorg-20.1.8/mlir/examples/standalone>
- `AddMLIR.cmake`, `AddLLVM.cmake`, `TableGen.cmake` — `lib/cmake/{mlir,llvm}/` in your install; they are readable, and they are the truth for your version
