// RUN: %writing_bin/06-hierarchy %s | FileCheck %s
// REQUIRES: writing-build
//
// Input for the class-and-list backend. Instructions carry a list of
// predicate records and an optional alias, and inherit through a small
// class hierarchy.

class Predicate<string n> { string Name = n; }
def HasFP : Predicate<"fp">;
def HasV2 : Predicate<"v2">;

class Format;
def RR : Format;

class Inst<string mnem, list<Predicate> preds = []> {
  string          Mnemonic   = mnem;
  list<Predicate> Predicates = preds;
  Inst            Alias      = ?;           // usually unset
}
class Terminator;
class Arith<string mnem> : Inst<mnem>;
class ArithRR<string mnem> : Arith<mnem> { Format Form = RR; }

def ADD  : ArithRR<"add">;
def FADD : Inst<"fadd", [HasFP, HasV2]>;
def RET  : Inst<"ret">, Terminator;
def PLUS : ArithRR<"plus"> { let Alias = ADD; }

// CHECK:      // 6 classes:
// CHECK-NEXT: //   Arith <1 template arg(s)>
// CHECK-NEXT: //   ArithRR <1 template arg(s)>
// CHECK-NEXT: //   Format <0 template arg(s)>
// CHECK-NEXT: //   Inst <2 template arg(s)>
// CHECK-NEXT: //   Predicate <1 template arg(s)>
// CHECK-NEXT: //   Terminator <0 template arg(s)>

// CHECK:      // ADD
// CHECK-NEXT: //   all superclasses:    Inst Arith ArithRR
// CHECK-NEXT: //   direct superclasses: ArithRR
// CHECK-NEXT: //   predicates:          (none)
// CHECK-NEXT: //   alias:               (unset)
// CHECK:      // FADD
// CHECK:      //   predicates:          fp v2
// CHECK:      // PLUS
// CHECK:      //   alias:               ADD
// CHECK:      // RET
// CHECK-NEXT: //   all superclasses:    Inst Terminator
// CHECK-NEXT: //   direct superclasses: Terminator Inst

// CHECK: // derived from Inst *and* Terminator: RET
