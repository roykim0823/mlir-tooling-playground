# Standard lit wiring. An installed LLVM ships no llvm-lit: accept `lit` on
# PATH unless -DLLVM_EXTERNAL_LIT was given.
if(NOT LLVM_EXTERNAL_LIT)
  find_program(LLVM_EXTERNAL_LIT NAMES llvm-lit lit)
endif()
configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.site.cfg.py.in
  ${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg.py
  MAIN_CONFIG
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.cfg.py
  )
add_lit_testsuite(check-hello "Running the hello regression tests"
  ${CMAKE_CURRENT_BINARY_DIR}
  DEPENDS hello-opt
  )
