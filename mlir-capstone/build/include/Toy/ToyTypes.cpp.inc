/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* TypeDef Definitions                                                        *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

#ifdef GET_TYPEDEF_LIST
#undef GET_TYPEDEF_LIST

::toy::ArrayType

#endif  // GET_TYPEDEF_LIST

#ifdef GET_TYPEDEF_CLASSES
#undef GET_TYPEDEF_CLASSES

static ::mlir::OptionalParseResult generatedTypeParser(::mlir::AsmParser &parser, ::llvm::StringRef *mnemonic, ::mlir::Type &value) {
  return ::mlir::AsmParser::KeywordSwitch<::mlir::OptionalParseResult>(parser)
    .Case(::toy::ArrayType::getMnemonic(), [&](llvm::StringRef, llvm::SMLoc) {
      value = ::toy::ArrayType::parse(parser);
      return ::mlir::success(!!value);
    })
    .Default([&](llvm::StringRef keyword, llvm::SMLoc) {
      *mnemonic = keyword;
      return std::nullopt;
    });
}

static ::llvm::LogicalResult generatedTypePrinter(::mlir::Type def, ::mlir::AsmPrinter &printer) {
  return ::llvm::TypeSwitch<::mlir::Type, ::llvm::LogicalResult>(def)    .Case<::toy::ArrayType>([&](auto t) {
      printer << ::toy::ArrayType::getMnemonic();
t.print(printer);
      return ::mlir::success();
    })
    .Default([](auto) { return ::mlir::failure(); });
}

namespace toy {
namespace detail {
struct ArrayTypeStorage : public ::mlir::TypeStorage {
  using KeyTy = std::tuple<int64_t, ::mlir::Type>;
  ArrayTypeStorage(int64_t size, ::mlir::Type elementType) : size(std::move(size)), elementType(std::move(elementType)) {}

  KeyTy getAsKey() const {
    return KeyTy(size, elementType);
  }

  bool operator==(const KeyTy &tblgenKey) const {
    return (size == std::get<0>(tblgenKey)) && (elementType == std::get<1>(tblgenKey));
  }

  static ::llvm::hash_code hashKey(const KeyTy &tblgenKey) {
    return ::llvm::hash_combine(std::get<0>(tblgenKey), std::get<1>(tblgenKey));
  }

  static ArrayTypeStorage *construct(::mlir::TypeStorageAllocator &allocator, KeyTy &&tblgenKey) {
    auto size = std::move(std::get<0>(tblgenKey));
    auto elementType = std::move(std::get<1>(tblgenKey));
    return new (allocator.allocate<ArrayTypeStorage>()) ArrayTypeStorage(std::move(size), std::move(elementType));
  }

  int64_t size;
  ::mlir::Type elementType;
};
} // namespace detail
ArrayType ArrayType::get(::mlir::MLIRContext *context, int64_t size, ::mlir::Type elementType) {
  return Base::get(context, std::move(size), std::move(elementType));
}

::mlir::Type ArrayType::parse(::mlir::AsmParser &odsParser) {
  ::mlir::Builder odsBuilder(odsParser.getContext());
  ::llvm::SMLoc odsLoc = odsParser.getCurrentLocation();
  (void) odsLoc;
  ::mlir::FailureOr<int64_t> _result_size;
  ::mlir::FailureOr<::mlir::Type> _result_elementType;
  // Parse literal '<'
  if (odsParser.parseLess()) return {};

  // Parse variable 'size'
  _result_size = ::mlir::FieldParser<int64_t>::parse(odsParser);
  if (::mlir::failed(_result_size)) {
    odsParser.emitError(odsParser.getCurrentLocation(), "failed to parse Toy_ArrayType parameter 'size' which is to be a `int64_t`");
    return {};
  }
  // Parse literal 'x'
  if (odsParser.parseKeyword("x")) return {};

  // Parse variable 'elementType'
  _result_elementType = ::mlir::FieldParser<::mlir::Type>::parse(odsParser);
  if (::mlir::failed(_result_elementType)) {
    odsParser.emitError(odsParser.getCurrentLocation(), "failed to parse Toy_ArrayType parameter 'elementType' which is to be a `::mlir::Type`");
    return {};
  }
  // Parse literal '>'
  if (odsParser.parseGreater()) return {};
  assert(::mlir::succeeded(_result_size));
  assert(::mlir::succeeded(_result_elementType));
  return ArrayType::get(odsParser.getContext(),
      int64_t((*_result_size)),
      ::mlir::Type((*_result_elementType)));
}

void ArrayType::print(::mlir::AsmPrinter &odsPrinter) const {
  ::mlir::Builder odsBuilder(getContext());
  odsPrinter << "<";
  odsPrinter.printStrippedAttrOrType(getSize());
  odsPrinter << ' ' << "x";
  odsPrinter << ' ';
  odsPrinter.printStrippedAttrOrType(getElementType());
  odsPrinter << ">";
}

int64_t ArrayType::getSize() const {
  return getImpl()->size;
}

::mlir::Type ArrayType::getElementType() const {
  return getImpl()->elementType;
}

} // namespace toy
MLIR_DEFINE_EXPLICIT_TYPE_ID(::toy::ArrayType)
namespace toy {

/// Parse a type registered to this dialect.
::mlir::Type ToyDialect::parseType(::mlir::DialectAsmParser &parser) const {
  ::llvm::SMLoc typeLoc = parser.getCurrentLocation();
  ::llvm::StringRef mnemonic;
  ::mlir::Type genType;
  auto parseResult = generatedTypeParser(parser, &mnemonic, genType);
  if (parseResult.has_value())
    return genType;
  
  parser.emitError(typeLoc) << "unknown  type `"
      << mnemonic << "` in dialect `" << getNamespace() << "`";
  return {};
}
/// Print a type registered to this dialect.
void ToyDialect::printType(::mlir::Type type,
                    ::mlir::DialectAsmPrinter &printer) const {
  if (::mlir::succeeded(generatedTypePrinter(type, printer)))
    return;
  
}
} // namespace toy

#endif  // GET_TYPEDEF_CLASSES

