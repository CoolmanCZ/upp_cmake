#!/bin/bash
START=$(date +%s.%N)
BUILD_DIR="build.msvc"

if [ -d $BUILD_DIR ]; then
    rm -rf $BUILD_DIR
fi

mkdir -p $BUILD_DIR

cd $BUILD_DIR
cmake -G "Visual Studio 14 Win64" .. && cmake --build . --target ALL_BUILD --config Release

DUR=$(echo "$(date +%s.%N) - ${START}" | bc)
echo "Execution time: $(date -d@0${DUR} -u +%H:%M:%S.%N)"
