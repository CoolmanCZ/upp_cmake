# Ultimate++ CMakeLists generator

GenerateCMakeFiles-lib.sh is the bash script for generating CMakeLists.txt files of the [Ultimate++](http://www.ultimatepp.org/) projects.
This script was created based on discussion [CMake support](http://www.ultimatepp.org/forums/index.php?t=msg&th=6013&goto=32310&#msg_32310) on the [Ultimate++ forum](http://www.ultimatepp.org/forums).

## Parameters
Using of the script is demonstrated in the example.sh, where you should change the variables:

### Main configuration parameters
* UPP_SRC_DIR - directory path of the Ultimate++ source tree
* PROJECT_NAME - full path to the ultimate++ project file
* PROJECT_FLAGS - build flags

### Optional configuration parameters
* GENERATE_VERBOSE - set to "1" - enable additional output during script processing on the screen
* GENERATE_DEBUG - set to "1" - enable debug output during script processing on the screen
* GENERATE_PACKAGE- set to "1" - create a tarball package of the project
* GENERATE_NOT_Cxx - set to "1" - do not use compiler -std=c++14 parameter (compiler parameter is enabled as default)
* GENERATE_NOT_PARALLEL - set to "1" - do not build with multiple processes (multiple process build is enabled as default)
* GENERATE_NOT_PCH - set to "1" - do not build with precompiled headers support (precompiled headers support is enabled as default)

* CMAKE_VERBOSE_OVERWRITE="0" - set to "0" - do not generate cmake verbose makefile output (even when the debug flag is set)
* CMAKE_VERBOSE_OVERWRITE="1" - set to "1" - always generate cmake verbose makefile output

## Usage
Parameters of the "generate_main_cmake_file" function are
```
generate_main_cmake_file <${PROJECT_NAME}> [${PROJECT_FLAGS}]
```

## Support
- New Core with C++11 build (require GCC 4.9+)
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

## Limitation
- Some options are not taken into account when generating CMakeLists (static_library, file depends)

## TODO
- Support of the precompiled headers (PCH) for MSVC

## DONE
- Resolve problem to build DLL,SO as target with flagPCH (The problem disappeared after refactoring of the PCH code.)

## Flags
Build and configuration flags, that are taken into account by the GenerateCMakeFiles-lib.sh script.
- yes - the flag changes / specifies the behavior of the script
- set - the flag is set by the script, if it is not defined
- 'empty' - the flag is not used / set by the script

Script set and using new flags (can be disabled by configuration parameters)
* flagGNUC14 - set compiler flag -std=c++14
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
WIN32   | set | Win32.
POSIX   | set | Anything else then WIN32.
LINUX   | set | Linux.
FREEBSD | set | FreeBSD.
SOLARIS | set | Solaris.

### Flags determining the builder (supplied by builder method)
Flag | Supported | Description
---  | ---       | ---
MSC71    | set | Microsoft Visual C++ 7.1
MSC8     | set | Microsoft Visual C++ 8.0
GCC      | set | GCC compiler in implicit mode (32 or 64).
GCC32    | yes | GCC compiler in 32-bit mode.
EVC_ARM  |     | Microsoft WinCE C++ ARM complier.
EVC_MIPS |     | Microsoft WinCE C++ MIPS complier.
EVC_SH3  |     | Microsoft WinCE C++ SH3 complier.
EVC_SH4  |     | Microsoft WinCE C++ SH4 complier.
INTEL    | set | Intel C++.

### Other flags (to be supplied by user)
Flag | Supported | Description
---  | ---       | ---
X11          |     | On POSIX systems turns on X11 backend.
NOGTK        |     | On POSIX systems turns on X11 backend and prevents linking against GTK libraries.
NONAMESPACE  |     | Create all U++ classes in global namespace instead of Upp::.
USEMALLOC    |     | Use malloc to allocate memory instead of U++ allocator.
NOAPPSQL     |     | Do not create global SQL/SQLR instances.
NOMYSQL      |     | Disable MySql package.
NOPOSTGRESQL |     | Disable PostgreSQL package.
