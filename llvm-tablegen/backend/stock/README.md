# The stock backends

`llvm-tblgen --help` lists about forty backends under "Action to perform".
[BackEnds](https://releases.llvm.org/20.1.0/docs/TableGen/BackEnds.html)
describes them in three groups: general backends that print records,
target backends that need a target description, and the one schema-free
generator, `--gen-searchable-tables`. These lessons run backends from all
three groups, from a ten-line input up to X86.

| # | File | Backends | Input |
|---|---|---|---|
| 1 | [`01_general_backends.td`](01_general_backends.td) | `--print-records`, `--print-detailed-records`, `--print-enums`, `--dump-json`, `--null-backend`, `--time-phases` | any `.td` |
| 2 | [`02_searchable_tables.td`](02_searchable_tables.td) + [`searchable_demo.cpp`](searchable_demo.cpp) | `--gen-searchable-tables` | `GenericEnum`, `GenericTable`, `SearchIndex` records |
| 3 | [`03_mini_target.td`](03_mini_target.td) | `--gen-register-info`, `--gen-instr-info`, `--gen-asm-writer`, `--gen-emitter`, `--gen-disassembler` | a 60-line target built on `Target.td` |
| 4 | [`04_llvm_inputs.test`](04_llvm_inputs.test) | `--gen-intrinsic-enums`, `--gen-vt`, `--gen-attrs`, `--gen-directive-decl` | the `.td` files LLVM installs |
| 5 | [`05_x86_target.test`](05_x86_target.test) | lesson 3's backends, plus X86-only ones | `../../x86/` (run `../../fetch-x86.sh`) |

```bash
lit -sv .                      # from this directory; lesson 5 needs x86/
cmake -S . -B build -DLLVM_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/llvm
cmake --build build && ./build/searchable-demo     # lesson 2's consumer
```

---

## 1 — The general backends

These accept any `.td` file, because they print records instead of
interpreting them. Use them to see exactly what a backend will receive.

| Flag | Prints |
|---|---|
| `--print-records` (the default) | classes, then defs sorted by name. The format is kept stable, so tests compare against it. Multiclasses are not printed. |
| `--print-detailed-records` | also the global `defvar`s, a source location for every class, record and field, and the `defm` chain behind each record. Not stable. |
| `--print-enums -class=C` | the names of the defs derived from `C` |
| `--dump-json` | every def as JSON, plus `"!instanceof"`: each class with its defs |
| `--null-backend` | nothing: parse only. With `--time-phases`, a timing report. |

```
X_hi  |01_general_backends.td:21|
  Defm sequence: |01_general_backends.td:25| |01_general_backends.td:21|
  Superclasses: Reg Special
  Fields:
    int Num = 5  |01_general_backends.td:17|
```

The overview uses `--print-detailed-records` on X86 to trace `ADD32rr` back to
its `defm`. [`../json`](../json) builds a backend on `--dump-json`.

## 2 — `--gen-searchable-tables`

The one code generator that needs no target. Include
`llvm/TableGen/SearchableTable.td` and describe what you want with records:

- **`GenericEnum`**: a C++ enum with one enumerator per record of
  `FilterClass`. Values come from `ValueField`, or 0, 1, … in name order.
- **`GenericTable`**: a `constexpr` array with one row per record of
  `FilterClass`, minus those whose `FilterClassField` bit is 0. `Fields` gives
  the columns in order. The array is sorted by `PrimaryKey`, and
  `PrimaryKeyName` names a binary-search lookup on it. `PrimaryKeyEarlyOut`
  makes the lookup reject keys outside the table's range before searching.
  `TypeOf_<field>` gives the C++ type of a column TableGen cannot infer, such
  as an enum.
- **`SearchIndex`**: a second lookup on another key. Strings are compared
  case-insensitively.

```cpp
constexpr Inst InstTable[] = {
  { "add", 0x1, ALU, false }, // 0
  ...
const Inst *lookupInstByEncoding(uint8_t Encoding) {
  if ((uint8_t)Encoding != std::clamp((uint8_t)Encoding, (uint8_t)0x1, (uint8_t)0x20))
    return nullptr;                                   // PrimaryKeyEarlyOut
```

Every block of the output is guarded by a macro: `GET_<Name>_DECL` for
declarations, `GET_<Name>_IMPL` for definitions. The file `#undef`s them at
the end. [`searchable_demo.cpp`](searchable_demo.cpp) shows the consumer's
side: define the row struct, include the DECL block, then include the IMPL
block in exactly one `.cpp`. The generated code uses `StringRef` and
`ArrayRef`, so it links `libLLVMSupport`; [`CMakeLists.txt`](CMakeLists.txt)
runs `llvm-tblgen` as a build step.

```
encoding 0x10 -> ld (LSU, hasSideFx=1)
name "Mul"    -> encoding 0x03
encoding 0x7f -> not found (dbg is not Listed)
encoding 0x99 -> not found (above the last key)
```

## 3 — A target the stock backends accept

The target backends do not accept arbitrary records. Each one reads classes
that `include/llvm/Target/Target.td` defines (`Register`, `RegisterClass`,
`Instruction`, `Operand`, `InstrInfo`, `Target`) and expects exactly one
`Target` record. This lesson is MiniISA
([language lesson 16](../../language/README.md#16--capstone-miniisa)) rewritten
against that schema. At about 60 lines it is enough for five real backends:

| Backend | Writes | MiniISA output |
|---|---|---|
| `--gen-register-info` | register enums, register classes, `MiniGenRegisterInfo` | `R0 = 1` … `NUM_TARGET_REGS // 5` |
| `--gen-instr-info` | the opcode enum and an `MCInstrDesc` per instruction | `ADDri`, … after the ~300 generic opcodes (`COPY`, `G_ADD`, …) every target gets |
| `--gen-asm-writer` | `printInstruction`, from each `AsmString` | `"add\t"` in the string table |
| `--gen-emitter` | `getBinaryCodeForInstr`, from each `field bits<32> Inst` | `UINT64_C(16777216), // ADDrr` (0x01000000) |
| `--gen-disassembler` | a decoder table over the same bits | `// Opcode: ADDrr` |

Encoding operands are matched to `(outs …)`/`(ins …)` operands **by name**:
`bits<4> rd` in the record fills `GPR:$rd`. `--gen-emitter` emits a constant
with each instruction's fixed bits, plus code that shifts each operand's
encoding into place:

```cpp
    case Mini::ADDrr:
      // op: rd
      op = getMachineOpValue(MI, MI.getOperand(0), Fixups, STI);
      op &= UINT64_C(15);
      op <<= 20;
```

## 4 — Stock backends on LLVM's own `.td` files

LLVM installs its target-independent `.td` files under `include/llvm`, so
these backends need nothing else. They also show the three shapes a `.inc`
file takes:

| Shape | Example | How the includer uses it |
|---|---|---|
| blocks behind `GET_` macros | `--gen-intrinsic-enums`: `#ifdef GET_INTRINSIC_ENUM_VALUES` | `#define` the block, `#include` the file; repeat per block |
| an X-macro list | `--gen-vt`: `GET_VT_ATTR(i32, 7, 32, …)`; `--gen-attrs`: `ATTRIBUTE_ENUM(AlwaysInline,alwaysinline)` | define the macro to expand each line into an enum entry, a table row, a `case` |
| a complete header | `--gen-directive-decl`: include guard, `namespace llvm::omp`, `enum class Directive` | include it once, like any header |

## 5 — The same backends on X86

Lesson 3's backends on a real target, after `../../fetch-x86.sh`. Each run
takes about a second, and the outputs run from 14 thousand lines
(`--gen-register-info`) to 420 thousand (`--gen-disassembler`).

- `ADD32rr`, which the [overview](../../README.md#walkthrough-one-x86-instruction)
  traced back to its `defm`, becomes opcode 610. Its `MCInstrDesc` carries
  `Commutable` and `ConvertibleTo3Addr`, the two `let`s from the multiclass.
- `--gen-disassembler` writes something completely different for X86. x86
  instructions vary in length, so `llvm-tblgen` switches to an X86-specific
  emitter that builds opcode maps and ModRM tables.
- X86 has backends of its own: `--gen-x86-fold-tables` (which register form
  folds a memory operand into which memory form), `--gen-x86-mnemonic-tables`
  and `--gen-x86-instr-mapping`.
- `--gen-emitter` fails:
  ``error: Record `AAA' does not have a field named `Inst'!``. X86 has no
  fixed-width `Inst` field; its encoder is hand-written C++
  (`X86MCCodeEmitter.cpp`). Not every target uses every backend.
