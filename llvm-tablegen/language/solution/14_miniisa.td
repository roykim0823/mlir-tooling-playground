//===-- 14_miniisa.td - A toy ISA description in TableGen ------*- tablegen -*-===//
//
// Lesson 14 — Capstone: a 4-register, 8-instruction toy ISA called MiniISA.
// It exercises classes, bits/dag/list types, template args, top-level `let`,
// bang operators, `defm`/`multiclass`, `defset`, `foreach`, `assert`, and DAGs.
//
//===----------------------------------------------------------------------------===//

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
