# Ultimate++ CMakeLists generator

GenerateCMakeFiles-lib.sh is the bash script for generating CMakeLists.txt files of the Ultimate++ projects.
This script was created based on discussion on the Ultimate++ forum - [CMake support](http://www.ultimatepp.org/forums/index.php?t=msg&th=6013&goto=32310&#msg_32310)

## Using
Using of the script is demonstrated in the example.sh, where you should change the variables:
* 1. "UPP_SRC_DIR" - directory path of the Ultimate++ source tree
* 2. "PROJECT_NAME" - full path to the ultimate++ project file
* 2. "PROJECT_FLAGS" - build flags

## Parameters
Parameters of the "generate_main_cmake_file" are
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

## Limitation
- Ultimate++ source tree and directory of the project should be in the same directory as the generator scripts during build (you can use symlinks)
- Some options are not taken into account when generating CMakeLists

## TODO
- Support to build shared libraries as target (DLL, SO)
