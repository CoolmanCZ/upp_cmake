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

GENERATE_CMAKE_VERSION="1.0"

OFN="CMakeLists.txt"        # Output file name

LINK_LIST="LINK_LIST"
DEPEND_LIST="DEPEND_LIST"
SOURCE_LIST_C="SOURCE_LIST_C"
SOURCE_LIST_CPP="SOURCE_LIST_CPP"
HEADER_LIST="HEADER_LIST"
INCLUDE_LIST="INCLUDE_LIST"
SOURCE_LIST_ICPP="SOURCE_LIST_ICPP"
SOURCE_LIST_RC="SOURCE_LIST_RC"
COMPILE_FLAGS_LIST="COMPILE_FLAGS_LIST"

PCH_FILE="PCH_FILE"
PCH_INCLUDE_LIST="PCH_INCLUDE_LIST"
PCH_COMPILE_DEFINITIONS="PCH_COMPILE_DEFINITIONS"

BIN_SUFFIX="-bin"
LIB_SUFFIX="-lib"

RE_BZIP2='[bB][zZ]2'
RE_ZIP='[zZ][iI][pP]'
RE_PNG='[pP][nN][gG]'
RE_C='\.([cC])$'
RE_CPP='\.([cC]+[xXpP]{0,2})$'
RE_ICPP='\.([iI][cC]+[xXpP]{0,2})$'
RE_RC='\.(rc)$'
RE_BRC='\.(brc)$'
RE_USES='^uses\('
RE_LINK='^link\('
RE_LIBRARY='^library\('
RE_OPTIONS='^options'
RE_DEPEND='^uses$'
RE_FILES='^file$'
RE_MAINCONFIG='^mainconfig'
RE_SEPARATOR='separator'
RE_FILE_DOT='\.'
RE_FILE_SPLIT='(options|charset|optimize_speed|highlight)'
RE_FILE_EXCLUDE='(depends\(\))'
RE_FILE_PCH='(PCH)'

FLAG_GUI=""
FLAG_MT=""

UPP_ALL_USES=()
UPP_ALL_USES_DONE=()

test_required_binaries()
{
    # Requirement for generating the CMakeList files
    local my_sed=$(which sed)
    local my_sort=$(which sort)
    local my_date=$(which date)

    if [ -z "${my_sed}" ] || [ -z "${my_sort}" ] || [ -z "${my_date}" ]; then
        echo "ERROR - Requirement for generating the CMakeList files failed."
        echo "ERROR - Can't continue -> Exiting!"
        echo "sed=\"${my_sed}\""
        echo "sort=\"${my_sort}\""
        echo "date=\"${my_date}\""
        exit 1
    fi
}

string_trim_spaces_both()
{
    local line="${1}"

    line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    echo "${line}"
}

string_remove_comma()
{
    local line="${1}"

    line="${line//,}"   # Remove ','
    line="${line//;}"   # Remove ';'
    line="${line//\"}"  # Remove '"'

    echo "${line}"
}

string_replace_dash()
{
    local line="${1}"

    line=`echo "${line}" | sed 's#/#_#g'`

    echo "${line}"
}

string_get_in_parenthesis()
{
    local line="${1}"

    line=`echo "${line}" | sed '1s/[^(]*(//;$s/)[^)]*$//'`  # Get string inside parenthesis
    line=`echo "${line}" | sed 's/& //g'`                   # Remove all '&'

    echo "${line}"
}

string_get_after_parenthesis()
{
    local line="${1}"

    line=`echo "${line}" | sed 's/^.*) //'`                 # Get string after the right parenthesis

    echo "${line}"
}

string_get_before_parenthesis()
{
    local line="${1}"

    line=`echo "${line}" | sed 's/(.*$//'`                  # Get string before the left parenthesis

    echo "${line}"
}

if_options_replace()
{
    local options="${1}"
    local output=""

    if [ -n "${options}" ]; then
        case "${options}" in
            "GNU")
                output="CMAKE_C_COMPILER_ID MATCHES GNU"
                ;;
            "XGNU")
                output="CMAKE_COMPILER_IS_GNUCXX"
                ;;
            "GCC")
                output="CMAKE_COMPILER_IS_GNUCC"
                ;;
            "SHARED")
                output="BUILD_SHARED_LIBS"
                ;;
            "MSC")
                output="MSVC"
                ;;
            "OSX11")
                output="APPLE"
                ;;
            "LINUX")
                output="\${CMAKE_SYSTEM_NAME} MATCHES Linux"
                ;;
            "FREEBSD")
                output="\${CMAKE_SYSTEM_NAME} MATCHES FreeBSD"
                ;;
            "DRAGONFLY")
                output="\${CMAKE_SYSTEM_NAME} MATCHES DragonFly"
                ;;
            "BSD")
                output="\${CMAKE_SYSTEM_NAME} MATCHES BSD"
                ;;
            "SOLARIS")
                output="\${CMAKE_SYSTEM_NAME} MATCHES Solaris"
                ;;
            "POSIX")
                output="DEFINED flagPOSIX"
                ;;
            "STACKTRACE")
                output="DEFINED flagSTACKTRACE"
                ;;
            "MSC8ARM")
                output="DEFINED flagMSC8ARM"
                ;;
            "GUI")
                output="DEFINED flagGUI"
                ;;
            "XLFD")
                output="DEFINED flagXLFD"
                ;;
            "NOGTK")
                output="BUILD_WITHOUT_GTK"
                ;;
            "RAINBOW")
                output="BUILD_WITH_RAINBOW"
                ;;
        esac

        if [ -z "${output}" ]; then
            output="${options}"
        fi

        echo "${output}"
    fi
}

if_options_parse()
{
    local operand=""
    local next_operand=" AND "
    local counter=0
    local output=""
    local list=""
    local OPTIONS=(${1})

    if [ -n "${OPTIONS}" ]; then
        for list in "${OPTIONS[@]}"; do

            # Don't process alone '!' operand
            if [[ ${list} =~ '!' ]] && [ ${#list} -eq 1 ]; then
                list=""
            fi

            if [ -n "${list}" ]; then
                (( counter++ ))

                operand="${next_operand}"

                if [ "${list}" = '|' ]; then
                    operand=" "
                    list=" OR "
                    next_operand=" "
                else
                    next_operand=" AND "
                fi

                if [[ ${list} =~ '!' ]]; then
                    list="${list//!}"
                    if [ ${counter} -eq 1 ]; then
                        operand="NOT "
                    else
                        operand+="NOT "
                    fi
                fi

                # Don't insert 'AND operand as first option parameter
                if [ ${counter} -eq 1 ] && [[ "${operand}" = " AND " ]]; then
                    operand=""
                fi

                list=$(if_options_replace "${list}")
                output+="${operand}${list}"
            fi

        done

        echo "${output}"
    fi
}

if_options_parse_all()
{
    local line="${1}"
    local ALL_OPTIONS=()
    local list=""
    local output=""
    local result=""

    # Split options by ')'
    OLD_IFS=${IFS}
    IFS=')'; read -d '' -ra ALL_OPTIONS <<< "${line}"
    IFS=${OLD_IFS}

    if [ -n "${ALL_OPTIONS}" ]; then
        for list in "${ALL_OPTIONS[@]}"; do
            list=${list//\(}                                  # Remove parenthesis
            result="("$(if_options_parse "${list}")")"        # Parse options
            result=`echo "${result}" | sed 's#(OR # OR (#g'`  # Move 'OR'
            result=`echo "${result}" | sed 's#()##g'`         # Delete empty parenthesis
            output+="${result}"
        done
    fi

    echo "${output}" | sed 's#)(#) AND (#g'                   # Put 'AND' between options
}

add_require_for_lib()
{
    local link_list="${1}"
    local check_lib_name="${2}"
    local req_lib_dir="DIRS"
    local req_lib_name=""
    local req_lib_param=""
    local use_pkg="0"

    case "${check_lib_name}" in
        "png")
            req_lib_name="PNG"
            ;;
        "bz2")
            req_lib_name="BZip2"
            req_lib_dir="DIR"
            ;;
        "pthread")
            req_lib_name="Threads"
            ;;
        "X11")
            req_lib_name="X11"
            req_lib_dir="DIR"
            ;;
        "expat")
            req_lib_name="EXPAT"
            ;;
        "freetype")
            req_lib_name="Freetype"
            ;;
        "ssl")
            req_lib_name="OpenSSL"
            ;;
        "gtk-x11-2.0")
            req_lib_name="GTK2"
            req_lib_param="gtk"
            ;;
        "gtk-3.0")
            req_lib_name="GTK3"
            req_lib_param="gtk+-3.0"
            use_pkg="1"
            ;;
    esac

    if [ -n "${req_lib_name}" ]; then
        if [ "${use_pkg}" == "0" ]; then
            echo "  find_package ( ${req_lib_name} REQUIRED ${req_lib_param})" >> ${OFN}
        else
            echo "  find_package ( PkgConfig REQUIRED )" >> ${OFN}
            echo "  pkg_check_modules ( ${req_lib_name} REQUIRED ${req_lib_param})" >> ${OFN}
        fi
        echo "  if ( ${req_lib_name^^}_FOUND )" >> ${OFN}
        echo "      list ( APPEND ${INCLUDE_LIST} \${${req_lib_name^^}_INCLUDE_${req_lib_dir}} )" >> ${OFN}
        echo "      list ( APPEND ${link_list} \${${req_lib_name^^}_LIBRARIES} )" >> ${OFN}
        echo "  endif()" >> ${OFN}
    fi
}

list_parse()
{
    local line="${1}"
    local list="${2}"
    local target_name="${3}"
    local options=""
    local parameters=""

    echo >> ${OFN}
    echo "#${1}" >> ${OFN}

    if [[ "${line}" =~ BUILDER_OPTION ]]; then
        $(if_options_builder "${line}")
    else
        options=$(string_get_in_parenthesis "${line}")
        options=$(if_options_parse_all "${options}")              # Parse options
#        echo "\"option: $options\""

        parameters=$(string_get_after_parenthesis "${line}")
        parameters=$(string_remove_comma "${parameters}")
#        echo "\"param : $parameters\""
#        echo "\"list  : $list\""

        # Add optional dependency target to generate CMakeLists.txt
        if [[ ${list} =~ "${DEPEND_LIST}" ]]; then
            local -a new_parameters=(${parameters})
            parameters=""
            for item in ${new_parameters[@]}; do
                parameters+="$(string_replace_dash "${item}${LIB_SUFFIX}") "
                UPP_ALL_USES+=(${item})
            done
        fi

        if [ -n "${options}" ] ; then
            echo "if (${options})" >> ${OFN}
            if [ -n "${target_name}" ]; then
                local -a check_library_array=(${parameters})
                for check_library in "${check_library_array[@]}"; do
                    add_require_for_lib "${list}" "${check_library}"
                done
            fi
            echo "  list ( APPEND ${list} ${parameters} )" >> ${OFN}
            echo "endif()" >> ${OFN}
        fi
    fi
}

link_parse()
{
    local line="${1}"
    local target_name="${2}"
    local options=""
    local parameters=""

    echo >> ${OFN}
    echo "#${1}" >> ${OFN}

    options=$(string_get_in_parenthesis "${line}")
    options=$(if_options_parse_all "${options}")              # Parse options

    parameters=$(string_get_after_parenthesis "${line}")
    parameters="${parameters//;}"
    parameters="${parameters//\"}"

    if [ -n "${options}" ]; then
        echo "if (${options})" >> ${OFN}
        echo "  set ( MAIN_TARGET_LINK_FLAGS "\${MAIN_TARGET_LINK_FLAGS} ${parameters}" PARENT_SCOPE )" >> ${OFN}
        echo "endif()" >> ${OFN}
    fi
}

if_options_builder()
{
    local line="${1}"
    local options=$(string_get_after_parenthesis "${line}")
    local parameters_gcc=""
    local parameters_msvc=""

    if [[ ${options} =~ NOWARNINGS ]]; then
        parameters_gcc="-w"
        parameters_msvc="-W0"
    fi

    if [ -n "${parameters_gcc}" ]; then
        echo 'if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )' >> ${OFN}
        echo "  set ( CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE} \"\${CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE}} ${parameters_gcc}\")" >> ${OFN}
        echo "  set ( CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE} \"\${CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE}} ${parameters_gcc}\")" >> ${OFN}
        echo 'elseif ( MSVC )' >> ${OFN}
        echo "  set ( CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE} \"\${CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE}} ${parameters_msvc}\")" >> ${OFN}
        echo "  set ( CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE} \"\${CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE}} ${parameters_msvc}\")" >> ${OFN}
        echo 'endif()' >> ${OFN}
    fi
}

binary_resource_parse()
{
    local parse_file="${1}"
    local line=""
    local binary_array_first_def=""
    local binary_mask_first_def=""

    if [ -n "${parse_file}" ] && [ -f "${parse_file}" ]; then
        local -a binary_array_names
        local -a binary_array_names_library
        while read line; do
            if [ -n "${line}" ]; then
                local parameter="$(string_get_before_parenthesis "${line}")"
                parameter="$(string_trim_spaces_both "${parameter}")"
                local options="$(string_get_in_parenthesis "${line}")"
                OLD_IFS=${IFS}; IFS=','; read -d '' -ra options_params < <(printf '%s\0' "${options}"); IFS=${OLD_IFS}

                if [ "${parameter}" == "BINARY_ARRAY" ]; then
                    local symbol_name=$(string_trim_spaces_both "${options_params[0]}")
                    local symbol_name_array=$(string_trim_spaces_both "${options_params[1]}")
                    local symbol_file_name=`echo "${options_params[2]}" | sed 's/.*"\(.*\)".*$/\1/'`
                    local symbol_file_compress=`echo "${options_params[3]}" | sed 's/.*" \(.*\)$/\1/'`
                else
                    local symbol_name=$(string_trim_spaces_both "${options_params[0]}")
                    local symbol_file_name=`echo "${options_params[1]}" | sed 's/.*"\(.*\)".*$/\1/'`
                    local symbol_file_compress=`echo "${options_params[1]}" | sed 's/.*" \(.*\)$/\1/'`
                fi

                if [ -z "${symbol_file_compress}" ]; then
                    symbol_file_compress="none"
                fi

                # Parse BINARY resources
                if [ "${parameter}" == "BINARY" ]; then

                    echo >> ${OFN}
                    echo "# BINARY file" >> ${OFN}
                    echo "create_brc_source ( ${symbol_file_name} ${symbol_name}.cpp ${symbol_name} ${symbol_file_compress} write )" >> ${OFN}
                    echo "set_source_files_properties ( \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp PROPERTIES GENERATED TRUE )" >> ${OFN}
                    echo "list ( APPEND ${SOURCE_LIST_CPP} \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp )" >> ${OFN}

                # parse BINARY_ARRAY resources
                elif [ "${parameter}" == "BINARY_ARRAY" ]; then

                    local file_creation="append"
                    if [ -z "${binary_array_first_def}" ]; then
                        binary_array_first_def="done"
                        file_creation="write"
                    fi

                    binary_array_names+=("${symbol_name}_${symbol_name_array}")

                    echo >> ${OFN}
                    echo "# BINARY_ARRAY file" >> ${OFN}
                    echo "create_brc_source ( ${symbol_file_name} binary_array.cpp ${symbol_name}_${symbol_name_array} ${symbol_file_compress} ${file_creation} )" >> ${OFN}
                # parse BINARY_MASK resources
                elif [ "${parameter}" == "BINARY_MASK" ]; then

                    local -a binary_mask_files="($(eval echo "${symbol_file_name}"))"

                    if [ -n "${binary_mask_files}" ]; then
                        local all_count=0
                        local binary_file=""
                        local -a all_array_files

                        for binary_file in "${binary_mask_files[@]}"; do
                            if [ -f "${binary_file}" ]; then

                                local file_creation="append"
                                if [ -z "${binary_mask_first_def}" ]; then
                                    binary_mask_first_def="done"
                                    file_creation="write"
                                fi

                                echo >> ${OFN}
                                echo "# BINARY_MASK file" >> ${OFN}
                                echo "create_brc_source ( ${binary_file} ${symbol_name}.cpp ${symbol_name}_${all_count} ${symbol_file_compress} ${file_creation} )" >> ${OFN}

                                all_array_files+=("$(basename "${binary_file}")")
                                (( all_count++ ))
                            fi
                        done

                        # Generate cpp file for the BINARY_MASK
                        echo >> ${OFN}
                        echo "# Append additional information of the BINARY_MASK binary resource (${symbol_name})" >> ${OFN}
                        echo "file ( APPEND \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp \"" >> ${OFN}
                        echo "int ${symbol_name}_count = ${all_count};" >> ${OFN}

                        echo "int ${symbol_name}_length[] = {" >> ${OFN}
                        for (( i=0; i<${all_count}; i++ )); do
                            echo "  ${symbol_name}_${i}_length," >> ${OFN}
                        done
                        echo "};" >> ${OFN}

                        echo "unsigned char *${symbol_name}[] = {" >> ${OFN}
                        for (( i=0; i<${all_count}; i++ )); do
                            echo "  ${symbol_name}_${i}_," >> ${OFN}
                        done
                        echo "};" >> ${OFN}

                        echo "char const *${symbol_name}_files[] = {" >> ${OFN}
                        local binary_filename=""
                        for binary_file_name in "${all_array_files[@]}"; do
                            echo "  \\\"${binary_file_name}\\\"," >> ${OFN}
                        done
                        echo "};" >> ${OFN}

                        echo "\")" >> ${OFN}
                        echo "set_source_files_properties ( \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp PROPERTIES GENERATED TRUE )" >> ${OFN}
                        echo "list ( APPEND ${SOURCE_LIST_CPP} \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp )" >> ${OFN}

                    else
                        echo >> ${OFN}
                        echo "# BINARY_MASK file" >> ${OFN}
                        echo "# No files match the mask: '${symbol_file_name}'" >> ${OFN}
                    fi

                fi # BINARY end
            fi
        done < "${parse_file}"

        # Generate cpp file for the BINARY_ARRAY
        if [ -n "${binary_array_names}" ]; then
            local -a binary_array_names_sorted
            OLD_IFS="${IFS}"; export LC_ALL=C; IFS=$'\n' binary_array_names_sorted=($(sort -u <<<"${binary_array_names[*]}")); IFS="${OLD_IFS}"

#           echo "# ${binary_array_names[@]}" >> ${OFN}
#           echo "# ${binary_array_names_sorted[@]}" >> ${OFN}

            local test_first_iteration
            local binary_array_name_count=0
            local binary_array_name_test
            local binary_array_name_first
            local binary_array_name_second

            echo >> ${OFN}
            echo "# Append additional information of the BINARY_ARRAY binary resource (${symbol_name})" >> ${OFN}
            echo "file ( APPEND \${CMAKE_CURRENT_BINARY_DIR}/binary_array.cpp \"" >> ${OFN}

            for binary_array_record in "${binary_array_names_sorted[@]}"; do
                binary_array_name_split=(${binary_array_record//_/ })
                if [ ! "${binary_array_name_split[0]}" == "${binary_array_name_test}" ]; then
                    if [ -z ${test_first_iteration} ]; then
                        test_first_iteration="done"
                    else
                        echo "int ${binary_array_name_test}_count = ${binary_array_name_count};" >> ${OFN}
                        echo -e "${binary_array_name_first}" >> ${OFN}
                        echo -e "};\n" >> ${OFN}
                        echo -e "${binary_array_name_second}" >> ${OFN}
                        echo -e "};\n" >> ${OFN}
                        binary_array_name_count=0
                    fi
                    binary_array_name_test=${binary_array_name_split[0]};
                    binary_array_name_first="int ${binary_array_name_split[0]}_length[] = {"
                    binary_array_name_second="unsigned char *${binary_array_name_split[0]}[] = {"
                fi
                (( binary_array_name_count++ ))
                binary_array_name_first+="\n    ${binary_array_record}_length,"
                binary_array_name_second+="\n   ${binary_array_record}_,"
            done
            echo "int ${binary_array_name_test}_count = ${binary_array_name_count};" >> ${OFN}
            echo -e "${binary_array_name_first}" >> ${OFN}
            echo -e "};" >> ${OFN}
            echo -e "${binary_array_name_second}" >> ${OFN}
            echo -e "};" >> ${OFN}
            echo "\")" >> ${OFN}
            echo "set_source_files_properties ( \${CMAKE_CURRENT_BINARY_DIR}/binary_array.cpp PROPERTIES GENERATED TRUE )" >> ${OFN}
            echo "list ( APPEND ${SOURCE_LIST_CPP} \${CMAKE_CURRENT_BINARY_DIR}/binary_array.cpp )" >> ${OFN}
        fi
    else
        echo "File \"${parse_file}\" not found!"
    fi
}

generate_cmake_header()
{
    cat > ${OFN} << EOL
# ${OFN} generated $(export LC_ALL=C; date)
cmake_minimum_required ( VERSION 2.8.10 )

#################################################
# In-Source builds are strictly prohibited.
#################################################
if ( \${CMAKE_SOURCE_DIR} STREQUAL \${CMAKE_BINARY_DIR} )
  message ( FATAL_ERROR
  "\n****************************** ERROR ******************************\n"
  "In-source build are not allowed. "
  "Please do not polute the sources with binaries or any project unrelated files. "
  "To remove generated files run:\n"
  "'rm -rf CMakeCache.txt CMakeFiles'\n"
  "To build the project, please do the following:\n"
  "'mkdir build && cd build && cmake ..'"
  "\n****************************** ERROR ******************************\n")
endif()

# Set the default library directory to store built libraries
set ( LIBRARY_OUTPUT_PATH \${PROJECT_BINARY_DIR}/lib )
EOL
}

generate_cmake_from_upp()
{
    local upp_ext="${1}"
    local object_name="${2}"
    local main_target="${3}"
    local USES=()
    local HEADER=()
    local SOURCE_C=()
    local SOURCE_CPP=()
    local SOURCE_RC=()
    local SOURCE_ICPP=()
    local OPTIONS=()
    local depend_start=0
    local options_start=0
    local files_start=0
    local mainconfig_start=0
    local tmp=""
    local list=""
    local line=""
    local line_array=()

    if [ -f "${upp_ext}" ]; then
        local target_name="$(string_replace_dash "${object_name}")"

        # _start: 0 = not in the block, 1 = in the block, 2 = in the block with the end, -1 = block done
        while read line; do
            # Parse compiler options
            if [[ ${line} =~ $RE_USES ]]; then
                list_parse "${line}" ${target_name}_${DEPEND_LIST}
            fi

            # Parse library options
            if [[ ${line} =~ $RE_LIBRARY ]]; then
                list_parse "${line}" ${LINK_LIST} "${target_name}"
            fi

            # Begin of the options section
            if [[ ${line} =~ $RE_OPTIONS ]]; then
                options_start=1
                # Parse project options with the condition
                if [[ ${line} =~ '(' ]] && [[ ${line} =~ ';' ]]; then
                    list_parse "${line}" ${COMPILE_FLAGS_LIST} "${target_name}"
                    options_start=0
                fi
                continue;
            fi

            # End of the options section (line with ';')
            if [ ${options_start} -gt 0 ] && [[ ${line} =~ ';' ]]; then
                options_start=2
            fi

            # Parse link options
            if [[ ${line} =~ $RE_LINK ]]; then
                link_parse "${line}" "${target_name}"
            fi

            # Begin of the dependency section
            if [[ ${line} =~ $RE_DEPEND ]]; then
                depend_start=1
                continue
            fi

            # End of the dependency section (line with ';')
            if [ ${depend_start} -gt 0 ] && [[ ${line} =~ ';' ]]; then
                depend_start=2
            fi

            # Begin of the files section
            if [[ ${line} =~ $RE_FILES ]]; then
                files_start=1
                continue
            fi

            # End of the files section (line with ';')
            if [ ${files_start} -gt 0 ] && [[ ${line} =~ ';' ]]; then
                files_start=2
            fi

            # Begin of the mainconfig section
            if [[ ${line} =~ $RE_MAINCONFIG ]]; then
                mainconfig_start=1
                continue
            fi

            # End of the mainconfig section (line with ';')
            if [ ${mainconfig_start} -gt 0 ] && [[ ${line} =~ ';' ]]; then
                mainconfig_start=2
            fi

            # Skip lines with "separator" mark
            if [ ${files_start} -gt 0 ] && [[ ${line} =~ $RE_SEPARATOR ]]; then
                continue;
            fi

            # Parse file names
            if [ ${files_start} -gt 0 ]; then
                # Find precompiled header option
                if [[ "${line}" =~ $RE_FILE_PCH ]] && [[ "${line}" =~ BUILDER_OPTION ]]; then
                    local pch_file=${line// */}
                    echo >> ${OFN}
                    echo '# Precompiled headers file' >> ${OFN}
                    echo "set ( ${PCH_FILE} "\${CMAKE_CURRENT_SOURCE_DIR}/${pch_file}" )" >> ${OFN}
                fi

                # Split lines with charset, options, ...
                if [[ "${line}" =~ $RE_FILE_SPLIT ]]; then
                    line="${line// */}"
                fi

                line_array=(${line})
                for list in "${line_array[@]}"; do
                    list=${list//,}
                    list=${list//;}

                    if [[ "${list}" =~ $RE_FILE_EXCLUDE ]]; then
                        continue;
                    fi

                    if [ -d "${list}" ]; then
                        if [ "${GENERATE_VERBOSE}" == "1" ]; then
                            echo "WARNING - directory \"${list}\" can't be added to the list."
                        fi
                    elif [ ! -f "${list}" ]; then
                        if [ "${GENERATE_VERBOSE}" == "1" ]; then
                            echo "WARNING - file \"${list}\" doesn't exist! It was not added to the list."
                        fi
                    else
                        if [[ ${list} =~ $RE_C ]]; then         # C/C++ source files
                            SOURCE_C+=(${list})
                        elif [[ ${list} =~ $RE_CPP ]]; then     # C/C++ source files
                            SOURCE_CPP+=(${list})
                        elif [[ ${list} =~ $RE_RC ]]; then      # Windows resource config files
                            SOURCE_RC+=(${list})
                        elif [[ ${list} =~ $RE_ICPP ]]; then    # icpp C/C++ source files
                            SOURCE_ICPP+=(${list})
                        elif [[ ${list} =~ $RE_BRC ]]; then     # BRC resource files
                            $(binary_resource_parse "$list")
                            HEADER+=(${list})
                        elif [[ ${list} =~ $RE_FILE_DOT ]]; then  # header files
                            HEADER+=(${list})
                        fi
                    fi
                done
                if [ $files_start -eq 2 ]; then
                    files_start=-1
                fi
            fi

            # Parse dependency
            if [ ${depend_start} -gt 0 ]; then
                tmp="${line//,}"
                USES+=(${tmp//;})
                UPP_ALL_USES+=(${tmp//;})
                if [ $depend_start -eq 2 ]; then
                    depend_start=-1
                fi
            fi

            # Parse mainconfig
            if [ ${mainconfig_start} -gt 0 ]; then
                if [[ ${line} =~ "GUI" ]]; then
                    FLAG_GUI="1"
                fi
                if [[ ${line} =~ "MT" ]]; then
                    FLAG_MT="1"
                fi
                if [ $mainconfig_start -eq 2 ]; then
                    depend_start=-1
                fi
            fi

            # Parse options
            if [ ${options_start} -gt 0 ]; then
                tmp="${line//,}"
                OPTIONS+=(${tmp//;})
                if [ $options_start -eq 2 ]; then
                    options_start=-1
                fi
            fi

        done < <(sed 's#\\#/#g' "${upp_ext}")

        # Create project option definitions
        if [ -n "${OPTIONS}" ] ; then
            echo >> ${OFN}
            echo "add_definitions (" >> ${OFN}
            for list in "${OPTIONS[@]}"; do
                echo "${list}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Create header files list
        if [ -n "${HEADER}" ] ; then
            echo >> ${OFN}
            echo "list ( APPEND ${HEADER_LIST}" >> ${OFN}
            for list in "${HEADER[@]}"; do
                echo "      ${list}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Create C source files list
        if [ -n "${SOURCE_C}" ] ; then
            echo >> ${OFN}
            echo "list ( APPEND ${SOURCE_LIST_C}" >> ${OFN}
            for list in "${SOURCE_C[@]}"; do
                echo "      ${list}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Create CPP source files list
        if [ -n "${SOURCE_CPP}" ] ; then
            echo >> ${OFN}
            echo "list ( APPEND ${SOURCE_LIST_CPP}" >> ${OFN}
            for list in "${SOURCE_CPP[@]}"; do
                echo "      ${list}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Create icpp source files list
        if [ -n "${SOURCE_ICPP}" ] ; then
            echo >> ${OFN}
            echo "list ( APPEND ${SOURCE_LIST_ICPP}" >> ${OFN}
            for list in "${SOURCE_ICPP[@]}"; do
                echo "      ${list}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Create dependency list
        if [ -n "${USES}" ] ; then
            echo >> ${OFN}
            echo "list ( APPEND ${target_name}_${DEPEND_LIST}" >> ${OFN}
            for list in "${USES[@]}"; do
                local dependency_name="$(string_replace_dash "${list}")"
                echo "      ${dependency_name}${LIB_SUFFIX}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Copy Windows resource config file
        if [ -n "${main_target}" ] && [ -n "${SOURCE_RC}" ] ; then
            for list in "${SOURCE_RC[@]}"; do
                if [ -f "${list}" ]; then
                    echo >> ${OFN}
                    echo "# Copy Windows resource config file to the main program build directory" >> ${OFN}
                    local line_rc_params=()
                    while read line_rc; do
                        if [[ ${line_rc} =~ ICON ]]; then
                            line_rc_params=(${line_rc})
                            echo "file ( COPY \"${list}\" DESTINATION \${PROJECT_BINARY_DIR} )" >> ${OFN}
                            echo "file ( COPY ${line_rc_params[3]} DESTINATION \${PROJECT_BINARY_DIR} )" >> ${OFN}
                            break
                        fi
                    done < ${list}
                fi
            done
        fi

        echo >> ${OFN}
        echo '# icpp files processing' >> ${OFN}
        echo "foreach ( icppFile \${$SOURCE_LIST_ICPP} )" >> ${OFN}
        echo '  set ( output_file "${CMAKE_CURRENT_BINARY_DIR}/${icppFile}.cpp" )' >> ${OFN}
        echo '  file ( WRITE "${output_file}" "#include \"${CMAKE_CURRENT_SOURCE_DIR}/${icppFile}\"\n" )' >> ${OFN}
        echo "  list ( APPEND ${SOURCE_LIST_CPP} \${output_file} )" >> ${OFN}
        echo 'endforeach()' >> ${OFN}

        echo >> ${OFN}
        echo "# Module properties" >> ${OFN}
        echo "create_cpps_from_icpps()" >> ${OFN}
        echo "set_source_files_properties ( \${$HEADER_LIST} PROPERTIES HEADER_FILE_ONLY ON )" >> ${OFN}
        echo "add_library ( ${target_name}${LIB_SUFFIX} \${LIB_TYPE} \${$SOURCE_LIST_CPP} \${$SOURCE_LIST_C})" >> ${OFN}
        echo "target_include_directories ( ${target_name}${LIB_SUFFIX} PUBLIC \${${INCLUDE_LIST}} )" >> ${OFN}
        echo "set_property ( TARGET ${target_name}${LIB_SUFFIX} APPEND PROPERTY COMPILE_OPTIONS \"\${${COMPILE_FLAGS_LIST}}\" )" >> ${OFN}

        echo >> ${OFN}
        echo "# Module dependecies" >> ${OFN}
        echo "if ( ${target_name}_${DEPEND_LIST} )" >> ${OFN}
        echo "  add_dependencies ( ${target_name}${LIB_SUFFIX} \${${target_name}_$DEPEND_LIST} )" >> ${OFN}
        echo "endif()" >> ${OFN}

        echo >> ${OFN}
        echo "# Module link" >> ${OFN}
        echo "if ( ${target_name}_${DEPEND_LIST} OR ${LINK_LIST} )" >> ${OFN}
        echo "  target_link_libraries ( ${target_name}${LIB_SUFFIX} \${${target_name}_${DEPEND_LIST}} \${${LINK_LIST}} )" >> ${OFN}
        echo "endif()" >> ${OFN}

        echo >> ${OFN}
        echo '# Precompiled headers settings' >> ${OFN}
        echo "get_directory_property ( ${PCH_COMPILE_DEFINITIONS} COMPILE_DEFINITIONS )" >> ${OFN}
        echo "set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES ${COMPILE_FLAGS_LIST} \"\${${COMPILE_FLAGS_LIST}}\" )" >> ${OFN}
        echo "set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES ${PCH_FILE} \"\${${PCH_FILE}}\" )" >> ${OFN}
        echo "set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES ${PCH_INCLUDE_LIST} \"\${${INCLUDE_LIST}}\" )" >> ${OFN}
        echo "set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES ${PCH_COMPILE_DEFINITIONS} \"\${${PCH_COMPILE_DEFINITIONS}}\" )" >> ${OFN}
        echo >> ${OFN}
        echo "list ( LENGTH ${PCH_FILE} ${PCH_FILE}_LENGTH )" >> ${OFN}
        echo "if ( ${PCH_FILE}_LENGTH GREATER 1 )" >> ${OFN}
        echo '  message ( FATAL_ERROR "Precompiled headers list can contain only one header file!" )' >> ${OFN}
        echo 'endif()' >> ${OFN}
        echo "if ( ${PCH_FILE} AND DEFINED flagPCH )" >> ${OFN}
        echo "  get_filename_component ( PCH_NAME \${${PCH_FILE}} NAME )" >> ${OFN}
        echo "  set ( PCH_DIR \${PROJECT_PCH_DIR}/${target_name}${LIB_SUFFIX} )" >> ${OFN}
        echo '  set ( PCH_HEADER ${PCH_DIR}/${PCH_NAME} )' >> ${OFN}
        echo '  if ( ${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU" )' >> ${OFN}
        echo '      if ( ${CMAKE_VERBOSE_MAKEFILE} EQUAL 1 )' >> ${OFN}
        echo '        set ( PCH_INCLUDE_PARAMS " -H -Winvalid-pch -include ${PCH_HEADER}" )' >> ${OFN}
        echo '      else()' >> ${OFN}
        echo '        set ( PCH_INCLUDE_PARAMS " -Winvalid-pch -include ${PCH_HEADER}" )' >> ${OFN}
        echo '      endif()' >> ${OFN}
        echo '  endif()' >> ${OFN}
        echo '  if ( ${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" )' >> ${OFN}
        echo '      set ( PCH_INCLUDE_PARAMS " -Winvalid-pch -include-pch ${PCH_HEADER}.pch" )' >> ${OFN}
        echo '  endif()' >> ${OFN}
        echo '  if ( MSVC )' >> ${OFN}
        echo "      set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES COMPILE_FLAGS \"-Yu\${PCH_NAME} -Fp\${PCH_HEADER}.pch\" )" >> ${OFN}
        echo "      set_source_files_properties ( \${$SOURCE_LIST_CPP} PROPERTIES COMPILE_FLAGS \"Yc\${PCH_NAME} -Fp\${PCH_HEADER}.pch\" )" >> ${OFN}
        echo '  endif()' >> ${OFN}
        echo '  if ( PCH_INCLUDE_PARAMS )' >> ${OFN}
        echo "      set_source_files_properties ( \${$SOURCE_LIST_CPP} PROPERTIES COMPILE_FLAGS \"\${PCH_INCLUDE_PARAMS}\" )" >> ${OFN}
        echo '  endif()' >> ${OFN}
        echo 'endif()' >> ${OFN}
        echo >> ${OFN}

    fi
}

generate_cmake_file()
{
    local param1="$(string_remove_comma "${1}")"
    local param2="$(string_remove_comma "${2}")"
    local cur_dir=$(pwd)
    local sub_dir=$(dirname "${param1}")
    local upp_name=$(basename "${param1}")
    local object_name="${param2}"
    local cmake_flags="${3}"

    if [ "${GENERATE_VERBOSE}" == "1" ]; then
        echo "full path: ${cur_dir}"
        echo "sub_dir: ${sub_dir}"
        echo "upp_name: ${upp_name}"
        echo "object_name: ${object_name}"
    fi

    if [ -f "${sub_dir}/${OFN}" ] && [ "${GENERATE_VERBOSE}" == "1" ]; then
        echo "File \"${sub_dir}/${OFN}\" already exist!"
    fi

    if [ -f "${sub_dir}/${upp_name}" ]; then
        cd ${sub_dir}

        generate_cmake_header

        if [ -n "${cmake_flags}" ]; then
            echo >> ${OFN}
            echo "# Module definitions" >> ${OFN}
            echo "add_definitions ( "${cmake_flags}" )" >> ${OFN}
        fi

        local main_target=""
        if [[ ${cmake_flags} =~ (flagMAIN) ]]; then
            main_target="true"
        fi

        generate_cmake_from_upp "${upp_name}" "${object_name}" "${main_target}"

        cd ${cur_dir}
    else
        echo "File \"${sub_dir}/${upp_name}\" doesn't exist!"
    fi

    if [ "${GENERATE_VERBOSE}" == "1" ]; then
        echo "--------------------------------------------------------------------"
    fi
}

get_upp_to_process()
{
    local -a upp_all_only
    local upp_all
    local upp_all_done

    for upp_all in "${UPP_ALL_USES[@]}"; do
        local in_both=""
        for upp_all_done in "${UPP_ALL_USES_DONE[@]}"; do
            [ "${upp_all}" = "$upp_all_done" ] && in_both="Yes"
        done
        if [ ! "${in_both}" ]; then
          upp_all_only+=("${upp_all}")
        fi
    done

    if [ -n "${upp_all_only}" ]; then
        echo "${upp_all_only[0]}"
    fi

}

generate_package_file()
{
    if [ -z "${PROJECT_NAME}" ]; then
        echo "ERROR - Variable \$PROJECT_NAME is not defined! Can't create archive package!"
    else
        echo -n "Creating archive "

        local -a sorted_UPP_ALL_USES_DONE=$(printf "%s\n" "${UPP_ALL_USES_DONE[@]}" | sort -u);

        local package_src_name_archive=$(basename ${PROJECT_NAME}).tar.bz2
        local package_src_name_archive_list="package_archive_list.txt"

        echo "CMakeLists.txt" > ${package_src_name_archive_list}

        find $(dirname ${PROJECT_NAME}) -name '*' -type f >> ${package_src_name_archive_list}

        echo "${UPP_SRC_DIR}/uppconfig.h" >> ${package_src_name_archive_list}
        echo "${UPP_SRC_DIR}/guiplatform.h" >> ${package_src_name_archive_list}

        for pkg_name in ${sorted_UPP_ALL_USES_DONE[@]}; do
            find ${UPP_SRC_DIR}/${pkg_name} -name '*' -type f >> ${package_src_name_archive_list}
        done

        tar -c -j -f ${package_src_name_archive} -T ${package_src_name_archive_list}
        rm ${package_src_name_archive_list}

        echo "... DONE"
    fi
}

generate_main_cmake_file()
{
    local main_target="${1}"
    local main_definitions="${2//\"}"
    local main_target_dirname=$(dirname "${1}")
    local main_target_basename=$(basename "${1}")
    local main_target_name="${main_target_basename%%.*}"

    if [ ! -f "${main_target}" ]; then
        echo "Usage: generate_main_cmake_file <full path to the ultimate++ project file> [build flags]"
        echo
        echo "ERROR - Target \"${main_target}\" doesn't exist!"
        exit 1
    fi

    test_required_binaries

    generate_cmake_file "${main_target}" "${main_target_name}" "-DflagMAIN"

    generate_cmake_header

    if [ -z "${GENERATE_NOT_C11}" ] || [ "${GENERATE_NOT_C11}" != "1" ]; then
        main_definitions+=" -DflagGNUC11"
    fi

    if [ -z "${GENERATE_NOT_PARALLEL}" ] || [ "${GENERATE_NOT_PARALLEL}" != "1" ]; then
        main_definitions+=" -DflagMP"
    fi

    if [ -z "${GENERATE_NOT_PCH}" ] || [ "${GENERATE_NOT_PCH}" != "1" ]; then
        main_definitions+=" -DflagPCH"
    fi

#    if [ -n "${FLAG_MT}" ]; then
#        echo 'add_definitions ( -DflagMT )' >> ${OFN}
#    fi
#    if [ -n "${FLAG_GUI}" ]; then
#        echo 'add_definitions ( -DflagGUI )' >> ${OFN}
#    fi

    # Begin of the cat (CMakeFiles.txt)
    cat >> ${OFN} << EOL

# Set the project common path
set ( UPP_SOURCE_DIRECTORY ${UPP_SRC_DIR} )
set ( PROJECT_INC_DIR \${PROJECT_BINARY_DIR}/inc )
set ( PROJECT_PCH_DIR \${PROJECT_BINARY_DIR}/pch )

# Set the default include directory for the whole project
include_directories ( BEFORE \${UPP_SOURCE_DIRECTORY} )
include_directories ( BEFORE \${PROJECT_INC_DIR} )

# Set the default path for built executables to the bin directory
set ( EXECUTABLE_OUTPUT_PATH \${PROJECT_BINARY_DIR}/bin )

# Project definitions
add_definitions ( ${main_definitions} )

# Read compiler definitions - used to set appropriate modules
get_directory_property ( FlagDefs COMPILE_DEFINITIONS )

# Platform flags settings
if ( WIN32 )
  remove_definitions( -DflagPOSIX )
  remove_definitions( -DflagLINUX )
  remove_definitions( -DflagFREEBSD )
  remove_definitions( -DflagSOLARIS )

  if ( NOT "\${FlagDefs}" MATCHES "flagWIN32" )
    add_definitions ( -DflagWIN32 )
  endif()

else()
  remove_definitions( -DflagWIN32 )

  if ( NOT "\${FlagDefs}" MATCHES "POSIX" )
    add_definitions ( -DflagPOSIX )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "Linux" AND NOT "\${FlagDefs}" MATCHES "flagLINUX" )
    add_definitions( -DflagLINUX )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "FreeBSD" AND NOT "\${FlagDefs}" MATCHES "flagFREEBSD" )
    add_definitions( -DflagFREEBSD )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "Solaris" AND NOT "\${FlagDefs}" MATCHES "flagSOLARIS" )
    add_definitions( -DflagSOLARIS )
  endif()

endif()
get_directory_property ( FlagDefs COMPILE_DEFINITIONS )

# Set GCC builder flag
if ( CMAKE_COMPILER_IS_GNUCC )
  remove_definitions ( -DflagMSC )

  if ( NOT "\${FlagDefs}" MATCHES "flagGCC(;|$)" )
    add_definitions( -DflagGCC )
  endif()

  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()

# Check supported compilation architecture environment
if ( "\${FlagDefs}" MATCHES "flagGCC32" OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8 )
  set ( STATUS_COMPILATION "32" )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -m32" )
else()
  set ( STATUS_COMPILATION "64" )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -m64" )
  set ( MSVC_ARCH "X64" )
endif()
message ( STATUS "Build compilation: \${STATUS_COMPILATION} bits" )

# Set MSVC builder flags
if ( MSVC )
  remove_definitions( -DflagGCC )

  if ( NOT "\${FlagDefs}" MATCHES "flagMSC(;|$)" )
    add_definitions ( -DflagMSC )
  endif()

  if ( \${MSVC_VERSION} EQUAL 1200 )
      add_definitions ( -DflagMSC6\${MSVC_ARCH} )
  endif()
  if ( \${MSVC_VERSION} EQUAL 1300 OR \${MSVC_VERSION} EQUAL 1310)
      add_definitions ( -DflagMSC7\${MSVC_ARCH} )
      add_definitions ( -DflagMSC71\${MSVC_ARCH} )
  endif()
  if ( \${MSVC_VERSION} EQUAL 1400 )
      add_definitions ( -DflagMSC8\${MSVC_ARCH} )
  endif()
  if ( \${MSVC_VERSION} EQUAL 1500 )
      add_definitions ( -DflagMSC9\${MSVC_ARCH} )
  endif()
  if ( \${MSVC_VERSION} EQUAL 1600 )
      add_definitions ( -DflagMSC10\${MSVC_ARCH} )
  endif()
  if ( \${MSVC_VERSION} EQUAL 1700 )
      add_definitions ( -DflagMSC11\${MSVC_ARCH} )
  endif()
  if ( \${MSVC_VERSION} EQUAL 1800 )
      add_definitions ( -DflagMSC12\${MSVC_ARCH} )
  endif()
  if ( \${MSVC_VERSION} EQUAL 1900 )
      add_definitions ( -DflagMSC14\${MSVC_ARCH} )
  endif()

  if ( "\${FlagDefs}" MATCHES "flagMP" AND NOT \${MSVC_VERSION} LESS 1400 )
    set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -MP" )
  endif()

  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()

# Set Intel builder flag
if ( \${CMAKE_CXX_COMPILER_ID} STREQUAL "Intel" AND NOT "\${FlagDefs}" MATCHES "flagINTEL" )
  add_definitions( -DflagINTEL )
  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()

# Set CLANG compiler flags
if ( \${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" )
  set ( CMAKE_COMPILER_IS_CLANG TRUE )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -Wno-logical-op-parentheses" )
endif()

# Set link directories on BSD systems
if ( \${CMAKE_SYSTEM_NAME} MATCHES BSD )
    link_directories ( /usr/local/lib )
endif()

# Set debug/release compiler options
if ( "\${FlagDefs}" MATCHES "flagDEBUG" )
  set ( CMAKE_VERBOSE_MAKEFILE 1 )
  set ( CMAKE_BUILD_TYPE DEBUG )
  add_definitions ( -D_DEBUG )

  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -O0" )

  if ( NOT "\${FlagDefs}" MATCHES "(flagDEBUG)(;|$)" )
      add_definitions ( -DflagDEBUG )
      get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
  endif()

  if ( MSVC )
      if ( "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14)X64" )
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -debug -OPT:NOREF" )
      else()
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -incremental:yes -debug -OPT:NOREF" )
      endif()
  endif()

else()
  set ( CMAKE_VERBOSE_MAKEFILE 0 )
  set ( CMAKE_BUILD_TYPE RELEASE )
  add_definitions ( -D_RELEASE )

  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -O3" )
  set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -GS-" )

  if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )
      set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -ffunction-sections -fdata-sections" )
      set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -Wl,-s,--gc-sections" )
  endif()

  if ( MSVC )
      if ( "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14)X64" )
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -release -OPT:REF,ICF" )
      else()
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -incremental:no -release -OPT:REF,ICF" )
      endif()
  endif()

endif()
message ( STATUS "Build type: " \${CMAKE_BUILD_TYPE} )

if ( "\${FlagDefs}" MATCHES "flagDEBUG_MINIMAL" )
  if ( NOT MINGW )
      set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -ggdb" )
  endif()
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -g1" )
  set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -Zd" )
endif()

if ( "\${FlagDefs}" MATCHES "flagDEBUG_FULL" )
  if ( NOT MINGW )
      set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -ggdb" )
  endif()
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -g2" )
  set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -Zi" )
endif()

# Set static/shared compiler options
if ( "\${FlagDefs}" MATCHES "(flagSO)(;|$)" )
  set ( BUILD_SHARED_LIBS ON )
  set ( LIB_TYPE SHARED )
  if ( NOT "\${FlagDefs}" MATCHES "(flagSHARED)(;|$)" )
      add_definitions ( -DflagSHARED )
      get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
  endif()
endif()

if ( "\${FlagDefs}" MATCHES "flagSHARED" )
  set ( STATUS_SHARED "TRUE" )
  set ( EXTRA_GXX_FLAGS "\${EXTRA_GXX_FLAGS} -fuse-cxa-atexit" )
else()
  set ( STATUS_SHARED "FALSE" )
  set ( BUILD_SHARED_LIBS OFF )
  set ( LIB_TYPE STATIC )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -static -fexceptions" )

  if ( MINGW )
      set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -static-libgcc" )
  endif()

endif()
message ( STATUS "Build with flagSHARED: \${STATUS_SHARED}" )

# Precompiled headers support
if ( "\${FlagDefs}" MATCHES "flagPCH" )
  if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )
    if ( \${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 3.4 )
        message ( WARNING
            "Precompiled headers are introduced with GCC 3.4.\n"
            "No support of the PCH in any earlier releases. (current version \${CMAKE_CXX_COMPILER_VERSION})." )
        remove_definitions ( -DflagPCH )
    endif()
    if ( \${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 3.5 )
        message ( WARNING
            "There are some problems with precompiled headers in Clang version less 3.5.\n"
            "No support of the PCH in any earlier releases. (current version \${CMAKE_CXX_COMPILER_VERSION})." )
        remove_definitions ( -DflagPCH )
    endif()
  else()
    remove_definitions ( -DflagPCH )
  endif()

  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()

if ( "\${FlagDefs}" MATCHES "flagPCH" )
  message ( STATUS "Build with flagPCH: TRUE" )
else()
  message ( STATUS "Build with flagPCH: FALSE" )
endif()

# Main configuration flags (MT, GUI, DLL)
if ( "\${FlagDefs}" MATCHES "flagMT" )
  find_package ( Threads REQUIRED )
  if ( THREADS_FOUND )
      include_directories ( \${THREADS_INCLUDE_DIRS} )
      list ( APPEND main_${LINK_LIST} \${THREADS_LIBRARIES} )
  endif()
endif()

# Set compiler options
if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )
  if ( "\${FlagDefs}" MATCHES "flagGNUC11" )
    set ( EXTRA_GXX_FLAGS "\${EXTRA_GXX_FLAGS} -std=c++11" )
  endif()

  if ( MINGW )
      get_directory_property ( FlagDefs COMPILE_DEFINITIONS )

      set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -mwindows" )

      if ( "\${FlagDefs}" MATCHES "flagDLL" )
          set ( BUILD_SHARED_LIBS ON )
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -shared" )
          string ( REGEX REPLACE "-static " "" CMAKE_EXE_LINKER_FLAGS \${CMAKE_EXE_LINKER_FLAGS} )
      endif()

      if ("\${FlagDefs}" MATCHES "flagGUI" )
          list ( APPEND main_${LINK_LIST} mingw32 )
      else()
          set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -mconsole" )
      endif()

      if ( "\${FlagDefs}" MATCHES "flagMT" )
          set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -mthreads" )
      endif()

      # The optimalization might be broken on MinGW - remove optimalization flag (cross compile).
      string ( REGEX REPLACE "-O3" "" EXTRA_GCC_FLAGS \${EXTRA_GCC_FLAGS} )

      get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
  endif()

  set ( CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE} "\${CMAKE_CXX_FLAGS_\${BUILD_TYPE}} \${EXTRA_GXX_FLAGS} \${EXTRA_GCC_FLAGS}" )
  set ( CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE} "\${CMAKE_C_FLAGS_\${BUILD_TYPE}} \${EXTRA_GCC_FLAGS}" )

  set ( CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> rs <TARGET> <LINK_FLAGS> <OBJECTS>" )
  set ( CMAKE_CXX_ARCHIVE_APPEND "<CMAKE_AR> rs <TARGET> <LINK_FLAGS> <OBJECTS>" )
  set ( CMAKE_C_ARCHIVE_CREATE "<CMAKE_AR> rs <TARGET> <LINK_FLAGS> <OBJECTS>" )
  set ( CMAKE_C_ARCHIVE_APPEND "<CMAKE_AR> rs <TARGET> <LINK_FLAGS> <OBJECTS>" )

elseif ( MSVC )
  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )

  set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -nologo" )

  if ( "\${FlagDefs}" MATCHES "flagEVC" )
      if ( NOT "\${FlagDefs}" MATCHES "flagSH3" AND  NOT "\${FlagDefs}" MATCHES "flagSH4" )
          # disable stack checking
          set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -Gs8192" )
      endif()
      # read-only string pooling, turn off exception handling
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -GF -GX-" )
  elseif ( "\${FlagDefs}" MATCHES "flagCLR" )
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -EHac" )
  elseif ( "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9)ARM" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14)X64" )
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -EHsc" )
  else()
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -GX" )
  endif()

  if ( \${CMAKE_BUILD_TYPE} STREQUAL DEBUG )
      set ( EXTRA_MSVC_FLAGS_Mx "d" )
  endif()
  if ( "\${FlagDefs}" MATCHES "flagSHARED" OR "\${FlagDefs}" MATCHES "flagCLR" )
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -MD\${EXTRA_MSVC_FLAGS_Mx}" )
  else()
      if ( "\${FlagDefs}" MATCHES "flagMT" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9)ARM" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14)X64" )
          set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -MT\${EXTRA_MSVC_FLAGS_Mx}" )
      else()
          set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -ML\${EXTRA_MSVC_FLAGS_Mx}" )
      endif()
  endif()

  #,5.01 needed to support WindowsXP
  if ( NOT "\${FlagDefs}" MATCHES "(flagMSC(8|9|10|11|12|14)X64)" )
      set ( MSVC_LINKER_SUBSYSTEM ",5.01" )
  endif()
  if ( "\${FlagDefs}" MATCHES "flagMSC(8|9)ARM" )
      set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -subsystem:windowsce,4.20 /ARMPADCODE -NODEFAULTLIB:\"oldnames.lib\"" )
  else()
      if ( "\${FlagDefs}" MATCHES "flagGUI" OR "\${FlagDefs}" MATCHES "flagMSC(8|9)ARM" )
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -subsystem:windows\${MSVC_LINKER_SUBSYSTEM}" )
      else()
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -subsystem:console\${MSVC_LINKER_SUBSYSTEM}" )
      endif()
  endif()

  if ( "\${FlagDefs}" MATCHES "flagDLL" )
      set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -dll" )
  endif()

  set ( CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE} "\${CMAKE_CXX_FLAGS_\${BUILD_TYPE}} \${EXTRA_MSVC_FLAGS}" )
  set ( CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE} "\${CMAKE_C_FLAGS_\${BUILD_TYPE}} \${EXTRA_MSVC_FLAGS}" )
endif()

# Function to generate precompiled header
function ( generate_pch TARGET_NAME ${PCH_FILE} PCH_INCLUDE_DIRS )
    set ( PCH_OUTPUT_DIR \${PROJECT_PCH_DIR}/\${TARGET_NAME} )
    get_filename_component ( PCH_NAME \${${PCH_FILE}} NAME )
    get_filename_component ( TARGET_DIR \${${PCH_FILE}} PATH )

    file ( COPY \${PCH_FILE} DESTINATION \${PCH_OUTPUT_DIR} )

    # Prepare compile flag definition
    get_target_property ( ${COMPILE_FLAGS_LIST} \${TARGET_NAME} ${COMPILE_FLAGS_LIST} )
    string ( REGEX REPLACE ";" " " ${COMPILE_FLAGS_LIST} "\${${COMPILE_FLAGS_LIST}}" )
    set ( compile_flags "\${CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE}} \${${COMPILE_FLAGS_LIST}}" )

    # Add copied header file directory
    # That directory is searched before (or instead of) the directory containing the original header
    # Commented out due to problem with the main target compilation ( it is not necessary to include this dir )
    #list ( APPEND compile_flags "-I\${PCH_OUTPUT_DIR}" )

    # Add main target defined include directories
    get_directory_property ( include_directories DIRECTORY \${CMAKE_CURRENT_SOURCE_DIR} INCLUDE_DIRECTORIES )
    foreach ( include_dir \${include_directories} )
        list ( APPEND compile_flags "-I\${include_dir}" )
    endforeach()

    # Add source directory of the precompiled header file - can't be the first included directory
    list ( APPEND compile_flags "-iquote\${TARGET_DIR}" )

    # Add included directories of the external packages collected from defintions of all targets
    foreach ( include_dir \${PCH_INCLUDE_DIRS} )
        list ( APPEND compile_flags "-I\${include_dir}" )
    endforeach()

    # Add target compile definitions
    get_target_property ( ${PCH_COMPILE_DEFINITIONS} \${TARGET_NAME} ${PCH_COMPILE_DEFINITIONS} )
    foreach ( compile_def \${${PCH_COMPILE_DEFINITIONS}} )
        list ( APPEND compile_flags "-D\${compile_def}" )
    endforeach()

    list ( REMOVE_DUPLICATES compile_flags )
    separate_arguments ( compile_flags )

    # Prepare compilations options
    set ( PCH_BINARY_SUFFIX ".pch" )
    if ( \${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU" )
        set ( PCH_BINARY_SUFFIX ".gch" )
    endif()

    set ( PCH_HEADER "\${PCH_OUTPUT_DIR}/\${PCH_NAME}" )
    set ( PCH_BINARY "\${PCH_HEADER}\${PCH_BINARY_SUFFIX}" )
    set ( PCH_COMPILE_PARAMS -x c++-header -o \${PCH_BINARY} \${PCH_HEADER} )

    # Generate precompiled header file
    add_custom_command ( OUTPUT \${PCH_BINARY}
        COMMAND \${CMAKE_CXX_COMPILER} \${compile_flags} \${PCH_COMPILE_PARAMS}
        COMMENT "PCH for the file \${PCH_HEADER}"
    )

    add_custom_target ( \${TARGET_NAME}_gch DEPENDS \${PCH_BINARY} )
    add_dependencies ( \${TARGET_NAME} \${TARGET_NAME}_gch )
endfunction()

# Function to create cpp source from icpp files
function ( create_cpps_from_icpps )
  file ( GLOB icpp_files RELATIVE "\${CMAKE_CURRENT_SOURCE_DIR}" "\${CMAKE_CURRENT_SOURCE_DIR}/*.icpp" )
  foreach ( icppFile \${icpp_files} )
      set ( output_file "\${CMAKE_CURRENT_BINARY_DIR}/\${icppFile}.cpp" )
      file ( WRITE "\${output_file}" "#include \"\${CMAKE_CURRENT_SOURCE_DIR}/\${icppFile}\"\n" )
  endforeach()
endfunction()

# Function to create cpp source file from binary resource definition
function ( create_brc_source input_file output_file symbol_name compression symbol_append )
  if ( NOT EXISTS \${CMAKE_CURRENT_SOURCE_DIR}/\${input_file} )
      message ( FATAL_ERROR "Input file does not exist: \${CMAKE_CURRENT_SOURCE_DIR}/\${input_file}" )
  endif()

  file ( REMOVE \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name} )

  if ( \${compression} MATCHES "[bB][zZ]2" )
      find_program ( BZIP2_EXEC bzip2 )
      if ( NOT BZIP2_EXEC )
          message ( FATAL_ERROR "BZIP2 executable not found!" )
      endif()
      set ( COMPRESS_SUFFIX "bz2" )
      set ( COMMAND_COMPRESS \${BZIP2_EXEC} -k -f \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name} )
  elseif ( \${compression} MATCHES "[zZ][iI][pP]" )
      find_program ( ZIP_EXEC zip )
      if ( NOT ZIP_EXEC )
          message ( FATAL_ERROR "ZIP executable not found!" )
      endif()
      set ( COMPRESS_SUFFIX "zip" )
      set ( COMMAND_COMPRESS \${ZIP_EXEC} \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name}.\${COMPRESS_SUFFIX} \${symbol_name} )
  endif()

  file ( COPY \${CMAKE_CURRENT_SOURCE_DIR}/\${input_file} DESTINATION \${CMAKE_CURRENT_BINARY_DIR} )
  get_filename_component ( input_file_name \${CMAKE_CURRENT_SOURCE_DIR}/\${input_file} NAME )
  file ( RENAME \${CMAKE_CURRENT_BINARY_DIR}/\${input_file_name} \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name} )
  if ( COMMAND_COMPRESS )
      execute_process ( COMMAND \${COMMAND_COMPRESS} WORKING_DIRECTORY \${CMAKE_CURRENT_BINARY_DIR} OUTPUT_VARIABLE XXXX )
      file ( RENAME \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name}.\${COMPRESS_SUFFIX} \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name} )
  endif()

  file ( READ \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name} hex_string HEX )

  set ( CUR_INDEX 0 )
  string ( LENGTH "\${hex_string}" CUR_LENGTH )
  math ( EXPR FILE_LENGTH "\${CUR_LENGTH} / 2" )
  set ( \${hex_string} 0)

  set ( output_string "static unsigned char \${symbol_name}_[] = {\n" )
  while ( CUR_INDEX LESS CUR_LENGTH )
      string ( SUBSTRING "\${hex_string}" \${CUR_INDEX} 2 CHAR )
      set ( output_string "\${output_string} 0x\${CHAR}," )
      math ( EXPR CUR_INDEX "\${CUR_INDEX} + 2" )
  endwhile()
  set ( output_string "\${output_string} 0x00 }\;\n\n" )
  set ( output_string "\${output_string}unsigned char *\${symbol_name} = \${symbol_name}_\;\n\n" )
  set ( output_string "\${output_string}int \${symbol_name}_length = \${FILE_LENGTH}\;\n\n" )

  if ( \${symbol_append} MATCHES "append" )
      file ( APPEND \${CMAKE_CURRENT_BINARY_DIR}/\${output_file} \${output_string} )
  else()
      file ( WRITE \${CMAKE_CURRENT_BINARY_DIR}/\${output_file} \${output_string} )
  endif()
endfunction()

# Initialize definition flags (flags are used during targets compilation)
get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
foreach( comp_def \${FlagDefs} )
  set ( \${comp_def} 1 )
endforeach()

EOL
# End of the cat (CMakeFiles.txt)

    echo '# Include dependent directories of the project' >> ${OFN}
    while [ ${#UPP_ALL_USES_DONE[@]} -lt ${#UPP_ALL_USES[@]} ]; do
        local process_upp=$(get_upp_to_process)
#        echo "num of elements all : ${#UPP_ALL_USES[@]}"
#        echo "num of elements done: ${#UPP_ALL_USES_DONE[@]}"
#        echo "process_upp=\"${process_upp}\""

        if [ -n "${process_upp}" ]; then
            if [[ ${process_upp} =~ '/' ]]; then
                tmp_upp_name="$(basename ${process_upp}).upp"
                generate_cmake_file ${UPP_SRC_DIR}/${process_upp}/${tmp_upp_name} "${process_upp}"
            else
                generate_cmake_file ${UPP_SRC_DIR}/${process_upp}/${process_upp}.upp "${process_upp}"
            fi
            echo "add_subdirectory ( ${UPP_SRC_DIR}/${process_upp} )" >> ${OFN}
        fi

        UPP_ALL_USES_DONE+=("${process_upp}")
    done

    echo "add_subdirectory ( ${main_target_dirname} )" >> ${OFN}

    local -a array_library=$(printf "%s\n" "${UPP_ALL_USES_DONE[@]}" | sort -u | sed 's#/#_#g');
    local library_dep="${main_target_name}${LIB_SUFFIX};"
    for list_library in ${array_library[@]}; do
        library_dep+="${list_library}${LIB_SUFFIX};"
    done

    # Begin of the cat (CMakeFiles.txt)
    cat >> ${OFN} << EOL

# Creation of the file build_info.h
set ( BUILD_INFO_H \${PROJECT_INC_DIR}/build_info.h )
string ( TIMESTAMP bmYEAR %Y )
string ( TIMESTAMP bmMONTH %m )
string ( TIMESTAMP bmDAY %d )
string ( TIMESTAMP bmHOUR %H )
string ( TIMESTAMP bmMINUTE %M )
string ( TIMESTAMP bmSECOND %S )
string ( REGEX REPLACE "^0(.*)" \\\\1 bmMONTH \${bmMONTH} )
string ( REGEX REPLACE "^0(.*)" \\\\1 bmDAY \${bmDAY} )
string ( REGEX REPLACE "^0(.*)" \\\\1 bmHOUR \${bmHOUR} )
string ( REGEX REPLACE "^0(.*)" \\\\1 bmMINUTE \${bmMINUTE} )
string ( REGEX REPLACE "^0(.*)" \\\\1 bmSECOND \${bmSECOND} )
cmake_host_system_information ( RESULT bmHOSTNAME QUERY HOSTNAME )
file ( WRITE  \${BUILD_INFO_H} "#define bmYEAR \${bmYEAR}\n#define bmMONTH \${bmMONTH}\n#define bmDAY \${bmDAY}\n" )
file ( APPEND \${BUILD_INFO_H} "#define bmHOUR \${bmHOUR}\n#define bmMINUTE \${bmMINUTE}\n#define bmSECOND \${bmSECOND}\n" )
file ( APPEND \${BUILD_INFO_H} "#define bmTIME Time(\${bmYEAR}, \${bmMONTH}, \${bmDAY}, \${bmHOUR}, \${bmMINUTE}, \${bmSECOND})\n" )
file ( APPEND \${BUILD_INFO_H} "#define bmMACHINE \"\${bmHOSTNAME}\"\n" )
if ( WIN32 )
  file ( APPEND \${BUILD_INFO_H} "#define bmUSER \"\$ENV{USERNAME}\"\n" )
else()
  file ( APPEND \${BUILD_INFO_H} "#define bmUSER \"\$ENV{USER}\"\n" )
endif()

# Collect icpp files
file ( GLOB_RECURSE cpp_ini_files "\${CMAKE_CURRENT_BINARY_DIR}/../*.icpp.cpp" )

# Collect windows resource config file
if ( WIN32 )
  file ( GLOB rc_file "\${PROJECT_BINARY_DIR}/*.rc" )
endif()

# Main program definition
file ( WRITE \${PROJECT_BINARY_DIR}/null.cpp "" )
if ( "\${FlagDefs}" MATCHES "(flagSO)(;|$)" )
  add_library ( ${main_target_name}${BIN_SUFFIX} \${PROJECT_BINARY_DIR}/null.cpp \${rc_file} \${cpp_ini_files} )
  if ( WIN32 )
    include ( GenerateExportHeader )
    generate_export_header ( ${main_target_name}${BIN_SUFFIX}
        BASE_NAME ${main_target_name}${BIN_SUFFIX}
        EXPORT_MACRO_NAME ${main_target_name}${BIN_SUFFIX}_EXPORT
        EXPORT_FILE_NAME ${main_target_name}${BIN_SUFFIX}_Export.h
        STATIC_DEFINE ${main_target_name}${BIN_SUFFIX}_BUILT_AS_STATIC
    )
  endif()
else()
  add_executable ( ${main_target_name}${BIN_SUFFIX} \${PROJECT_BINARY_DIR}/null.cpp \${rc_file} \${cpp_ini_files} )
endif()

# Main program dependecies
set ( ${main_target_name}_${DEPEND_LIST} "${library_dep}" )

add_dependencies ( ${main_target_name}${BIN_SUFFIX} \${${main_target_name}_${DEPEND_LIST}})
if ( DEFINED MAIN_TARGET_LINK_FLAGS )
  set_target_properties ( ${main_target_name}${BIN_SUFFIX} PROPERTIES LINK_FLAGS \${MAIN_TARGET_LINK_FLAGS} )
endif()

# Precompiled headers processing
if ( "\${FlagDefs}" MATCHES "flagPCH" )
  if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )
    # Collect included directories of the external packages from all targets
    foreach ( target \${${main_target_name}_${DEPEND_LIST}} )
        get_target_property ( ${PCH_INCLUDE_LIST} \${target} ${PCH_INCLUDE_LIST} )
        list ( APPEND PCH_INCLUDE_DIRS \${${PCH_INCLUDE_LIST}} )
    endforeach()
    if ( PCH_INCLUDE_DIRS )
        list ( REMOVE_DUPLICATES PCH_INCLUDE_DIRS )
    endif()

    foreach ( target \${${main_target_name}_${DEPEND_LIST}} )
        get_target_property ( ${PCH_FILE} \${target} ${PCH_FILE} )
        if ( ${PCH_FILE} )
            generate_pch ( \${target} \${${PCH_FILE}} "\${PCH_INCLUDE_DIRS}" )
        endif()
    endforeach()
  endif()
endif()

# Main program link
target_link_libraries ( ${main_target_name}${BIN_SUFFIX} \${main_$LINK_LIST} \${${main_target_name}_${DEPEND_LIST}} )
set_target_properties ( ${main_target_name}${BIN_SUFFIX} PROPERTIES OUTPUT_NAME ${main_target_name} )
EOL
# End of the cat (CMakeFiles.txt)

    # Show used plugins
    if [ "${GENERATE_DEBUG}" == "1" ]; then
        declare -A sorted_UPP_ALL_USES=$(printf "%s\n" "${UPP_ALL_USES[@]}" | sort -u);
        declare -A sorted_UPP_ALL_USES_DONE=$(printf "%s\n" "${UPP_ALL_USES_DONE[@]}" | sort -u);

        echo "Plugins used   : " ${sorted_UPP_ALL_USES[@]}
        echo "CMake generated: " ${sorted_UPP_ALL_USES_DONE[@]}
    fi

    # Generate package file
    if [ "${GENERATE_PACKAGE}" == "1" ]; then
        generate_package_file
    fi
}

