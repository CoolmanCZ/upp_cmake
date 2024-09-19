# Ultimate++ CMakeLists generator

```GenerateCMakeFiles-lib.sh``` is the bash script library for generating CMakeLists.txt files (configuration files used by CMake) of the Ultimate++ projects. How to use this library is shown in the script example section.

[CMake](https://cmake.org/) is an open-source, cross-platform family of tools designed to build, test and package software. CMake is used to control the software compilation process using simple platform and compiler independent configuration files, and generate native makefiles and workspaces that can be used in the compiler environment of your choice.

[Ultimate++](http://www.ultimatepp.org/) is a C++ cross-platform rapid application development framework focused on programmers productivity. It includes a set of libraries (GUI, SQL, etc.), and an integrated development environment.

This script library was created based on discussion [CMake support](http://www.ultimatepp.org/forums/index.php?t=msg&th=6013&goto=32310&#msg_32310) on the [Ultimate++ forum](http://www.ultimatepp.org/forums).

# Supported features
- New Core with C++17 build (require GCC 7+)
- Release or debug build
- Binary resource support (BINARY, BINARY_MASK, BINARY_ARRAY)
- Cross compile support (require MINGW GCC 4.9+)
- (MSYS2) MINGW support
- Generated CMakeLists.txt files can be used to create a MS Visual C++ project
- Generated CMakeLists.txt files are generated only for dependent modules of the processed Ultimate++ project
- Create a distribution package
- Build shared libraries as the target (DLL, SO)
- Precompiled headers (PCH) (for GCC 4.9+, Clang 3.5+)
- Batch processing support
- import.ext file support

## UPP package sections
UPP package format is described at [Ultimate++ documentation page](https://www.ultimatepp.org/app$ide$upp$en-us.html). Each section of .upp file begins with a keyword and ends with semicolon. The recognized section keywords are:
- [ ] custom
- [x] file
- [x] flags
- [x] include
- [x] library
- [x] static_library
- [x] link
- [x] options
- [x] target
- [x] uses
- [x] pkg_config
- **acceptflags** (ignored in CMakeLists generator)
- **mainconfig** (ignored in CMakeLists generator)
- **charset** (ignored in CMakeLists generator)
- **description** (ignored in CMakeLists generator)
- **optimize_size** (ignored in CMakeLists generator)
- **optimize_speed** (ignored in CMakeLists generator)
- **noblitz** (ignored in CMakeLists generator)

## Limitation
Some section options are not taken into account when generate CMakeLists:
- file - only options relevant to build are mentioned
  - options
  - depends
  - optimize_speed (ignored)
  - optimize_size (ignored)
- include - all include directories are processed as a relative path
- static_library - library is considered as a normal library
- target - only main target is renamed


# Script library parameters
Using of the script library is demonstrated in the [example.sh](example.sh), where you should change the variables described below in the text.

## Main configuration parameters
* UPP_SRC_DIR - directory path of the Ultimate++ source tree
* PROJECT_NAME - full path to the ultimate++ project file
* PROJECT_FLAGS - project build and configuration flags

## Optional configuration parameters
* PROJECT_EXTRA_COMPILE_FLAGS - extra compile flags
* PROJECT_EXTRA_LINK_FLAGS - extra link flags
* PROJECT_EXTRA_INCLUDE_DIR - extra directory path which will be added as a include path
* PROJECT_EXTRA_INCLUDE_SUBDIRS - set tp "1" - sub-directories in the extra directory path will be added as a include path

* GENERATE_VERBOSE - set to "1" - enable additional output during script processing on the screen
* GENERATE_DEBUG - set to "1" - enable debug output during script processing on the screen
* GENERATE_PACKAGE- set to "1" - create a tarball package of the project
* GENERATE_NOT_Cxx - set to "1" - do not use compiler -std=c++17 parameter (compiler parameter is enabled as default)
* GENERATE_NOT_PARALLEL - set to "1" - do not build with multiple processes (multiple process build is enabled as default)
* GENERATE_NOT_PCH - set to "1" - do not build with precompiled headers support (precompiled headers support is enabled as default)
* GENERATE_NOT_REMOVE_UNUSED_CODE - set to "1" - do not use compile and link parameters to remove unused code and functions (unused code and functions are removed as default)

* CMAKE_VERBOSE_OVERWRITE="0" - set to "0" - do not generate cmake verbose makefile output (even when the debug flag is set)
* CMAKE_VERBOSE_OVERWRITE="1" - set to "1" - always generate cmake verbose makefile output

## Usage
Parameters of the "generate_main_cmake_file" function are
```
generate_main_cmake_file <${PROJECT_NAME}> [${PROJECT_FLAGS}]
```

### Example:
``` bash
#!/bin/bash

source ./GenerateCMakeFiles-lib.sh

GENERATE_VERBOSE="1"        # set to "1" - enable additional output during script processing on the screen
GENERATE_DEBUG="1"          # set to "1" - enable debug output during script processing on the screen
GENERATE_PACKAGE="1"        # set to "1" - create a tarball package of the project

UPP_SRC_BASE="upp-x11-src"
UPP_SRC_DIR="${UPP_SRC_BASE}/uppsrc"
PROJECT_NAME="${UPP_SRC_DIR}/ide/ide.upp"
PROJECT_FLAGS="-DflagGUI -DflagMT -DflagGCC -DflagLINUX -DflagPOSIX -DflagSHARED"

generate_main_cmake_file "${PROJECT_NAME}" "${PROJECT_FLAGS}"
```

### TODO
- Support of the precompiled headers (PCH) for MSVC

### DONE
- Resolve problem to build DLL,SO as target with flagPCH (The problem disappeared after refactoring of the PCH code.)


# CMake additional options
These options enhance the CMakeLists.txt configuration file with additional functionality and they are not a part of the Ultimate++ build system.

### REMOVE_UNUSED_CODE (default: ON)
When this option is set ON binaries are built with removed unused code and functions.

Example: ```cmake -DREMOVE_UNUSED_CODE=OFF ..```

*Note: Default can be changed by the script library configuration parameter GENERATE_NOT_REMOVE_UNUSED_CODE.*

### ENABLE_INCLUDE_WHAT_YOU_USE (default: OFF)
Enable static code analysis with [include-what-you-use](https://include-what-you-use.org/).

Example: ```cmake -DENABLE_INCLUDE_WHAT_YOU_USE=ON ..```

### ENABLE_CPPCHECK (default: OFF)
Enable static code analysis with [Cppcheck](http://cppcheck.sourceforge.net/).

Example: ```cmake -DENABLE_CPPCHECK=ON ..```

### ENABLE_CLANG_TIDY (default: OFF)
Enable static code analysis with [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) is run together with the compiler. The clang-tidy checks should be defined in the 'Checks' option in the .clang-tidy file.

Example: ```cmake -DENABLE_CLANG_TIDY=ON ..```

### CLANG_TIDY_OPTIONS (defualt: empty)
Add extra clang-tidy command line options. Options must be separated by `;`.

Example: ```cmake -DCLANG_TIDY_OPTIONS="--fix" ..```

# Ultimate++ build and configuration flags
Build and configuration flags, that are taken into account by CMake. They can be specified in the variable PROJECT_FLAGS in the ```GenerateCMakeFiles-lib.sh``` script library (use **flag** prefix e.g. *-DflagMT*).

- yes - the flag changes / specifies the behavior of the CMake
- set - the flag is set automatically by the CMake
- 'empty' - the flag is not used by the CMake and is only promoted further

CMake sets and using new flags (can be disabled by the script library configuration parameters)
* flagGNUC17 - set compiler flag -std=c++17
* flagMP - enable multiple process build (MSVC)
* flagPCH - use precompiled headers during build (only GCC and Clang are supported now)

### Main configuration flags
Flag | Supported | Description
---  | ---       | ---
MT  | yes | Build multi-threaded application.
GUI |     | Build GUI application.
DLL | yes | Target is .dll/.so.

### Output method flags
Flag | Supported | Description
---  | ---       | ---
DEBUG         | yes | Target is to be linked with debug version of libraries.
DEBUG_MINIMAL | yes | Minimal debug information - depends on actual builder, usually it should provide line numbers information to debugger.
DEBUG_FULL    | yes | Full debug info.
SHARED        | yes | Prefer dynamic libraries when linking.
SO            | yes | Link non-main packages as shared libraries (.dll/.so). Implies SHARED.
BLITZ         |     | Use blitz build.

### Platform flags
Flag | Supported | Description
---  | ---       | ---
WIN32     | set | Win32
POSIX     | set | Anything else then WIN32
LINUX     | set | Linux
BSD       | set | BSD/OS
FREEBSD   | set | FreeBSD
NETBSD    | set | NetBSD
OPENBSD   | set | OpenBSD
SOLARIS   | set | Solaris
OSX       | set | Darwin
DRAGONFLY | set | DragonFly
ANDROID   | set | Android

### Flags determining the builder (supplied by builder method)
Flag | Supported | Description
---  | ---       | ---
MSC71(X64) | set | Microsoft Visual C++ 7.1
MSC8(X64)  | set | Microsoft Visual C++ 8.0
MSC9(X64)  | set | Microsoft Visual C++ 9.0
MSC10(X64) | set | Microsoft Visual C++ 10.0
MSC11(X64) | set | Microsoft Visual C++ 11.0
MSC12(X64) | set | Microsoft Visual C++ 12.0
MSC14(X64) | set | Microsoft Visual C++ 14.0
MSC15(X64) | set | Microsoft Visual C++ 15.0
MSC17(X64) | yes | Microsoft Visual C++ 17.0
MSC19(X64) | yes | Microsoft Visual C++ 19.0
GCC        | set | GCC compiler in implicit mode (32 or 64).
GCC32      | yes | GCC compiler in 32-bit mode.
EVC_ARM    |     | Microsoft WinCE C++ ARM complier.
EVC_MIPS   |     | Microsoft WinCE C++ MIPS complier.
EVC_SH3    |     | Microsoft WinCE C++ SH3 complier.
EVC_SH4    |     | Microsoft WinCE C++ SH4 complier.
INTEL      | set | Intel C++.

### Other flags (must be set by user)
Flag | Supported | Description
---  | ---       | ---
X11          |     | On POSIX systems turns on X11 backend.
NOGTK        |     | On POSIX systems turns on X11 backend and prevents linking against GTK libraries.
NONAMESPACE  |     | Create all U++ classes in global namespace instead of Upp::.
USEMALLOC    |     | Use malloc to allocate memory instead of U++ allocator.
NOAPPSQL     |     | Do not create global SQL/SQLR instances.
NOMYSQL      |     | Disable MySql package.
NOPOSTGRESQL |     | Disable PostgreSQL package.

