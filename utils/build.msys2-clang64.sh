#!/bin/bash
START=$(date +%s.%N)
BUILD_DIR="build.msys2"

if [ -d $BUILD_DIR ]; then
    rm -rf $BUILD_DIR
fi

mkdir -p $BUILD_DIR

cd $BUILD_DIR
cmake -G "MinGW Makefiles" -DCMAKE_TOOLCHAIN_FILE=../upp_cmake/utils/toolchain-msys2-clang64.cmake .. && mingw32-make -j $(nproc)

DUR=$(echo "$(date +%s.%N) - ${START}" | bc)
echo "Execution time: $(date -d@0${DUR} -u +%H:%M:%S.%N)"
