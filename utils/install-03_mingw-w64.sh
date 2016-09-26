#!/bin/bash

dst_dir="/var/tmp/mingw_install"
mkdir -p -P ${dst_dir}

wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/main/i/isl/libisl13_0.14-2_amd64.deb -P ${dst_dir}

binutils_ver="2.26-8ubuntu2"
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/main/b/binutils/binutils_${binutils_ver}_amd64.deb -P ${dst_dir}

mingw_bin_ver="2.26-3ubuntu1+6.6"
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/b/binutils-mingw-w64/binutils-mingw-w64-i686_${mingw_bin_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/b/binutils-mingw-w64/binutils-mingw-w64-x86-64_${mingw_bin_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/b/binutils-mingw-w64/binutils-mingw-w64_${mingw_bin_ver}_all.deb -P ${dst_dir}

mingw_ver="4.0.6-1"
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64-common_${mingw_ver}_all.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64-i686-dev_${mingw_ver}_all.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64-tools_${mingw_ver}_amd64.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64-x86-64-dev_${mingw_ver}_all.deb -P ${dst_dir}
wget -nc http://cz.archive.ubuntu.com/ubuntu/pool/universe/m/mingw-w64/mingw-w64_${mingw_ver}_all.deb -P ${dst_dir}

mingw_gcc_ver="4.9.2-10ubuntu7+15.1"
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

