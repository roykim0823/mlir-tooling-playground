; Input for the llvm-reduce section. Same story as crash.mlir, in LLVM IR:
; "instcombine does something wrong around udiv"; shrink the module while
; interesting-ll.sh still finds a udiv in instcombine's output.
define i32 @helper(i32 %x) {
entry:
  %r = add i32 %x, 1
  ret i32 %r
}
define i32 @suspect(i32 %a, i32 %b, i32 %c) {
entry:
  %dead = mul i32 %a, 7
  %sum = add i32 %a, %b
  %diff = sub i32 %sum, %c
  %q = udiv i32 %diff, 3
  %q0 = add i32 %q, 0
  %h = call i32 @helper(i32 %q0)
  ret i32 %h
}
define float @unrelated(float %x) {
entry:
  %sq = fmul float %x, %x
  ret float %sq
}
