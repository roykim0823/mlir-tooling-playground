// =============================================================================
// Lesson 15 — Instruction Encoding & the `field` keyword
//
//   The single most common real-world TableGen pattern: build a fixed-width
//   instruction *encoding word* by assigning sub-ranges of a `bits<N>` field
//   from other fields. This is how every LLVM target describes its machine
//   instruction format, and what backends like `--gen-emitter` /
//   `--gen-disassembler` consume.
//
//   The `field` keyword marks a member as part of the record's "interface"
//   that a backend reads out. In modern TableGen it is essentially optional
//   (`bits<32> Inst;` works too), but you will see it everywhere in LLVM
//   target `.td` files, traditionally documenting "a backend reads this".
// =============================================================================

class Inst<bits<6> opcode> {
  field bits<32> Inst;        // the 32-bit machine encoding word

  // Opcode always lives in the top 6 bits; the rest is filled in by subclasses.
  let Inst{31-26} = opcode;
  // Bits not yet assigned remain `?` (unset) — that is how a *class* can
  // describe a format whose operand bits are only filled in per instruction.
}

// R-type: opcode | rs | rt | rd | shamt | funct   (classic MIPS-like layout)
class RType<bits<6> opcode, bits<6> funct> : Inst<opcode> {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  bits<5> shamt = 0;

  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6}  = shamt;
  let Inst{5-0}   = funct;
}

// I-type: opcode | rs | rt | imm16
class IType<bits<6> opcode> : Inst<opcode> {
  bits<5>  rs;
  bits<5>  rt;
  bits<16> imm;

  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-0}  = imm;
}

// Concrete instructions fill in the operand fields, fully resolving `Inst`.
def ADD  : RType<0b000000, 0b100000> { let rd = 1; let rs = 2; let rt = 3; }
def ADDI : IType<0b001000>           { let rs = 2; let rt = 1; let imm = 42; }
