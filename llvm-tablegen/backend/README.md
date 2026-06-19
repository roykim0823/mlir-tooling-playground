# Writing TableGen Backends

The sibling [`language/`](../language) tutorial teaches the TableGen *language*
and reads records back with the stock `--print-records` / `--dump-json` output.
This one goes the other side: **writing your own backend in C++** — a program
that links LLVM's TableGen library, parses a `.td` into a `RecordKeeper`, and
emits text — then closes (Lesson 6) by driving a *stock* backend
(`--gen-searchable-tables`) end to end.

Based on the [TableGen Backend Developer's Guide](https://llvm.org/docs/TableGen/BackGuide.html).
Each lesson is a small, self-contained backend you build and run on a `.td` input.

## Prerequisites

An LLVM install with development files (headers + `libLLVMTableGen`, e.g.
`brew install llvm@20`). The lessons target **LLVM 20**.

```bash
ls /opt/homebrew/opt/llvm@20/include/llvm/TableGen/Record.h   # the backend API
```

## Directory layout / lessons

The backend API splits naturally into stages; each subdirectory is one lesson.

| Directory | Lesson | Teaches |
|---|---|---|
| `1-entry-point/` | 1 — [The backend skeleton](#lesson-1--the-backend-skeleton) | `TableGenMain`, the `bool(raw_ostream&, const RecordKeeper&)` contract, `emitSourceFileHeader` |
| `2-records-and-values/` | 2 — [Finding records, reading fields](#lesson-2--finding-records-reading-fields) | `getAllDerivedDefinitions`, `getValueAsString/Int/Bit`, `getName` |
| `3-init-values/` | 3 — [The `Init` value hierarchy](#lesson-3--the-init-value-hierarchy) | `dyn_cast` over `IntInit`/`StringInit`/`BitsInit`/`ListInit`/`DefInit`/`DagInit`/`UnsetInit` |
| `4-emitting-and-errors/` | 4 — [Emitting output & errors](#lesson-4--emitting-output--errors) | guarded output, `PrintError`/`PrintFatalError` with record locations |
| `5-registration/` | 5 — [Registering multiple backends](#lesson-5--registering-multiple-backends) | `TableGen::Emitter::OptClass`, `--gen-*` dispatch (the real llvm-tblgen pattern) |
| `6-searchable-tables/` | 6 — [Driving a stock backend](#lesson-6--driving-a-stock-backend---gen-searchable-tables) | `--gen-searchable-tables`, the `GET_*_DECL`/`_IMPL` include idiom, linking `libLLVMSupport` |

## Build & run

`run-all.sh` builds everything and runs each lesson on its `.td`:

```bash
./run-all.sh
```

Or by hand (CMake links `LLVMTableGen` + `LLVMSupport`):

```bash
cmake -S . -B build -DLLVM_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/llvm
cmake --build build
./build/01-skeleton 1-entry-point/01_skeleton.td
```

---

## Lesson 1 — The backend skeleton

*Source: `1-entry-point/01_skeleton.cpp` + `.td`*

A backend is a function `bool(raw_ostream&, const RecordKeeper&)` — return
**false** for success. `TableGenMain` does parsing and command-line handling
(the input file / `-I` / `-o` are global `cl::opt`s, so `main` calls
`cl::ParseCommandLineOptions` first). `emitSourceFileHeader` writes the standard
"do not edit" banner.

```cpp
static bool emitSkeleton(raw_ostream &OS, const RecordKeeper &records) {
  emitSourceFileHeader("Skeleton backend — record summary", OS, records);
  OS << "// records parsed: " << records.getDefs().size() << "\n";
  for (const auto &entry : records.getDefs())
    OS << "//   def " << entry.first << "\n";
  return false;
}
int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  return TableGenMain(argv[0], &emitSkeleton);
}
```

## Lesson 2 — Finding records, reading fields

*Source: `2-records-and-values/02_walk_records.cpp` + `.td`*

Select records with `getAllDerivedDefinitions("Class")`, then read fields with
the typed accessors. This turns every `Instruction` record into a C++ table row
— a miniature `--gen-instr-info`.

```cpp
for (const Record *R : records.getAllDerivedDefinitions("Instruction"))
  OS << "  { \"" << R->getValueAsString("Mnemonic") << "\", "
     << R->getValueAsInt("Opcode") << ", "
     << (R->getValueAsBit("IsTerminator") ? "true" : "false")
     << " }, // " << R->getName() << "\n";
```

Output (excerpt): `{ "jmp", 100, true }, // JMP`.

## Lesson 3 — The `Init` value hierarchy

*Source: `3-init-values/03_init_types.cpp` + `.td`*

The typed accessors are wrappers; underneath every value is an `Init`. For
fields whose type you don't know up front, `dyn_cast` the `Init` to a concrete
kind. This backend reports the kind of every field of one record.

```cpp
if (const auto *I = dyn_cast<IntInit>(V))         OS << "int " << I->getValue();
else if (const auto *S = dyn_cast<StringInit>(V)) OS << "string \"" << S->getValue() << '"';
else if (const auto *L = dyn_cast<ListInit>(V))   OS << "list of " << L->size();
else if (const auto *D = dyn_cast<DefInit>(V))    OS << "ref -> def " << D->getDef()->getName();
else if (const auto *G = dyn_cast<DagInit>(V))    OS << "dag, " << G->getNumArgs() << " args";
// ... BitInit, BitsInit, UnsetInit
```

Output (excerpt): `// Pattern : dag: operator reg, 2 arg(s)`.

## Lesson 4 — Emitting output & errors

*Source: `4-emitting-and-errors/04_enum_emitter.cpp` + `.td`*

Emit a guarded C++ `enum class`, and *validate* the input first. The TableGen
error helpers (`PrintError`, `PrintFatalError`, `PrintWarning`, `PrintNote`)
take a `const Record *` so the message points at the offending `def` in the
`.td` source.

```cpp
DenseSet<int64_t> seen;
for (const Record *R : records.getAllDerivedDefinitions("EnumCase")) {
  int64_t v = R->getValueAsInt("Value");
  if (v < 0)              PrintFatalError(R, "enum value must be non-negative...");
  if (!seen.insert(v).second) PrintFatalError(R, "duplicate enum value " + Twine(v));
}
```

Feed it a duplicate value and TableGen reports it with a source location:

```
04_enum_emitter.td:3:5: error: duplicate enum value 0
def Dup  : EnumCase<0>;
    ^
```

## Lesson 5 — Registering multiple backends

*Source: `5-registration/05_registered_tool.cpp` + `.td`*

Real tools bundle many backends and select one with a `--gen-*` flag. Register
each with `TableGen::Emitter::OptClass<E>` (where `E` has a
`(const RecordKeeper&)` constructor and a `run(raw_ostream&)` method); then
`main` calls `TableGenMain(argv[0])` with **no** explicit function — the
selected option's emitter runs. This is exactly how `llvm-tblgen` dispatches.

```cpp
static TableGen::Emitter::OptClass<NamesEmitter> X("gen-names", "...");
static TableGen::Emitter::OptClass<CountEmitter> Y("gen-count", "...");
int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  return TableGenMain(argv[0]);   // runs whichever --gen-* was chosen
}
```

```bash
./build/05-registered-tool --gen-names 5-registration/05_registered_tool.td
./build/05-registered-tool --gen-count 5-registration/05_registered_tool.td
```

## Lesson 6 — Driving a stock backend: `--gen-searchable-tables`

*Source: `6-searchable-tables/06_searchable_table.td` + `06_searchable_demo.cpp`*

Lessons 1–5 *wrote* backends. The mirror image matters just as much: `llvm-tblgen`
ships backends you can drive without writing any C++. `--gen-searchable-tables`
is the most target-independent one — include a support file, describe a table,
and it emits a `constexpr` array plus binary-search lookups.

```tablegen
include "llvm/TableGen/SearchableTable.td"
class Inst<string name, bits<8> enc> { string Name = name; bits<8> Encoding = enc; bit HasSideFx = 0; }
def : Inst<"add", 0x01>;
def : Inst<"ld",  0x10> { let HasSideFx = 1; }

def InstTable : GenericTable {
  let FilterClass    = "Inst";
  let Fields         = ["Name", "Encoding", "HasSideFx"];
  let PrimaryKey     = ["Encoding"];          // sorted column -> binary search
  let PrimaryKeyName = "lookupInstByEncoding";
}
def lookupInstByName : SearchIndex { let Table = InstTable; let Key = ["Name"]; }
```

The emitted `.inc` is guarded by `GET_<Table>_DECL` / `GET_<Table>_IMPL` macros;
the consumer `#include`s it twice (declarations, then definitions in one `.cpp`)
and links `libLLVMSupport`, because the generated lookups use `StringRef`/`ArrayRef`:

```bash
./build/06-searchable-demo
# encoding 0x10 -> ld  (hasSideFx=1)
# name "mul"   -> encoding 0x03
# encoding 0x99 -> not found (as expected)
```

> This is exactly what a real target backend (`--gen-instr-info`,
> `mlir-tblgen --gen-op-defs`, …) does under the hood: walk records, emit a C++
> `.inc`, and `#include` it behind `GET_*` macros. `--gen-searchable-tables` is
> the target-independent version, so it fits in a tutorial.

---

## Where this fits

- [`../language/`](../language) — the language these backends consume.
- [`mlir-tablegen/`](../../mlir-tablegen) — MLIR's `mlir-tblgen` is the same idea
  with a fixed set of backends (`--gen-op-defs`, `--gen-rewriters`, …); this
  tutorial shows what writing one of those backends looks like underneath.
- Reference: <https://llvm.org/docs/TableGen/BackGuide.html>
