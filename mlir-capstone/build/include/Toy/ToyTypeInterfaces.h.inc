/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Interface Declarations                                                     *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

namespace toy {
class ContainerTypeInterface;
namespace detail {
struct ContainerTypeInterfaceInterfaceTraits {
  struct Concept {
    /// The methods defined by the interface.
    int64_t (*getNumElements)(const Concept *impl, ::mlir::Type );
    ::mlir::Type (*getContainedType)(const Concept *impl, ::mlir::Type );
  };
  template<typename ConcreteType>
  class Model : public Concept {
  public:
    using Interface = ::toy::ContainerTypeInterface;
    Model() : Concept{getNumElements, getContainedType} {}

    static inline int64_t getNumElements(const Concept *impl, ::mlir::Type tablegen_opaque_val);
    static inline ::mlir::Type getContainedType(const Concept *impl, ::mlir::Type tablegen_opaque_val);
  };
  template<typename ConcreteType>
  class FallbackModel : public Concept {
  public:
    using Interface = ::toy::ContainerTypeInterface;
    FallbackModel() : Concept{getNumElements, getContainedType} {}

    static inline int64_t getNumElements(const Concept *impl, ::mlir::Type tablegen_opaque_val);
    static inline ::mlir::Type getContainedType(const Concept *impl, ::mlir::Type tablegen_opaque_val);
  };
  template<typename ConcreteModel, typename ConcreteType>
  class ExternalModel : public FallbackModel<ConcreteModel> {
  public:
    using ConcreteEntity = ConcreteType;
  };
};
template <typename ConcreteType>
struct ContainerTypeInterfaceTrait;

} // namespace detail
class ContainerTypeInterface : public ::mlir::TypeInterface<ContainerTypeInterface, detail::ContainerTypeInterfaceInterfaceTraits> {
public:
  using ::mlir::TypeInterface<ContainerTypeInterface, detail::ContainerTypeInterfaceInterfaceTraits>::TypeInterface;
  template <typename ConcreteType>
  struct Trait : public detail::ContainerTypeInterfaceTrait<ConcreteType> {};
  /// Number of elements.
  int64_t getNumElements() const;
  /// The element type.
  ::mlir::Type getContainedType() const;
};
namespace detail {
  template <typename ConcreteType>
  struct ContainerTypeInterfaceTrait : public ::mlir::TypeInterface<ContainerTypeInterface, detail::ContainerTypeInterfaceInterfaceTraits>::Trait<ConcreteType> {
  };
}// namespace detail
} // namespace toy
namespace toy {
template<typename ConcreteType>
int64_t detail::ContainerTypeInterfaceInterfaceTraits::Model<ConcreteType>::getNumElements(const Concept *impl, ::mlir::Type tablegen_opaque_val) {
  return (::llvm::cast<ConcreteType>(tablegen_opaque_val)).getNumElements();
}
template<typename ConcreteType>
::mlir::Type detail::ContainerTypeInterfaceInterfaceTraits::Model<ConcreteType>::getContainedType(const Concept *impl, ::mlir::Type tablegen_opaque_val) {
  return (::llvm::cast<ConcreteType>(tablegen_opaque_val)).getContainedType();
}
template<typename ConcreteType>
int64_t detail::ContainerTypeInterfaceInterfaceTraits::FallbackModel<ConcreteType>::getNumElements(const Concept *impl, ::mlir::Type tablegen_opaque_val) {
  return static_cast<const ConcreteType *>(impl)->getNumElements(tablegen_opaque_val);
}
template<typename ConcreteType>
::mlir::Type detail::ContainerTypeInterfaceInterfaceTraits::FallbackModel<ConcreteType>::getContainedType(const Concept *impl, ::mlir::Type tablegen_opaque_val) {
  return static_cast<const ConcreteType *>(impl)->getContainedType(tablegen_opaque_val);
}
} // namespace toy
