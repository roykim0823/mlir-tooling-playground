file(REMOVE_RECURSE
  "ToyDialect.md"
  "ToyOpInterfaces.md"
  "ToyPasses.md"
  "ToyTypeInterfaces.md"
  "include/Toy/ToyAttrs.cpp.inc"
  "include/Toy/ToyAttrs.h.inc"
  "include/Toy/ToyDialect.cpp.inc"
  "include/Toy/ToyDialect.h.inc"
  "include/Toy/ToyOpInterfaces.cpp.inc"
  "include/Toy/ToyOpInterfaces.h.inc"
  "include/Toy/ToyOps.cpp.inc"
  "include/Toy/ToyOps.h.inc"
  "include/Toy/ToyPasses.h.inc"
  "include/Toy/ToyPatterns.inc"
  "include/Toy/ToyPdllPatterns.h.inc"
  "include/Toy/ToyTypeInterfaces.cpp.inc"
  "include/Toy/ToyTypeInterfaces.h.inc"
  "include/Toy/ToyTypes.cpp.inc"
  "include/Toy/ToyTypes.h.inc"
)

# Per-language clean rules from dependency scanning.
foreach(lang )
  include(CMakeFiles/intrinsics_gen.dir/cmake_clean_${lang}.cmake OPTIONAL)
endforeach()
