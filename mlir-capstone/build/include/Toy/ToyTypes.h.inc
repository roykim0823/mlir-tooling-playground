/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* TypeDef Declarations                                                       *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

#ifdef GET_TYPEDEF_CLASSES
#undef GET_TYPEDEF_CLASSES


namespace mlir {
class AsmParser;
class AsmPrinter;
} // namespace mlir
namespace toy {
class ArrayType;
namespace detail {
struct ArrayTypeStorage;
} // namespace detail
class ArrayType : public ::mlir::Type::TypeBase<ArrayType, ::mlir::Type, detail::ArrayTypeStorage, ::toy::ContainerTypeInterface::Trait> {
public:
  using Base::Base;
  static constexpr ::llvm::StringLiteral name = "toy.array";
  static constexpr ::llvm::StringLiteral dialectName = "toy";
  static ArrayType get(::mlir::MLIRContext *context, int64_t size, ::mlir::Type elementType);
  static constexpr ::llvm::StringLiteral getMnemonic() {
    return {"array"};
  }

  static ::mlir::Type parse(::mlir::AsmParser &odsParser);
  void print(::mlir::AsmPrinter &odsPrinter) const;
  int64_t getSize() const;
  ::mlir::Type getElementType() const;
  int64_t getNumElements() const;
  ::mlir::Type getContainedType() const;
};
} // namespace toy
MLIR_DECLARE_EXPLICIT_TYPE_ID(::toy::ArrayType)

#endif  // GET_TYPEDEF_CLASSES

