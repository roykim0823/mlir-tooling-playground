// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 16 — Capstone: MiniISA
//
// A 4-register, 14-instruction toy ISA that uses most of the language at once:
// classes and template arguments (6, 7), bits/dag/list types (2), top-level
// let (8), multiclass/defm (9), defset (10), foreach and assert (11, 12), dags
// (13) and bang operators (4). ../../backend/json turns this file into a C++
// header; ../../backend/stock/03_mini_target.td rewrites it against LLVM's
// real Target.td so the stock --gen-* backends accept it.

// ---------- 1. Registers ---------------------------------------------------
class Register<string n, bits<2> num> {
  string  AsmName     = n;
  bits<2> Encoding    = num;
  bit     CalleeSaved = 0;
}

defset list<Register> AllRegs = {
  def R0 : Register<"r0", 0b00>;
  def R1 : Register<"r1", 0b01>;
  def R2 : Register<"r2", 0b10> { let CalleeSaved = 1; }
  def R3 : Register<"r3", 0b11> { let CalleeSaved = 1; }
}

// ---------- 2. Operand classes ---------------------------------------------
class Operand;
def REG : Operand;
def IMM : Operand;

// ---------- 3. Instruction skeleton ----------------------------------------
class Inst<bits<4> opc, string mnem, dag outs, dag ins> {
  bits<4>      Opcode     = opc;
  string       Mnemonic   = mnem;
  dag          OutOps     = outs;
  dag          InOps      = ins;
  list<string> Predicates = [];
  bit          HasSideFx  = 0;
  bit          IsBranch   = 0;
  bit          IsCall     = 0;
}

def ops;     // placeholder operator for operand DAGs

// ---------- 4. A multiclass for RR / RI shape ------------------------------
multiclass ArithOp<bits<4> opc, string mnem> {
  def _rr : Inst<opc, mnem,
                 (ops REG:$dst),
                 (ops REG:$s1, REG:$s2)>;
  def _ri : Inst<opc, mnem,
                 (ops REG:$dst),
                 (ops REG:$s1, IMM:$s2)>;
}

// ---------- 5. Define every arithmetic op in one block ---------------------
let HasSideFx = 0 in {
  defm ADD : ArithOp<0b0001, "add">;
  defm SUB : ArithOp<0b0010, "sub">;
  defm AND : ArithOp<0b0011, "and">;
  defm OR  : ArithOp<0b0100, "or">;
  defm XOR : ArithOp<0b0101, "xor">;
}

// ---------- 6. Memory + control flow ---------------------------------------
def LOAD  : Inst<0b1000, "ld",   (ops REG:$dst), (ops REG:$addr)>      { let HasSideFx = 1; }
def STORE : Inst<0b1001, "st",   (ops),          (ops REG:$src, REG:$addr)> { let HasSideFx = 1; }
def JMP   : Inst<0b1110, "jmp",  (ops),          (ops IMM:$tgt)>       { let IsBranch = 1; }
def CALL  : Inst<0b1111, "call", (ops),          (ops IMM:$tgt)>       { let IsCall = 1; let IsBranch = 1; }

// ---------- 7. A sanity assertion ------------------------------------------
foreach R = AllRegs in
  assert !le(!size(R.AsmName), 4), "register name too long: " # R.AsmName;

// ---------- 8. A summary record using bang operators ------------------------
def Summary {
  int    NumRegs        = !size(AllRegs);
  int    NumCalleeSaved = !size(!filter(R, AllRegs, R.CalleeSaved));
  string CalleeList     = !interleave(
                            !foreach(R, !filter(R, AllRegs, R.CalleeSaved), R.AsmName),
                            ", ");
}

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def ADD_ri { // Inst
// CHECK-NEXT:  bits<4> Opcode = { 0, 0, 0, 1 };
// CHECK-NEXT:  string Mnemonic = "add";
// CHECK-NEXT:  dag OutOps = (ops REG:$dst);
// CHECK-NEXT:  dag InOps = (ops REG:$s1, IMM:$s2);
// CHECK-NEXT:  list<string> Predicates = [];
// CHECK-NEXT:  bit HasSideFx = 0;
// CHECK-NEXT:  bit IsBranch = 0;
// CHECK-NEXT:  bit IsCall = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def CALL { // Inst
// CHECK-NEXT:  bits<4> Opcode = { 1, 1, 1, 1 };
// CHECK-NEXT:  string Mnemonic = "call";
// CHECK-NEXT:  dag OutOps = (ops);
// CHECK-NEXT:  dag InOps = (ops IMM:$tgt);
// CHECK-NEXT:  list<string> Predicates = [];
// CHECK-NEXT:  bit HasSideFx = 0;
// CHECK-NEXT:  bit IsBranch = 1;
// CHECK-NEXT:  bit IsCall = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def LOAD { // Inst
// CHECK-NEXT:  bits<4> Opcode = { 1, 0, 0, 0 };
// CHECK-NEXT:  string Mnemonic = "ld";
// CHECK-NEXT:  dag OutOps = (ops REG:$dst);
// CHECK-NEXT:  dag InOps = (ops REG:$addr);
// CHECK-NEXT:  list<string> Predicates = [];
// CHECK-NEXT:  bit HasSideFx = 1;
// CHECK-NEXT:  bit IsBranch = 0;
// CHECK-NEXT:  bit IsCall = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def R2 { // Register
// CHECK-NEXT:  string AsmName = "r2";
// CHECK-NEXT:  bits<2> Encoding = { 1, 0 };
// CHECK-NEXT:  bit CalleeSaved = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def Summary {
// CHECK-NEXT:  int NumRegs = 4;
// CHECK-NEXT:  int NumCalleeSaved = 2;
// CHECK-NEXT:  string CalleeList = "r2, r3";
// CHECK-NEXT:  }
