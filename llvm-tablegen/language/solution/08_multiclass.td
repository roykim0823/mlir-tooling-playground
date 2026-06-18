// =============================================================================
// Lesson 8 — `multiclass` and `defm`
//
//   A `multiclass` is a macro that defines multiple records at once. You define
//   it with `multiclass` and invoke it with `defm`.
// =============================================================================

def ops;        // placeholder operator for the operand DAGs below
def GPR;
def Imm;

class Inst<int opc, string asm, dag operands> {
  int    Opcode   = opc;
  string Asm      = asm;
  dag    Operands = operands;
}

// -----------------------------------------------------------------------------
// A multiclass for the reg/reg and reg/imm forms of an arithmetic op.
//
//   `def _rr` inside the multiclass becomes `NAME # _rr`, where NAME is the
//   `defm`'s name. So `defm ADD` + `def _rr` -> `ADD_rr`.
// -----------------------------------------------------------------------------
multiclass ArithRI<int opc, string asm> {
  def _rr : Inst<opc, !strconcat(asm, " $d, $s1, $s2"),
                 (ops GPR:$d, GPR:$s1, GPR:$s2)>;
  def _ri : Inst<opc, !strconcat(asm, " $d, $s1, $s2"),
                 (ops GPR:$d, GPR:$s1, Imm:$s2)>;
}

defm ADD : ArithRI<0b111, "add">;   // -> ADD_rr, ADD_ri
defm SUB : ArithRI<0b101, "sub">;   // -> SUB_rr, SUB_ri
defm MUL : ArithRI<0b100, "mul">;   // -> MUL_rr, MUL_ri

// -----------------------------------------------------------------------------
// Multiclasses can call other multiclasses, and a `defm` can also inherit
// plain classes (listed *after* all the multiclasses).
// -----------------------------------------------------------------------------
class Inst2<int opc, string n> { int Opcode = opc; string Name = n; }

multiclass Basic<int opc> {
  def rr : Inst2<opc, "rr">;
  def rm : Inst2<opc, "rm">;
}

multiclass Scalar<int opc> {
  defm SS : Basic<opc>;        // -> NAME_SS_rr, NAME_SS_rm
  defm SD : Basic<opc>;        // -> NAME_SD_rr, NAME_SD_rm
  def  X  : Inst2<opc, "x">;   // -> NAME_X
}

class Predicated { bit IsPredicated = 1; }

defm FADD : Scalar<0xF>;            // FADD_SS_rr, FADD_SS_rm, FADD_SD_rr, ...
defm CMP  : Scalar<0xA>, Predicated;   // all five CMP records get IsPredicated = 1

// -----------------------------------------------------------------------------
// "Try it yourself" — shift ops producing _l, _r, _ra forms.
// -----------------------------------------------------------------------------
multiclass ShiftOps<int opc> {
  def _l  : Inst2<opc, "shl">;    // left
  def _r  : Inst2<opc, "shr">;    // right logical
  def _ra : Inst2<opc, "sra">;    // right arithmetic
}

defm SH : ShiftOps<0x3>;           // SH_l, SH_r, SH_ra
