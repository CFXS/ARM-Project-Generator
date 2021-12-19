file(GLOB_RECURSE sources CONFIGURE_DEPENDS
  "src/*.c"
  "src/*.cc"
  "src/*.cpp"
  "src/*.cxx"
)

file(GLOB_RECURSE headers CONFIGURE_DEPENDS
  "src/*.h"
  "src/*.hh"
  "src/*.hpp"
  "src/*.hxx"
)
