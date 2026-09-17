/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* AttrDef Declarations                                                       *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

#ifdef GET_ATTRDEF_CLASSES
#undef GET_ATTRDEF_CLASSES


namespace mlir {
class AsmParser;
class AsmPrinter;
} // namespace mlir
namespace toy {
class ShapeAttr;
namespace detail {
struct ShapeAttrStorage;
} // namespace detail
class ShapeAttr : public ::mlir::Attribute::AttrBase<ShapeAttr, ::mlir::Attribute, detail::ShapeAttrStorage> {
public:
  using Base::Base;
  static constexpr ::llvm::StringLiteral name = "toy.shape";
  static constexpr ::llvm::StringLiteral dialectName = "toy";
  static ShapeAttr get(::mlir::MLIRContext *context, int64_t rows, int64_t cols);
  static constexpr ::llvm::StringLiteral getMnemonic() {
    return {"shape"};
  }

  static ::mlir::Attribute parse(::mlir::AsmParser &odsParser, ::mlir::Type odsType);
  void print(::mlir::AsmPrinter &odsPrinter) const;
  int64_t getRows() const;
  int64_t getCols() const;
};
} // namespace toy
MLIR_DECLARE_EXPLICIT_TYPE_ID(::toy::ShapeAttr)

#endif  // GET_ATTRDEF_CLASSES

