#!/bin/bash

dst_dir="/var/tmp/mingw_install"
mkdir -p -P ${dst_dir}

wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/main/i/isl/libisl15_0.18-1_amd64.deb -P ${dst_dir}

binutils_ver="2.29-8ubuntu1"
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/main/b/binutils/binutils_${binutils_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/main/b/binutils/binutils-common_${binutils_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/main/b/binutils/binutils-x86-64-linux-gnu_${binutils_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/main/b/binutils/libbinutils_${binutils_ver}_amd64.deb -P ${dst_dir}

mingw_bin_ver="2.28-1ubuntu1+7.4ubuntu1"
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/b/binutils-mingw-w64/binutils-mingw-w64-i686_${mingw_bin_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/b/binutils-mingw-w64/binutils-mingw-w64-x86-64_${mingw_bin_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/b/binutils-mingw-w64/binutils-mingw-w64_${mingw_bin_ver}_all.deb -P ${dst_dir}

mingw_ver="5.0.2-2"
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64-common_${mingw_ver}_all.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64-i686-dev_${mingw_ver}_all.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64-tools_${mingw_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64-x86-64-dev_${mingw_ver}_all.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64_${mingw_ver}_all.deb -P ${dst_dir}

mingw_gcc_ver="6.3.0-14ubuntu3+19.3"
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/g++-mingw-w64-i686_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/g++-mingw-w64-x86-64_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/g++-mingw-w64_${mingw_gcc_ver}_all.deb -P ${dst_dir}

wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gcc-mingw-w64-base_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gcc-mingw-w64-i686_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gcc-mingw-w64-x86-64_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gcc-mingw-w64_${mingw_gcc_ver}_all.deb -P ${dst_dir}

#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gfortran-mingw-w64-i686_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gfortran-mingw-w64-x86-64_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gfortran-mingw-w64_${mingw_gcc_ver}_all.deb -P ${dst_dir}

#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gnat-mingw-w64_4.6.3-1ubuntu5+5ubuntu1_all.deb -P ${dst_dir}
#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gnat-mingw-w64-x86-64_4.6.3-1ubuntu5+5ubuntu1_amd64.deb -P ${dst_dir}
#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gnat-mingw-w64-i686_4.6.3-1ubuntu5+5ubuntu1_amd64.deb -P ${dst_dir}

#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gobjc++-mingw-w64-i686_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gobjc++-mingw-w64-x86-64_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gobjc++-mingw-w64_${mingw_gcc_ver}_all.deb -P ${dst_dir}

#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gobjc-mingw-w64-i686_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gobjc-mingw-w64-x86-64_${mingw_gcc_ver}_amd64.deb -P ${dst_dir}
#wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-mingw-w64/gobjc-mingw-w64_${mingw_gcc_ver}_all.deb -P ${dst_dir}

cd ${dst_dir}
sudo dpkg -i *.deb

