/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Interface Declarations                                                     *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

namespace toy {
class BinaryArithOpInterface;
namespace detail {
struct BinaryArithOpInterfaceInterfaceTraits {
  struct Concept {
    /// The methods defined by the interface.
    double (*evaluate)(const Concept *impl, ::mlir::Operation *, double, double);
    ::llvm::StringRef (*getSymbol)(const Concept *impl, ::mlir::Operation *);
    bool (*isCommutative)(const Concept *impl, ::mlir::Operation *);
    ::mlir::Value (*getLhsValue)(const Concept *impl, ::mlir::Operation *);
    ::mlir::Value (*getRhsValue)(const Concept *impl, ::mlir::Operation *);
  };
  template<typename ConcreteOp>
  class Model : public Concept {
  public:
    using Interface = ::toy::BinaryArithOpInterface;
    Model() : Concept{evaluate, getSymbol, isCommutative, getLhsValue, getRhsValue} {}

    static inline double evaluate(const Concept *impl, ::mlir::Operation *tablegen_opaque_val, double lhs, double rhs);
    static inline ::llvm::StringRef getSymbol(const Concept *impl, ::mlir::Operation *tablegen_opaque_val);
    static inline bool isCommutative(const Concept *impl, ::mlir::Operation *tablegen_opaque_val);
    static inline ::mlir::Value getLhsValue(const Concept *impl, ::mlir::Operation *tablegen_opaque_val);
    static inline ::mlir::Value getRhsValue(const Concept *impl, ::mlir::Operation *tablegen_opaque_val);
  };
  template<typename ConcreteOp>
  class FallbackModel : public Concept {
  public:
    using Interface = ::toy::BinaryArithOpInterface;
    FallbackModel() : Concept{evaluate, getSymbol, isCommutative, getLhsValue, getRhsValue} {}

    static inline double evaluate(const Concept *impl, ::mlir::Operation *tablegen_opaque_val, double lhs, double rhs);
    static inline ::llvm::StringRef getSymbol(const Concept *impl, ::mlir::Operation *tablegen_opaque_val);
    static inline bool isCommutative(const Concept *impl, ::mlir::Operation *tablegen_opaque_val);
    static inline ::mlir::Value getLhsValue(const Concept *impl, ::mlir::Operation *tablegen_opaque_val);
    static inline ::mlir::Value getRhsValue(const Concept *impl, ::mlir::Operation *tablegen_opaque_val);
  };
  template<typename ConcreteModel, typename ConcreteOp>
  class ExternalModel : public FallbackModel<ConcreteModel> {
  public:
    using ConcreteEntity = ConcreteOp;
    bool isCommutative(::mlir::Operation *tablegen_opaque_val) const;
  };
};
template <typename ConcreteOp>
struct BinaryArithOpInterfaceTrait;

} // namespace detail
class BinaryArithOpInterface : public ::mlir::OpInterface<BinaryArithOpInterface, detail::BinaryArithOpInterfaceInterfaceTraits> {
public:
  using ::mlir::OpInterface<BinaryArithOpInterface, detail::BinaryArithOpInterfaceInterfaceTraits>::OpInterface;
  template <typename ConcreteOp>
  struct Trait : public detail::BinaryArithOpInterfaceTrait<ConcreteOp> {};
  /// Evaluate the op on two constant operands.
  double evaluate(double lhs, double rhs);
  /// The operator symbol, for diagnostics.
  ::llvm::StringRef getSymbol();
  /// Whether the operands may be swapped.
  bool isCommutative();
  /// The left operand.
  ::mlir::Value getLhsValue();
  /// The right operand.
  ::mlir::Value getRhsValue();
};
namespace detail {
  template <typename ConcreteOp>
  struct BinaryArithOpInterfaceTrait : public ::mlir::OpInterface<BinaryArithOpInterface, detail::BinaryArithOpInterfaceInterfaceTraits>::Trait<ConcreteOp> {
    /// Whether the operands may be swapped.
    bool isCommutative() {
      return false;
    }
  };
}// namespace detail
} // namespace toy
namespace toy {
template<typename ConcreteOp>
double detail::BinaryArithOpInterfaceInterfaceTraits::Model<ConcreteOp>::evaluate(const Concept *impl, ::mlir::Operation *tablegen_opaque_val, double lhs, double rhs) {
  return (llvm::cast<ConcreteOp>(tablegen_opaque_val)).evaluate(lhs, rhs);
}
template<typename ConcreteOp>
::llvm::StringRef detail::BinaryArithOpInterfaceInterfaceTraits::Model<ConcreteOp>::getSymbol(const Concept *impl, ::mlir::Operation *tablegen_opaque_val) {
  return (llvm::cast<ConcreteOp>(tablegen_opaque_val)).getSymbol();
}
template<typename ConcreteOp>
bool detail::BinaryArithOpInterfaceInterfaceTraits::Model<ConcreteOp>::isCommutative(const Concept *impl, ::mlir::Operation *tablegen_opaque_val) {
  return (llvm::cast<ConcreteOp>(tablegen_opaque_val)).isCommutative();
}
template<typename ConcreteOp>
::mlir::Value detail::BinaryArithOpInterfaceInterfaceTraits::Model<ConcreteOp>::getLhsValue(const Concept *impl, ::mlir::Operation *tablegen_opaque_val) {
  return (llvm::cast<ConcreteOp>(tablegen_opaque_val))->getOperand(0);
}
template<typename ConcreteOp>
::mlir::Value detail::BinaryArithOpInterfaceInterfaceTraits::Model<ConcreteOp>::getRhsValue(const Concept *impl, ::mlir::Operation *tablegen_opaque_val) {
  return (llvm::cast<ConcreteOp>(tablegen_opaque_val))->getOperand(1);
}
template<typename ConcreteOp>
double detail::BinaryArithOpInterfaceInterfaceTraits::FallbackModel<ConcreteOp>::evaluate(const Concept *impl, ::mlir::Operation *tablegen_opaque_val, double lhs, double rhs) {
  return static_cast<const ConcreteOp *>(impl)->evaluate(tablegen_opaque_val, lhs, rhs);
}
template<typename ConcreteOp>
::llvm::StringRef detail::BinaryArithOpInterfaceInterfaceTraits::FallbackModel<ConcreteOp>::getSymbol(const Concept *impl, ::mlir::Operation *tablegen_opaque_val) {
  return static_cast<const ConcreteOp *>(impl)->getSymbol(tablegen_opaque_val);
}
template<typename ConcreteOp>
bool detail::BinaryArithOpInterfaceInterfaceTraits::FallbackModel<ConcreteOp>::isCommutative(const Concept *impl, ::mlir::Operation *tablegen_opaque_val) {
  return static_cast<const ConcreteOp *>(impl)->isCommutative(tablegen_opaque_val);
}
template<typename ConcreteOp>
::mlir::Value detail::BinaryArithOpInterfaceInterfaceTraits::FallbackModel<ConcreteOp>::getLhsValue(const Concept *impl, ::mlir::Operation *tablegen_opaque_val) {
  return static_cast<const ConcreteOp *>(impl)->getLhsValue(tablegen_opaque_val);
}
template<typename ConcreteOp>
::mlir::Value detail::BinaryArithOpInterfaceInterfaceTraits::FallbackModel<ConcreteOp>::getRhsValue(const Concept *impl, ::mlir::Operation *tablegen_opaque_val) {
  return static_cast<const ConcreteOp *>(impl)->getRhsValue(tablegen_opaque_val);
}
template<typename ConcreteModel, typename ConcreteOp>
bool detail::BinaryArithOpInterfaceInterfaceTraits::ExternalModel<ConcreteModel, ConcreteOp>::isCommutative(::mlir::Operation *tablegen_opaque_val) const {
return false;
}
} // namespace toy
