/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Interface Definitions                                                      *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

/// Number of elements.
int64_t toy::ContainerTypeInterface::getNumElements() const {
      return getImpl()->getNumElements(getImpl(), *this);
  }
/// The element type.
::mlir::Type toy::ContainerTypeInterface::getContainedType() const {
      return getImpl()->getContainedType(getImpl(), *this);
  }
