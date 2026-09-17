static ::llvm::LogicalResult F64AttrPDLFn(::mlir::PatternRewriter &rewriter, ::mlir::Attribute self) {
  return ::mlir::success(((::llvm::isa<::mlir::FloatAttr>(self))) && ((::llvm::cast<::mlir::FloatAttr>(self).getType().isF64())));
}

static ::mlir::Attribute FoldMulF64PDLFn(::mlir::PatternRewriter &rewriter, ::mlir::Attribute a, ::mlir::Attribute b) {
  double lhs = llvm::cast<::mlir::FloatAttr>(a).getValueAsDouble();
  double rhs = llvm::cast<::mlir::FloatAttr>(b).getValueAsDouble();
  return rewriter.getF64FloatAttr(lhs * rhs);
}

namespace {

struct FoldMulConstants : ::mlir::PDLPatternModule {
  template <typename... ConfigsT>
  FoldMulConstants(::mlir::MLIRContext *context, ConfigsT &&...configs)
    : ::mlir::PDLPatternModule(::mlir::parseSourceString<::mlir::ModuleOp>(
R"mlir(pdl.pattern @FoldMulConstants : benefit(0) {
  %0 = operands loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":27:26)
  %1 = attribute loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":27:52)
  apply_native_constraint "F64Attr"(%1 : !pdl.attribute) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":27:55)
  %2 = types loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":27:26)
  %3 = operation "toy.constant"(%0 : !pdl.range<value>)  {"value" = %1} -> (%2 : !pdl.range<type>) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":27:26)
  %4 = result 0 of %3 loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":27:26)
  %5 = operands loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":28:26)
  %6 = attribute loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":28:52)
  apply_native_constraint "F64Attr"(%6 : !pdl.attribute) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":28:55)
  %7 = types loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":28:26)
  %8 = operation "toy.constant"(%5 : !pdl.range<value>)  {"value" = %6} -> (%7 : !pdl.range<type>) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":28:26)
  %9 = result 0 of %8 loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":28:26)
  %10 = types loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":27:14)
  %11 = operation "toy.mul"(%4, %9 : !pdl.value, !pdl.value)  -> (%10 : !pdl.range<type>) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":27:14)
  rewrite %11 {
    %12 = apply_native_rewrite "FoldMulF64"(%1, %6 : !pdl.attribute, !pdl.attribute) : !pdl.attribute loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":31:47)
    %13 = operation "toy.constant"  {"value" = %12} loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":31:21)
    replace %11 with %13 loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":31:3)
  } loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":31:3)
} loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":26:1)
    )mlir", context), std::forward<ConfigsT>(configs)...) {
    registerConstraintFunction("F64Attr", F64AttrPDLFn);
    registerRewriteFunction("FoldMulF64", FoldMulF64PDLFn);
  }
};


struct MulByOneRight : ::mlir::PDLPatternModule {
  template <typename... ConfigsT>
  MulByOneRight(::mlir::MLIRContext *context, ConfigsT &&...configs)
    : ::mlir::PDLPatternModule(::mlir::parseSourceString<::mlir::ModuleOp>(
R"mlir(pdl.pattern @MulByOneRight : benefit(0) {
  %0 = operand loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":36:26)
  %1 = operands loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":36:36)
  %2 = attribute = 1.000000e+00 : f64 loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":36:62)
  %3 = types loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":36:36)
  %4 = operation "toy.constant"(%1 : !pdl.range<value>)  {"value" = %2} -> (%3 : !pdl.range<type>) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":36:36)
  %5 = result 0 of %4 loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":36:36)
  %6 = types loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":36:14)
  %7 = operation "toy.mul"(%0, %5 : !pdl.value, !pdl.value)  -> (%6 : !pdl.range<type>) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":36:14)
  rewrite %7 {
    replace %7 with(%0 : !pdl.value) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":37:3)
  } loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":37:3)
} loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":35:1)
    )mlir", context), std::forward<ConfigsT>(configs)...) {
  }
};


struct MulByOneLeft : ::mlir::PDLPatternModule {
  template <typename... ConfigsT>
  MulByOneLeft(::mlir::MLIRContext *context, ConfigsT &&...configs)
    : ::mlir::PDLPatternModule(::mlir::parseSourceString<::mlir::ModuleOp>(
R"mlir(pdl.pattern @MulByOneLeft : benefit(0) {
  %0 = operands loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":40:26)
  %1 = attribute = 1.000000e+00 : f64 loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":40:52)
  %2 = types loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":40:26)
  %3 = operation "toy.constant"(%0 : !pdl.range<value>)  {"value" = %1} -> (%2 : !pdl.range<type>) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":40:26)
  %4 = result 0 of %3 loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":40:26)
  %5 = operand loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":40:72)
  %6 = types loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":40:14)
  %7 = operation "toy.mul"(%4, %5 : !pdl.value, !pdl.value)  -> (%6 : !pdl.range<type>) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":40:14)
  rewrite %7 {
    replace %7 with(%5 : !pdl.value) loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":41:3)
  } loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":41:3)
} loc("/Users/roy/study/mlir-tooling-playground/mlir-capstone/include/Toy/ToyPatterns.pdll":39:1)
    )mlir", context), std::forward<ConfigsT>(configs)...) {
  }
};

} // end namespace

template <typename... ConfigsT>
static void LLVM_ATTRIBUTE_UNUSED populateGeneratedPDLLPatterns(::mlir::RewritePatternSet &patterns, ConfigsT &&...configs) {
  patterns.add<FoldMulConstants>(patterns.getContext(), configs...);
  patterns.add<MulByOneRight>(patterns.getContext(), configs...);
  patterns.add<MulByOneLeft>(patterns.getContext(), configs...);
}
