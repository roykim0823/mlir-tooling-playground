// RUN: llvm-tblgen %s 2>&1 | FileCheck %s
//
// Lesson 7 — Template arguments
// ProgRef: "class" (template arguments, NAME), "Record Bodies", "def"
//
// A class can take template arguments in <...>. Each record that inherits the
// class passes its own values, so one class describes many records.

class Register<string n, int num> {
  string Name   = n;
  int    Number = num;
  bit    IsCallerSaved = 0;
}
def R0 : Register<"r0", 0>;
def R1 : Register<"r1", 1>;
def R2 : Register<"r2", 2> { let IsCallerSaved = 1; }

// Arguments with a default are optional, and must come after the required
// ones. Arguments can be passed by position or by name; positional first.
class Inst<int opc, string mnem = "?", bit hasSideFx = 0> {
  int    Opcode    = opc;
  string Mnemonic  = mnem;
  bit    HasSideFx = hasSideFx;
}
def ADD : Inst<0x01, "add">;              // hasSideFx defaults to 0
def NOP : Inst<0x00>;                     // two defaults
def OUT : Inst<0x10, "out", 1>;
def DIV : Inst<opc=0x20, mnem="div">;     // named
def MUL : Inst<0x21, hasSideFx=1>;        // positional, then named

// Every class has an implicit argument NAME, bound to the name of the def
// (or defm, lesson 9) that inherits it.
class Tagged { string MyName = NAME; }
def Alpha : Tagged;
def Beta  : Tagged;

// A record's own name can be passed to its parents.
def ops;
class SelfRef<dag d> { dag the_dag = d; }
def rec1 : SelfRef<(ops rec1)>;

// An argument the class never reads draws a warning (silence it with
// --no-warn-on-unused-template-args).
class Unused<int used, int unused> { int X = used; }
def U : Unused<1, 2>;
// CHECK: warning: unused template argument: Unused:unused

// ---- Try it yourself: answers -----------------------------------------------
// A class GPR<int n> with AsmName = "x" # n, and records X0..X3.
class GPR<int n> { string AsmName = "x" # n; }
def X0 : GPR<0>;
def X1 : GPR<1>;
def X2 : GPR<2>;
def X3 : GPR<3>;

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def ADD { // Inst
// CHECK-NEXT:  int Opcode = 1;
// CHECK-NEXT:  string Mnemonic = "add";
// CHECK-NEXT:  bit HasSideFx = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def Alpha { // Tagged
// CHECK-NEXT:  string MyName = "Alpha";
// CHECK-NEXT:  }
// CHECK-LABEL: def Beta { // Tagged
// CHECK-NEXT:  string MyName = "Beta";
// CHECK-NEXT:  }
// CHECK-LABEL: def DIV { // Inst
// CHECK-NEXT:  int Opcode = 32;
// CHECK-NEXT:  string Mnemonic = "div";
// CHECK-NEXT:  bit HasSideFx = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def MUL { // Inst
// CHECK-NEXT:  int Opcode = 33;
// CHECK-NEXT:  string Mnemonic = "?";
// CHECK-NEXT:  bit HasSideFx = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def NOP { // Inst
// CHECK-NEXT:  int Opcode = 0;
// CHECK-NEXT:  string Mnemonic = "?";
// CHECK-NEXT:  bit HasSideFx = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def OUT { // Inst
// CHECK-NEXT:  int Opcode = 16;
// CHECK-NEXT:  string Mnemonic = "out";
// CHECK-NEXT:  bit HasSideFx = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def R0 { // Register
// CHECK-NEXT:  string Name = "r0";
// CHECK-NEXT:  int Number = 0;
// CHECK-NEXT:  bit IsCallerSaved = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def R1 { // Register
// CHECK-NEXT:  string Name = "r1";
// CHECK-NEXT:  int Number = 1;
// CHECK-NEXT:  bit IsCallerSaved = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def R2 { // Register
// CHECK-NEXT:  string Name = "r2";
// CHECK-NEXT:  int Number = 2;
// CHECK-NEXT:  bit IsCallerSaved = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def U { // Unused
// CHECK-NEXT:  int X = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def X0 { // GPR
// CHECK-NEXT:  string AsmName = "x0";
// CHECK-NEXT:  }
// CHECK-LABEL: def X3 { // GPR
// CHECK-NEXT:  string AsmName = "x3";
// CHECK-NEXT:  }
// CHECK-LABEL: def rec1 { // SelfRef
// CHECK-NEXT:  dag the_dag = (ops rec1);
// CHECK-NEXT:  }
