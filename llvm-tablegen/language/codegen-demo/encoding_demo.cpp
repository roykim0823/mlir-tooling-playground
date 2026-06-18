// Demonstrates consuming the Lesson 15 encoding header (td2cpp.py output).
//
// 15_encoding.td resolves each instruction's `Inst` field into a 32-bit vector,
// which td2cpp.py emits as a `std::array<int64_t, 32>` (bit 0 = least
// significant). Here we pack those bits back into a uint32_t machine word —
// the value a real `--gen-emitter` backend would emit.
//
// Built by 4-codegen/CMakeLists.txt, or manually from the tablegen/ dir:
//   ./gen-all.sh
//   clang++ -std=c++17 -I generated 4-codegen/encoding_demo.cpp -o encoding_demo
#include <array>
#include <cstdint>
#include <cstdio>
#include "15_encoding.gen.h"

namespace enc = tdgen__15_encoding;

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
