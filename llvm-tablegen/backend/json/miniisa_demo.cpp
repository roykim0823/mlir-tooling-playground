// Consumes the header td2cpp.py generates from language lesson 16 (MiniISA).
//
// Built by CMakeLists.txt, or by hand:
//   python3 td2cpp.py --out-dir gen ../../language/examples/16_miniisa.td
//   clang++ -std=c++17 -I gen miniisa_demo.cpp -o miniisa_demo
//
// Every record of 16_miniisa.td is a constexpr struct here, so the data is
// available to C++ with no parsing at run time. That is the point of every
// TableGen backend, whatever it is written in.
#include <cstdio>
#include "16_miniisa.gen.h"

namespace mini = tdgen__16_miniisa;

int main() {
  std::printf("MiniISA summary: %lld regs, %lld callee-saved (%s)\n",
              (long long)mini::Summary.NumRegs,
              (long long)mini::Summary.NumCalleeSaved,
              mini::Summary.CalleeList);

  std::printf("%zu instructions, from %s to %s\n", mini::AllInst.size(),
              mini::AllInst.front(), mini::AllInst.back());

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
