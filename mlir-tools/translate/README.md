# `mlir-translate` — importing and exporting non-MLIR formats

`mlir-opt` transforms MLIR into MLIR. **`mlir-translate`** is the other tool
at the edges of the system: it turns MLIR into something else (LLVM IR, SPIR-V
binaries, C++ via EmitC) or something else into MLIR. Each such conversion is a
**translation**, registered under a flag, and an out-of-tree project adds its
own the same way the capstone adds passes to `toy-opt`: a library with the
registrations plus a 10-line `main`.

To run every command below:

```bash
./try.sh          # sections 1–3 as a transcript
./try.sh 3        # one section
```

Needs a prebuilt LLVM/MLIR. Section 3 uses the capstone's `toy-translate` and
is skipped with a hint until
[`../../mlir-capstone/`](../../mlir-capstone/README.md) is
built. Commands are as `try.sh` runs them, from [`examples/`](examples).

| # | Section |
|---|---|
| 1 | [The stock tool: export and import LLVM IR](#1-the-stock-tool-export-and-import-llvm-ir) |
| 2 | [A translation only knows its own dialects](#2-a-translation-only-knows-its-own-dialects) |
| 3 | [Your own format: `toy-translate`](#3-your-own-format-toy-translate) |
| 4 | [Anatomy of a translation](#4-anatomy-of-a-translation) |

---

## 1. The stock tool: export and import LLVM IR

`mlir-translate --help` lists the translations compiled into it; on LLVM 20
the interesting ones are:

```
--deserialize-spirv   deserializes the SPIR-V module
--import-llvm         Translate LLVMIR to MLIR
--mlir-to-cpp         translate from mlir to cpp
--mlir-to-llvmir      Translate MLIR to LLVMIR
--serialize-spirv     serialize SPIR-V dialect
```

Exactly one is chosen per run. **Export** takes MLIR in the LLVM *dialect*
([`examples/llvm_dialect.mlir`](examples/llvm_dialect.mlir)) and writes real
LLVM IR:

```bash
mlir-translate --mlir-to-llvmir llvm_dialect.mlir
```
```llvm
; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define i32 @add(i32 %0, i32 %1) {
  %3 = add i32 %0, %1
  ret i32 %3
}
```

**Import** is the reverse ([`examples/add.ll`](examples/add.ll)):

```bash
mlir-translate --import-llvm add.ll
```
```mlir
module attributes {dlti.dl_spec = #dlti.dl_spec<...>} {
  llvm.func @add(%arg0: i32, %arg1: i32) -> i32 {
    %0 = llvm.add %arg0, %arg1 : i32
    llvm.return %0 : i32
  }
}
```

and the two compose into a round trip. The tool shares `mlir-opt`'s plumbing:
`-o`, `--split-input-file`, `--verify-diagnostics`, `--mlir-print-debuginfo`
and the other printing flags all work, so translation tests are written like
any other lit test.

## 2. A translation only knows its own dialects

[`examples/arith.mlir`](examples/arith.mlir) uses `arith` and `func`. Feed it
to the LLVM IR exporter and it fails **before** translating:

```bash
mlir-translate --mlir-to-llvmir arith.mlir
```
```
arith.mlir:7:8: error: Dialect `arith' not found for custom op 'arith.addi'
```

Not "cannot lower arith.addi" — the *parser* rejects the file. Each
translation registers the dialects it can consume, and the tool builds the
context for parsing the input from that list alone; `--mlir-to-llvmir` asks
only for the LLVM dialect (and what it depends on). This is by design: a
translation is the last step, after lowering, and the lowering is `mlir-opt`'s
job:

```bash
mlir-opt arith.mlir -convert-arith-to-llvm -convert-func-to-llvm | mlir-translate --mlir-to-llvmir
```
```llvm
define i32 @f(i32 %0) {
  %2 = add i32 %0, %0
  ret i32 %2
}
```

When your own translation reports `Dialect ... not found`, the fix is the
registration's dialect list (Section 4), not the input.

## 3. Your own format: `toy-translate`

The capstone defines **toytext**, a deliberately tiny line-based format for
Toy programs, and two translations in
[`lib/ToyTranslate.cpp`](../../mlir-capstone/lib/ToyTranslate.cpp):

```
# toytext: one op per line, names instead of SSA values
v0 = const 1
v1 = const 2
v2 = add v0 v1        # add | mul | sub
print v2
```

[`tools/toy-translate.cpp`](../../mlir-capstone/tools/toy-translate.cpp)
is the whole tool:

```cpp
int main(int argc, char **argv) {
  toy::registerToyTranslations();
  return mlir::failed(mlir::mlirTranslateMain(argc, argv, "Toy translation tool"));
}
```

**Export** (`--mlir-to-toytext`) on the capstone's `test/translate.mlir`
(the binary lives in the capstone's build directory; `try.sh` puts it on
`PATH`, by hand use the path):

```bash
TOY=../../../mlir-capstone
$TOY/build/toy-translate --mlir-to-toytext $TOY/test/translate.mlir
```
```
# toytext exported by toy-translate --mlir-to-toytext
v0 = const 1
v1 = const 2
v2 = add v0 v1
v3 = mul v2 v0
v4 = sub v3 v1
print v4
```

**Import** (`--toytext-to-mlir`) brings it back, and — because the importer
attaches each line's position as the op's location — `--mlir-print-debuginfo`
shows where every op came from in the text file:

```bash
$TOY/build/toy-translate --toytext-to-mlir $TOY/test/translate-import.toytext --mlir-print-debuginfo
```
```mlir
module {
  %0 = toy.constant 3.000000e+00 loc(#loc1)
  %1 = toy.constant 4.000000e+00 loc(#loc2)
  %2 = toy.mul %0, %1 loc(#loc3)
  toy.print %2 loc(#loc4)
} loc(#loc)
#loc1 = loc("...translate-import.toytext":18:1)
#loc2 = loc("...translate-import.toytext":19:1)
...
```

Errors on either side are ordinary MLIR diagnostics. The importer's point at
the toytext line; the exporter's are attached to the op it cannot handle:

```bash
$TOY/build/toy-translate --toytext-to-mlir $TOY/test/Inputs/bad.toytext
# bad.toytext:3:1: error: unknown value 'nope'
# y = add x nope
# ^
$TOY/build/toy-translate --mlir-to-toytext $TOY/test/Inputs/unexportable.mlir
# unexportable.mlir:1:1: error: 'func.func' op cannot be exported to toytext (only toy.constant, BinaryArithOpInterface ops and toy.print at module level)
```

All of this is pinned by two lit tests in the capstone: `test/translate.mlir`
(export, round trip, the export error with `not`) and
`test/translate-import.toytext` (import, the locations, the import error). The
second one shows that lit does not care about the file type: `.toytext` is in
`config.suffixes`, and `RUN:` lines are found behind `#` comments just as well
as behind `//`.

## 4. Anatomy of a translation

Two structs from `mlir/Tools/mlir-translate/Translation.h`, whose constructors
register the translation under a flag. `registerToyTranslations()` creates
them as function-local statics, so registration is explicit and happens once:

```cpp
void toy::registerToyTranslations() {
  static TranslateFromMLIRRegistration exportReg(
      "mlir-to-toytext", "Export a module of Toy ops to the toytext format",
      exportToyText,                                        // LogicalResult(ModuleOp, raw_ostream &)
      [](DialectRegistry &registry) {                       // dialects the INPUT .mlir may use
        registry.insert<toy::ToyDialect, func::FuncDialect>();
      });

  static TranslateToMLIRRegistration importReg(
      "toytext-to-mlir", "Import the toytext format as a module of Toy ops",
      importToyText,                                        // OwningOpRef<Operation *>(llvm::SourceMgr &, MLIRContext *)
      [](DialectRegistry &registry) { registry.insert<toy::ToyDialect>(); });
}
```

**Export** (`TranslateFromMLIRRegistration`): the function receives the parsed
top-level op and an output stream. Passing a function typed on `ModuleOp`
rather than `Operation *` makes the driver do the cast and report "expected a
'builtin.module' op" when the input is something else. The dialect callback is what Section 2 was about: it is
the *only* source of dialects for parsing the input. The capstone's exporter
walks the module and handles three shapes of op — constants, anything
implementing `BinaryArithOpInterface` (so `toy.sub` needed no code when it was
added), and `print` — and emits an error on anything else:

```cpp
} else if (auto arith = dyn_cast<toy::BinaryArithOpInterface>(op)) {
  os << nameOf(arith->getResult(0)) << " = " << arith->getName().stripDialect() << " "
     << nameOf(arith.getLhsValue()) << " " << nameOf(arith.getRhsValue()) << "\n";
} else {
  return op.emitOpError("cannot be exported to toytext (...)");
}
```

**Import** (`TranslateToMLIRRegistration`): the function receives the input in
a `llvm::SourceMgr` and must return an owning reference to the new top-level
op, or null after emitting an error. The capstone's importer does three things
every importer should:

1. `context->loadDialect<toy::ToyDialect>()` first — the dialect callback made
   the dialect *available*, creating its ops still needs it *loaded*.
2. Build a `FileLineColLoc` from the source position for **every** op. That is
   what makes `--mlir-print-debuginfo` useful and lets any later pass report
   errors against the original text.
3. Run `mlir::verify()` on the result before returning it. The driver prints
   whatever you return; an invalid module will confuse the next tool instead
   of failing here.

A third struct, `TranslateRegistration`, is for translations that go from an
external format to another external format through MLIR internally; and
`mlirTranslateMain` provides `--split-input-file` and `--verify-diagnostics`,
so importer error messages are tested with `expected-error` lines exactly like
verifier messages.

## References

- `mlir-translate` — <https://mlir.llvm.org/docs/Tools/mlir-translate/> (section of the tools docs)
- LLVM IR target — <https://mlir.llvm.org/docs/TargetLLVMIR/>
- `Translation.h` — `mlir/Tools/mlir-translate/Translation.h` in your MLIR include directory
- Upstream translation tests — `mlir/test/Target/`
