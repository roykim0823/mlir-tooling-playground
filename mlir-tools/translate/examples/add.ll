; Input for the stock import: LLVM IR. --import-llvm turns it into the LLVM
; dialect (the reverse of llvm_dialect.mlir).
define i32 @add(i32 %a, i32 %b) {
entry:
  %sum = add i32 %a, %b
  ret i32 %sum
}
