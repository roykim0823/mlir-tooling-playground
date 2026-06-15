# Chapter 1 — lit basics

> Source: <https://llvm.org/docs/CommandGuide/lit.html> and
> <https://llvm.org/docs/TestingGuide.html>

## 1.1 What is lit?

`lit` (the **L**LVM **I**ntegrated **T**ester) is a *portable test runner*. Its
job is narrow and well-defined:

1. **Discover** test files under a directory.
2. **Read** the `RUN:` lines inside each file.
3. **Execute** those lines as shell commands (with substitutions applied).
4. **Report** a result per file: PASS / FAIL / etc.

`lit` does **not** know anything about compilers, IR, or what "correct" output
is. It just runs commands and checks their exit codes. The actual *verification*
of output is delegated to another tool — usually `FileCheck` (Chapter 2).

## 1.2 Invoking lit

```
llvm-lit [options] [tests...]
```

`tests` can be individual files or directories to search. `lit` exits non-zero
if any test fails.

The options you will actually use day-to-day:

| Option | Meaning |
|--------|---------|
| `-v`, `--verbose` | Show the failing command and its output for **failed** tests |
| `-a`, `--show-all` | Like `-v`, but for **all** tests (great for debugging a passing-but-confusing test) |
| `-q`, `--quiet` | Only show failures |
| `-s`, `--succinct` | Less output + a progress bar |
| `--filter REGEXP` | Run only tests whose **name** matches the regex |
| `-j N`, `--workers N` | Run N tests in parallel (default: auto) |
| `--time-tests` | Report wall-clock time per test |
| `--show-suites` / `--show-tests` | List discovered suites / tests and exit |
| `--debug` | Debug lit's own *configuration* discovery |
| `--order {smart,random,lexical}` | Execution order (`smart` = previously-failed first) |

You can also set `LIT_OPTS` in the environment to inject options when lit is
invoked indirectly (e.g. by a CMake `check` target):

```bash
LIT_OPTS="--filter=cse -a" cmake --build build --target check
```

## 1.3 How lit discovers tests

When you point lit at a directory, it looks for two kinds of Python config
files — and this is the standard LLVM/MLIR convention:

- **`lit.cfg.py`** — the *main* config, checked into source. Describes the test
  format and which file extensions are tests. Hand-written. (You'll edit this.)
- **`lit.site.cfg.py`** — the *generated* config, written by the build system
  (CMake) into the **build** directory from a template named
  **`lit.site.cfg.py.in`**. It bakes in absolute paths (where the tools were
  built) and then `load_config(...)`s the main `lit.cfg.py`.

This split is why you run lit against the **build** directory even though the
`.mlir` files live in source — the generated site config points the "test source
root" back at the real test directory. In the `example/` project the chain is:

```
example/build/test/lit.site.cfg.py   (generated: absolute paths)
        └── load_config ──►  example/test/lit.cfg.py   (the real config)
```

CMake produces the site config with one call (see `example/CMakeLists.txt`):

```cmake
configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.site.cfg.py.in   # template (source)
  ${CMAKE_CURRENT_BINARY_DIR}/test/lit.site.cfg.py      # generated (build)
  MAIN_CONFIG ${CMAKE_CURRENT_SOURCE_DIR}/test/lit.cfg.py)
```

### The `config` object

Both config files run as Python with a pre-defined `config` object. Key
attributes (you'll see these in `example/test/lit.cfg.py`):

| Attribute | Purpose |
|-----------|---------|
| `config.name` | Suite name shown in reports (`"LIT_FILECHECK_EXAMPLE"`) |
| `config.test_format` | How to run tests — `ShTest()` = "RUN lines are shell commands" |
| `config.suffixes` | Which extensions are tests (`[".mlir"]`) |
| `config.test_source_root` | Where the test files live |
| `config.test_exec_root` | Where tests execute (build dir) |
| `config.substitutions` | Text substitutions (FileCheck, %s, %t, tool names…) |
| `config.environment` | Env vars for the test process (e.g. `PATH` so `mlir-opt` resolves) |
| `config.excludes` | Directories/files to skip |
| `config.available_features` | Feature names usable in `REQUIRES`/`UNSUPPORTED`/`XFAIL` |

## 1.4 The RUN line

Inside a test file, any line containing `RUN:` (after a comment marker) is a
command for lit to execute. The comment marker is whatever the file's language
uses — `//` for MLIR/C++, `;` for LLVM IR, `#` for assembly.

```mlir
// RUN: mlir-opt %s -cse | FileCheck %s
```

Rules:

- Multiple `RUN:` lines run **in sequence**; if any command returns non-zero,
  the test FAILs.
- They support **pipes and redirection** (`|`, `>`, `<`).
- A command can be split across lines with a trailing `\`.
- Keep them simple — the LLVM guide explicitly recommends minimal RUN lines and
  using FileCheck (not `grep`) for verification.

The two common forms are equivalent:

```mlir
// pipe form (most common):
// RUN: mlir-opt %s -cse | FileCheck %s

// temp-file form (when you need the output twice, or to inspect it):
// RUN: mlir-opt %s -cse > %t
// RUN: FileCheck %s < %t
```

## 1.5 Substitutions

Before running a RUN line, lit replaces magic tokens. The essential ones:

| Token | Expands to |
|-------|------------|
| `%s` | the **source** path of the test file being run |
| `%S` | the **directory** containing the test file |
| `%t` | a temp file path **unique to this test** (safe scratch space) |
| `%T` | a temp **directory** unique to this test |
| `%p` | same as `%S` (deprecated alias) |
| `%%` | a literal `%` |

Tool names like `mlir-opt` and `FileCheck` are *also* registered as
substitutions (via `add_tool_substitutions` in `lit.cfg.py`) so the test uses
the freshly-built binary rather than whatever is on your system `PATH`.

## 1.6 Result codes

lit classifies each test into one of these (the documented set):

| Code | Meaning |
|------|---------|
| **PASS** | Succeeded |
| **FAIL** | Failed |
| **XFAIL** | Failed, and that was **expected** (`XFAIL:` directive) — counts as success |
| **XPASS** | Passed, but was expected to fail — counts as **failure** |
| **UNSUPPORTED** | Skipped because environment lacks a required feature |
| **UNRESOLVED** | Result couldn't be determined (e.g. no RUN lines) |
| **TIMEOUT** | Exceeded `--timeout` |
| **FLAKYPASS** | Passed only after a retry |

FAIL, XPASS, UNRESOLVED, and TIMEOUT all count as failures for the exit code.

## 1.7 Conditional execution: REQUIRES / UNSUPPORTED / XFAIL

These directives (placed alongside RUN lines) gate a test on
`config.available_features`:

```mlir
// REQUIRES: asserts            // run ONLY if all listed features are present
// UNSUPPORTED: system-windows  // skip if ANY listed condition is true
// XFAIL: target=powerpc{{.*}}  // expect failure if ANY condition is true
```

Rule of thumb from the testing guide:
- `REQUIRES` enables the test if **all** expressions are true.
- `UNSUPPORTED` disables the test if **any** expression is true.
- `XFAIL` expects failure if **any** expression is true.

## Try it

> Shortcut: `scripts/try-01.sh` runs everything below automatically.

Build the example once, then drive lit against its generated config. From
`tutorials/lit-and-filecheck/`:

```bash
cd example && ./run.sh        # configures + builds + runs all 3 tests
```

Now explore lit directly (the build dir now has the generated site config):

```bash
# Put the tools on PATH (adjust to your LLVM build):
export PATH="$PWD/../../../externals/llvm-project/build/bin:$PATH"

# 1. List every discovered test without running anything:
llvm-lit --show-tests build/test

# 2. Run just one test, verbosely:
llvm-lit -v build/test --filter='cse\.mlir'

# 3. Run all tests and time each one:
llvm-lit -v --time-tests build/test
```

Expected: step 2 prints `PASS: LIT_FILECHECK_EXAMPLE :: cse.mlir`.

➡️ Next: [Chapter 2 — FileCheck basics](02-filecheck-basics.md)
