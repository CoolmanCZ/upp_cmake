#!/bin/bash
#
# Copyright (C) 2016 Radek Malcic
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

source ./GenerateCMakeFiles-lib.sh

GENERATE_VERBOSE="1"
GENERATE_DEBUG="1"

UPP_SRC_BASE="upp-x11-src-2016-06-21"
UPP_SRC_DIR="${UPP_SRC_BASE}/uppsrc"

generate_main_cmake_file ${UPP_SRC_DIR}/ide/ide.upp "-DflagGUI -DflagMT -DflagGCC -DflagSHARED -DflagLINUX -DflagPOSIX"
#generate_main_cmake_file ${UPP_SRC_BASE}/reference/brc/brc.upp "-DflagLINUX -DflagPOSIX -DflagSHARED -DflagDEBUG"

if [ "${GENERATE_DEBUG}" == "1" ]; then
    declare -A sorted_UPP_ALL_USES=$(printf "%s\n" "${UPP_ALL_USES[@]}" | sort -u);
    declare -A sorted_UPP_ALL_USES_DONE=$(printf "%s\n" "${UPP_ALL_USES_DONE[@]}" | sort -u);

    echo "Plugins used   : " ${sorted_UPP_ALL_USES[@]}
    echo "CMake generated: " ${sorted_UPP_ALL_USES_DONE[@]}
fi

