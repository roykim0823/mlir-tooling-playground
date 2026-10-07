// RUN: llvm-tblgen -I %llvm_include --gen-register-info %s | FileCheck --check-prefix=REG %s
// RUN: llvm-tblgen -I %llvm_include --gen-instr-info %s    | FileCheck --check-prefix=INSTR %s
// RUN: llvm-tblgen -I %llvm_include --gen-asm-writer %s    | FileCheck --check-prefix=ASM %s
// RUN: llvm-tblgen -I %llvm_include --gen-emitter %s       | FileCheck --check-prefix=EMIT %s
// RUN: llvm-tblgen -I %llvm_include --gen-disassembler %s  | FileCheck --check-prefix=DIS %s
//
// Lesson 3 — A target the stock backends accept
// BackEnds: "LLVM BackEnds" (RegisterInfo, InstrInfo, AsmWriter, CodeEmitter,
// Disassembler)
//
// The target backends do not accept arbitrary records: each reads classes
// that include/llvm/Target/Target.td defines (Register, RegisterClass,
// Instruction, Target, ...) and expects one `Target` record. This is
// ../../language/examples/16_miniisa.td rewritten against that schema: still
// about 60 lines, and enough for five real backends. The overview runs the
// same backends on X86, where the inputs and outputs are a thousand times
// larger.

include "llvm/Target/Target.td"

// ---- Registers --------------------------------------------------------------
// Register<name> has a HWEncoding field (the number used in encodings) and a
// Namespace (the C++ namespace of the generated enums).
class MiniReg<bits<16> enc, string n> : Register<n> {
  let HWEncoding = enc;
  let Namespace  = "Mini";
}
foreach i = 0...3 in
  def R # i : MiniReg<i, "r" # i>;

// RegisterClass<namespace, value types, alignment, members>. `sequence` is a
// set operator that Target.td understands, not a bang operator.
def GPR : RegisterClass<"Mini", [i32], 32, (sequence "R%u", 0, 3)>;

// ---- Instructions -----------------------------------------------------------
def simm16 : Operand<i32>;

// Every instruction is 32 bits: an 8-bit opcode and then operand fields.
// Operand fields are matched to the operands in (outs ...)/(ins ...) by name.
class MiniInst<bits<8> op, dag outs, dag ins, string asm> : Instruction {
  let Namespace      = "Mini";
  let OutOperandList = outs;
  let InOperandList  = ins;
  let AsmString      = asm;
  let Size           = 4;
  let hasSideEffects = 0;
  field bits<32> Inst;
  let Inst{31-24} = op;
}

multiclass ALU<bits<8> op, string mnem> {
  def rr : MiniInst<op, (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
                    mnem # "\t$rd, $rs1, $rs2"> {
    bits<4> rd; bits<4> rs1; bits<4> rs2;
    let Inst{23-20} = rd;
    let Inst{19-16} = rs1;
    let Inst{15-12} = rs2;
  }
  def ri : MiniInst<!or(op, 0x80), (outs GPR:$rd), (ins GPR:$rs1, simm16:$imm),
                    mnem # "\t$rd, $rs1, $imm"> {
    bits<4> rd; bits<4> rs1; bits<16> imm;
    let Inst{23-20} = rd;
    let Inst{19-16} = rs1;
    let Inst{15-0}  = imm;
  }
}
defm ADD : ALU<0x01, "add">;
defm SUB : ALU<0x02, "sub">;
defm XOR : ALU<0x05, "xor">;

let mayLoad = 1 in
def LD : MiniInst<0x10, (outs GPR:$rd), (ins GPR:$addr), "ld\t$rd, ($addr)"> {
  bits<4> rd; bits<4> addr;
  let Inst{23-20} = rd;
  let Inst{19-16} = addr;
}
let isReturn = 1, isTerminator = 1, isBarrier = 1 in
def RET : MiniInst<0x22, (outs), (ins), "ret">;

// ---- The target ---------------------------------------------------------------
def MiniInstrInfo : InstrInfo;
def Mini : Target { let InstructionSet = MiniInstrInfo; }

// ---- --gen-register-info ----------------------------------------------------
// One enum value per register (0 is NoRegister), then register classes, then
// the MC and TargetRegisterInfo tables, each behind its own GET_REGINFO_ macro.
// REG-LABEL: #ifdef GET_REGINFO_ENUM
// REG:         R0 = 1,
// REG-NEXT:    R1 = 2,
// REG-NEXT:    R2 = 3,
// REG-NEXT:    R3 = 4,
// REG-NEXT:    NUM_TARGET_REGS // 5
// REG:         GPRRegClassID = 0,
// REG-LABEL: #ifdef GET_REGINFO_MC_DESC
// REG-LABEL: #ifdef GET_REGINFO_HEADER
// REG:       struct MiniGenRegisterInfo : public TargetRegisterInfo {
// REG-LABEL: #ifdef GET_REGINFO_TARGET_DESC

// ---- --gen-instr-info -------------------------------------------------------
// The opcode enum starts with the ~300 target-independent opcodes from
// Target.td and GenericOpcodes.td (COPY, G_ADD, ...); the target's own follow.
// The descriptor table records operand counts, size and flags for each.
// INSTR-LABEL: #ifdef GET_INSTRINFO_ENUM
// INSTR:         PHI	= 0,
// INSTR:         G_ADD	= {{[0-9]+}},
// INSTR:         ADDri	= [[ADDRI:[0-9]+]],
// INSTR-NEXT:    ADDrr	= {{[0-9]+}},
// INSTR-NEXT:    LD	= {{[0-9]+}},
// INSTR-NEXT:    RET	= {{[0-9]+}},
// INSTR:         INSTRUCTION_LIST_END = {{[0-9]+}}
// INSTR-LABEL: #ifdef GET_INSTRINFO_MC_DESC
// INSTR:         { {{[0-9]+}}, 2, 1, 4, {{.*}}(1ULL<<MCID::MayLoad){{.*}} },  // Inst #{{[0-9]+}} = LD
// INSTR:         { [[ADDRI]], 3, 1, 4, {{.*}} },  // Inst #[[ADDRI]] = ADDri

// ---- --gen-asm-writer -------------------------------------------------------
// The AsmString of every instruction, split into a string table and
// printOperand calls.
// ASM:       /* {{[0-9]+}} */ "add\t\000"
// ASM:       void MiniInstPrinter::printInstruction(const MCInst *MI, uint64_t Address, raw_ostream &O) {
// ASM:       getRegisterName(MCRegister Reg)

// ---- --gen-emitter ----------------------------------------------------------
// One constant per opcode holding the fixed bits of Inst; the operand bits are
// filled in at run time from the MCInst. ADDrr = 0x01000000, ADDri = 0x81000000.
// EMIT:      uint64_t MiniMCCodeEmitter::getBinaryCodeForInstr(const MCInst &MI,
// EMIT:        UINT64_C(2164260864),	// ADDri
// EMIT-NEXT:   UINT64_C(16777216),	// ADDrr
// EMIT:        case Mini::ADDrr:
// EMIT:          // op: rd
// EMIT-NEXT:     op = getMachineOpValue(MI, MI.getOperand(0), Fixups, STI);
// EMIT-NEXT:     op &= UINT64_C(15);
// EMIT-NEXT:     op <<= 20;

// ---- --gen-disassembler -----------------------------------------------------
// A decoder table that switches on the opcode bits and decodes the operands.
// DIS:       static const uint8_t DecoderTable32[
// DIS:       // Opcode: ADDrr
// DIS:       // Opcode: ADDri
// DIS:       static DecodeStatus decodeInstruction(
