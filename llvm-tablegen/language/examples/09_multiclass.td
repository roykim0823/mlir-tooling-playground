// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 9 — `multiclass` and `defm`
// ProgRef: "multiclass", "defm", "Examples: multiclasses and defms"
//
// A multiclass is a macro that defines several records. `defm` invokes it.
// Inside a multiclass, `def Foo` means `def NAME # Foo`, where NAME is the name
// given to the defm.

def ops;
def GPR;
def Imm;
class Inst<int opc, string asm, dag operands> {
  int    Opcode   = opc;
  string Asm      = asm;
  dag    Operands = operands;
}

multiclass ri_inst<int opc, string asmstr> {
  def _rr : Inst<opc, !strconcat(asmstr, " $dst, $src1, $src2"),
                 (ops GPR:$dst, GPR:$src1, GPR:$src2)>;
  def _ri : Inst<opc, !strconcat(asmstr, " $dst, $src1, $src2"),
                 (ops GPR:$dst, GPR:$src1, Imm:$src2)>;
}
defm ADD : ri_inst<0b111, "add">;   // ADD_rr, ADD_ri
defm SUB : ri_inst<0b101, "sub">;   // SUB_rr, SUB_ri

// A defm inside a multiclass also gets NAME prepended.
class Instruction<bits<4> opc, string Name> {
  bits<4> opcode = opc;
  string  name   = Name;
}
multiclass basic_r<bits<4> opc> {
  def rr : Instruction<opc, "rr">;
  def rm : Instruction<opc, "rm">;
}
multiclass basic_s<bits<4> opc> {
  defm SS : basic_r<opc>;            // NAME # SS # rr, ...
  defm SD : basic_r<opc>;
  def  X  : Instruction<opc, "x">;
}
defm FADD : basic_s<0xf>;            // FADDSSrr, FADDSSrm, FADDSDrr, FADDSDrm, FADDX

// A defm lists one or more multiclasses, then any plain classes; the plain
// classes' fields are added to every record it produces.
class XD { bits<4> Prefix = 11; }
class XS { bits<4> Prefix = 12; }
class I<bits<4> op> { bits<4> opcode = op; }
multiclass R {
  def rr : I<4>;
  def rm : I<2>;
}
multiclass Y {
  defm SS : R, XD;
  defm SD : R, XS;
}
defm Instr : Y;                      // InstrSSrr, InstrSSrm, InstrSDrr, InstrSDrm

// A multiclass can inherit other multiclasses, and use let inside.
multiclass Loads {
  let Prefix = 1 in
    def _ld : I<8>, XD;
}
multiclass LoadStore : Loads {
  def _st : I<9>, XS;
}
defm MEM : LoadStore;                // MEM_ld, MEM_st

// Without a name, the records get a unique generated name; with "" the
// multiclass's own names are used as they are.
defm    : Loads;                     // anonymous_N_ld
defm "" : Loads;                     // _ld

// ---- Try it yourself: answers -----------------------------------------------
// A ShiftOps<opc> multiclass producing _l, _r and _ra, invoked as SH.
multiclass ShiftOps<int opc> {
  def _l  : Inst<opc, "shl", (ops)>;
  def _r  : Inst<opc, "shr", (ops)>;
  def _ra : Inst<opc, "sra", (ops)>;
}
defm SH : ShiftOps<0x3>;

// ---- Expected output --------------------------------------------------------
// CHECK-LABEL: def ADD_ri { // Inst
// CHECK-NEXT:  int Opcode = 7;
// CHECK-NEXT:  string Asm = "add $dst, $src1, $src2";
// CHECK-NEXT:  dag Operands = (ops GPR:$dst, GPR:$src1, Imm:$src2);
// CHECK-NEXT:  }
// CHECK-LABEL: def ADD_rr { // Inst
// CHECK-NEXT:  int Opcode = 7;
// CHECK-NEXT:  string Asm = "add $dst, $src1, $src2";
// CHECK-NEXT:  dag Operands = (ops GPR:$dst, GPR:$src1, GPR:$src2);
// CHECK-NEXT:  }
// CHECK-LABEL: def FADDSDrm { // Instruction
// CHECK-NEXT:  bits<4> opcode = { 1, 1, 1, 1 };
// CHECK-NEXT:  string name = "rm";
// CHECK-NEXT:  }
// CHECK-LABEL: def FADDSDrr { // Instruction
// CHECK-NEXT:  bits<4> opcode = { 1, 1, 1, 1 };
// CHECK-NEXT:  string name = "rr";
// CHECK-NEXT:  }
// CHECK-LABEL: def FADDSSrm { // Instruction
// CHECK-NEXT:  bits<4> opcode = { 1, 1, 1, 1 };
// CHECK-NEXT:  string name = "rm";
// CHECK-NEXT:  }
// CHECK-LABEL: def FADDSSrr { // Instruction
// CHECK-NEXT:  bits<4> opcode = { 1, 1, 1, 1 };
// CHECK-NEXT:  string name = "rr";
// CHECK-NEXT:  }
// CHECK-LABEL: def FADDX { // Instruction
// CHECK-NEXT:  bits<4> opcode = { 1, 1, 1, 1 };
// CHECK-NEXT:  string name = "x";
// CHECK-NEXT:  }
// CHECK-LABEL: def InstrSDrm { // I XS
// CHECK-NEXT:  bits<4> opcode = { 0, 0, 1, 0 };
// CHECK-NEXT:  bits<4> Prefix = { 1, 1, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def InstrSDrr { // I XS
// CHECK-NEXT:  bits<4> opcode = { 0, 1, 0, 0 };
// CHECK-NEXT:  bits<4> Prefix = { 1, 1, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def InstrSSrm { // I XD
// CHECK-NEXT:  bits<4> opcode = { 0, 0, 1, 0 };
// CHECK-NEXT:  bits<4> Prefix = { 1, 0, 1, 1 };
// CHECK-NEXT:  }
// CHECK-LABEL: def InstrSSrr { // I XD
// CHECK-NEXT:  bits<4> opcode = { 0, 1, 0, 0 };
// CHECK-NEXT:  bits<4> Prefix = { 1, 0, 1, 1 };
// CHECK-NEXT:  }
// CHECK-LABEL: def MEM_ld { // I XD
// CHECK-NEXT:  bits<4> opcode = { 1, 0, 0, 0 };
// CHECK-NEXT:  bits<4> Prefix = { 0, 0, 0, 1 };
// CHECK-NEXT:  }
// CHECK-LABEL: def MEM_st { // I XS
// CHECK-NEXT:  bits<4> opcode = { 1, 0, 0, 1 };
// CHECK-NEXT:  bits<4> Prefix = { 1, 1, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def SH_l { // Inst
// CHECK-NEXT:  int Opcode = 3;
// CHECK-NEXT:  string Asm = "shl";
// CHECK-NEXT:  dag Operands = (ops);
// CHECK-NEXT:  }
// CHECK-LABEL: def SH_r { // Inst
// CHECK-NEXT:  int Opcode = 3;
// CHECK-NEXT:  string Asm = "shr";
// CHECK-NEXT:  dag Operands = (ops);
// CHECK-NEXT:  }
// CHECK-LABEL: def SH_ra { // Inst
// CHECK-NEXT:  int Opcode = 3;
// CHECK-NEXT:  string Asm = "sra";
// CHECK-NEXT:  dag Operands = (ops);
// CHECK-NEXT:  }
// CHECK-LABEL: def SUB_ri { // Inst
// CHECK-NEXT:  int Opcode = 5;
// CHECK-NEXT:  string Asm = "sub $dst, $src1, $src2";
// CHECK-NEXT:  dag Operands = (ops GPR:$dst, GPR:$src1, Imm:$src2);
// CHECK-NEXT:  }
// CHECK-LABEL: def SUB_rr { // Inst
// CHECK-NEXT:  int Opcode = 5;
// CHECK-NEXT:  string Asm = "sub $dst, $src1, $src2";
// CHECK-NEXT:  dag Operands = (ops GPR:$dst, GPR:$src1, GPR:$src2);
// CHECK-NEXT:  }
// CHECK-LABEL: def _ld { // I XD
// CHECK-NEXT:  bits<4> opcode = { 1, 0, 0, 0 };
// CHECK-NEXT:  bits<4> Prefix = { 0, 0, 0, 1 };
// CHECK-NEXT:  }
// CHECK-LABEL: def anonymous_{{[0-9]+}}_ld { // I XD
// CHECK-NEXT:  bits<4> opcode = { 1, 0, 0, 0 };
// CHECK-NEXT:  bits<4> Prefix = { 0, 0, 0, 1 };
// CHECK-NEXT:  }
