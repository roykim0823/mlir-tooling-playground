// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 10 — `defvar`, `defset`, `deftype`
// ProgRef: "defvar", "defset", "deftype", "Defvar in a record body"

// ---- defvar: a named, immutable value ----------------------------------------
// At top level a defvar is a global variable; its type is inferred.
defvar BaseOpc = 0x20;
defvar Names   = ["add", "sub", "mul"];

class Op<int idx> {
  int    Opc = !add(BaseOpc, idx);
  string Asm = Names[idx];
}
def OP0 : Op<0>;
def OP2 : Op<2>;

// Inside a body a defvar is a local: it holds a temporary, and is not a field.
def Local {
  defvar tmp = !mul(6, 7);
  int Answer = tmp;
}

// An inner name shadows an outer one: here the body's V hides the template
// argument V, from the defvar onwards.
class Shadow<int V> {
  int Before = V;
  defvar V = 7;
  int After = V;
}
def S : Shadow<3>;

// ---- defset: collect records into a global list ------------------------------
// Records defined inside the braces are defined as usual and also appended to
// the list. A nested defset adds its records to both lists.
class Reg<int n> { int Num = n; }
defset list<Reg> AllRegs = {
  def R0 : Reg<0>;
  defset list<Reg> ArgRegs = {
    def A0 : Reg<10>;
    def A1 : Reg<11>;
  }
}
def Counts {
  int       NumAll  = !size(AllRegs);
  int       NumArgs = !size(ArgRegs);
  list<Reg> All     = AllRegs;
}

// ---- deftype: a name for a type ----------------------------------------------
// Top level only, and only for primitive types and other aliases.
deftype byte     = bits<8>;
deftype halfword = bits<16>;
def Insn {
  byte     Opcode = 0xAB;
  halfword Imm    = 0xBEEF;
}

// ---- Try it yourself: answers -----------------------------------------------
// 1. Two defsets: callee-saved and caller-saved registers.
// 2. A summary record built with !listconcat and !size.
defset list<Reg> Callee = {
  def S0 : Reg<8>;
  def S1 : Reg<9>;
}
defset list<Reg> Caller = {
  def T0 : Reg<5>;
  def T1 : Reg<6>;
  def T2 : Reg<7>;
}
def RegSummary {
  list<Reg> Both   = !listconcat(Callee, Caller);
  int       NumAll = !size(!listconcat(Callee, Caller));
}

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def A0 { // Reg
// CHECK-NEXT:  int Num = 10;
// CHECK-NEXT:  }
// CHECK-LABEL: def Counts {
// CHECK-NEXT:  int NumAll = 3;
// CHECK-NEXT:  int NumArgs = 2;
// CHECK-NEXT:  list<Reg> All = [R0, A0, A1];
// CHECK-NEXT:  }
// CHECK-LABEL: def Insn {
// CHECK-NEXT:  bits<8> Opcode = { 1, 0, 1, 0, 1, 0, 1, 1 };
// CHECK-NEXT:  bits<16> Imm = { 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1 };
// CHECK-NEXT:  }
// CHECK-LABEL: def Local {
// CHECK-NEXT:  int Answer = 42;
// CHECK-NEXT:  }
// CHECK-LABEL: def OP0 { // Op
// CHECK-NEXT:  int Opc = 32;
// CHECK-NEXT:  string Asm = "add";
// CHECK-NEXT:  }
// CHECK-LABEL: def OP2 { // Op
// CHECK-NEXT:  int Opc = 34;
// CHECK-NEXT:  string Asm = "mul";
// CHECK-NEXT:  }
// CHECK-LABEL: def RegSummary {
// CHECK-NEXT:  list<Reg> Both = [S0, S1, T0, T1, T2];
// CHECK-NEXT:  int NumAll = 5;
// CHECK-NEXT:  }
// CHECK-LABEL: def S { // Shadow
// CHECK-NEXT:  int Before = 3;
// CHECK-NEXT:  int After = 7;
// CHECK-NEXT:  }
