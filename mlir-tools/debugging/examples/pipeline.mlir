// Input for the "watch the IR change" sections. Two passes have work to do:
//   -cse           merges the duplicate constants, mulf and addf
//   -canonicalize  folds  x * 1.0  ->  x   (x + 0.0 is NOT folded: -0.0 + 0.0 != -0.0)
// Locations are explicit so --mlir-print-debuginfo has something to show.
func.func @compute(%arg0: f64) -> f64 {
  %c1 = arith.constant 1.0 : f64 loc("pipeline.mlir":7:9)
  %c1_dup = arith.constant 1.0 : f64 loc("pipeline.mlir":8:9)
  %c0 = arith.constant 0.0 : f64 loc("pipeline.mlir":9:9)
  %0 = arith.mulf %arg0, %c1 : f64 loc("pipeline.mlir":10:8)
  %1 = arith.mulf %arg0, %c1_dup : f64 loc("pipeline.mlir":11:8)
  %2 = arith.addf %0, %1 : f64 loc("pipeline.mlir":12:8)
  %3 = arith.addf %0, %1 : f64 loc("pipeline.mlir":13:8)
  %4 = arith.addf %2, %c0 : f64 loc("pipeline.mlir":14:8)
  %5 = arith.addf %4, %3 : f64 loc("pipeline.mlir":15:8)
  return %5 : f64 loc("pipeline.mlir":16:3)
} loc("pipeline.mlir":6:1)
