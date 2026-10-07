// RUN: llvm-tblgen %s | FileCheck %s
//
// Lesson 11 — `foreach` and `if`
// ProgRef: "foreach", "if"
//
// Both statements select or repeat *statements* (defs, defms, lets, nested
// loops) at the top level or inside a multiclass. For values inside a record,
// use the bang operators !foreach and !if (lesson 4).

class Reg<int n> {
  int Num   = n;
  bit IsArg = 0;
}

// The iteration value can be a range, a range list in braces, or any list.
foreach i = 0...3 in
  def R # i : Reg<i>;                    // R0..R3

foreach i = {8-9, 12} in                 // a range list
  def H # i : Reg<i>;                    // H8, H9, H12

foreach name = ["sp", "lr", "pc"] in
  def !toupper(name) : Reg<0>;           // SP, LR, PC

// A braced body repeats several statements; a defvar in it lives for one
// iteration only. Loops nest.
foreach i = !range(2) in {
  defvar sq = !mul(i, i);
  def Sq # i : Reg<sq>;
  foreach j = [0, 1] in
    def P # i # _ # j : Reg<!add(!mul(i, 2), j)>;
}

// if/then/else picks statements. Here it appears inside a foreach body.
foreach i = 0...3 in {
  if !lt(i, 2) then
    def V # i : Reg<i> { let IsArg = 1; }
  else
    def V # i : Reg<i>;
}

// A dangling else binds to the nearest if.
defvar a = 1;
defvar b = 0;
if a then
  if b then
    def Both;
  else
    def OnlyA;

// llvm-tblgen 20 does not accept `if` inside a class or record body, although
// ProgRef says it does; compute such fields with !if instead.

// ---- Try it yourself: answers -----------------------------------------------
// 32 registers X0..X31 where the first 8 have IsArg = 1.
foreach i = 0...31 in {
  if !lt(i, 8) then
    def X # i : Reg<i> { let IsArg = 1; }
  else
    def X # i : Reg<i>;
}

// ---- Expected output --------------------------------------------------------
// CHECK-NOT: def Both
// CHECK-LABEL: def H12 { // Reg
// CHECK-NEXT:  int Num = 12;
// CHECK-NEXT:  bit IsArg = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def LR { // Reg
// CHECK-NEXT:  int Num = 0;
// CHECK-NEXT:  bit IsArg = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def OnlyA {
// CHECK-NEXT:  }
// CHECK-LABEL: def P1_1 { // Reg
// CHECK-NEXT:  int Num = 3;
// CHECK-NEXT:  bit IsArg = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def Sq1 { // Reg
// CHECK-NEXT:  int Num = 1;
// CHECK-NEXT:  bit IsArg = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def V1 { // Reg
// CHECK-NEXT:  int Num = 1;
// CHECK-NEXT:  bit IsArg = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def V2 { // Reg
// CHECK-NEXT:  int Num = 2;
// CHECK-NEXT:  bit IsArg = 0;
// CHECK-NEXT:  }
// CHECK-LABEL: def X7 { // Reg
// CHECK-NEXT:  int Num = 7;
// CHECK-NEXT:  bit IsArg = 1;
// CHECK-NEXT:  }
// CHECK-LABEL: def X8 { // Reg
// CHECK-NEXT:  int Num = 8;
// CHECK-NEXT:  bit IsArg = 0;
// CHECK-NEXT:  }
