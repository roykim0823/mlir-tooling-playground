# LLVM TableGen

TableGen is the language LLVM uses for large, repetitive tables: registers,
instructions, intrinsics, Clang diagnostics, MLIR operations. You write
**records** in `.td` files, using **classes** to factor out what records
share. A **backend** reads the finished records and writes something else,
usually a C++ `.inc` file.

```
 .td files ──► llvm-tblgen front end ──► RecordKeeper ──► backend ──► .inc / anything
               parse, include, expand    every class      --gen-instr-info
               let/multiclass/foreach    and record       --print-records
                                                          a C++ or Python program
```

This track follows LLVM's four TableGen documents, using the
[LLVM 20 versions](https://releases.llvm.org/20.1.0/docs/TableGen/index.html)
because the llvm.org/docs copies are built from LLVM's main branch:

| Document | Where it is covered |
|---|---|
| [TableGen Overview](https://releases.llvm.org/20.1.0/docs/TableGen/index.html) | this README: the X86 walkthrough below |
| [Programmer's Reference](https://releases.llvm.org/20.1.0/docs/TableGen/ProgRef.html) | [`language/`](language): 17 lessons, one runnable file each |
| [BackEnds](https://releases.llvm.org/20.1.0/docs/TableGen/BackEnds.html) | [`backend/stock/`](backend/stock): the backends `llvm-tblgen` ships |
| [Backend Developer's Guide](https://releases.llvm.org/20.1.0/docs/TableGen/BackGuide.html) | [`backend/json/`](backend/json) (a script) and [`backend/writing/`](backend/writing) (C++) |

Read this page, then `language/`, then [`backend/`](backend).

## Setup

- **LLVM 20** with `llvm-tblgen`, `FileCheck`, the headers and the CMake files:
  `brew install llvm@20`. Set `LLVM_BIN` if yours is not
  `/opt/homebrew/opt/llvm@20/bin`.
- **lit** (`pip install lit`), **CMake**, and **jq** for the JSON examples.
- **The X86 sources**, for the walkthrough below. LLVM installs the
  target-independent `.td` files (`include/llvm/Target/Target.td`,
  `IR/Intrinsics.td`, …) but not the targets themselves. This script
  downloads the 59 files X86 needs, 3.6 MB, from the tag that matches your
  `llvm-tblgen` (a `.td` only parses with the TableGen it was written for)
  into `x86/`, which git ignores:

  ```bash
  ./fetch-x86.sh          # fetched 59 X86 .td files at llvmorg-20.1.8 into x86/
  ```

## Every example is a test

Each example carries `RUN:` lines (its commands) and `CHECK:` lines (its
expected output), and [`lit.cfg.py`](lit.cfg.py) makes the whole track one
lit suite:

```bash
./check.sh                # build the C++ parts, then run all 33 tests
lit -sv language          # or run any part directly
```

Tests that need `x86/` or a CMake build report `UNSUPPORTED` until that piece
exists, instead of failing. Track 1
([`../lit-and-filecheck`](../lit-and-filecheck)) teaches lit and FileCheck.

---

## Walkthrough: one X86 instruction

The overview page shows what TableGen is for by running it on `X86.td`. Here
are the same steps against LLVM 20's X86 sources.
[`overview.test`](overview.test) runs every command in this section and checks
its output.

```bash
LLVM=/opt/homebrew/opt/llvm@20
alias tblgen-x86='$LLVM/bin/llvm-tblgen -I $LLVM/include -I x86 x86/X86.td'
```

### 1. What is in there

`llvm-tblgen` takes one root file. `include` pulls in the rest, searching the
`-I` directories: the X86 files, and `$LLVM/include` for `Target.td`. A flag
picks the backend (`llvm-tblgen --help` lists them all). The default,
`--print-records`, prints every class and record: 3.1 million lines for X86.

`--print-enums -class=C` lists the records derived from class `C`:

```console
$ tblgen-x86 --print-enums -class=Register
AH, AL, AX, BH, BL, BP, BPH, BPL, BX, CH, CL, CR0, CR1, ...
$ tblgen-x86 --dump-json | jq '."!instanceof".Instruction | length'
22803
```

### 2. One record, fully expanded

This is `ADD32rr`, the 32-bit register-register `add`, as `--print-records`
shows it (abridged; the full record has 111 fields):

```
def ADD32rr {	// InstructionEncoding Instruction X86Inst I NoCD8 ITy Sched BinOpRR DefEFLAGS NDD BinOpRR_RF OpSize32
  ...
  string Namespace = "X86";
  dag OutOperandList = (outs GR32:$dst);
  dag InOperandList = (ins GR32:$src1, GR32:$src2);
  string AsmString = "add{l}	{$src2, $src1|$src1, $src2}";
  list<dag> Pattern = [(set GR32:$dst, EFLAGS, (X86add_flag GR32:$src1, GR32:$src2))];
  list<Register> Defs = [EFLAGS];
  ...
  bit isConvertibleToThreeAddress = 1;
  bit isCommutable = 1;
  ...
  bits<8> Opcode = { 0, 0, 0, 0, 0, 0, 0, 1 };
  Format Form = MRMDestReg;
  ...
}
```

The comment lists the 12 classes it inherits from
([language lesson 6](language/README.md#6--classes-and-records)). The fields
are what the backends consume:
- the operand lists `(outs …)` and `(ins …)` are dags (lesson 13);
- `Pattern` tells instruction selection what IR this instruction implements;
- `AsmString` holds both AT&T and Intel syntax: `{att|intel}`.

The overview page prints an older version of this record, with different
classes and fewer fields. The idea is unchanged, but always check records
against your own TableGen.

### 3. Where it came from

No one wrote those 111 fields by hand. `--print-detailed-records` gives the
source location of the record and of every field, and the chain of `defm`s
that produced it:

```console
$ tblgen-x86 --print-detailed-records | grep -A2 '^ADD32rr '
ADD32rr  |X86InstrArithmetic.td:631|
  Defm sequence: |X86InstrArithmetic.td:1083| |X86InstrArithmetic.td:631|
  Superclasses: (InstructionEncoding) (Instruction) (X86Inst) (I) ... BinOpRR_RF OpSize32
```

Line 1083 is one `defm`
([lesson 9](language/README.md#9--multiclass-and-defm)):

```tablegen
defm ADD : ArithBinOp_RF<0x01, 0x03, 0x05, "add", MRM0r, MRM0m,
                         X86add_flag, add, 1, 1, 1>;
```

Line 631 is inside that multiclass. `def 32rr` becomes `NAME # 32rr`, which
is `ADD32rr`. The two flags from step 2 are top-level `let`s around it
([lesson 8](language/README.md#8--let-and-how-records-are-built)), set from
template arguments:

```tablegen
multiclass ArithBinOp_RF<bits<8> BaseOpc, ..., bit CommutableRR,
                         bit ConvertibleToThreeAddress,
                         bit ConvertibleToThreeAddressRR> {
  let isCommutable = CommutableRR,
      isConvertibleToThreeAddress = ConvertibleToThreeAddressRR in {
    let Predicates = [NoNDD] in {
      def 8rr  : BinOpRR_RF<BaseOpc, mnemonic, Xi8 , opnodeflag>;
      ...
      def 32rr : BinOpRR_RF<BaseOpc, mnemonic, Xi32, opnodeflag>, OpSize32;
```

That single `defm` line makes 156 records: every operand size, register and
memory form, and encoding variant of `add`. Removing that duplication is what
TableGen exists to do.

### 4. What a backend makes of it

TableGen gives the record no meaning; a backend does.
`--gen-instr-info` turns `ADD32rr` into an opcode, `ADD32rr = 610`, and a
descriptor whose flags `Commutable` and `ConvertibleTo3Addr` come from the two
`let`s above. [`backend/stock`](backend/stock) lesson 5 runs that and other
backends on X86. Lesson 3 runs the same backends on a 60-line target first,
where the whole output can be read.

---

## The pieces, as the overview names them

| Overview term | What it is | Lesson |
|---|---|---|
| record / definition | a concrete record, made with `def` | [1](language/README.md#1--records-fields-and-literals), [6](language/README.md#6--classes-and-records) |
| class | an abstract record that others inherit from, with template arguments | [6](language/README.md#6--classes-and-records), [7](language/README.md#7--template-arguments) |
| multiclass | a group of records instantiated together by `defm` | [9](language/README.md#9--multiclass-and-defm) |
| backend | a program that reads the records and writes output | [`backend/`](backend) |

Backend output follows one convention: a `.inc` file of blocks, each behind
a `GET_…` macro. The includer defines the macro for the part it needs:

```cpp
#define GET_REGINFO_ENUM
#include "X86GenRegisterInfo.inc"
```

[`backend/stock`](backend/stock) lesson 4 shows the variants of this.

## Tools

- **`tblgen-lsp-server`** ships next to `llvm-tblgen` and gives editors
  go-to-definition, hover and diagnostics for `.td` files. It reads include
  paths from a `tablegen_compile_commands.yml`; see the TableGen section of
  the [MLIR LSP documentation](https://mlir.llvm.org/docs/Tools/MLIRLSP/).
- `llvm/utils/emacs` and `llvm/utils/vim` in the LLVM sources have editor
  modes, and the TableGen
  [README](https://github.com/llvm/llvm-project/blob/release/20.x/llvm/utils/TableGen/README.md)
  lists more tools.

## Limits

The overview closes with TableGen's known weaknesses. The domain-specific
languages people build on it are weaker than real DSLs, which makes `.td`
files large and complex. And because every backend gives the records its own
meaning, a `.td` file means little until you know which backend reads it.
Some in LLVM want stricter rules for backends; others want smaller languages
built for one purpose. MLIR's PDLL ([`../mlir-patterns`](../mlir-patterns)),
a language only for rewrite patterns where DRR uses TableGen, is an example
of the second.

## Relationship to the rest of the repo

- [`../mlir-tablegen/`](../mlir-tablegen): `mlir-tblgen` is the same front end
  with MLIR's backends (ODS, attributes and types, passes, interfaces).
  [`backend/writing`](backend/writing) shows what such a backend looks like
  underneath.
