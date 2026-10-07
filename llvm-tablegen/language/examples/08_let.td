// RUN: llvm-tblgen %s | FileCheck %s
// RUN: not llvm-tblgen -DBAD_LET %s 2>&1 | FileCheck --check-prefix=BAD %s
//
// Lesson 8 — The `let` statement, and how records are built
// ProgRef: "let", "Record Bodies", "How records are built"
//
// `let` overrides a field's value. It has two forms: inside a record body it
// affects that record; at top level, `let ... in` applies to every class and
// record defined inside its scope.

class Inst {
  bit     hasSideFx = 0;
  int     Latency   = 1;
  bits<8> Opcode    = 0;
}

// Body form.
def LOAD : Inst {
  let hasSideFx = 1;
  let Latency   = 4;
}

// Top-level form, over a braced scope or a single statement. Scopes nest.
let hasSideFx = 1 in {
  def STORE : Inst;
  let Latency = 8 in
    def STORE8 : Inst;
}

// Both forms can set a range of bits; the body form uses {...}, the
// top-level form <...>.
def ADD : Inst {
  let Opcode{7...4} = 0b0010;
  let Opcode{3...0} = 0b1100;
}
let Opcode<7...4> = 0b1111 in
  def SUB : Inst;

// Top-level bindings are applied right after inheritance, so a body `let`
// still has the last word.
let Latency = 2 in
  def MUL : Inst { let Latency = 3; }

// A top-level let may only name inherited fields. A field the record defines
// itself is unknown at the moment the binding is applied.
#ifdef BAD_LET
let Own = 5 in
  def Bad : Inst { int Own = 3; }
#endif
// BAD: error: Value 'Own' unknown!

// ---- How records are built --------------------------------------------------
// 1. inherit parent fields and substitute template arguments,
// 2. apply top-level lets, 3. process the body (fields, lets, defvars),
// 4. resolve references between fields.
// Because step 4 comes last, a let changes every field computed from the one
// it sets. Template arguments are already substituted in step 1, so xplus1
// does not change.
class C<int x> {
  int Y      = x;
  int Yplus1 = !add(Y, 1);
  int xplus1 = !add(x, 1);
}
let Y = 10 in
  def rec1 : C<5>;
def rec2 : C<5> { let Y = 10; }

// ---- Growing a list ---------------------------------------------------------
// There is no "let append". To extend a list along a class chain, pass the
// extras down as template arguments and !listconcat them.
class HasPreds<list<string> preds = []> { list<string> Predicates = preds; }
class L1<list<string> extra = []> : HasPreds<!listconcat(["HasV1"], extra)>;
class L2<list<string> extra = []> : L1<!listconcat(["HasV2"], extra)>;
def Plain  : L2;
def WithFP : L2<["HasFP"]>;

// ---- Try it yourself: answers -----------------------------------------------
// 1. Mark a group of instruction records as calls with one top-level let.
// 2. The list idiom above, with a third level added.
class Instr { bit isCall = 0; }
let isCall = 1 in {
  def CALL  : Instr;
  def CALLR : Instr;
}
def RET : Instr;

class L3<list<string> extra = []> : L2<!listconcat(["HasV3"], extra)>;
def WithSIMD : L3<["HasSIMD"]>;

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def ADD { // Inst
// CHECK-NEXT:  bit hasSideFx = 0;
// CHECK-NEXT:  int Latency = 1;
// CHECK-NEXT:  bits<8> Opcode = { 0, 0, 1, 0, 1, 1, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def CALL { // Instr
// CHECK-NEXT:  bit isCall = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def CALLR { // Instr
// CHECK-NEXT:  bit isCall = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def LOAD { // Inst
// CHECK-NEXT:  bit hasSideFx = 1;
// CHECK-NEXT:  int Latency = 4;
// CHECK-NEXT:  bits<8> Opcode = { 0, 0, 0, 0, 0, 0, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def MUL { // Inst
// CHECK-NEXT:  bit hasSideFx = 0;
// CHECK-NEXT:  int Latency = 3;
// CHECK-NEXT:  bits<8> Opcode = { 0, 0, 0, 0, 0, 0, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def Plain { // HasPreds L1 L2
// CHECK-NEXT:  list<string> Predicates = ["HasV1", "HasV2"];
// CHECK-NEXT:  }
// CHECK-LABEL: def RET { // Instr
// CHECK-NEXT:  bit isCall = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def STORE { // Inst
// CHECK-NEXT:  bit hasSideFx = 1;
// CHECK-NEXT:  int Latency = 1;
// CHECK-NEXT:  bits<8> Opcode = { 0, 0, 0, 0, 0, 0, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def STORE8 { // Inst
// CHECK-NEXT:  bit hasSideFx = 1;
// CHECK-NEXT:  int Latency = 8;
// CHECK-NEXT:  bits<8> Opcode = { 0, 0, 0, 0, 0, 0, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def SUB { // Inst
// CHECK-NEXT:  bit hasSideFx = 0;
// CHECK-NEXT:  int Latency = 1;
// CHECK-NEXT:  bits<8> Opcode = { 1, 1, 1, 1, 0, 0, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def WithFP { // HasPreds L1 L2
// CHECK-NEXT:  list<string> Predicates = ["HasV1", "HasV2", "HasFP"];
// CHECK-NEXT:  }
// CHECK-LABEL: def WithSIMD { // HasPreds L1 L2 L3
// CHECK-NEXT:  list<string> Predicates = ["HasV1", "HasV2", "HasV3", "HasSIMD"];
// CHECK-NEXT:  }
// CHECK-LABEL: def rec1 { // C
// CHECK-NEXT:  int Y = 10;
// CHECK-NEXT:  int Yplus1 = 11;
// CHECK-NEXT:  int xplus1 = 6;
// CHECK-NEXT:  }
// CHECK-LABEL: def rec2 { // C
// CHECK-NEXT:  int Y = 10;
// CHECK-NEXT:  int Yplus1 = 11;
// CHECK-NEXT:  int xplus1 = 6;
// CHECK-NEXT:  }
