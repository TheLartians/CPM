[![Build Status](https://travis-ci.com/TheLartians/CPM.svg?branch=master)](https://travis-ci.com/TheLartians/CPM)

# CPM

CPM is a simple dependency manager written in CMake built on top of CMake's built-in [FetchContent](https://cmake.org/cmake/help/latest/module/FetchContent.html) module.

## Supported projects

Any project that you can add via `add_subdirectory` should already work with CPM.

## Usage

After `CPM.cmake` has been added to your project, you can call `CPMAddPackage` to add and recursively fetch dependencies at configure time. `CPMAddPackage` takes the following named arguments.

```cmake
CPMAddPackage(
  NAME          # The dependency name (usually chosen to match the target name)
  VERSION       # The minimum version of the dependency (optional, defaults to 0)
  OPTIONS       # Configuration options passed to the dependency (optional)
  DOWNLOAD_ONLY # If set, the project is downloaded, but not configured (optional)
  [...]         # Origin options, see below
)
```

The origin is usually defined as a git repository and tag, but [svn revisions and direct URLs are also supported](https://cmake.org/cmake/help/latest/module/FetchContent.html#declaring-content-details).
If `GIT_TAG` hasn't been explicitly specified it defaults to `v(VERSION)`, a common convention for github projects.
`GIT_TAG` can also be set to a branch name such as `master` to download the most recent version.

After calling `CPMAddPackage`, targets defined in the dependency can be added and the variables `(DEPENDENCY)_SOURCE_DIR` and `(DEPENDENCY)_BINARY_DIR` are set to the source and binary directory of the dependency.

## Full Example

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
  OPTIONS
    "LARS_PARSER_BUILD_GLUE_EXTENSION ON"
)

# add executable
add_executable(myProject myProject.cpp)
set_target_properties(myProject PROPERTIES CXX_STANDARD 17)
target_link_libraries(myProject LarsParser)
```

See the [examples directory](https://github.com/TheLartians/CPM/tree/master/examples) for more examples with source code.

## Adding CPM

To add CPM to your current project, simply add `cmake/CPM.cmake` to your project's `cmake` directory. The command below will perform this automatically.

```bash
wget -O cmake/CPM.cmake https://raw.githubusercontent.com/TheLartians/CPM/master/cmake/CPM.cmake
```

## Updating CPM

To update CPM to the newest version, simply update the script in the project's cmake directory, for example by running the command above. Dependencies using CPM will automatically use the updated script of the outermost project.

## Snipplets

These examples demonstrate how to include some well-known projects with CPM.

### [Catch2](https://github.com/catchorg/Catch2.git)

Has a CMakeLists.txt that supports `add_subdirectory`.

```cmake
CPMAddPackage(
  NAME Catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  VERSION 2.5.0
)
```

### [google/benchmark](https://github.com/google/benchmark.git)

Has a CMakeLists.txt that supports `add_subdirectory`, but needs some configuring to work without external dependencies.

```cmake
CPMAddPackage(
  NAME benchmark
  GIT_REPOSITORY https://github.com/google/benchmark.git
  VERSION 1.4.1
  OPTIONS
   "BENCHMARK_ENABLE_TESTING Off"
)

# needed to compile with C++17
set_target_properties(benchmark PROPERTIES CXX_STANDARD 17)
```

### [Simple match](https://github.com/jbandela/simple_match.git)

Header-only library without releases or CMakeLists.txt, target must be created manually.

```cmake
CPMAddPackage(
  NAME simple_match
  GIT_REPOSITORY https://github.com/jbandela/simple_match.git
  GIT_TAG a3ab17f3d98db302de68ad85ed399a42ae41889e
  DOWNLOAD_ONLY True
)

add_library(simple_match INTERFACE IMPORTED)
target_include_directories(simple_match INTERFACE "${simple_match_SOURCE_DIR}/include")
```

### [Lua](https://www.lua.org)

Library without CMakeLists.txt, target must be created manually.

```cmake
CPMAddPackage(
  NAME lua
  GIT_REPOSITORY https://github.com/lua/lua.git
  VERSION 5-3-4
  DOWNLOAD_ONLY YES
)

FILE(GLOB lua_sources ${lua_SOURCE_DIR}/*.c)
add_library(lua STATIC ${lua_sources})

target_include_directories(lua
  PUBLIC
    $<BUILD_INTERFACE:${lua_SOURCE_DIR}>
)
```

## Local packages

CPM can be configured to use `find_package` to search for locally installed dependencies first.
If `CPM_LOCAL_PACKAGES_ONLY` is set, CPM will error when dependency is not found locally.

## Advantages

- **Small repos** CPM takes care of project dependencies, allowing you to focus on creating small, well-tested frameworks.
- **Cross-Plattform** CPM adds projects via `add_subdirectory`, which is compatible with all cmake toolchains and generators.
- **Reproducable builds** By using versioning via git tags it is ensured that a project will always be in the same state everywhere.
- **No installation required** No need to install anything. Just add the script to your project and you're good to go.
- **No Setup required** There is a good chance your existing projects already work as CPM dependencies.
- **Simple source distribution** CPM makes including projects with source files and dependencies easy, reducing the need for monolithic header files.

## Limitations

- **First version used** In diamond-shaped dependency graphs (e.g. `A` depends on `C`@1.1 and `B`, which itself depends on `C`@1.2 the first added dependency will be used (in this case `C`@1.1). In this case, B requires a newer version of `C` than `A`, so CPM will emit an error. This can be resolved by updating the outermost dependency version.
- **No auto-update** To update a dependency, version must be adapted manually and there is no way for CPM to figure out the most recent version.
- **No pre-built binaries** Unless they are installed or included in the linked repository. 

For projects with more complex needs and where an extra setup step doesn't matter, it is worth to check out fully featured C++ package managers such as [conan](https://conan.io) or [hunter](https://github.com/ruslo/hunter).
