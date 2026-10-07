// RUN: llvm-tblgen %s | FileCheck %s
// RUN: llvm-tblgen --dump-json %s | jq -c '.ADD["!fields"]' | FileCheck --check-prefix=JSON %s
// REQUIRES: jq
//
// Lesson 17 — Capstone: instruction encoding and `field`
// ProgRef: "Identifiers" (the `field` keyword), "Suffixed values"
//
// The most common pattern in real target descriptions: a fixed-width encoding
// word, bits<32> Inst, assembled by assigning bit ranges from other fields.
// In a class, Inst holds references such as rs{4} to operand fields that are
// still `?`; a concrete instruction sets the operands and Inst resolves to
// plain bits (ADD below is 0x00430820). --gen-emitter and --gen-disassembler read this field
// (../../backend/stock/03_mini_target.td runs them).
//
// `field` is a reserved word that ProgRef calls deprecated except for this
// use: it marks Inst as the encoding rather than an operand. With llvm-tblgen
// 20 the --gen-emitter output is the same with or without it; what it does
// change is --dump-json, which lists `field` members under "!fields".

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

// ---- Expected output --------------------------------------------------------
// CHECK:      class RType<
// CHECK-NEXT:   field bits<32> Inst = { RType:opcode{5}, {{.*}}, rs{4}, {{.*}}, RType:funct{0} };
// CHECK-NEXT:   bits<5> rd = { ?, ?, ?, ?, ? };
// CHECK-LABEL: def ADD { // Inst RType
// CHECK-NEXT:  field bits<32> Inst = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 };
// CHECK-NEXT:  bits<5> rd = { 0, 0, 0, 0, 1 };
// CHECK-NEXT:  bits<5> rs = { 0, 0, 0, 1, 0 };
// CHECK-NEXT:  bits<5> rt = { 0, 0, 0, 1, 1 };
// CHECK-NEXT:  bits<5> shamt = { 0, 0, 0, 0, 0 };
// CHECK-NEXT:  }
// CHECK-LABEL: def ADDI { // Inst IType
// CHECK-NEXT:  field bits<32> Inst = { 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0 };
// CHECK-NEXT:  bits<5> rs = { 0, 0, 0, 1, 0 };
// CHECK-NEXT:  bits<5> rt = { 0, 0, 0, 0, 1 };
// CHECK-NEXT:  bits<16> imm = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0 };
// CHECK-NEXT:  }
// JSON: ["Inst"]
