// Input for the printing-options section: a dense constant large enough to be
// elided with --mlir-elide-elementsattrs-if-larger, and two ops sharing a
// result so --mlir-print-value-users has something to annotate.
func.func @tensors() -> (tensor<8xi32>, tensor<8xi32>) {
  %c = arith.constant dense<[1, 2, 3, 4, 5, 6, 7, 8]> : tensor<8xi32>
  %0 = arith.addi %c, %c : tensor<8xi32>
  %1 = arith.muli %c, %0 : tensor<8xi32>
  return %0, %1 : tensor<8xi32>, tensor<8xi32>
}
