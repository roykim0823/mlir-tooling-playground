# Language servers — `mlir-lsp-server`, `tblgen-lsp-server`, `mlir-pdll-lsp-server`

MLIR ships three **language servers**: editor back-ends that give `.mlir`,
`.td`, and `.pdll` files live diagnostics, hover, go-to-definition, references
and completion in VS Code, Neovim, Emacs — anything that speaks the Language
Server Protocol. This tutorial drives the servers by hand, from a text file, so
you can see and test exactly what an editor receives, and then shows how to get
the same for your own dialect, which the stock server does not know.

To replay every session below:

```bash
./try.sh          # sections 1–5 as a transcript, no editor needed
./try.sh 2        # one section
```

Needs a prebuilt LLVM/MLIR (`brew install llvm@20`). Sections 3–5 use the
capstone's build directory and its `toy-lsp-server`, and are skipped with a
hint until [`../../mlir-capstone/`](../../mlir-capstone/README.md)
is built.

| # | Section | Server |
|---|---|---|
| 1 | [Driving a server by hand: diagnostics](#1-driving-a-server-by-hand-diagnostics) | `mlir-lsp-server` |
| 2 | [Navigation: hover, definition, references, symbols](#2-navigation-hover-definition-references-symbols) | `mlir-lsp-server` |
| 3 | [TableGen and the compilation database](#3-tablegen-and-the-compilation-database) | `tblgen-lsp-server` |
| 4 | [PDLL](#4-pdll) | `mlir-pdll-lsp-server` |
| 5 | [Your own dialect: `toy-lsp-server`](#5-your-own-dialect-toy-lsp-server) | capstone |
| 6 | [Wiring it into an editor](#6-wiring-it-into-an-editor) | VS Code, others |

The pieces in this directory: [`sessions/`](sessions) holds hand-written
JSON-RPC sessions, [`make-session.py`](make-session.py) builds one for a real
file, [`summarize.py`](summarize.py) turns a server's replies into a few
readable lines, and [`../.vscode/settings.json`](../../.vscode/settings.json)
wires everything into VS Code for this repo.

---

## 1. Driving a server by hand: diagnostics

A language server is a process that reads JSON-RPC messages on stdin and
writes replies on stdout. Every MLIR server has a **`--lit-test`** mode that
makes this convenient: messages are read from a file, separated by a line of
five dashes, `//` comments are ignored, and replies are pretty-printed. It is
how upstream tests the servers (`mlir/test/mlir-lsp-server/*.test`), and it
is all we need here.

[`sessions/mlir-diagnostics.session`](sessions/mlir-diagnostics.session), with
the comments stripped, is three messages plus the shutdown:

```json
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"processId":1,"rootUri":null,"capabilities":{}}}
// -----
{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"test:///demo.mlir","languageId":"mlir","version":1,"text":"func.func @f(%a: i32, %b: i64) -> i32 {\n ... %1 = arith.addi %0, %b : i32\n ..."}}}
// -----
{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"test:///demo.mlir","version":2},"contentChanges":[{"text":"...fixed text..."}]}}
```

The client sends the **whole document text** on open and on every change (MLIR
servers use full-document sync). The server answers each with a
`publishDiagnostics` notification:

```bash
mlir-lsp-server --lit-test < sessions/mlir-diagnostics.session 2>/dev/null | ./summarize.py
```
```
capabilities: codeActionProvider, completionProvider, definitionProvider, hoverProvider, referencesProvider, textDocumentSync
diagnostics for test:///demo.mlir: 1
  line 4, col 23: use of value '%b' expects different type than prior uses: 'i32' vs 'i64'
diagnostics for test:///demo.mlir: 0
```

The first `didOpen` has a type error and produces one diagnostic at the exact
position an editor would underline; the `didChange` with the fixed text clears
it. The raw reply is what the editor consumes — the same message `mlir-opt`
would print, with a range instead of `file:line:col`:

```bash
mlir-lsp-server --lit-test < sessions/mlir-diagnostics.session 2>/dev/null | grep -B1 -A3 '"message": "use of value'
```
```json
        "category": "Parse Error",
        "message": "use of value '%b' expects different type than prior uses: 'i32' vs 'i64'",
        "range": {
          "end": {
            "character": 24,
```

When you write sessions yourself:

- Positions are **0-based** `{line, character}` in the protocol; `summarize.py`
  prints them 1-based, as editors do.
- The server logs to **stderr** (`--log=verbose` for everything); replies go to
  stdout. Keep the two apart or the JSON parse fails.

## 2. Navigation: hover, definition, references, symbols

[`sessions/mlir-navigation.session`](sessions/mlir-navigation.session) opens a
valid document and asks the questions an editor asks when you hover or
Cmd-click:

```
0 func.func @compute(%a: i32) -> i32 {
1   %c1 = arith.constant 1 : i32
2   %sum = arith.addi %a, %c1 : i32
3   %prod = arith.muli %sum, %c1 : i32
4   return %prod : i32
5 }
```

```bash
mlir-lsp-server --lit-test < sessions/mlir-navigation.session 2>/dev/null | ./summarize.py
```
```
reply 1 (hover):                      # on the op name `arith.addi` (line 2, col 12)
  | "arith.addi"
  | Generic Form:
  | ```mlir
  | %1 = "arith.addi"(%arg0, %0) <{overflowFlags = #arith.overflow<none>}> : (i32, i32) -> i32
  | ```
reply 2 (hover):                      # on the USE of %sum (line 3, col 22)
  | Operation: "arith.addi"
  | Result #0
  | Type: `i32`
reply 3 (locations):                  # go-to-definition from that use
  test:///nav.mlir line 3, col 3
reply 4 (locations):                  # references of %c1: definition + both uses
  test:///nav.mlir line 2, col 3
  test:///nav.mlir line 3, col 25
  test:///nav.mlir line 4, col 28
reply 5 (symbols): compute            # document outline
```

Hover on an **op** shows its generic form — the same thing
`--mlir-print-op-generic` shows ([debugging track](../debugging/README.md)),
which is why this hover is the fastest way to see an op's real attributes and
types. Hover on a **value** tells you which op defines it, which result, and
its type. Definition and references work on SSA values, block labels and
symbols (`@compute`).

> Navigation needs a document that **parses**. On the broken document of
> Section 1 every hover returns `null`: there is no IR to navigate. Fix the
> diagnostics first.

## 3. TableGen and the compilation database

`tblgen-lsp-server` does the same for `.td` files: hover shows a record with
its `summary`/`description`, definition jumps to a class or def, references
lists every use. One thing is different: a `.td` file is meaningless without
its **include paths** (`include "mlir/IR/OpBase.td"` must resolve). The server
learns them from a **compilation database**, a YAML file with one entry per
`.td`:

```yaml
--- !FileInfo:
  filepath: ".../mlir-capstone/include/Toy/ToyOps.td"
  includes: ".../mlir-capstone;/opt/homebrew/opt/llvm@20/include;.../mlir-capstone/include;.../mlir-capstone/build/include"
```

You never write this file: every `mlir_tablegen()` call in CMake appends to
`tablegen_compile_commands.yml` in the build directory. The capstone's is at
`mlir-capstone/build/tablegen_compile_commands.yml`. Pass it with
`--tablegen-compilation-database=` (an editor does this for you, Section 6).

Real files are too big to embed in a hand-written message, so
[`make-session.py`](make-session.py) builds the session; positions are given
1-based as in an editor:

```bash
./make-session.py ../../mlir-capstone/include/Toy/ToyOps.td --hover 84:7 --definition 84:14 --references 84:14 > /tmp/td.session
tblgen-lsp-server --lit-test --tablegen-compilation-database=../../mlir-capstone/build/tablegen_compile_commands.yml \
    < /tmp/td.session 2>/dev/null | ./summarize.py
```
```
diagnostics for file:///.../include/Toy/ToyOps.td: 0
reply 1 (hover):                      # on `AddOp` in `def AddOp : Toy_Op<...`
  | **def** `AddOp`
  | ***
  | f64 addition
  | ***
  |  add / mul / sub implement BinaryArithOpInterface (ToyInterfaces.td). The
  |  trait DECLARES evaluate()/getSymbol() ...
reply 2 (locations):                  # definition of `Toy_Op`
  file:///.../include/Toy/ToyOps.td line 34, col 7
reply 3 (locations):                  # references of `Toy_Op`: the class + every op using it
  file:///.../include/Toy/ToyOps.td line 34, col 7
  file:///.../include/Toy/ToyOps.td line 66, col 18
  ...
```

Note what the hover shows: the record's `summary` **and** the `//` comment
above it. And what happens **without** the database:

```bash
tblgen-lsp-server --lit-test < /tmp/td.session 2>/dev/null | ./summarize.py | head -4
```
```
diagnostics for file:///.../ToyOps.td: 2
  line 15, col 9: could not find include file 'mlir/IR/OpBase.td'
  line 15, col 9: Unexpected token at top level
```

Every `.td` in your editor lit up red at line 1 means exactly this: the server
has no compilation database (or the file is not in it — it is keyed by absolute
path, so a moved checkout needs a re-run of CMake). `--tablegen-extra-dir=` adds
a global include directory as a stopgap.

## 4. PDLL

Same again for `.pdll`, with `--pdll-compilation-database=` pointing at the
`pdll_compile_commands.yml` that `add_mlir_pdll_library()` writes. This server
knows the ODS the pattern file `#include`s, so hovering an `op<toy.mul>` shows
the op's ODS summary:

```bash
./make-session.py ../../mlir-capstone/include/Toy/ToyPatterns.pdll --hover 27:18 --hover 31:27 --definition 31:50 > /tmp/pdll.session
mlir-pdll-lsp-server --lit-test --pdll-compilation-database=../../mlir-capstone/build/pdll_compile_commands.yml \
    < /tmp/pdll.session 2>/dev/null | ./summarize.py
```
```
capabilities: completionProvider, definitionProvider, documentLinkProvider, documentSymbolProvider, hoverProvider, inlayHintProvider, referencesProvider, signatureHelpProvider, textDocumentSync
diagnostics for file:///.../ToyPatterns.pdll: 0
reply 1 (hover):                      # on `toy.mul` inside op<toy.mul>
  | **OpName**: `toy.mul`
  | ***
  | f64 multiplication
  | ***
reply 2 (hover):                      # on `toy.constant` in the replace
  | **OpName**: `toy.constant`
  | ***
  | a constant f64 value
  | ***
reply 3 (locations):                  # definition of the native rewrite `FoldMulF64(a, b)` -> its `Rewrite` declaration
  file:///.../ToyPatterns.pdll line 19, col 9
```

It is the most capable of the three servers (inlay hints, signature help for
native constraints/rewrites, completion of op names and operand names from
ODS) — the [PDLL track](../../mlir-patterns/pdll/README.md) is much nicer to follow with
it running.

## 5. Your own dialect: `toy-lsp-server`

Open a Toy file with the stock server and every op is an error:

```bash
mlir-lsp-server --lit-test < sessions/toy.session 2>/dev/null | ./summarize.py | head -3
```
```
diagnostics for test:///good.mlir: 1
  line 2, col 8: Dialect `toy' not found for custom op 'toy.constant'
```

The server only knows the dialects compiled into it, and in LLVM 20 it has no
`--load-dialect-plugin`. The fix is the same one the capstone uses for `opt`
and `reduce`: a 15-line binary around the library —
[`tools/toy-lsp-server.cpp`](../../mlir-capstone/tools/toy-lsp-server.cpp):

```cpp
int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  registry.insert<toy::ToyDialect, mlir::func::FuncDialect>();
  return mlir::failed(mlir::MlirLspServerMain(argc, argv, registry));
}
```
```cmake
add_llvm_executable(toy-lsp-server tools/toy-lsp-server.cpp)
target_link_libraries(toy-lsp-server PRIVATE MLIRToy MLIRLspServerLib MLIRFuncDialect)
```

The same session against it:

```bash
../../mlir-capstone/build/toy-lsp-server --lit-test < sessions/toy.session 2>/dev/null | ./summarize.py
```
```
diagnostics for test:///good.mlir: 0
reply 1 (hover):                      # on toy.constant
  | "toy.constant"
  | Generic Form:
  | ```mlir
  | %0 = "toy.constant"() <{value = 2.000000e+00 : f64}> : () -> f64
  | ```
reply 2 (locations):                  # definition of %c from its use in toy.mul
  test:///good.mlir line 2, col 3
diagnostics for test:///bad.mlir: 1
  line 2, col 8: 'toy.add' op operand #0 must be 64-bit float, but got 'i32'
```

Toy parses, hover and definition work, and the **ODS verifier's** message for
a bad `toy.add` arrives as a diagnostic at the op's position — the editor
now enforces your `.td` constraints while you type.

This session is also a **lit test**,
[`test/lsp.test`](../../mlir-capstone/test/lsp.test): the RUN line
is `toy-lsp-server --lit-test < %s | FileCheck %s`, and the CHECK lines sit
between the messages, matching the pretty-printed replies. That is how
upstream tests its servers, and how you can pin "my dialect's editor support
works" in CI.

## 6. Wiring it into an editor

**VS Code.** Install the *MLIR* extension (`llvm-vs-code-extensions.vscode-mlir`;
it provides the `mlir`, `tablegen` and `pdll` languages) and tell it where the
servers and databases are. This repo's [`.vscode/settings.json`](../../.vscode/settings.json)
does exactly that for Homebrew's `llvm@20` and the capstone build:

```jsonc
{
  "mlir.server_path": "/opt/homebrew/opt/llvm@20/bin/mlir-lsp-server",
  "mlir.tablegen_server_path": "/opt/homebrew/opt/llvm@20/bin/tblgen-lsp-server",
  "mlir.tablegen_compilation_databases": [
    "${workspaceFolder}/mlir-capstone/build/tablegen_compile_commands.yml"
  ],
  "mlir.pdll_server_path": "/opt/homebrew/opt/llvm@20/bin/mlir-pdll-lsp-server",
  "mlir.pdll_compilation_databases": [
    "${workspaceFolder}/mlir-capstone/build/pdll_compile_commands.yml"
  ],
  "mlir.onSettingsChanged": "restart"
}
```

For the capstone's `.mlir` files, point `mlir.server_path` at
`${workspaceFolder}/mlir-capstone/build/toy-lsp-server` instead
(one server per workspace; a Toy server still handles upstream dialects it
registers, here `func` and `builtin`). `mlir.*_additional_server_args` passes
flags such as `--log=verbose`; the extension shows server stderr in the
*Output* panel under *MLIR*.

**Other editors.** Any LSP client works; the command is just the server
binary, plus `--tablegen-compilation-database=`/`--pdll-compilation-database=`
for the two that need it. With Neovim's built-in client, for example:

```lua
vim.api.nvim_create_autocmd("FileType", { pattern = "mlir", callback = function()
  vim.lsp.start({ name = "mlir", cmd = { "mlir-lsp-server" } })
end })
vim.api.nvim_create_autocmd("FileType", { pattern = "tablegen", callback = function()
  vim.lsp.start({ name = "tblgen", cmd = { "tblgen-lsp-server",
    "--tablegen-compilation-database=" .. vim.fn.getcwd() .. "/mlir-capstone/build/tablegen_compile_commands.yml" } })
end })
```

**Checklist when nothing lights up:**

1. Is the server path right, and is it executable? Run
   `mlir-lsp-server --lit-test < sessions/mlir-diagnostics.session` by hand.
2. For `.td`/`.pdll`: is the file listed in the compilation database? It is
   keyed by absolute path; rebuild (re-run CMake) after moving the tree.
3. For your dialect: are you running *your* server, not the stock one?
   Section 5's "Dialect not found" is the symptom.
4. Turn on `--log=verbose` and read the Output panel; every request and reply
   is logged.

## References

- MLIR LSP servers — <https://mlir.llvm.org/docs/Tools/MLIRLSP/>
- VS Code extension — <https://marketplace.visualstudio.com/items?itemName=llvm-vs-code-extensions.vscode-mlir>
- Language Server Protocol — <https://microsoft.github.io/language-server-protocol/>
- Upstream server tests (the `--lit-test` format) — `mlir/test/mlir-lsp-server/`, `mlir/test/tblgen-lsp-server/`, `mlir/test/mlir-pdll-lsp-server/`
