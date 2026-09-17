// Input for the "what the generic reducer cannot do" section. Symbol
// references (the call) stop the op-erasing reducer from touching functions;
// -opt-reduction-pass='opt-pass=symbol-dce ...' removes the unused PRIVATE
// one, the used one stays.
func.func private @helper(%x: i32) -> i32 {
  %c1 = arith.constant 1 : i32
  %0 = arith.addi %x, %c1 : i32
  return %0 : i32
}
func.func private @unused_helper(%x: i32) -> i32 {
  return %x : i32
}
func.func @suspect(%a: i32, %b: i32) -> i32 {
  %c2 = arith.constant 2 : i32
  %0 = arith.divui %a, %c2 : i32
  %1 = call @helper(%0) : (i32) -> i32
  return %1 : i32
}
