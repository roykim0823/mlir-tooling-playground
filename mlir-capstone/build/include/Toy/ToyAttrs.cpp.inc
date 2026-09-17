/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* AttrDef Definitions                                                        *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

#ifdef GET_ATTRDEF_LIST
#undef GET_ATTRDEF_LIST

::toy::ShapeAttr

#endif  // GET_ATTRDEF_LIST

#ifdef GET_ATTRDEF_CLASSES
#undef GET_ATTRDEF_CLASSES

static ::mlir::OptionalParseResult generatedAttributeParser(::mlir::AsmParser &parser, ::llvm::StringRef *mnemonic, ::mlir::Type type, ::mlir::Attribute &value) {
  return ::mlir::AsmParser::KeywordSwitch<::mlir::OptionalParseResult>(parser)
    .Case(::toy::ShapeAttr::getMnemonic(), [&](llvm::StringRef, llvm::SMLoc) {
      value = ::toy::ShapeAttr::parse(parser, type);
      return ::mlir::success(!!value);
    })
    .Default([&](llvm::StringRef keyword, llvm::SMLoc) {
      *mnemonic = keyword;
      return std::nullopt;
    });
}

static ::llvm::LogicalResult generatedAttributePrinter(::mlir::Attribute def, ::mlir::AsmPrinter &printer) {
  return ::llvm::TypeSwitch<::mlir::Attribute, ::llvm::LogicalResult>(def)    .Case<::toy::ShapeAttr>([&](auto t) {
      printer << ::toy::ShapeAttr::getMnemonic();
t.print(printer);
      return ::mlir::success();
    })
    .Default([](auto) { return ::mlir::failure(); });
}

namespace toy {
namespace detail {
struct ShapeAttrStorage : public ::mlir::AttributeStorage {
  using KeyTy = std::tuple<int64_t, int64_t>;
  ShapeAttrStorage(int64_t rows, int64_t cols) : rows(std::move(rows)), cols(std::move(cols)) {}

  KeyTy getAsKey() const {
    return KeyTy(rows, cols);
  }

  bool operator==(const KeyTy &tblgenKey) const {
    return (rows == std::get<0>(tblgenKey)) && (cols == std::get<1>(tblgenKey));
  }

  static ::llvm::hash_code hashKey(const KeyTy &tblgenKey) {
    return ::llvm::hash_combine(std::get<0>(tblgenKey), std::get<1>(tblgenKey));
  }

  static ShapeAttrStorage *construct(::mlir::AttributeStorageAllocator &allocator, KeyTy &&tblgenKey) {
    auto rows = std::move(std::get<0>(tblgenKey));
    auto cols = std::move(std::get<1>(tblgenKey));
    return new (allocator.allocate<ShapeAttrStorage>()) ShapeAttrStorage(std::move(rows), std::move(cols));
  }

  int64_t rows;
  int64_t cols;
};
} // namespace detail
ShapeAttr ShapeAttr::get(::mlir::MLIRContext *context, int64_t rows, int64_t cols) {
  return Base::get(context, std::move(rows), std::move(cols));
}

::mlir::Attribute ShapeAttr::parse(::mlir::AsmParser &odsParser, ::mlir::Type odsType) {
  ::mlir::Builder odsBuilder(odsParser.getContext());
  ::llvm::SMLoc odsLoc = odsParser.getCurrentLocation();
  (void) odsLoc;
  ::mlir::FailureOr<int64_t> _result_rows;
  ::mlir::FailureOr<int64_t> _result_cols;
  // Parse literal '<'
  if (odsParser.parseLess()) return {};

  // Parse variable 'rows'
  _result_rows = ::mlir::FieldParser<int64_t>::parse(odsParser);
  if (::mlir::failed(_result_rows)) {
    odsParser.emitError(odsParser.getCurrentLocation(), "failed to parse Toy_ShapeAttr parameter 'rows' which is to be a `int64_t`");
    return {};
  }
  // Parse literal 'x'
  if (odsParser.parseKeyword("x")) return {};

  // Parse variable 'cols'
  _result_cols = ::mlir::FieldParser<int64_t>::parse(odsParser);
  if (::mlir::failed(_result_cols)) {
    odsParser.emitError(odsParser.getCurrentLocation(), "failed to parse Toy_ShapeAttr parameter 'cols' which is to be a `int64_t`");
    return {};
  }
  // Parse literal '>'
  if (odsParser.parseGreater()) return {};
  assert(::mlir::succeeded(_result_rows));
  assert(::mlir::succeeded(_result_cols));
  return ShapeAttr::get(odsParser.getContext(),
      int64_t((*_result_rows)),
      int64_t((*_result_cols)));
}

void ShapeAttr::print(::mlir::AsmPrinter &odsPrinter) const {
  ::mlir::Builder odsBuilder(getContext());
  odsPrinter << "<";
  odsPrinter.printStrippedAttrOrType(getRows());
  odsPrinter << ' ' << "x";
  odsPrinter << ' ';
  odsPrinter.printStrippedAttrOrType(getCols());
  odsPrinter << ">";
}

int64_t ShapeAttr::getRows() const {
  return getImpl()->rows;
}

int64_t ShapeAttr::getCols() const {
  return getImpl()->cols;
}

} // namespace toy
MLIR_DEFINE_EXPLICIT_TYPE_ID(::toy::ShapeAttr)
namespace toy {

/// Parse an attribute registered to this dialect.
::mlir::Attribute ToyDialect::parseAttribute(::mlir::DialectAsmParser &parser,
                                      ::mlir::Type type) const {
  ::llvm::SMLoc typeLoc = parser.getCurrentLocation();
  ::llvm::StringRef attrTag;
  {
    ::mlir::Attribute attr;
    auto parseResult = generatedAttributeParser(parser, &attrTag, type, attr);
    if (parseResult.has_value())
      return attr;
  }
  
  parser.emitError(typeLoc) << "unknown attribute `"
      << attrTag << "` in dialect `" << getNamespace() << "`";
  return {};
}
/// Print an attribute registered to this dialect.
void ToyDialect::printAttribute(::mlir::Attribute attr,
                         ::mlir::DialectAsmPrinter &printer) const {
  if (::mlir::succeeded(generatedAttributePrinter(attr, printer)))
    return;
  
}
} // namespace toy

#endif  // GET_ATTRDEF_CLASSES

