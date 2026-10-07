# Writing TableGen backends in C++

A C++ backend links LLVM's TableGen library, lets `TableGenMain` parse the
`.td` into a `RecordKeeper`, and writes output from the records it finds.
This follows the
[TableGen Backend Developer's Guide](https://releases.llvm.org/20.1.0/docs/TableGen/BackGuide.html)
(BackGuide). Each lesson is a small standalone backend plus a `.td` input
whose `RUN:`/`CHECK:` lines are its expected output.

| # | Directory | Teaches | BackGuide |
|---|---|---|---|
| 1 | [`1-entry-point/`](1-entry-point) | `TableGenMain`, the `bool(raw_ostream&, const RecordKeeper&)` contract, `emitSourceFileHeader` | The Backend Skeleton |
| 2 | [`2-records-and-values/`](2-records-and-values) | `getAllDerivedDefinitions`, `getValueAsString/Int/Bit`, `getName` | Getting Records; Getting Record Names and Fields |
| 3 | [`3-init-values/`](3-init-values) | `dyn_cast` over `IntInit`, `StringInit`, `BitsInit`, `ListInit`, `DefInit`, `DagInit`, `UnsetInit` | Data Structures: `Init` |
| 4 | [`4-emitting-and-errors/`](4-emitting-and-errors) | guarded output, `PrintFatalError` with record locations | Emitting Text; Printing Error Messages |
| 5 | [`5-registration/`](5-registration) | `TableGen::Emitter::OptClass`, `--gen-*` dispatch | The Backend Skeleton (registration) |
| 6 | [`6-classes-and-lists/`](6-classes-and-lists) | `getClasses`, superclasses, `getValueAsListOfDefs`, `getValueAsOptionalDef`, multi-class queries | Getting Classes; Getting Record Superclasses |
| 7 | [`7-debugging/`](7-debugging) | `OS << *R`, diagnostics on a field, phase timers | Printing Error Messages; Debugging Tools |

## Build and run

```bash
cmake -S . -B build -DLLVM_DIR=/opt/homebrew/opt/llvm@20/lib/cmake/llvm
cmake --build build
./build/01-skeleton 1-entry-point/01_skeleton.td
lit -sv .              # every lesson, against its CHECK lines
```

[`CMakeLists.txt`](CMakeLists.txt) uses LLVM's own CMake helpers
(`add_llvm_executable`, `HandleLLVMOptions`) so the flags match the LLVM
build, for instance `-fno-rtti`. It links `LLVMTableGen` and `LLVMSupport`.

> **macOS.** If `CXX` is Homebrew's clang, its default SDK can have a
> different name from the one LLVM's exported zlib/libedit targets point at
> (`MacOSX26.sdk` and `MacOSX.sdk`). CMake then passes the SDK's
> `usr/include` as `-isystem` ahead of libc++, and every C++ header fails with
> "tried including <stddef.h> but didn't find libc++'s <stddef.h> header". The
> CMakeLists marks that directory as implicit, which removes the flag. The
> linker's "built for newer macOS version" warnings are harmless.

---

## Lesson 1 — The backend skeleton

A backend is a function `bool(raw_ostream&, const RecordKeeper&)` that
returns **false** on success. `TableGenMain` parses the input and handles the
command line. The input file, `-I`, `-D` and `-o` are global `cl::opt`s, so
`main` calls `cl::ParseCommandLineOptions` first. `emitSourceFileHeader`
writes the standard "do not edit" banner.

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

`getAllDerivedDefinitions("Class")` selects records; the typed accessors read
their fields. This turns every `Instruction` record into a row of a C++
table, a small version of `--gen-instr-info`. The records come back sorted by
name.

```cpp
for (const Record *R : records.getAllDerivedDefinitions("Instruction"))
  OS << "  { \"" << R->getValueAsString("Mnemonic") << "\", "
     << R->getValueAsInt("Opcode") << ", "
     << (R->getValueAsBit("IsTerminator") ? "true" : "false")
     << " }, // " << R->getName() << "\n";
```

Output (excerpt): `{ "jmp", 100, true }, // JMP`.

## Lesson 3 — The `Init` value hierarchy

The typed accessors are wrappers. Underneath, every value is an `Init`. When a
field's type is not known in advance, `dyn_cast` the `Init` to a concrete
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

## Lesson 4 — Emitting output and errors

This lesson emits a guarded C++ `enum class`, and validates the input first.
The error helpers (`PrintError`, `PrintFatalError`, `PrintWarning`,
`PrintNote`) take a `const Record *`, so the message points at the offending
`def` in the `.td` source.

```cpp
DenseSet<int64_t> seen;
for (const Record *R : records.getAllDerivedDefinitions("EnumCase")) {
  int64_t v = R->getValueAsInt("Value");
  if (v < 0)                  PrintFatalError(R, "enum value must be non-negative...");
  if (!seen.insert(v).second) PrintFatalError(R, "duplicate enum value " + Twine(v));
}
```

The second `RUN:` line passes `-DDUP`, which adds a duplicate. Records are
visited in name order, so the later name is blamed:

```
04_enum_emitter.td:17:5: error: duplicate enum value 1
def Teal : EnumCase<1>;   // sorts after Green, so it is the one reported
    ^
```

## Lesson 5 — Registering several backends

Real tools bundle many backends and choose one with a `--gen-*` flag. Register
each with `TableGen::Emitter::OptClass<E>`, where `E` has a
`(const RecordKeeper&)` constructor and a `run(raw_ostream&)` method. `main`
then calls `TableGenMain(argv[0])` with no function, and the selected option's
emitter runs. This is how `llvm-tblgen` dispatches.

```cpp
static TableGen::Emitter::OptClass<NamesEmitter> X("gen-names", "...");
static TableGen::Emitter::OptClass<CountEmitter> Y("gen-count", "...");
int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv);
  return TableGenMain(argv[0]);   // runs whichever --gen-* was chosen
}
```

Each registration adds an option under "Action to perform" in `--help`, the
same list `llvm-tblgen --help` prints for its own backends.

## Lesson 6 — Classes, superclasses and lists of records

Real backends also look at the class hierarchy, and at fields that hold
other records:

| Call | Returns |
|---|---|
| `records.getClasses()` | every class, in a name-sorted map |
| `Class->getTemplateArgs()` | a class's template arguments |
| `R->getSuperClasses()` | every superclass, in the order its fields were copied in |
| `R->getDirectSuperClasses(Vec)` | only those named after `:` |
| `R->getValueAsListOfDefs("F")` | a `list<SomeClass>` field, as records |
| `R->getValueAsOptionalDef("F")` | a record field, or null if it is `?` (`getValueAsDef` would abort) |
| `records.getAllDerivedDefinitions({"A", "B"})` | defs derived from both A *and* B |

```
// RET
//   all superclasses:    Inst Terminator
//   direct superclasses: Terminator Inst
```

`getDirectSuperClasses` lists the parents in reverse source order (as of LLVM
20).

## Lesson 7 — Debugging a backend

Three habits make a backend easier to debug:

- **Print a record** the way `--print-records` does, with `OS << *R`.
- **Point a diagnostic at a field.** `R->getValue("F")` is the field's
  `RecordVal`, and its `getLoc()` is the line that last set it. A warning
  there, followed by a note at the record, reads:

  ```
  07_debugging.td:12:7: warning: latency 0 is treated as 1
    let Latency = 0;
        ^
  07_debugging.td:11:5: note: in this record
  def NOP : Op {
      ^
  ```

- **Name your phases.** `records.getTimer().startTimer("…")` starts a phase
  (and stops the previous one); `--time-phases` then reports each phase next
  to TableGen's own "Parse, build records".

To inspect the *input* rather than the backend, run `llvm-tblgen
--print-detailed-records` on it ([`../stock`](../stock) lesson 1).

---

## Where this fits

- [`../stock/`](../stock): the backends that ship with `llvm-tblgen`, which
  are built the same way (lesson 5's registration is how they are selected).
- [`../json/`](../json): the same idea in a Python script, without the
  library.
- [`../../../mlir-tablegen/`](../../../mlir-tablegen): `mlir-tblgen` is a
  `TableGenMain` tool like these, with MLIR's backends registered.
