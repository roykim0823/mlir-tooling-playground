// Demonstrates consuming a header produced by td2cpp.py (Lesson 14 capstone).
//
// Built by 4-codegen/CMakeLists.txt, or manually from the tablegen/ dir:
//   ./gen-all.sh                                   # produces generated/14_miniisa.gen.h
//   clang++ -std=c++17 -I generated 4-codegen/miniisa_demo.cpp -o miniisa_demo
//
// The generated MiniISA header gives us constexpr structs for every record in
// 14_miniisa.td, so the instruction table is available to C++ with zero runtime
// parsing — exactly how real LLVM backends consume TableGen output.
#include <cstdio>
#include "14_miniisa.gen.h"

namespace mini = tdgen__14_miniisa;

int main() {
  std::printf("MiniISA summary: %lld regs, %lld callee-saved (%s)\n",
              (long long)mini::Summary.NumRegs,
              (long long)mini::Summary.NumCalleeSaved,
              mini::Summary.CalleeList);

  std::printf("CALL  mnemonic=%-4s isCall=%lld isBranch=%lld\n",
              mini::CALL.Mnemonic,
              (long long)mini::CALL.IsCall,
              (long long)mini::CALL.IsBranch);

  std::printf("LOAD  mnemonic=%-4s hasSideFx=%lld\n",
              mini::LOAD.Mnemonic,
              (long long)mini::LOAD.HasSideFx);

  std::printf("R2    asm=%s calleeSaved=%lld encoding={%lld,%lld}\n",
              mini::R2.AsmName,
              (long long)mini::R2.CalleeSaved,
              (long long)mini::R2.Encoding[0],
              (long long)mini::R2.Encoding[1]);
  return 0;
}
