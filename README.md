[![Build Status](https://travis-ci.com/TheLartians/CPM.svg?branch=master)](https://travis-ci.com/TheLartians/CPM)

# CPM

CPM is a simple GIT dependency manager written in CMake built on top of CMake's built-in [FetchContent](https://cmake.org/cmake/help/latest/module/FetchContent.html) module.

## Supported projects

Any project that you can add via `add_subdirectory` should already work with CPM.

## Usage

To add a new dependency to your project simply add the Projects target name, the git URL and the version. If the git tag for this version does not match the pattern `v$VERSION`, then the exact branch or tag can be specified with the `GIT_TAG` argument. CMake options can also be supplied with the package. If a package is not CMake compaitible it can still be downloaded with the `DOWNLOAD_ONLY` flag. See below for usage examples.

```cmake
cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

# create project
project(MyProject)

# add dependencies
include(cmake/CPM.cmake)

CPMAddPackage(
  NAME LarsParser
  VERSION 1.8
  GIT_REPOSITORY https://github.com/TheLartians/Parser.git
  GIT_TAG v1.8 # optional here, as indirectly defined by VERSION
  OPTIONS      # optional CMake arguments passed to the dependency
    "LARS_PARSER_BUILD_GLUE_EXTENSION ON"
)

# add executable
add_executable(myProject myProject.cpp)
set_target_properties(myProject PROPERTIES CXX_STANDARD 17)
target_link_libraries(myProject LarsParser)
```

## Adding CPM

To add CPM to your current project, simply add `cmake/CPM.cmake` to your project's `cmake` directory. The command below will perform this automatically.

```bash
wget -O cmake/CPM.cmake https://raw.githubusercontent.com/TheLartians/CPM/master/cmake/CPM.cmake
```

## Examples

### Catch2

Has a CMakeLists.txt that supports `add_subdirectory`.

```cmake
CPMAddPackage(
  NAME Catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  VERSION 2.5.0
)
```

### google/benchmark

Has a CMakeLists.txt that supports `add_subdirectory`, but needs some configuring.

```cmake
CPMAddPackage(
  NAME benchmark
  GIT_REPOSITORY https://github.com/google/benchmark.git
  VERSION 1.4.1
  OPTIONS
   "BENCHMARK_ENABLE_TESTING Off"
   "BENCHMARK_USE_LIBCXX ON"
)

# needed to compile with C++17
set_target_properties(benchmark PROPERTIES CXX_STANDARD 17)
```

### Lua

Has no CMakeLists.txt, target must be created manually.

```cmake
CPMAddPackage(
  NAME lua
  GIT_REPOSITORY https://github.com/lua/lua.git
  VERSION 5-3-4
  GIT_SHALLOW YES
  DOWNLOAD_ONLY YES
)

FILE(GLOB lua_sources ${lua_SOURCE_DIR}/*.c)
add_library(lua STATIC ${lua_sources})

target_include_directories(lua
  PUBLIC
    $<BUILD_INTERFACE:${lua_SOURCE_DIR}>
)
```

### robin_hood::unordered_map

Has CMakeLists.txt, but it seems it is only used for testing.
Therefore we must create or own target.

```cmake
CPMAddPackage(
  NAME RobinHood
  VERSION 3.2.7
  GIT_REPOSITORY https://github.com/martinus/robin-hood-hashing.git
  DOWNLOAD_ONLY Yes
)

add_library(RobinHood INTERFACE IMPORTED)
target_include_directories(RobinHood INTERFACE "${RobinHood_SOURCE_DIR}/src/include")
```

## Updating CPM

To update CPM to the newest version, simply update the script in the project's cmake directory, for example by running the command above. Dependencies using CPM will automatically use the updated script of the outermost project.

## Global Options

Setting the CMake option `CPM_USE_LOCAL_PACKAGES` will activate finding packages via `find_package`. If the option `CPM_LOCAL_PACKAGES_ONLY` is set, CPM will only use local packages.

## Advantages

- **Small repos** CPM takes care of project dependencies, allowing you to focus on creating small, well-tested frameworks.
- **Cross-Plattform** CPM adds projects via `add_subdirectory`, which is compatible with all cmake toolchains and generators.
- **Reproducable builds** By using versioning via git tags it is ensured that a project will always be in the same state everywhere.
- **No installation required** No need to install anything. Just add the script to your project and you're good to go.
- **No Setup required** There is a good chance your existing projects already work as CPM dependencies.

## Limitations

- **First version used** In diamond-shaped dependency graphs (e.g. `A` depends on `C`(v1.1) and `A` depends on `B` depends on `C`(v1.2)) the first added dependency will be used (in this case `C`@1.1). If the current version is older than the version beeing added, or if provided options are incompatible, a CMake warning will be emitted. To resolve, add the new version of the common dependency to the outer project.
- **No auto-update** To update a dependency, version numbers or git tags in the cmake scripts must be adapted manually.
- **No pre-built binaries** Unless they are installed or included in the linked repository.
