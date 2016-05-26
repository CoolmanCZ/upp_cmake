# Ultimate++ CMakeList generator

GenerateCMakeFiles-lib.sh is the bash script for generating CMakeList.txt files of the Ultimate++ projects.
This script was created based on discussion on the Ultimate++ forum - [CMake support](http://www.ultimatepp.org/forums/index.php?t=msg&th=6013&goto=32310&#msg_32310)

## Using
Using of the script is demonstrated in the GenerateCMakeFiles.sh where you should change
1. The variable "UPP_SRC_DIR" - directory path of the Ultimate++ source tree
2. Parameters of the command "generate_main_cmake_file"

## Parameters
Parameters of the "generate_main_cmake_file" are
```
generate_main_cmake_file <full path to the ultimate++ project file> [build flags]
```

## Support
- New Core with C++11 build (require GCC 4.9+)
- Release or debug build
- Binary resource support (BINARY, BINARY_MASK, BINARY_ARRAY)

## Limitation
- Initial version was tested only on LINUX platform
- Ultimate++ source tree and directory of the project should be in the same directory as the generator scripts (you can use symlinks)
- Not all options of the files are taken into consideration during CMakeList generating
- CMakeList.txt files are generated only for dependent modules of the processed Ultimate++ project

## TODO
- Using of the script with MSYS2 MINGW under Windows OS
- Create symlinks (copy directory tree) automatically
- Generate distribution package
