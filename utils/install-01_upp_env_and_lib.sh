#!/bin/bash

# Install build environment
sudo apt-get install build-essential cmake
sudo ln -s /usr/bin/make /usr/bin/gmake

# Install Clang version supporting PCH
sudo apt-get install clang-3.5 lldb-3.5 llvm
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-3.5 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-3.5 100
sudo update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-3.5 100

# Install GCC version supporting -std=c++11 parameter
sudo add-apt-repository ppa:ubuntu-toolchain-r/test
sudo apt-get update
sudo apt-get install g++-4.9 gcc-4.9 cpp-4.9

sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 100
sudo update-alternatives --install /usr/bin/cpp cpp /usr/bin/cpp-4.9 100
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 100

# Install required packages by UPP
sudo apt-get install libbz2-dev libfreetype6-dev libpng12-dev gtk2.0-dev libnotify-dev libssl-dev

sudo apt-get autoremove

