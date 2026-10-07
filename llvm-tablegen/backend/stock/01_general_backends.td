// RUN: llvm-tblgen --print-records %s | FileCheck --check-prefix=RECORDS %s
// RUN: llvm-tblgen --print-detailed-records %s | FileCheck --check-prefix=DETAILED %s
// RUN: llvm-tblgen --print-enums -class=Reg %s | FileCheck --check-prefix=ENUM-REG %s
// RUN: llvm-tblgen --print-enums -class=Special %s | FileCheck --check-prefix=ENUM-SPECIAL %s
// RUN: llvm-tblgen --null-backend --time-phases %s 2>&1 | FileCheck --check-prefix=TIME %s
// RUN: llvm-tblgen --dump-json %s | jq -c '."!instanceof"' | FileCheck --check-prefix=JSON-INST %s
// RUN: llvm-tblgen --dump-json %s | jq -c '.X_hi' | FileCheck --check-prefix=JSON-REC %s
// REQUIRES: jq
//
// Lesson 1 — The general backends
// BackEnds: "General BackEnds"; BackGuide: "Debugging Tools"
//
// These backends accept any .td file, because they print records instead of
// interpreting them. Use them to see what a backend will receive.

defvar Width = 32;
class Reg<int n> { int Num = n; }
class Special;
multiclass Pair<int base> {
  def _lo : Reg<base>;
  def _hi : Reg<!add(base, 1)>, Special;
}
def R0 : Reg<0>;
def SP : Reg<31>, Special;
defm X : Pair<4>;

// --print-records, the default. Classes first, then defs sorted by name. The
// output format is kept stable over time so tests can compare it. Template
// arguments print as Class:arg; multiclasses are not printed at all.
// RECORDS:      ------------- Classes -----------------
// RECORDS-NEXT: class Reg<int Reg:n = ?> {
// RECORDS-NEXT:   int Num = Reg:n;
// RECORDS:      ------------- Defs -----------------
// RECORDS-NEXT: def R0 { // Reg
// RECORDS:      def X_hi { // Reg Special

// --print-detailed-records adds the global defvars, every source location,
// and the chain of defms that produced a record. Its format is *not* stable.
// DETAILED:      Global Variables (1)
// DETAILED:      Width = 32
// DETAILED:      Classes (2)
// DETAILED:      Records (4)
// DETAILED:      X_hi  |{{.*}}01_general_backends.td:21|
// DETAILED-NEXT:   Defm sequence: |{{.*}}01_general_backends.td:25| |{{.*}}01_general_backends.td:21|
// DETAILED-NEXT:   Superclasses: Reg Special
// DETAILED-NEXT:   Fields:
// DETAILED-NEXT:     int Num = 5  |{{.*}}01_general_backends.td:17|

// --print-enums -class=C lists the defs that derive from C: the start of an
// enum. (The overview runs it on X86's registers.)
// ENUM-REG:     R0, SP, X_hi, X_lo,
// ENUM-SPECIAL: SP, X_hi,

// --null-backend parses and stops; with --time-phases it shows where the time
// goes. A C++ backend can add its own phases (../writing, lesson 6).
// TIME:      TableGen Phase Timing
// TIME:      Parse, build records
// TIME:      Backend overall

// --dump-json writes every def as JSON, plus "!instanceof": for each class,
// the defs that derive from it. Each def carries "!superclasses", "!fields"
// (members declared with `field`), "!locs" and "!anonymous". ../json builds a
// backend in Python on top of this.
// JSON-INST: {"Reg":["R0","SP","X_hi","X_lo"],"Special":["SP","X_hi"]}
// JSON-REC:  {"!anonymous":false,"!fields":[],"!locs":["{{.*}}01_general_backends.td:21","{{.*}}01_general_backends.td:25"],"!name":"X_hi","!superclasses":["Reg","Special"],"Num":5}
