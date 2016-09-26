#!/bin/bash

sudo apt-get install texinfo

# Install new gdb 7.10
#apt-get install libbabeltrace-ctf1 libbabeltrace
#wget -nc http://archive.ubuntu.com/ubuntu/pool/main/g/gdb/gdb_7.10-1ubuntu2_amd64.deb
#wget -nc http://archive.ubuntu.com/ubuntu/pool/main/g/gdb/gdb_7.11.1-0ubuntu1~16.04_amd64.deb
#sudo dpdg -i gdb_7.10-1ubuntu2_amd64.deb

# Disable demangling in gdb by adding this to your .gdbinit "set demangle-style none"
# echo "set demangle-style none" >> ~/.gdbinit

# build gdb source code
cur_dir=`pwd`

mkdir -p /var/tmp/gdb-build
cd /var/tmp/gdb-build
wget -nc http://ftp.gnu.org/gnu/gdb/gdb-7.11.1.tar.gz
tar xf gdb-7.11.1.tar.gz
cd gdb-7.11.1
./configure
make
sudo make install

cd $cur_dir

