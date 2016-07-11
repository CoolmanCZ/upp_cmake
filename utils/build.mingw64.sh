#!/bin/bash

BUILD_DIR="build.mingw64"

if [ -d $BUILD_DIR ]; then
    rm -rf $BUILD_DIR
fi

mkdir -p $BUILD_DIR

cd $BUILD_DIR
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw64.cmake .. && make -j 4

