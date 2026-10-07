// Consumes the header td2cpp.py generates from language lesson 17.
//
// 17_encoding.td resolves each instruction's `Inst` field to 32 bits, which
// --dump-json lists least significant first and td2cpp.py emits as a
// std::array<int64_t, 32>. Packing them back into a uint32_t gives the machine
// word that --gen-emitter would compute (../stock/03_mini_target.td).
//
// Built by CMakeLists.txt, or by hand:
//   python3 td2cpp.py --out-dir gen ../../language/examples/17_encoding.td
//   clang++ -std=c++17 -I gen encoding_demo.cpp -o encoding_demo
#include <array>
#include <cstdint>
#include <cstdio>
#include "17_encoding.gen.h"

namespace enc = tdgen__17_encoding;

template <std::size_t N>
static uint32_t pack(const std::array<int64_t, N> &bits) {
  uint32_t word = 0;
  for (std::size_t i = 0; i < N; ++i)
    word |= uint32_t(bits[i] & 1) << i;
  return word;
}

int main() {
  std::printf("ADD  (R-type) encoding = 0x%08x\n", pack(enc::ADD.Inst));
  std::printf("ADDI (I-type) encoding = 0x%08x\n", pack(enc::ADDI.Inst));
  return 0;
}
