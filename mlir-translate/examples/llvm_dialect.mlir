// Input for the stock export: a module in the LLVM *dialect* (MLIR ops that
// mirror LLVM IR one-to-one). --mlir-to-llvmir turns it into real LLVM IR.
llvm.func @add(%a: i32, %b: i32) -> i32 {
  %0 = llvm.add %a, %b : i32
  llvm.return %0 : i32
}
