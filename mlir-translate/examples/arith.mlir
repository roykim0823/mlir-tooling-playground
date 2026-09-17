// Not exportable as-is: arith.addi is not an LLVM-dialect op, and the
// --mlir-to-llvmir translation registers only the dialects it can consume, so
// the failure is a PARSE error ("Dialect `arith' not found"), not a lowering
// error. Lower first (mlir-opt -convert-arith-to-llvm -convert-func-to-llvm),
// then translate.
func.func @f(%a: i32) -> i32 {
  %0 = arith.addi %a, %a : i32
  return %0 : i32
}
