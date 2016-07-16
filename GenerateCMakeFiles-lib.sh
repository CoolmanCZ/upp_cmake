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

OFN="CMakeLists.txt"        # Output file name

LINK_LIST="LINK_LIST"
DEPEND_LIST="DEPEND_LIST"
SOURCE_LIST="SOURCE_LIST"
HEADER_LIST="HEADER_LIST"
SOURCE_LIST_ICPP="SOURCE_LIST_ICPP"
SOURCE_LIST_RC="SOURCE_LIST_RC"

BIN_SUFFIX="-bin"
LIB_SUFFIX="-lib"

RE_BZIP2='[bB][zZ]2'
RE_ZIP='[zZ][iI][pP]'
RE_PNG='[pP][nN][gG]'
RE_CPP='\.([cC]+[xXpP]{0,2})$'
RE_ICPP='\.([iI][cC]+[xXpP]{0,2})$'
RE_RC='\.(rc)$'
RE_BRC='\.(brc)$'
RE_USES='^uses\('
RE_LINK='^link\('
RE_LIBRARY='^library\('
RE_OPTIONS='^options\('
RE_DEPEND='^uses$'
RE_FILES='^file$'
RE_MAINCONFIG='^mainconfig'
RE_SEPARATOR='separator'
RE_FILE_DOT='\.'
RE_FILE_SPLIT='(options|charset|optimize_speed|highlight)'
RE_FILE_EXCLUDE='(depends\(\))'

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

    if [ -n ${OPTIONS} ]; then
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

list_parse()
{
    local line="${1}"
    local list="${2}"
    local options=""
    local parameters=""

    echo >> ${OFN}
    echo "#${1}" >> ${OFN}

    options=$(string_get_in_parenthesis "${line}")
    options=$(if_options_parse_all "${options}")              # Parse options
#    echo "\"option: $options\""

    parameters=$(string_get_after_parenthesis "${line}")
    parameters=$(string_remove_comma "${parameters}")
#    echo "\"param : $parameters\""
#    echo "\"list  : $list\""

    # Add optional dependency target to generate CMakeLists.txt
    if [[ ${list} =~ "$DEPEND_LIST" ]]; then
        local -a new_parameters=(${parameters})
        parameters=""
        for item in ${new_parameters[@]}; do
            parameters+="$(string_replace_dash "${item}${LIB_SUFFIX}") "
            UPP_ALL_USES+=(${item})
        done
    fi

    if [ -n "${options}" ] ; then
        echo "if (${options})" >> ${OFN}
        echo "      list ( APPEND ${list} ${parameters} )" >> ${OFN}
        echo "endif()" >> ${OFN}
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
        echo "  SET ( MAIN_TARGET_LINK_FLAGS "\${MAIN_TARGET_LINK_FLAGS} ${parameters}" PARENT_SCOPE )" >> ${OFN}
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

options_parse()
{
    local line="${1}"
    local options=""
    local parameters=""

    echo >> ${OFN}
    echo "#${1}" >> ${OFN}

    if [[ ${line} =~ BUILDER_OPTION ]]; then
        $(if_options_builder "${line}")
    else
        options=$(string_get_in_parenthesis "${line}")
        options=$(if_options_parse_all "${options}")              # Parse options

        parameters=$(string_get_after_parenthesis "${line}")
        parameters=$(string_remove_comma "${parameters}")

        if [ -n "${options}" ]; then
            echo "if ($options)" >> ${OFN}
            echo "      add_definitions ( ${parameters} )" >> ${OFN}
            echo "endif()" >> ${OFN}
        fi
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
                    echo "list ( APPEND ${SOURCE_LIST} \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp )" >> ${OFN}

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

                    if [ -n ${binary_mask_files} ]; then
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
                        echo "list ( APPEND ${SOURCE_LIST} \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp )" >> ${OFN}

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
            echo "list ( APPEND ${SOURCE_LIST} \${CMAKE_CURRENT_BINARY_DIR}/binary_array.cpp )" >> ${OFN}
        fi
    else
        echo "File \"${parse_file}\" not found!"
    fi
}

generate_cmake_header()
{
    echo "# ${OFN} generated $(export LC_ALL=C; date)" > ${OFN}
    echo "cmake_minimum_required ( VERSION 2.8 )" >> ${OFN}

    echo >> ${OFN}
    echo "#################################################" >> ${OFN}
    echo "# In-Source builds are strictly prohibited." >> ${OFN}
    echo "#################################################" >> ${OFN}

    echo "if ( \${CMAKE_SOURCE_DIR} STREQUAL \${CMAKE_BINARY_DIR} )" >> ${OFN}
    echo "  message ( FATAL_ERROR" >> ${OFN}
    echo "  \"\n****************************** ERROR ******************************\n\"" >> ${OFN}
    echo "  \"In-source build are not allowed. \"" >> ${OFN}
    echo "  \"Please do not polute the sources with binaries or any project unrelated files. \"" >> ${OFN}
    echo "  \"To remove generated files run:\n\"" >> ${OFN}
    echo "  \"'rm -rf CMakeCache.txt CMakeFiles'\n\"" >> ${OFN}
    echo "  \"To build the project, please do the following:\n\"" >> ${OFN}
    echo "  \"'mkdir build && cd build && cmake ..'\"" >> ${OFN}
    echo "  \"\n****************************** ERROR ******************************\n\")" >> ${OFN}
    echo "endif()" >> ${OFN}

    echo >> ${OFN}
    echo "# Set the default path for built libraries to the lib directory" >> ${OFN}
    echo "set ( LIBRARY_OUTPUT_PATH \${PROJECT_BINARY_DIR}/lib )" >> ${OFN}
    echo "include_directories ( BEFORE \${PROJECT_BINARY_DIR}/inc )" >> ${OFN}
}

generate_cmake_from_upp()
{
    local upp_ext="${1}"
    local object_name="${2}"
    local main_target="${3}"
    local USES=()
    local HEADER=()
    local SOURCE=()
    local SOURCE_RC=()
    local SOURCE_ICPP=()
    local uses_start=""
    local files_start=""
    local mainconfig_start=""
    local tmp=""
    local list=""
    local line=""
    local line_array=()

    if [ -f "${upp_ext}" ]; then
        local target_name="$(string_replace_dash "${object_name}")"

        while read line; do
            # Parse compiler options
            if [[ ${line} =~ $RE_USES ]]; then
                list_parse "${line}" ${target_name}_${DEPEND_LIST}
            fi

            # Parse library options
            if [[ ${line} =~ $RE_LIBRARY ]]; then
                list_parse "${line}" ${LINK_LIST}
            fi

            # Parse project options
            if [[ ${line} =~ $RE_OPTIONS ]]; then
                options_parse "${line}"
            fi

            # Parse link options
            if [[ ${line} =~ $RE_LINK ]]; then
                link_parse "${line}" "${target_name}"
            fi

            # Begin of dependency section
            if [[ ${line} =~ $RE_DEPEND ]]; then
                uses_start="1"
                continue
            fi

            # End of dependency section (by empty line)
            if [ -n "${uses_start}" ] && [ -z "${line}" ]; then
                uses_start=""
            fi

            # Begin of files section
            if [[ ${line} =~ $RE_FILES ]]; then
                files_start="1"
                continue
            fi

            # End of file section (by empty line)
            if [ -n "${files_start}" ] && [ -z "${line}" ]; then
                files_start=""
            fi

            # Begin of mainconfig section
            if [[ ${line} =~ $RE_MAINCONFIG ]]; then
                mainconfig_start="1"
                continue
            fi

            # End of mainconfig section (by empty line)
            if [ -n "${mainconfig_start}" ] && [ -z "${line}" ]; then
                mainconfig_start=""
            fi

            # Skip lines with "separator" mark
            if [ -n "${files_start}" ] && [[ ${line} =~ $RE_SEPARATOR ]]; then
                continue;
            fi

            # Split lines with charset, options, ...
            if [ -n "${files_start}" ] && [[ "${line}" =~ $RE_FILE_SPLIT ]]; then
                line="${line// */}"
            fi

            # Parse file names
            if [ -n "${files_start}" ]; then
                line_array=(${line})
                for list in "${line_array[@]}"; do
                    list=${list//,}
                    list=${list//;}

                    if [[ "${list}" =~ $RE_FILE_EXCLUDE ]]; then
                        continue;
                    fi

                    if [ ! -f "${list}" ]; then
                        echo "WARNING - \"${list}\" doesn't exist! It was not added to the list."
                    else
                        if [[ ${list} =~ $RE_CPP ]]; then         # C/C++ source files
                            SOURCE+=(${list})
                        elif [[ ${list} =~ $RE_RC ]]; then        # Windows resource config files
                            SOURCE_RC+=(${list})
                        elif [[ ${list} =~ $RE_ICPP ]]; then      # icpp C/C++ source files
                            SOURCE_ICPP+=(${list})
                        elif [[ ${list} =~ $RE_BRC ]]; then       # BRC resource files
                            $(binary_resource_parse "$list")
                            HEADER+=(${list})
                        elif [[ ${list} =~ $RE_FILE_DOT ]]; then  # header files
                            HEADER+=(${list})
                        fi
                    fi
                done
            fi

            # Parse dependency
            if [ -n "${uses_start}" ]; then
                tmp="${line//,}"
                USES+=(${tmp//;})
                UPP_ALL_USES+=(${tmp//;})
            fi

            # Parse mainconfig
            if [ -n "${mainconfig_start}" ]; then
                if [[ ${line} =~ "GUI" ]]; then
                    FLAG_GUI="1"
                fi
                if [[ ${line} =~ "MT" ]]; then
                    FLAG_MT="1"
                fi
            fi

        done < <(sed 's#\\#/#g' "${upp_ext}")

        # Create header files list
        if [ -n ${HEADER} ] ; then
            echo >> ${OFN}
            echo "list ( APPEND ${HEADER_LIST}" >> ${OFN}
            for list in "${HEADER[@]}"; do
                echo "      ${list}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Create source files list
        if [ -n ${SOURCE} ] ; then
            echo >> ${OFN}
            echo "list ( APPEND ${SOURCE_LIST}" >> ${OFN}
            for list in "${SOURCE[@]}"; do
                echo "      ${list}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Create icpp source files list
        if [ -n ${SOURCE_ICPP} ] ; then
            echo >> ${OFN}
            echo "list ( APPEND ${SOURCE_LIST_ICPP}" >> ${OFN}
            for list in "${SOURCE_ICPP[@]}"; do
                echo "      ${list}" >> ${OFN}
            done
            echo ")" >> ${OFN}
        fi

        # Create dependency list
        if [ -n ${USES} ] ; then
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
                            echo "file ( COPY ${list} DESTINATION \${PROJECT_BINARY_DIR} )" >> ${OFN}
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
        echo "  list ( APPEND ${SOURCE_LIST} \${output_file} )" >> ${OFN}
        echo 'endforeach()' >> ${OFN}

        echo >> ${OFN}
        echo "# Module properties" >> ${OFN}
        echo "create_cpps_from_icpps()" >> ${OFN}
        echo "set_source_files_properties ( \${$HEADER_LIST} PROPERTIES HEADER_FILE_ONLY ON )" >> ${OFN}
        echo "add_library ( ${target_name}${LIB_SUFFIX} \${INIT_FILE} \${$SOURCE_LIST} )" >> ${OFN}

        echo >> ${OFN}
        echo "# Module dependecies" >> ${OFN}
        echo "if ( DEFINED ${target_name}_${DEPEND_LIST} )" >> ${OFN}
        echo "      add_dependencies ( ${target_name}${LIB_SUFFIX} \${${target_name}_$DEPEND_LIST} )" >> ${OFN}
        echo "endif()" >> ${OFN}

        echo >> ${OFN}
        echo "# Module link" >> ${OFN}
        echo "if ( DEFINED ${target_name}_${DEPEND_LIST} OR DEFINED $LINK_LIST )" >> ${OFN}
        echo "      target_link_libraries ( ${target_name}${LIB_SUFFIX} \${${target_name}_${DEPEND_LIST}} \${$LINK_LIST} )" >> ${OFN}
        echo "endif()" >> ${OFN}
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

    if [ -n ${upp_all_only} ]; then
        echo "${upp_all_only[0]}"
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

    echo >> ${OFN}
    echo "# Set the default path for built executables to the bin directory" >> ${OFN}
    echo "set ( EXECUTABLE_OUTPUT_PATH \${PROJECT_BINARY_DIR}/bin )" >> ${OFN}

    echo >> ${OFN}
    echo "# Project definitions" >> ${OFN}
    echo "add_definitions ( "${main_definitions}" )" >> ${OFN}

#    if [ -n "${FLAG_MT}" ]; then
#        echo 'add_definitions ( -DflagMT )' >> ${OFN}
#    fi
#    if [ -n "${FLAG_GUI}" ]; then
#        echo 'add_definitions ( -DflagGUI )' >> ${OFN}
#    fi

    echo >> ${OFN}
    echo '# Read compiler definitions - used to set appropriate modules' >> ${OFN}
    echo 'get_directory_property ( FlagDefs COMPILE_DEFINITIONS )' >> ${OFN}
#    echo "message ( STATUS \"FlagDefs: \" \${FlagDefs} )" >> ${OFN}

    echo >> ${OFN}
    echo '# Check supported compilation arch environment' >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagGCC32" OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8 )' >> ${OFN}
    echo '  set ( STATUS_COMPILATION "32" )' >> ${OFN}
    echo '  set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -m32" )' >> ${OFN}
    echo 'else()' >> ${OFN}
    echo '  set ( STATUS_COMPILATION "64" )' >> ${OFN}
    echo '  set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -m64" )' >> ${OFN}
    echo '  set ( MSVC_ARCH "X64" )' >> ${OFN}
    echo 'endif()' >> ${OFN}
    echo 'message ( STATUS "Build compilation: ${STATUS_COMPILATION} bits" )' >> ${OFN}

    echo >> ${OFN}
    echo '# Set MSVC compiler flags' >> ${OFN}
    echo 'if ( MSVC )' >> ${OFN}
    echo '  if ( ${MSVC_VERSION} EQUAL 1200 )' >> ${OFN}
    echo '      add_definitions ( -DflagMSC6${MSVC_ARCH} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( ${MSVC_VERSION} EQUAL 1300 OR ${MSVC_VERSION} EQUAL 1310)' >> ${OFN}
    echo '      add_definitions ( -DflagMSC7${MSVC_ARCH} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( ${MSVC_VERSION} EQUAL 1400 )' >> ${OFN}
    echo '      add_definitions ( -DflagMSC8${MSVC_ARCH} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( ${MSVC_VERSION} EQUAL 1500 )' >> ${OFN}
    echo '      add_definitions ( -DflagMSC9${MSVC_ARCH} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( ${MSVC_VERSION} EQUAL 1600 )' >> ${OFN}
    echo '      add_definitions ( -DflagMSC10${MSVC_ARCH} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( ${MSVC_VERSION} EQUAL 1700 )' >> ${OFN}
    echo '      add_definitions ( -DflagMSC11${MSVC_ARCH} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( ${MSVC_VERSION} EQUAL 1800 )' >> ${OFN}
    echo '      add_definitions ( -DflagMSC12${MSVC_ARCH} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( ${MSVC_VERSION} EQUAL 1900 )' >> ${OFN}
    echo '      add_definitions ( -DflagMSC14${MSVC_ARCH} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# Set CLANG compiler flags' >> ${OFN}
    echo 'if ( ${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" )' >> ${OFN}
    echo '  set ( CMAKE_COMPILER_IS_CLANG TRUE )' >> ${OFN}
    echo '  set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -Wno-logical-op-parentheses" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# Parse definition flags' >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagDEBUG" )' >> ${OFN}
    echo '  set ( CMAKE_VERBOSE_MAKEFILE 1 )' >> ${OFN}
    echo '  set ( CMAKE_BUILD_TYPE DEBUG )' >> ${OFN}
    echo '  add_definitions ( -D_DEBUG )' >> ${OFN}
    echo >> ${OFN}
    echo '  set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -O0" )' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( NOT "${FlagDefs}" MATCHES "(flagDEBUG)[;$]" )' >> ${OFN}
    echo '      add_definitions ( -DflagDEBUG )' >> ${OFN}
    echo '      get_directory_property ( FlagDefs COMPILE_DEFINITIONS )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( MSVC )' >> ${OFN}
    echo '      if ( "${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|15)" OR "${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|15)X64" )' >> ${OFN}
    echo '          set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -debug -OPT:NOREF" )' >> ${OFN}
    echo '      else()' >> ${OFN}
    echo '          set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -incremental:yes -debug -OPT:NOREF" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo 'else()' >> ${OFN}
    echo '  set ( CMAKE_VERBOSE_MAKEFILE 0 )' >> ${OFN}
    echo '  set ( CMAKE_BUILD_TYPE RELEASE )' >> ${OFN}
    echo '  add_definitions ( -D_RELEASE )' >> ${OFN}
    echo >> ${OFN}
    echo '  set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -O3" )' >> ${OFN}
    echo '  set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -GS-" )' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )' >> ${OFN}
    echo '      set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -ffunction-sections -fdata-sections" )' >> ${OFN}
    echo '      set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-s,--gc-sections" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( MSVC )' >> ${OFN}
    echo '      if ( "${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|15)" OR "${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|15)X64" )' >> ${OFN}
    echo '          set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -release -OPT:REF,ICF" )' >> ${OFN}
    echo '      else()' >> ${OFN}
    echo '          set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -incremental:no -release -OPT:REF,ICF" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo 'endif()' >> ${OFN}
    echo 'message ( STATUS "Build type: " ${CMAKE_BUILD_TYPE} )' >> ${OFN}

    echo >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagDEBUG_MINIMAL" )' >> ${OFN}
    echo '  if ( NOT MINGW )' >> ${OFN}
    echo '      set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -ggdb" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -g1" )' >> ${OFN}
    echo '  set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -Zd" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagDEBUG_FULL" )' >> ${OFN}
    echo '  if ( NOT MINGW )' >> ${OFN}
    echo '      set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -ggdb" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -g2" )' >> ${OFN}
    echo '  set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -Zi" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagSHARED" )' >> ${OFN}
    echo '  set ( STATUS_SHARED "TRUE" )' >> ${OFN}
    echo '  set ( EXTRA_GXX_FLAGS "${EXTRA_GXX_FLAGS} -fuse-cxa-atexit" )' >> ${OFN}
    echo 'else()' >> ${OFN}
    echo '  set ( STATUS_SHARED "FALSE" )' >> ${OFN}
    echo '  set ( BUILD_SHARED_LIBS OFF )' >> ${OFN}
    echo '  set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -static -fexceptions" )' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( MINGW )' >> ${OFN}
    echo '      set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libgcc" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo 'endif()' >> ${OFN}
    echo 'message ( STATUS "Build with flagSHARED: ${STATUS_SHARED}" )' >> ${OFN}

    echo >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagMT" )' >> ${OFN}
    echo '  find_package ( Threads REQUIRED )' >> ${OFN}
    echo '  if ( THREADS_FOUND )' >> ${OFN}
    echo '      include_directories ( ${THREADS_INCLUDE_DIRS} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${THREADS_LIBRARIES} )" >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagSSL" )' >> ${OFN}
    echo '  find_package ( OpenSSL REQUIRED )' >> ${OFN}
    echo '  if ( OPENSSL_FOUND )' >> ${OFN}
    echo '      include_directories ( ${OPENSSL_INCLUDE_DIRS} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${OPENSSL_LIBRARIES} )" >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# Set compiler options' >> ${OFN}
    echo 'if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )' >> ${OFN}
    echo '  set ( EXTRA_GXX_FLAGS "${EXTRA_GXX_FLAGS} -std=c++11" )' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( MINGW )' >> ${OFN}
    echo '      add_definitions ( -DflagWIN32 )' >> ${OFN}
    echo '      remove_definitions( -DflagPOSIX )' >> ${OFN}
    echo '      remove_definitions( -DflagLINUX )' >> ${OFN}
    echo '      remove_definitions( -DflagFREEBSD )' >> ${OFN}
    echo '      remove_definitions( -DflagSOLARIS )' >> ${OFN}
    echo '      get_directory_property ( FlagDefs COMPILE_DEFINITIONS )' >> ${OFN}
    echo >> ${OFN}
    echo '      set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -mwindows" )' >> ${OFN}
    echo >> ${OFN}
    echo '      if ( "${FlagDefs}" MATCHES "flagDLL" )' >> ${OFN}
    echo '          set ( BUILD_SHARED_LIBS ON )' >> ${OFN}
    echo '          set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -shared" )' >> ${OFN}
    echo '          string ( REGEX REPLACE "-static " "" CMAKE_EXE_LINKER_FLAGS ${CMAKE_EXE_LINKER_FLAGS} )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo >> ${OFN}
    echo '      if ("${FlagDefs}" MATCHES "flagGUI" )' >> ${OFN}
    echo "          list ( APPEND main_${LINK_LIST} mingw32 )" >> ${OFN}
    echo '      else()' >> ${OFN}
    echo '          set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -mconsole" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo >> ${OFN}
    echo '      if ( "${FlagDefs}" MATCHES "flagMT" )' >> ${OFN}
    echo '          set ( EXTRA_GCC_FLAGS "${EXTRA_GCC_FLAGS} -mthreads" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo >> ${OFN}
    echo '      # The optimalization might be broken on MinGW - remove optimalization flag (cross compile).' >> ${OFN}
    echo '      string ( REGEX REPLACE "-O3" "" EXTRA_GCC_FLAGS ${EXTRA_GCC_FLAGS} )' >> ${OFN}
    echo >> ${OFN}
    echo '      get_directory_property ( FlagDefs COMPILE_DEFINITIONS )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  set ( CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE} "${CMAKE_CXX_FLAGS_${BUILD_TYPE}} ${EXTRA_GXX_FLAGS} ${EXTRA_GCC_FLAGS}" )' >> ${OFN}
    echo '  set ( CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE} "${CMAKE_C_FLAGS_${BUILD_TYPE}} ${EXTRA_GCC_FLAGS}" )' >> ${OFN}
    echo >> ${OFN}
    echo '  set ( CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> -rs <TARGET> <LINK_FLAGS> <OBJECTS>" )' >> ${OFN}
    echo '  set ( CMAKE_CXX_ARCHIVE_APPEND "<CMAKE_AR> -rs <TARGET> <LINK_FLAGS> <OBJECTS>" )' >> ${OFN}
    echo '  set ( CMAKE_C_ARCHIVE_CREATE "<CMAKE_AR> -rs <TARGET> <LINK_FLAGS> <OBJECTS>" )' >> ${OFN}
    echo '  set ( CMAKE_C_ARCHIVE_APPEND "<CMAKE_AR> -rs <TARGET> <LINK_FLAGS> <OBJECTS>" )' >> ${OFN}
    echo >> ${OFN}
    echo 'elseif ( MSVC )' >> ${OFN}
    echo '  add_definitions ( -DflagMSC )' >> ${OFN}
    echo '  add_definitions ( -DflagWIN32 )' >> ${OFN}
    echo '  remove_definitions( -DflagPOSIX )' >> ${OFN}
    echo '  remove_definitions( -DflagLINUX )' >> ${OFN}
    echo '  remove_definitions( -DflagFREEBSD )' >> ${OFN}
    echo '  remove_definitions( -DflagSOLARIS )' >> ${OFN}
    echo '  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )' >> ${OFN}
    echo >> ${OFN}
    echo '  set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -nologo" )' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( "${FlagDefs}" MATCHES "flagEVC" )' >> ${OFN}
    echo '      if ( NOT "${FlagDefs}" MATCHES "flagSH3" AND  NOT "${FlagDefs}" MATCHES "flagSH4" )' >> ${OFN}
    echo '          # disable stack checking' >> ${OFN}
    echo '          set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -Gs8192" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo '      # read-only string pooling, turn off exception handling' >> ${OFN}
    echo '      set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -GF -GX-" )' >> ${OFN}
    echo '  elseif ( "${FlagDefs}" MATCHES "flagCLR" )' >> ${OFN}
    echo '      set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -EHac" )' >> ${OFN}
    echo '  elseif ( "${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|15)" OR "${FlagDefs}" MATCHES "flagMSC(8|9)ARM" OR "${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|15)X64" )' >> ${OFN}
    echo '      set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -EHsc" )' >> ${OFN}
    echo '  else()' >> ${OFN}
    echo '      set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -GX" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( ${CMAKE_BUILD_TYPE} STREQUAL DEBUG )' >> ${OFN}
    echo '      set ( EXTRA_MSVC_FLAGS_Mx "d" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( "${FlagDefs}" MATCHES "flagSHARED" OR "${FlagDefs}" MATCHES "flagCLR" )' >> ${OFN}
    echo '      set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -MD${EXTRA_MSVC_FLAGS_Mx}" )' >> ${OFN}
    echo '  else()' >> ${OFN}
    echo '      if ( "${FlagDefs}" MATCHES "flagMT" OR "${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|15)" OR "${FlagDefs}" MATCHES "flagMSC(8|9)ARM" OR "${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|15)X64" )' >> ${OFN}
    echo '          set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -MT${EXTRA_MSVC_FLAGS_Mx}" )' >> ${OFN}
    echo '      else()' >> ${OFN}
    echo '          set ( EXTRA_MSVC_FLAGS "${EXTRA_MSVC_FLAGS} -ML${EXTRA_MSVC_FLAGS_Mx}" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  #,5.01 needed to support WindowsXP' >> ${OFN}
    echo '  if ( NOT "${FlagDefs}" MATCHES "(flagMSC(8|9|10|11|12|15)X64)" )' >> ${OFN}
    echo '      set ( MSVC_LINKER_SUBSYSTEM ",5.01" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo '  if ( "${FlagDefs}" MATCHES "flagMSC(8|9)ARM" )' >> ${OFN}
    echo '      set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -subsystem:windowsce,4.20 /ARMPADCODE -NODEFAULTLIB:\"oldnames.lib\"" )' >> ${OFN}
    echo '  else()' >> ${OFN}
    echo '      if ( "${FlagDefs}" MATCHES "flagGUI" OR "${FlagDefs}" MATCHES "flagMSC(8|9)ARM" )' >> ${OFN}
    echo '          set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -subsystem:windows${MSVC_LINKER_SUBSYSTEM}" )' >> ${OFN}
    echo '      else()' >> ${OFN}
    echo '          set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -subsystem:console${MSVC_LINKER_SUBSYSTEM}" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( "${FlagDefs}" MATCHES "flagDLL" )' >> ${OFN}
    echo '      set ( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -dll" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  set ( CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE} "${CMAKE_CXX_FLAGS_${BUILD_TYPE}} ${EXTRA_MSVC_FLAGS}" )' >> ${OFN}
    echo '  set ( CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE} "${CMAKE_C_FLAGS_${BUILD_TYPE}} ${EXTRA_MSVC_FLAGS}" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# Function to create cpp source from icpp files' >> ${OFN}
    echo 'function ( create_cpps_from_icpps )' >> ${OFN}
    echo '  file ( GLOB icpp_files RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/*.icpp" )' >> ${OFN}
    echo '  foreach ( icppFile ${icpp_files} )' >> ${OFN}
    echo '      set ( output_file "${CMAKE_CURRENT_BINARY_DIR}/${icppFile}.cpp" )' >> ${OFN}
    echo '      file ( WRITE "${output_file}" "#include \"${CMAKE_CURRENT_SOURCE_DIR}/${icppFile}\"\n" )' >> ${OFN}
    echo '  endforeach()' >> ${OFN}
    echo 'endfunction()' >> ${OFN}

    echo >> ${OFN}
    echo '# Function to create cpp source file from binary resource definition' >> ${OFN}
    echo 'function ( create_brc_source input_file output_file symbol_name compression symbol_append )' >> ${OFN}
    echo '  if ( NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${input_file} )' >> ${OFN}
    echo '      message ( FATAL_ERROR "Input file does not exist: ${CMAKE_CURRENT_SOURCE_DIR}/${input_file}" )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  file ( REMOVE ${CMAKE_CURRENT_BINARY_DIR}/${symbol_name} )' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( ${compression} MATCHES "[bB][zZ]2" )' >> ${OFN}
    echo '      find_program ( BZIP2_EXEC bzip2 )'>> ${OFN}
    echo '      if ( NOT BZIP2_EXEC )' >> ${OFN}
    echo '          message ( FATAL_ERROR "BZIP2 executable not found!" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo '      set ( COMPRESS_SUFFIX "bz2" )' >> ${OFN}
    echo '      set ( COMMAND_COMPRESS ${BZIP2_EXEC} -k -f ${CMAKE_CURRENT_BINARY_DIR}/${symbol_name} )' >> ${OFN}
    echo '  elseif ( ${compression} MATCHES "[zZ][iI][pP]" )' >> ${OFN}
    echo '      find_program ( ZIP_EXEC zip )'>> ${OFN}
    echo '      if ( NOT ZIP_EXEC )' >> ${OFN}
    echo '          message ( FATAL_ERROR "ZIP executable not found!" )' >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo '      set ( COMPRESS_SUFFIX "zip" )' >> ${OFN}
    echo '      set ( COMMAND_COMPRESS ${ZIP_EXEC} ${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.${COMPRESS_SUFFIX} ${symbol_name} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  file ( COPY ${CMAKE_CURRENT_SOURCE_DIR}/${input_file} DESTINATION ${CMAKE_CURRENT_BINARY_DIR} )' >> ${OFN}
    echo '  get_filename_component ( input_file_name ${CMAKE_CURRENT_SOURCE_DIR}/${input_file} NAME )' >> ${OFN}
    echo '  file ( RENAME ${CMAKE_CURRENT_BINARY_DIR}/${input_file_name} ${CMAKE_CURRENT_BINARY_DIR}/${symbol_name} )' >> ${OFN}
    echo '  if ( COMMAND_COMPRESS )' >> ${OFN}
    echo '      execute_process ( COMMAND ${COMMAND_COMPRESS} WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} OUTPUT_VARIABLE XXXX )' >> ${OFN}
    echo '      file ( RENAME ${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.${COMPRESS_SUFFIX} ${CMAKE_CURRENT_BINARY_DIR}/${symbol_name} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  file ( READ ${CMAKE_CURRENT_BINARY_DIR}/${symbol_name} hex_string HEX )' >> ${OFN}
    echo >> ${OFN}
    echo '  set ( CURINDEX 0 )' >> ${OFN}
    echo '  string ( LENGTH "${hex_string}" CURLENGTH )' >> ${OFN}
    echo '  math ( EXPR FILELENGTH "${CURLENGTH} / 2" )' >> ${OFN}
    echo '  set ( ${hex_string} 0)' >> ${OFN}
    echo >> ${OFN}
    echo '  set ( output_string "static unsigned char ${symbol_name}_[] = {\n" )' >> ${OFN}
    echo '  while ( CURINDEX LESS CURLENGTH )' >> ${OFN}
    echo '      string ( SUBSTRING "${hex_string}" ${CURINDEX} 2 CHAR )' >> ${OFN}
    echo '      set ( output_string "${output_string} 0x${CHAR}," )' >> ${OFN}
    echo '      math ( EXPR CURINDEX "${CURINDEX} + 2" )' >> ${OFN}
    echo '  endwhile()' >> ${OFN}
    echo '  set ( output_string "${output_string} 0x00 }\;\n\n" )' >> ${OFN}
    echo '  set ( output_string "${output_string}unsigned char *${symbol_name} = ${symbol_name}_\;\n\n" )' >> ${OFN}
    echo '  set ( output_string "${output_string}int ${symbol_name}_length = ${FILELENGTH}\;\n\n" )' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( ${symbol_append} MATCHES "append" )' >> ${OFN}
    echo '      file ( APPEND ${CMAKE_CURRENT_BINARY_DIR}/${output_file} ${output_string} )' >> ${OFN}
    echo '  else()' >> ${OFN}
    echo '      file ( WRITE ${CMAKE_CURRENT_BINARY_DIR}/${output_file} ${output_string} )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo 'endfunction()' >> ${OFN}

    echo >> ${OFN}
    echo '# Import and set up required packages and libraries' >> ${OFN}
    echo 'if ( NOT WIN32 )' >> ${OFN}
    echo '  find_package ( Freetype )' >> ${OFN}
    echo '  if ( FREETYPE_FOUND )' >> ${OFN}
    echo '      include_directories ( ${FREETYPE_INCLUDE_DIRS} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${FREETYPE_LIBRARIES} )" >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  find_package ( EXPAT )' >> ${OFN}
    echo '  if ( EXPAT_FOUND )' >> ${OFN}
    echo '      include_directories ( ${EXPAT_INCLUDE_DIRS} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${EXPAT_LIBRARIES} )" >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( NOT BUILD_WITHOUT_GTK )' >> ${OFN}
    echo '      find_package ( GTK2 2.6 REQUIRED gtk )' >> ${OFN}
    echo '      if ( GTK2_FOUND )' >> ${OFN}
    echo '          include_directories ( ${GTK2_INCLUDE_DIRS} )' >> ${OFN}
    echo "          list ( APPEND main_${LINK_LIST} \${GTK2_LIBRARIES} )" >> ${OFN}
    echo '      endif()' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  find_package ( X11 )' >> ${OFN}
    echo '  if ( X11_FOUND )' >> ${OFN}
    echo '      include_directories ( ${X11_INCLUDE_DIR} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${X11_LIBRARIES} )" >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  find_package ( BZip2 REQUIRED )' >> ${OFN}
    echo '  if ( BZIP2_FOUND )' >> ${OFN}
    echo '      include_directories ( ${BZIP_INCLUDE_DIRS} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${BZIP2_LIBRARIES} )" >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo >> ${OFN}
    echo '  if ( ${CMAKE_SYSTEM_NAME} MATCHES BSD )' >> ${OFN}
    echo '      link_directories ( /usr/local/lib )' >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# Initialize definition flags' >> ${OFN}
    echo 'get_directory_property ( FlagDefs COMPILE_DEFINITIONS )' >> ${OFN}
    echo 'foreach( comp_def ${FlagDefs} )' >> ${OFN}
    echo '  set ( ${comp_def} 1 )' >> ${OFN}
    echo 'endforeach()' >> ${OFN}

    echo >> ${OFN}
    echo "# Set include and library directories" >> ${OFN}
    echo "include_directories ( BEFORE \${CMAKE_CURRENT_SOURCE_DIR} )" >> ${OFN}
    echo "include_directories ( BEFORE ${UPP_SRC_DIR} )" >> ${OFN}

    echo >> ${OFN}
    echo '# Include dependent directories of the project' >> ${OFN}
    while [ ${#UPP_ALL_USES_DONE[@]} -lt ${#UPP_ALL_USES[@]} ]; do
        local process_upp=$(get_upp_to_process)
        local png_lib_added=""
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
            if [ -z "${png_lib_added}" ] && [[ "${process_upp}" =~ $RE_PNG ]]; then
                png_lib_added="done"
                echo >> ${OFN}
                echo '# Add PNG library' >> ${OFN}
                echo 'if ( NOT "${FlagDefs}" MATCHES "flagWIN32" )' >> ${OFN}
                echo '  find_package ( PNG REQUIRED )' >> ${OFN}
                echo '  if ( PNG_FOUND )' >> ${OFN}
                echo '      include_directories( ${PNG_INCLUDE_DIR} )' >> ${OFN}
                echo "      list ( APPEND main_${LINK_LIST} \${PNG_LIBRARIES} )" >> ${OFN}
                echo '  endif()' >> ${OFN}
                echo 'endif()' >> ${OFN}
                echo >> ${OFN}
            fi
        fi

        UPP_ALL_USES_DONE+=("${process_upp}")
    done

    echo "add_subdirectory ( ${main_target_dirname} )" >> ${OFN}

    local -a array_library=$(printf "%s\n" "${UPP_ALL_USES_DONE[@]}" | sort -u | sed 's#/#_#g');
    local library_dep="${main_target_name}${LIB_SUFFIX} "
    for list_library in ${array_library[@]}; do
        library_dep+="${list_library}${LIB_SUFFIX} "
    done

    echo >> ${OFN}
    echo '# Creation of the file build_info.h' >> ${OFN}
    echo 'set ( BUILD_INFO_H ${PROJECT_BINARY_DIR}/inc/build_info.h )' >> ${OFN}
    echo 'string ( TIMESTAMP bmYEAR %Y )'>> ${OFN}
    echo 'string ( TIMESTAMP bmMONTH %m )'>> ${OFN}
    echo 'string ( TIMESTAMP bmDAY %d )'>> ${OFN}
    echo 'string ( TIMESTAMP bmHOUR %H )'>> ${OFN}
    echo 'string ( TIMESTAMP bmMINUTE %M )'>> ${OFN}
    echo 'string ( TIMESTAMP bmSECOND %S )'>> ${OFN}
    echo 'string ( REGEX REPLACE "^0" "" bmMONTH ${bmMONTH} )' >> ${OFN}
    echo 'string ( REGEX REPLACE "^0" "" bmDAY ${bmDAY} )' >> ${OFN}
    echo 'string ( REGEX REPLACE "^0" "" bmHOUR ${bmHOUR} )' >> ${OFN}
    echo 'string ( REGEX REPLACE "^0" "" bmSECOND ${bmSECOND} )' >> ${OFN}
    echo 'cmake_host_system_information ( RESULT bmHOSTNAME QUERY HOSTNAME )'>> ${OFN}
    echo 'file ( WRITE  ${BUILD_INFO_H} "#define bmYEAR ${bmYEAR}\n#define bmMONTH ${bmMONTH}\n#define bmDAY ${bmDAY}\n" )' >> ${OFN}
    echo 'file ( APPEND ${BUILD_INFO_H} "#define bmHOUR ${bmHOUR}\n#define bmMINUTE ${bmMINUTE}\n#define bmSECOND ${bmSECOND}\n" )' >> ${OFN}
    echo 'file ( APPEND ${BUILD_INFO_H} "#define bmTIME Time(${bmYEAR}, ${bmMONTH}, ${bmDAY}, ${bmHOUR}, ${bmMINUTE}, ${bmSECOND})\n" )' >> ${OFN}
    echo 'file ( APPEND ${BUILD_INFO_H} "#define bmMACHINE \"${bmHOSTNAME}\"\n" )' >> ${OFN}
    echo 'if ( WIN32 )' >> ${OFN}
    echo '  file ( APPEND ${BUILD_INFO_H} "#define bmUSER \"$ENV{USERNAME}\"\n" )' >> ${OFN}
    echo 'else()' >> ${OFN}
    echo '  file ( APPEND ${BUILD_INFO_H} "#define bmUSER \"$ENV{USER}\"\n" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# Collect icpp files' >> ${OFN}
    echo 'file ( GLOB_RECURSE cpp_ini_files "${CMAKE_CURRENT_BINARY_DIR}/../*.icpp.cpp" )' >> ${OFN}

    echo >> ${OFN}
    echo '# Collect windows resource config file' >> ${OFN}
    echo 'if ( WIN32 )' >> ${OFN}
    echo '  file ( GLOB rc_file "${PROJECT_BINARY_DIR}/*.rc" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# Main program definition' >> ${OFN}
    echo 'file ( WRITE ${PROJECT_BINARY_DIR}/null.cpp "" )' >> ${OFN}
    echo "add_executable ( ${main_target_name}${BIN_SUFFIX} \${PROJECT_BINARY_DIR}/null.cpp \${rc_file} \${cpp_ini_files} )" >> ${OFN}

    echo >> ${OFN}
    echo "# Main program dependecies" >> ${OFN}
    echo "add_dependencies ( ${main_target_name}${BIN_SUFFIX} ${library_dep})" >> ${OFN}
    echo "set_target_properties ( ${main_target_name}${BIN_SUFFIX} PROPERTIES LINK_FLAGS \${MAIN_TARGET_LINK_FLAGS} )" >> ${OFN}

    echo >> ${OFN}
    echo "# Main program link" >> ${OFN}
    echo "target_link_libraries ( ${main_target_name}${BIN_SUFFIX} \${main_$LINK_LIST} ${library_dep} )" >> ${OFN}

    echo >> ${OFN}
    echo "set_target_properties ( ${main_target_name}${BIN_SUFFIX} PROPERTIES OUTPUT_NAME ${main_target_name} )" >> ${OFN}

}

