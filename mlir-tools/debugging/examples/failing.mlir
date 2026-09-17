// Input for the "when a pass fails" sections. -reconcile-unrealized-casts
// removes cast pairs that cancel out; a cast whose result is used by a real
// op cannot be removed, so the pass reports an error and FAILS on this file.
func.func @leftover_cast(%arg0: i64) -> i32 {
  %0 = builtin.unrealized_conversion_cast %arg0 : i64 to i32
  return %0 : i32
}
