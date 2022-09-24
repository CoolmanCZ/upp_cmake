#!/bin/bash
#
# Copyright (C) 2016-2022 Radek Malcic
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

GENERATE_DATE="$(export LC_ALL=C; date)"

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
TARGET_RENAME="TARGET_RENAME"

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
RE_USES='^uses$'
RE_LINK='^link$'
RE_LIBRARY='^library$'
RE_PKG_CONFIG='^pkg_config$'
RE_STATIC_LIBRARY='^static_library$'
RE_OPTIONS='^options$'
RE_FILES='^file$'
RE_INCLUDE='^include$'
RE_TARGET='^target$'
RE_SEPARATOR='separator'
RE_IMPORT='import.ext'
RE_IMPORT_ADD='^files|^includes'
RE_IMPORT_DEL='^exclude'
RE_FILE_DOT='\.'
RE_FILE_SPLIT='(options|charset|optimize_speed|highlight)'
RE_FILE_EXCLUDE='(depends\(\))'
RE_FILE_PCH='(PCH)'

UPP_ALL_USES=()
UPP_ALL_USES_DONE=()
INCLUDE_SYSTEM_LIST=()

SECTIONS=("acceptflags" "charset" "custom" "description" "file" "flags" "include" "library" "static_library" "link" "optimize_size" "optimize_speed" "options" "mainconfig" "noblitz" "target" "uses" "pkg_config")
RE_SKIP_SECTIONS='(acceptflags|mainconfig|charset|description|optimize_size|optimize_speed|noblitz)'

get_section_name()
{
    local line="${1}"
    line="${line//\(/ }"
    line="${line//\)/ }"
    local tmp=(${line})
    local name="$(string_trim_spaces_both "${tmp[0]}")"
    if [[ " ${SECTIONS[@]} " =~ " ${name} " ]]; then
        echo "${name}"
    fi
}

get_section_line()
{
    local section="${1}"
    local line="$(string_trim_spaces_both "${2}")"
    line="${line/#${section}/}"
    echo "$(string_trim_spaces_both "${line}")"
}

test_required_binaries()
{
    # Requirement for generating the CMakeList files
    local my_sort="$(which sort)"
    local my_date="$(which date)"
    local my_find="$(which find)"
    local my_xargs="$(which xargs)"

    if [ -z "${my_sort}" ] || [ -z "${my_date}" ] || [ -z "${my_find}" ] || [ -z "${my_xargs}" ] ; then
        echo "ERROR - Requirement for generating the CMakeList files failed."
        echo "ERROR - Can not continue -> Exiting!"
        echo "sort=\"${my_sort}\""
        echo "date=\"${my_date}\""
        echo "find=\"${my_find}\""
        echo "xargs=\"${my_xargs}\""
        exit 1
    fi
}

string_trim_spaces_both()
{
    local line="${1}"

    line="${line#"${line%%[![:space:]]*}"}" # remove leading whitespace from a string
    line="${line%"${line##*[![:space:]]}"}" # remove trailing whitespace from a string

    echo "${line}"
}

string_remove_separators()
{
    local line="${1}"

    line="${line//,}"   # Remove ','
    line="${line//;}"   # Remove ';'

echo "${line}"
}

string_remove_comma()
{
    local line="$(string_remove_separators "${1}")"

    line="${line//\"}"  # Remove '"'

    echo "${line}"
}

string_replace_dash()
{
    local line="${1}"

    line="${line//\//_}"

    echo "${line}"
}

string_get_in_parenthesis()
{
    local line="${1}"

    if [[ "${line}" =~ \( ]]; then
        # Get string inside parenthesis
        line=${line#*(}
        line=${line%)*}
        line="${line//& }"  # Remove all '& '
        echo "${line}"
    else
        echo
    fi
}

string_get_after_parenthesis()
{
    local line="${1}"

    line="${line##*) }"       # Get string after the right parenthesis

    echo "${line}"
}

string_get_before_parenthesis()
{
    local line="${1}"

    line="${line%%(*}"        # Get string before the left parenthesis

    echo "${line}"
}

if_options_replace()
{
    local options="$(string_trim_spaces_both "${1}")"
    local output=""

    if [ -n "${options}" ]; then
        case "${options}" in
            "OR") # operand
                output="OR"
                ;;
            "SHARED")
                output="BUILD_SHARED_LIBS"
                ;;
            "WIN32")
                output="WIN32"
                ;;
        esac

        if [ -n "${options}" ] && [ -z "${output}" ]; then
            output="DEFINED flag${options}"
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
    local options_replacement="${1/|/ | }"
    local OPTIONS=(${options_replacement})

    if [ -n "${OPTIONS}" ]; then
        for list in "${OPTIONS[@]}"; do

            # Don't process alone '!' operand
            if [[ "${list}" =~ '!' ]] && [ "${#list}" -eq 1 ]; then
                list=""
            fi

            if [ -n "${list}" ]; then
                (( counter++ ))

                operand="${next_operand}"

                if [ "${list}" = '|' ]; then
                    operand=" "
                    list="OR"
                    next_operand=" "
                else
                    next_operand=" AND "
                fi

                if [[ "${list}" =~ '!' ]]; then
                    list="${list//!}"
                    if [ "${counter}" -eq 1 ]; then
                        operand="NOT "
                    else
                        operand+="NOT "
                    fi
                fi

                # Don't insert 'AND operand as first option parameter
                if [ "${counter}" -eq 1 ] && [[ "${operand}" = " AND " ]]; then
                    operand=""
                fi

                list="$(if_options_replace "${list}")"
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

    # Split options
    local begin=0
    local brace=0
    for i in $( seq 0 $(( ${#line} )) ); do
        if [ "${line:${i}:1}" == "(" ]; then
            local length=$((i - begin))
            if [ ${length} -gt 1 ]; then
              ALL_OPTIONS+=("${line:${begin}:${length}}")
            fi
            begin=$((i + 1))
            (( brace++ ))
        fi
        if [ ${brace} -gt 0 ] && [ "${line:${i}:1}" == ")" ]; then
            local length=$((i - begin))
            if [ ${length} -gt 1 ]; then
              ALL_OPTIONS+=("${line:${begin}:${length}}")
            fi
            begin=$((i + 1))
            (( brace-- ))
        fi
    done
    if [ $begin -lt ${#line} ]; then
        ALL_OPTIONS+=("${line:${begin}}")
    fi

    if [ ${#ALL_OPTIONS[@]} -eq 0 ]; then
      ALL_OPTIONS+=("$(string_trim_spaces_both "${line}")")
    fi

    # Process options
    if [ -n "${ALL_OPTIONS}" ]; then
        for list in "${ALL_OPTIONS[@]}"; do
            result="("$(if_options_parse "${list}")")"  # Parse options
            result="${result//\(OR / OR \(}"            # Move 'OR'
            result="${result//\(\)}"                    # Delete empty parenthesis
            output+="${result}"
        done
    fi

    echo "${output//\)\(/\) AND \(}"                    # Put 'AND' between options
}

add_require_for_lib()
{
    local link_list="${1}"
    local check_lib_name="${2}"
    local pkg_config_module="${3}"
    local req_lib_dir="DIRS"
    local req_lib_name=""
    local req_lib_param=""
    local use_pkg="0"

    if [ "${pkg_config_module}" == "1" ]; then
        req_lib_name="${check_lib_name}"
        req_lib_param="${check_lib_name}"
        use_pkg="1"
    fi

    if [ -n "${req_lib_name}" ]; then
        if [ "${use_pkg}" == "0" ]; then
            echo "  find_package ( ${req_lib_name} REQUIRED ${req_lib_param} )" >> "${OFN}"
        else
            echo "  find_package ( PkgConfig REQUIRED )" >> "${OFN}"
            echo "  pkg_check_modules ( ${req_lib_name^^} REQUIRED ${req_lib_param})" >> "${OFN}"
        fi
        echo "  if ( ${req_lib_name^^}_FOUND )" >> "${OFN}"
        echo "      list ( APPEND ${INCLUDE_LIST} \${${req_lib_name^^}_INCLUDE_${req_lib_dir}} )" >> "${OFN}"
        echo "      list ( APPEND ${link_list} \${${req_lib_name^^}_LIBRARIES} )" >> "${OFN}"
        echo "      # remove leading or trailing whitespace (e.g. for SDL2)" >> "${OFN}"
        echo "      if ( ${link_list} )" >> "${OFN}"
        echo "          string ( STRIP \"\${${link_list}}\" ${link_list} )" >> "${OFN}"
        echo "      endif()" >> "${OFN}"
        if [ "${check_lib_name}" == "pthread" ]; then
            echo "      if ( CMAKE_THREAD_LIBS_INIT )" >> "${OFN}"
            echo "          list ( APPEND ${link_list} \${CMAKE_THREAD_LIBS_INIT} )" >> "${OFN}"
            echo "      endif()" >> "${OFN}"
        fi
        echo "  endif()" >> "${OFN}"
    else
        echo "${check_lib_name}"
    fi
}

add_all_uses() {
    local value="$1"

    if [[ ! " ${UPP_ALL_USES[@]} " =~ " ${value} " ]]; then
        UPP_ALL_USES+=(${value})
    fi
}

list_parse()
{
    local line="${1}"
    local list="${2}"
    local target_name="${3}"
    local list_append="${4}"
    local options=""
    local parameters=""

    echo >> "${OFN}"
    if [ -z "${list_append}" ]; then
        echo "# ${line}" >> "${OFN}"
    else
        echo "# ${list_append} ${line}" >> "${OFN}"
    fi
#    echo "\"line: $line\""

    if [[ "${line}" =~ BUILDER_OPTION ]]; then
        $(if_options_builder "${line}")
    else
        if [ -z "${list_append}" ]; then
            options="$(string_get_in_parenthesis "${line}")"
#            echo "\"options: $options\""
            options=$(if_options_parse_all "${options}")            # Parse options
#            echo "\"options: $options\""

            parameters="$(string_get_after_parenthesis "${line}")"
            parameters="$(string_remove_comma "${parameters}")"
#            echo "\"param  : $parameters\""
        else
#            echo "\"options:\""
            parameters="$(string_remove_comma "${line}")"
#            echo "\"param : $parameters\""
        fi
#            echo "\"list  : $list\""

        if [ -n "${options}" ] ; then
            echo "if (${options})" >> "${OFN}"
        fi

        # Add optional dependency target to generate CMakeLists.txt
        if [[ "${list}" =~ "${DEPEND_LIST}" ]]; then
            local -a new_parameters=("${parameters}")
            parameters=""
            for item in ${new_parameters[@]}; do
                parameters+="$(string_replace_dash "${item}${LIB_SUFFIX}") "
                add_all_uses "${item}"
            done

            local trim_link_parameters="$(string_trim_spaces_both "${parameters}")"
            if [ -n "${trim_link_parameters}" ]; then
                echo "  list ( APPEND ${list} ${trim_link_parameters} )" >> "${OFN}"
            fi
        fi

        local add_link_library=""
        if [ -n "${target_name}" ]; then
            local pkg_config_module="0"
            if [[ "${line}" =~ ^pkg_config || "${list_append}" =~ ^pkg_config ]]; then
                pkg_config_module="1"
            fi
            local -a check_library_array=(${parameters})
            for check_library in "${check_library_array[@]}"; do
                add_link_library+="$(add_require_for_lib "${list}" "${check_library}" "${pkg_config_module}") "
            done
        fi

        local trim_link_library="$(string_trim_spaces_both "${add_link_library}")"
        if [ -n "${trim_link_library}" ]; then
            echo "  list ( APPEND ${list} ${trim_link_library} )" >> "${OFN}"
        fi

        if [ -n "${options}" ] ; then
            echo "endif()" >> "${OFN}"
        fi
    fi
}

target_parse()
{
    local line="${1}"
    local options=""
    local parameters=""

    echo >> "${OFN}"
    echo "#${1}" >> "${OFN}"

    line="${line/#${section}/}"
    options="$(string_get_in_parenthesis "${line}")"
    if [ -n "${options}" ]; then
        options="$(if_options_parse_all "${options}")"              # Parse options
    fi

    parameters="$(string_get_after_parenthesis "${line}")"
    parameters="${parameters//;}"
    parameters="${parameters//\"}"
    parameters="$(string_trim_spaces_both "${parameters}")"

    if [ -n "${options}" ]; then
        echo "if (${options})" >> "${OFN}"
        echo "  set ( ${TARGET_RENAME} \"${parameters}\" PARENT_SCOPE )" >> "${OFN}"
        echo "endif()" >> "${OFN}"
    else
        echo "set ( ${TARGET_RENAME} \"${parameters}\" PARENT_SCOPE )" >> "${OFN}"
    fi
}

link_parse()
{
    local line="${1}"
    local options=""
    local parameters=""

    echo >> "${OFN}"
    echo "# ${1}" >> "${OFN}"

    options="$(string_get_in_parenthesis "${line}")"
    if [ -n "${options}" ]; then
        options="$(if_options_parse_all "${options}")"              # Parse options
    fi

    parameters="$(string_get_after_parenthesis "${line}")"
    parameters="${parameters//;}"
    parameters="${parameters//\"}"

    if [ -n "${options}" ]; then
        echo "if (${options})" >> "${OFN}"
        echo "  set ( MAIN_TARGET_LINK_FLAGS "\${MAIN_TARGET_LINK_FLAGS} ${parameters}" PARENT_SCOPE )" >> "${OFN}"
        echo "endif()" >> "${OFN}"
    fi
}

if_options_builder()
{
    local line="${1}"
    local options="$(string_get_after_parenthesis "${line}")"
    local parameters_gcc=""
    local parameters_msvc=""

    if [[ "${options}" =~ NOWARNINGS ]]; then
        parameters_gcc="-w"
        parameters_msvc="-W0"
    fi

    if [ -n "${parameters_gcc}" ]; then
        echo 'if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )' >> "${OFN}"
        echo "  set ( CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE} \"\${CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE}} ${parameters_gcc}\")" >> "${OFN}"
        echo "  set ( CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE} \"\${CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE}} ${parameters_gcc}\")" >> "${OFN}"
        echo 'elseif ( MSVC )' >> "${OFN}"
        echo "  set ( CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE} \"\${CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE}} ${parameters_msvc}\")" >> "${OFN}"
        echo "  set ( CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE} \"\${CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE}} ${parameters_msvc}\")" >> "${OFN}"
        echo 'endif()' >> "${OFN}"
    fi
}

binary_resource_parse()
{
    local parse_file="${1}"
    local binary_array_first_def=""
    local binary_mask_first_def=""

    if [ -n "${parse_file}" ] && [ -f "${parse_file}" ]; then
        local line=""
        local -a lines
        local -a binary_array_names
        local -a binary_array_names_library

        mapfile -t lines < "${parse_file}"

        for line in "${lines[@]}"; do
            # Remove DOS line ending
            line="${line//[$'\r']/}"

            if [ -n "${line}" ]; then
                local parameter="$(string_get_before_parenthesis "${line}")"
                parameter="$(string_trim_spaces_both "${parameter}")"
                local options="$(string_get_in_parenthesis "${line}")"
                read -d '' -ra options_params < <(printf '%s\0' "${options}")

                if [ "${parameter}" == "BINARY_ARRAY" ]; then
                    local symbol_name="$(string_trim_spaces_both "${options_params[0]//,}")"
                    local symbol_name_array="$(string_trim_spaces_both "${options_params[1]//,}")"
                    local symbol_file_name="$(string_trim_spaces_both "${options_params[2]//\"}")"
                    local symbol_file_compress="${options_params[4]}"
                else
                    local symbol_name="$(string_trim_spaces_both "${options_params[0]//,}")"
                    local symbol_file_name="$(string_trim_spaces_both "${options_params[1]//\"}")"
                    local symbol_file_compress="${options_params[2]}"
                fi

                if [ -z "${symbol_file_compress}" ]; then
                    symbol_file_compress="none"
                fi

                # Parse BINARY resources
                if [ "${parameter}" == "BINARY" ]; then

                    echo >> "${OFN}"
                    echo "# BINARY file" >> "${OFN}"
                    echo "create_brc_source ( ${symbol_file_name} ${symbol_name}.cpp ${symbol_name} ${symbol_file_compress} write )" >> "${OFN}"
                    echo "set_source_files_properties ( \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp PROPERTIES GENERATED TRUE )" >> "${OFN}"
                    echo "list ( APPEND ${SOURCE_LIST_CPP} \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp )" >> "${OFN}"

                # parse BINARY_ARRAY resources
                elif [ "${parameter}" == "BINARY_ARRAY" ]; then

                    local file_creation="append"
                    if [ -z "${binary_array_first_def}" ]; then
                        binary_array_first_def="done"
                        file_creation="write"
                    fi

                    binary_array_names+=("${symbol_name}_${symbol_name_array}")

                    echo >> "${OFN}"
                    echo "# BINARY_ARRAY file" >> "${OFN}"
                    echo "create_brc_source ( ${symbol_file_name} binary_array.cpp ${symbol_name}_${symbol_name_array} ${symbol_file_compress} ${file_creation} )" >> "${OFN}"

                # parse BINARY_MASK resources
                elif [ "${parameter}" == "BINARY_MASK" ]; then

                    local -a binary_mask_files=("$(eval echo "${symbol_file_name}")")

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

                                echo >> "${OFN}"
                                echo "# BINARY_MASK file" >> "${OFN}"
                                echo "create_brc_source ( ${binary_file} ${symbol_name}.cpp ${symbol_name}_${all_count} ${symbol_file_compress} ${file_creation} )" >> "${OFN}"

                                all_array_files+=("$(basename "${binary_file}")")
                                (( all_count++ ))
                            fi
                        done

                        # Generate cpp file for the BINARY_MASK
                        echo >> "${OFN}"
                        echo "# Append additional information of the BINARY_MASK binary resource (${symbol_name})" >> "${OFN}"
                        echo "file ( APPEND \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp \"" >> "${OFN}"
                        echo "int ${symbol_name}_count = ${all_count};" >> "${OFN}"

                        echo "int ${symbol_name}_length[] = {" >> "${OFN}"
                        for (( i=0; i<${all_count}; i++ )); do
                            echo "  ${symbol_name}_${i}_length," >> "${OFN}"
                        done
                        echo "};" >> "${OFN}"

                        echo "unsigned char *${symbol_name}[] = {" >> "${OFN}"
                        for (( i=0; i<${all_count}; i++ )); do
                            echo "  ${symbol_name}_${i}_," >> "${OFN}"
                        done
                        echo "};" >> "${OFN}"

                        echo "char const *${symbol_name}_files[] = {" >> "${OFN}"
                        local binary_filename=""
                        for binary_file_name in "${all_array_files[@]}"; do
                            echo "  \\\"${binary_file_name}\\\"," >> "${OFN}"
                        done
                        echo "};" >> "${OFN}"

                        echo "\")" >> "${OFN}"
                        echo "set_source_files_properties ( \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp PROPERTIES GENERATED TRUE )" >> "${OFN}"
                        echo "list ( APPEND ${SOURCE_LIST_CPP} \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp )" >> "${OFN}"

                    else
                        echo >> "${OFN}"
                        echo "# BINARY_MASK file" >> "${OFN}"
                        echo "# No files match the mask: '${symbol_file_name}'" >> "${OFN}"
                    fi

                fi # BINARY end
            fi
        done

        # Generate cpp file for the BINARY_ARRAY
        if [ -n "${binary_array_names}" ]; then
#           echo "# ${binary_array_names[@]}" >> "${OFN}"

            local test_first_iteration
            local binary_array_name_count=0
            local binary_array_name_test
            local binary_array_name_first
            local binary_array_name_second

            echo >> "${OFN}"
            echo "# Append additional information of the BINARY_ARRAY binary resource" >> "${OFN}"
            echo "file ( APPEND \${CMAKE_CURRENT_BINARY_DIR}/binary_array.cpp \"" >> "${OFN}"

            for binary_array_record in "${binary_array_names[@]}"; do
                binary_array_name_split=(${binary_array_record//_[0-9]/ })
                if [ ! "${binary_array_name_split[0]}" == "${binary_array_name_test}" ]; then
                    if [ -z "${test_first_iteration}" ]; then
                        test_first_iteration="done"
                    else
                        echo "int ${binary_array_name_test}_count = ${binary_array_name_count};" >> "${OFN}"
                        echo -e "${binary_array_name_first}" >> "${OFN}"
                        echo -e "};\n" >> "${OFN}"
                        echo -e "${binary_array_name_second}" >> "${OFN}"
                        echo -e "};\n" >> "${OFN}"
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
            echo "int ${binary_array_name_test}_count = ${binary_array_name_count};" >> "${OFN}"
            echo -e "${binary_array_name_first}" >> "${OFN}"
            echo -e "};" >> "${OFN}"
            echo -e "${binary_array_name_second}" >> "${OFN}"
            echo -e "};" >> "${OFN}"
            echo "\")" >> "${OFN}"
            echo "set_source_files_properties ( \${CMAKE_CURRENT_BINARY_DIR}/binary_array.cpp PROPERTIES GENERATED TRUE )" >> "${OFN}"
            echo "list ( APPEND ${SOURCE_LIST_CPP} \${CMAKE_CURRENT_BINARY_DIR}/binary_array.cpp )" >> "${OFN}"
        fi
    else
        echo "File \"${parse_file}\" not found!"
    fi
}

import_ext_parse()
{
    local parse_file="$(string_remove_comma ${1})"
    local files_add=0
    local files_del=0
    local line=""
    local -a lines
    local -a added_files
    local -a excluded_files
    local -a result

    mapfile -t lines < "${parse_file}"

    for line in "${lines[@]}"; do
        # Remove DOS line ending
        line="${line//[$'\r']/}"

        # Begin of the add section
        if [[ "${line}" =~ $RE_IMPORT_ADD ]]; then
            files_add=1
        fi

        # Begin of the del section
        if [[ "${line}" =~ $RE_IMPORT_DEl ]]; then
            files_del=1
        fi

        if [ "${files_add}" -gt 0 ]; then
            # End of the add section (line with ';')
            if [[ ${line} =~ ';' ]]; then
                files_add=2
            fi

            # Remove ',' and ';'
            line="$(string_remove_separators "${line}")"

            # Convert line to array
            read -a line_array <<< "${line}"
            for list in "${line_array[@]}"; do
                list="$(string_remove_separators "${list}")"
                if [[ ! "${list}" =~ $RE_IMPORT_ADD ]]; then
                    if [[ "${list}" =~ "*" ]]; then
                        added_files+=("$(find -name "${list}")")
                    else
                        added_files+=("$(find -nowarn -samefile "${list}" 2>/dev/null)")
                    fi
                fi
            done

            if [ "${files_add}" -eq 2 ]; then
                files_add=-1
            fi
        fi

        if [ "${files_del}" -gt 0 ]; then
            # End of the del section (line with ';')
            if [ "${files_del}" -gt 0 ] && [[ "${line}" =~ ';' ]]; then
                files_del=2
            fi

            # Remove ',' and ';'
            line="$(string_remove_separators "${line}")"

            # Convert line to array
            read -a line_array <<< "${line}"
            for list in "${line_array[@]}"; do
                list="$(string_remove_separators "${list}")"
                if [[ ! "${list}" =~ $RE_IMPORT_DEl ]]; then
                    if [[ "${list}" =~ "*" ]]; then
                        excluded_files+=("$(find -name "${list}")")
                    else
                        excluded_files+=("$(find -samefile "${list}" 2>/dev/null)")
                    fi
                fi
            done

            if [ "${files_del}" -eq 2 ]; then
                files_del=-1
            fi
        fi
    done

    for value in "${added_files[@]}"; do
        if [[ ! " ${excluded_files[@]} " =~ " ${value} " ]]; then
            result+=(${value})
        fi
    done
    echo "${result[@]}"
}

generate_cmake_header()
{

    if [ -f ""${OFN}"" ]; then
        rm ""${OFN}""
    fi

    cat > "${OFN}" << EOL
# ${OFN} generated ${GENERATE_DATE}
cmake_minimum_required ( VERSION 3.4.1 )

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

    local tmp=""
    local line=""
    local dir_array=()

    INCLUDE_SYSTEM_LIST=()

    if [ -f "${upp_ext}" ]; then
        local target_name="$(string_replace_dash "${object_name}")"
        local name=""
        local content=()
        local section_name=()
        local section_content=()

        # parse upp file
        while read -r line; do
            # Replace '\' to '/'
            line="${line//\\//}"
            # Remove DOS line ending
            line="${line//[$'\r']/}"
            test_name="$(get_section_name "${line}")"
            if [ ! "${test_name}" == "" ]; then
                if [ ! "${name}" == "" ]; then
                    section_name+=("${name}")
                    section_content+=("$(printf " \'%s\' " "${content[@]}")")
                    content=()
                fi
                name="${test_name}"
            fi

            section_line="$(get_section_line "${name}" "${line}")"
            if [ "${section_line}" == "" ]; then
                continue;
            fi

            content+=("${section_line}")
        done < "${upp_ext}"
        section_name+=("${name}")
        section_content+=("$(printf " \'%s\' " "${content[@]}")")

        # process sections
        for index in ${!section_name[@]}; do
            local section="${section_name[$index]}"
            if [[ "${section}" =~ $RE_SKIP_SECTIONS ]]; then
                continue;
            fi

            content=()
            while read word; do
                content+=("$word")
            done < <(echo "${section_content[$index]}" | xargs -n 1)

#            echo "section: ${section} (${#content[@]})"
#            echo "content: ${content[@]}"
#            echo "data   : ${section_content[$index]}"
#            echo "===================================================================="

            # Parse target options
            if [ -n "${main_target}" ] && [[ "${section}" =~ $RE_TARGET ]]; then
                for LINE in "${content[@]}"; do
                    target_parse "target ${LINE}"
                done
            fi

            # Parse compiler options
            if [[ "${section}" =~ $RE_USES ]]; then
                for LINE in "${content[@]}"; do
                    if [[ "${LINE:0:1}" == "(" ]] && [[ ${LINE} =~ ';' ]]; then
                        list_parse "uses${LINE}" ${target_name}_${DEPEND_LIST}
                    else
                        tmp="$(string_remove_separators "${LINE}")"
                        USES+=(${tmp})
                        add_all_uses "${tmp}"
                    fi
                done
            fi

            # Parse library list options
            if [[ "${section}" =~ $RE_LIBRARY ]] || [[ "${section}" =~ $RE_PKG_CONFIG ]] || [[ "${section}" =~ $RE_STATIC_LIBRARY ]]; then
                for LINE in "${content[@]}"; do
                    if [[ "${LINE:0:1}" == "(" ]] && [[ "${LINE}" =~ ';' ]]; then
                        if [[ "${section}" =~ $RE_PKG_CONFIG ]]; then
                            list_parse "pkg_config${LINE}" "${LINK_LIST}" "${target_name}"
                        else
                            list_parse "library${LINE}" "${LINK_LIST}" "${target_name}"
                        fi
                    else
                        if [[ "${section}" =~ $RE_PKG_CONFIG ]]; then
                            list_parse "${LINE}" "${LINK_LIST}" "${target_name}" "pkg_config"
                        else
                            list_parse "${LINE}" "${LINK_LIST}" "${target_name}" "append library"
                        fi
                    fi
                done
            fi

            # Parse options section
            if [[ "${section}" =~ $RE_OPTIONS ]]; then
                for LINE in "${content[@]}"; do
                    if [[ "${LINE:0:1}" == "(" ]] && [[ "${LINE}" =~ ';' ]]; then
                        list_parse "options${LINE}" "${COMPILE_FLAGS_LIST}" "${target_name}"
                    else
                        tmp="$(string_remove_separators "${LINE}")"
                        OPTIONS+=(${tmp})
                    fi
                done
            fi

            # Parse include options
            if [[ "${section}" =~ $RE_INCLUDE ]]; then
                for LINE in "${content[@]}"; do
                    LINE="$(string_remove_separators "${LINE}")"
                    INCLUDE_SYSTEM_LIST+=("${LINE}")
                done
            fi

            # Parse link options
            if [[ "${section}" =~ $RE_LINK ]]; then
                for LINE in "${content[@]}"; do
                    link_parse "link${LINE}"
                done
            fi

            # Parse files
            if [[ "${section}" =~ $RE_FILES ]]; then
                local list=""
                local line_array=()

                for LINE in "${content[@]}"; do
                    # Skip lines with "separator" mark
                    if [[ "${LINE}" =~ $RE_SEPARATOR ]]; then
                        continue
                    fi

                    # Find precompiled header option
                    if [[ "${LINE}" =~ $RE_FILE_PCH ]] && [[ "${LINE}" =~ BUILDER_OPTION ]]; then
                        local pch_file=${LINE// */}
                        echo >> "${OFN}"
                        echo '# Precompiled headers file' >> "${OFN}"
                        echo "set ( ${PCH_FILE} "\${CMAKE_CURRENT_SOURCE_DIR}/${pch_file}" )" >> "${OFN}"
                    fi

                    # Split lines with charset, options, ...
                    if [[ "${LINE}" =~ $RE_FILE_SPLIT ]]; then
                        LINE="${LINE// */}"
                    fi

                    if [[ "${LINE}" =~ $RE_IMPORT ]]; then
                        line_array=("$(import_ext_parse "${LINE}")")
                        dir_array=("$(dirname ${line_array[@]} | sort -u)")
                    else
                        line_array+=(${LINE})
                    fi
                done

                for list in "${line_array[@]}"; do
                    list="$(string_remove_separators "${list}")"

                    if [[ "${list}" =~ $RE_FILE_EXCLUDE ]]; then
                        continue;
                    fi

                    if [ -d "${list}" ]; then
                        if [ "${GENERATE_DEBUG}" == "1" ]; then
                            echo "WARNING - skipping the directory \"${list}\". Directory can't be added to the source list."
                        fi
                    elif [ ! -f "${list}" ]; then
                        if [ "${GENERATE_DEBUG}" == "1" ]; then
                            echo "WARNING - file \"${list}\" doesn't exist! It was not added to the source list."
                        fi
                    else
                        if [[ "${list}" =~ $RE_C ]]; then         # C/C++ source files
                            SOURCE_C+=(${list})
                        elif [[ "${list}" =~ $RE_CPP ]]; then     # C/C++ source files
                            SOURCE_CPP+=(${list})
                        elif [[ "${list}" =~ $RE_RC ]]; then      # Windows resource config files
                            SOURCE_RC+=(${list})
                        elif [[ "${list}" =~ $RE_ICPP ]]; then    # icpp C/C++ source files
                            SOURCE_ICPP+=(${list})
                        elif [[ "${list}" =~ $RE_BRC ]]; then     # BRC resource files
                            $(binary_resource_parse "$list")
                            HEADER+=("${list}")
                        elif [[ "${list}" =~ $RE_FILE_DOT ]]; then  # header files
                            HEADER+=(${list})
                        fi
                    fi
                done
            fi

        done

        # Create include directory list
        if [ -n "${dir_array}" ]; then
            echo >> "${OFN}"
            echo "include_directories (" >> "${OFN}"
            for list in "${dir_array[@]}"; do
                if [[ " ${list} " != " . " ]]; then
                    echo "      ${list}" >> "${OFN}"
                fi
            done
            echo ")" >> "${OFN}"
        fi

        # Create project option definitions
        if [ -n "${OPTIONS}" ]; then
            echo >> "${OFN}"
            echo "add_definitions (" >> "${OFN}"
            for list in "${OPTIONS[@]}"; do
                echo "${list}" >> "${OFN}"
            done
            echo ")" >> "${OFN}"
        fi

        # Create header files list
        if [ -n "${HEADER}" ]; then
            echo >> "${OFN}"
            echo "list ( APPEND ${HEADER_LIST}" >> "${OFN}"
            for list in "${HEADER[@]}"; do
                echo "      ${list}" >> "${OFN}"
            done
            echo ")" >> "${OFN}"
        fi

        # Create C source files list
        if [ -n "${SOURCE_C}" ]; then
            echo >> "${OFN}"
            echo "list ( APPEND ${SOURCE_LIST_C}" >> "${OFN}"
            for list in "${SOURCE_C[@]}"; do
                echo "      ${list}" >> "${OFN}"
            done
            echo ")" >> "${OFN}"
        fi

        # Create CPP source files list
        if [ -n "${SOURCE_CPP}" ]; then
            echo >> "${OFN}"
            echo "list ( APPEND ${SOURCE_LIST_CPP}" >> "${OFN}"
            for list in "${SOURCE_CPP[@]}"; do
                echo "      ${list}" >> "${OFN}"
            done
            echo ")" >> "${OFN}"
        fi

        # Create icpp source files list
        if [ -n "${SOURCE_ICPP}" ]; then
            echo >> "${OFN}"
            echo "list ( APPEND ${SOURCE_LIST_ICPP}" >> "${OFN}"
            for list in "${SOURCE_ICPP[@]}"; do
                echo "      ${list}" >> "${OFN}"
            done
            echo ")" >> "${OFN}"
        fi

        # Create dependency list
        if [ -n "${USES}" ]; then
            echo >> "${OFN}"
            echo "list ( APPEND ${target_name}_${DEPEND_LIST}" >> "${OFN}"
            for list in "${USES[@]}"; do
                local dependency_name="$(string_replace_dash "${list}")"
                echo "      ${dependency_name}${LIB_SUFFIX}" >> "${OFN}"
            done
            echo ")" >> "${OFN}"
        fi

        # Copy Windows resource config file
        if [ -n "${main_target}" ] && [ -n "${SOURCE_RC}" ] ; then
            for list in "${SOURCE_RC[@]}"; do
                if [ -f "${list}" ]; then
                    echo >> "${OFN}"
                    echo "# Copy Windows resource config file to the main program build directory" >> "${OFN}"
                    local line_rc_params=()
                    while read line_rc; do
                        if [[ "${line_rc}" =~ ICON ]]; then
                            line_rc_params=(${line_rc})
                            echo "file ( COPY \"${list}\" DESTINATION \${PROJECT_BINARY_DIR}/\${CMAKE_PROJECT_NAME} )" >> "${OFN}"
                            echo "file ( COPY ${line_rc_params[3]} DESTINATION \${PROJECT_BINARY_DIR}/\${CMAKE_PROJECT_NAME} )" >> "${OFN}"
                            break
                        fi
                    done < "${list}"
                fi
            done
        fi

        echo >> "${OFN}"
        echo "# Module properties" >> "${OFN}"
        echo "create_cpps_from_icpps()" >> "${OFN}"
        echo "set_source_files_properties ( \${$HEADER_LIST} PROPERTIES HEADER_FILE_ONLY ON )" >> "${OFN}"
        echo "add_library ( ${target_name}${LIB_SUFFIX} \${LIB_TYPE} \${$SOURCE_LIST_CPP} \${$SOURCE_LIST_C} \${$HEADER_LIST} )" >> "${OFN}"
        echo "target_include_directories ( ${target_name}${LIB_SUFFIX} PUBLIC \${${INCLUDE_LIST}} )" >> "${OFN}"
        echo "set_property ( TARGET ${target_name}${LIB_SUFFIX} APPEND PROPERTY COMPILE_OPTIONS \"\${${COMPILE_FLAGS_LIST}}\" )" >> "${OFN}"

        echo >> "${OFN}"
        echo "# Module link" >> "${OFN}"
        echo "if ( ${target_name}_${DEPEND_LIST} OR ${LINK_LIST} )" >> "${OFN}"
        echo "  target_link_libraries ( ${target_name}${LIB_SUFFIX} \${${target_name}_${DEPEND_LIST}} \${${LINK_LIST}} )" >> "${OFN}"
        echo "endif()" >> "${OFN}"

        echo >> "${OFN}"
        echo '# Precompiled headers settings' >> "${OFN}"
        echo "get_directory_property ( ${PCH_COMPILE_DEFINITIONS} COMPILE_DEFINITIONS )" >> "${OFN}"
        echo "set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES ${COMPILE_FLAGS_LIST} \"\${${COMPILE_FLAGS_LIST}}\" )" >> "${OFN}"
        echo "set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES ${PCH_FILE} \"\${${PCH_FILE}}\" )" >> "${OFN}"
        echo "set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES ${PCH_INCLUDE_LIST} \"\${${INCLUDE_LIST}}\" )" >> "${OFN}"
        echo "set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES ${PCH_COMPILE_DEFINITIONS} \"\${${PCH_COMPILE_DEFINITIONS}}\" )" >> "${OFN}"
        echo >> "${OFN}"
        echo "list ( LENGTH ${PCH_FILE} ${PCH_FILE}_LENGTH )" >> "${OFN}"
        echo "if ( ${PCH_FILE}_LENGTH GREATER 1 )" >> "${OFN}"
        echo '  message ( FATAL_ERROR "Precompiled headers list can contain only one header file!" )' >> "${OFN}"
        echo 'endif()' >> "${OFN}"
        echo >> "${OFN}"
        echo "if ( ${PCH_FILE} AND DEFINED flagPCH )" >> "${OFN}"
        echo "  get_filename_component ( PCH_NAME \${${PCH_FILE}} NAME )" >> "${OFN}"
        echo "  set ( PCH_DIR \${PROJECT_PCH_DIR}/${target_name}${LIB_SUFFIX} )" >> "${OFN}"
        echo '  set ( PCH_HEADER ${PCH_DIR}/${PCH_NAME} )' >> "${OFN}"
        echo '  if ( ${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU" )' >> "${OFN}"
        echo '      if ( ${CMAKE_VERBOSE_MAKEFILE} EQUAL 1 )' >> "${OFN}"
        echo '        set ( PCH_INCLUDE_PARAMS " -H -Winvalid-pch -include ${PCH_HEADER}" )' >> "${OFN}"
        echo '      else()' >> "${OFN}"
        echo '        set ( PCH_INCLUDE_PARAMS " -Winvalid-pch -include ${PCH_HEADER}" )' >> "${OFN}"
        echo '      endif()' >> "${OFN}"
        echo '  endif()' >> "${OFN}"
        echo '  if ( ${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" )' >> "${OFN}"
        echo '      set ( PCH_INCLUDE_PARAMS " -Winvalid-pch -include-pch ${PCH_HEADER}.pch" )' >> "${OFN}"
        echo '  endif()' >> "${OFN}"
        echo '  if ( MSVC )' >> "${OFN}"
        echo "      set_target_properties ( ${target_name}${LIB_SUFFIX} PROPERTIES COMPILE_FLAGS \"-Yu\${PCH_NAME} -Fp\${PCH_HEADER}.pch\" )" >> "${OFN}"
        echo "      set_source_files_properties ( \${$SOURCE_LIST_CPP} PROPERTIES COMPILE_FLAGS \"Yc\${PCH_NAME} -Fp\${PCH_HEADER}.pch\" )" >> "${OFN}"
        echo '  endif()' >> "${OFN}"
        echo '  if ( PCH_INCLUDE_PARAMS )' >> "${OFN}"
        echo "      set_source_files_properties ( \${$SOURCE_LIST_CPP} PROPERTIES COMPILE_FLAGS \"\${PCH_INCLUDE_PARAMS}\" )" >> "${OFN}"
        echo '  endif()' >> "${OFN}"
        echo 'endif()' >> "${OFN}"
        echo >> "${OFN}"

    fi
}

generate_cmake_file()
{
    local param1="$(string_remove_comma "${1}")"
    local param2="$(string_remove_comma "${2}")"
    local cur_dir="$(pwd)"
    local sub_dir="$(dirname "${param1}")"
    local upp_name="$(basename "${param1}")"
    local object_name="${param2}"
    local cmake_flags="${3}"

    if [ "${GENERATE_VERBOSE}" == "1" ]; then
        echo "full path: ${cur_dir}"
        echo "sub_dir: ${sub_dir}"
        echo "upp_name: ${upp_name}"
        echo "object_name: ${object_name}"
    fi

    if [ -f "${sub_dir}/${upp_name}" ]; then
        cd "${sub_dir}"

        generate_cmake_header

        if [ -n "${cmake_flags}" ]; then
            echo >> "${OFN}"
            echo "# Module definitions" >> "${OFN}"
            echo "add_definitions ( "${cmake_flags}" )" >> "${OFN}"
        fi

        local main_target=""
        if [[ "${cmake_flags}" =~ (flagMAIN) ]]; then
            main_target="true"
        fi

        generate_cmake_from_upp "${upp_name}" "${object_name}" "${main_target}"

        cd "${cur_dir}"
    else
        echo "ERROR: file \"${sub_dir}/${upp_name}\" doesn't exist!"
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
        echo "ERROR - BASH variable \$PROJECT_NAME is not defined! Can't create archive package!"
        exit 1
    else
        echo -n "Creating archive "

        local -a sorted_UPP_ALL_USES_DONE=$(printf "%s\n" "${UPP_ALL_USES_DONE[@]}" | sort -u);

        local package_src_name_archive="$(basename "${PROJECT_NAME}").tar.bz2"
        local package_src_name_archive_list="package_archive_list.txt"

        echo "CMakeLists.txt" > "${package_src_name_archive_list}"

        find -H $(dirname "${PROJECT_NAME}") -type d '(' -name .svn -o -name .git ')' -prune -o -name '*' -type f >> "${package_src_name_archive_list}"

        echo "${UPP_SRC_DIR}/uppconfig.h" >> "${package_src_name_archive_list}"
        echo "${UPP_SRC_DIR}/guiplatform.h" >> "${package_src_name_archive_list}"

        for pkg_name in ${sorted_UPP_ALL_USES_DONE[@]}; do
            find "${UPP_SRC_DIR}/${pkg_name}" -name '*' -type f >> "${package_src_name_archive_list}"
        done

        tar -c -j -f "${package_src_name_archive}" -T "${package_src_name_archive_list}"
        rm "${package_src_name_archive_list}"

        echo "... DONE"
    fi
}

generate_main_cmake_file()
{
    local main_target="${1}"
    local main_definitions="${2//\"}"
    local main_target_dirname="$(dirname "${1}")"
    local main_target_basename="$(basename "${1}")"
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

    if [ -z "${GENERATE_NOT_Cxx}" ] || [ "${GENERATE_NOT_Cxx}" != "1" ]; then
        main_definitions+=" -DflagGNUC14"
    fi

    if [ -z "${GENERATE_NOT_PARALLEL}" ] || [ "${GENERATE_NOT_PARALLEL}" != "1" ]; then
        main_definitions+=" -DflagMP"
    fi

    if [ -z "${GENERATE_NOT_PCH}" ] || [ "${GENERATE_NOT_PCH}" != "1" ]; then
        main_definitions+=" -DflagPCH"
    fi

    REMOVE_UNUSED_CODE="OFF"
    if [ -z "${GENERATE_NOT_REMOVE_UNUSED_CODE}" ] || [ "${GENERATE_NOT_REMOVE_UNUSED_CODE}" != "1" ]; then
        REMOVE_UNUSED_CODE="ON"
    fi

	if [ -n "${PROJECT_EXTRA_INCLUDE_DIR}" ]; then
        PROJECT_EXTRA_INCLUDE="${PROJECT_EXTRA_INCLUDE_DIR}"
		if [ "${PROJECT_EXTRA_INCLUDE_SUBDIRS}" == "1" ]; then
			subdirs="$(ls -d -- ${PROJECT_EXTRA_INCLUDE_DIR}/*)"
            PROJECT_EXTRA_INCLUDE="${PROJECT_EXTRA_INCLUDE} ${subdirs//$'\n'/$' '}"
		fi
	fi

    # Begin of the cat (CMakeFiles.txt)
    cat >> "${OFN}" << EOL

# Overwrite cmake verbose makefile output
# (e.g. do not generate cmake verbose makefile output even when the debug flag is set)
# not set - do not overwrite settings
# 0 - do not generate cmake verbose makefile output
# 1 - always generate cmake verbose makefile output
set ( CMAKE_VERBOSE_OVERWRITE ${CMAKE_VERBOSE_OVERWRITE} )

# Project name
project ( ${main_target_name} )

# Set the project common path
set ( UPP_SOURCE_DIRECTORY ${UPP_SRC_DIR} )
set ( UPP_EXTRA_INCLUDE ${PROJECT_EXTRA_INCLUDE} )
set ( PROJECT_INC_DIR \${PROJECT_BINARY_DIR}/inc )
set ( PROJECT_PCH_DIR \${PROJECT_BINARY_DIR}/pch )

# Set the default include directory for the whole project
include_directories ( BEFORE \${UPP_SOURCE_DIRECTORY} )
include_directories ( BEFORE \${PROJECT_INC_DIR} \${UPP_EXTRA_INCLUDE} )
include_directories ( BEFORE \${CMAKE_CURRENT_SOURCE_DIR} )

EOL
# End of the cat (CMakeFiles.txt)

    # include directories relevant to the package
    local include_dirname="${main_target_dirname}"
    while [ ! "${include_dirname}" == "." ]; do
        echo "include_directories ( BEFORE \${CMAKE_SOURCE_DIR}/${include_dirname} )" >> "${OFN}"
        include_dirname="$(dirname "${include_dirname}")"
    done

    # Begin of the cat (CMakeFiles.txt)
    cat >> "${OFN}" << EOL

# Set the default path for built executables to the bin directory
set ( EXECUTABLE_OUTPUT_PATH \${PROJECT_BINARY_DIR}/bin )

# Project definitions
add_definitions ( ${main_definitions} )

# Option to distinguish whether to build binary with removed unused code and functions
option ( REMOVE_UNUSED_CODE "Build binary with removed unused code and functions." ${REMOVE_UNUSED_CODE} )

# Option to enable static analysis with include-what-you-use
option ( ENABLE_INCLUDE_WHAT_YOU_USE "Enable static analysis with include-what-you-use" OFF )
if ( ENABLE_INCLUDE_WHAT_YOU_USE )
    find_program( INCLUDE_WHAT_YOU_USE include-what-you-use )
    if ( INCLUDE_WHAT_YOU_USE )
        set( CMAKE_CXX_INCLUDE_WHAT_YOU_USE \${INCLUDE_WHAT_YOU_USE} )
    else()
        message( WARNING "include-what-you-use requested but executable not found" )
        set( CMAKE_CXX_INCLUDE_WHAT_YOU_USE "" CACHE STRING "" FORCE )
    endif()
endif()

# Option to enable static analysis with cppcheck
option ( ENABLE_CPPCHECK "Enable static analysis with cppcheck" OFF )
if ( ENABLE_CPPCHECK )
    find_program( CPPCHECK cppcheck)
    if ( CPPCHECK )
        set( CMAKE_CXX_CPPCHECK
        \${CPPCHECK}
        --suppress=missingInclude
        --enable=all
        --inline-suppr
        --inconclusive
        -i
        \${CMAKE_SOURCE_DIR}/imgui/lib )
    else()
        message( WARNING "cppcheck requested but executable not found" )
        set( CMAKE_CXX_CPPCHECK "" CACHE STRING "" FORCE )
    endif()
endif()

# Option to enable static analysis with clang-tidy
option ( ENABLE_CLANG_TIDY "Run clang-tidy with the compiler." OFF )
if ( ENABLE_CLANG_TIDY )
    if ( CMake_SOURCE_DIR STREQUAL CMake_BINARY_DIR )
        message ( FATAL_ERROR "ENABLE_CLANG_TIDY requires an out-of-source build!" )
    endif()

    if ( CMAKE_VERSION VERSION_LESS 3.5 )
        message ( WARNING "ENABLE_CLANG_TIDY is ON but CMAKE_VERSION is less than 3.5!" )
        set( CMAKE_C_CLANG_TIDY "" CACHE STRING "" FORCE )
        set( CMAKE_CXX_CLANG_TIDY "" CACHE STRING "" FORCE )
    else()
        find_program ( CLANG_TIDY_COMMAND NAMES clang-tidy )
        if ( NOT CLANG_TIDY_COMMAND )
            message ( WARNING "ENABLE_CLANG_TIDY is ON but clang-tidy is not found!" )
            set( CMAKE_C_CLANG_TIDY "" CACHE STRING "" FORCE )
            set( CMAKE_CXX_CLANG_TIDY "" CACHE STRING "" FORCE )
        else()
            set( CMAKE_C_CLANG_TIDY "\${CLANG_TIDY_COMMAND}" )
            set( CMAKE_CXX_CLANG_TIDY "\${CLANG_TIDY_COMMAND}" )
        endif()
    endif()
endif()

# Extra compilation and link flags
set ( PROJECT_EXTRA_COMPILE_FLAGS "${PROJECT_EXTRA_COMPILE_FLAGS}" )
message ( STATUS "Extra compilation flags: \${PROJECT_EXTRA_COMPILE_FLAGS}" )
set ( PROJECT_EXTRA_LINK_FLAGS "${PROJECT_EXTRA_LINK_FLAGS}" )
message ( STATUS "Extra link flags: \${PROJECT_EXTRA_LINK_FLAGS}" )

# Remove flags which are set by CMake
remove_definitions( -DflagLINUX )
remove_definitions( -DflagBSD )
remove_definitions( -DflagFREEBSD )
remove_definitions( -DflagNETBSD )
remove_definitions( -DflagOPENBSD )
remove_definitions( -DflagSOLARIS )
remove_definitions( -DflagOSX )
remove_definitions( -DflagDRAGONFLY )
remove_definitions( -DflagANDROID )

# Read compiler definitions - used to set appropriate modules
get_directory_property ( FlagDefs COMPILE_DEFINITIONS )

# Platform flags settings
if ( WIN32 )
  remove_definitions( -DflagPOSIX )
  remove_definitions( -DflagOSX11 )

  if ( NOT "\${FlagDefs}" MATCHES "flagWIN32(;|$)" )
    add_definitions ( -DflagWIN32 )
  endif()

  if ( CMAKE_SYSTEM_VERSION STREQUAL "10.0" AND NOT "\${FlagDefs}" MATCHES "flagWIN10(;|$)" )
    add_definitions ( -DflagWIN10 )
  endif()

else()
  remove_definitions( -DflagWIN32 )

  if ( NOT "\${FlagDefs}" MATCHES "flagSHARED(;|$)" )
    add_definitions ( -DflagSHARED )
  endif()

  if ( NOT "\${FlagDefs}" MATCHES "POSIX(;|$)" )
    add_definitions ( -DflagPOSIX )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "Linux" AND NOT "\${FlagDefs}" MATCHES "flagLINUX(;|$)" )
    add_definitions ( -DflagLINUX )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "BSD" AND NOT "\${FlagDefs}" MATCHES "flagBSD(;|$)" )
    add_definitions ( -DflagBSD )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "FreeBSD" AND NOT "\${FlagDefs}" MATCHES "flagFREEBSD(;|$)" )
    add_definitions ( -DflagFREEBSD )
    if ( NOT "\${FlagDefs}" MATCHES "flagBSD(;|$)" )
      add_definitions ( -DflagBSD )
    endif()
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "NetBSD" AND NOT "\${FlagDefs}" MATCHES "flagNETBSD(;|$)" )
    add_definitions ( -DflagNETBSD )
    if ( NOT "\${FlagDefs}" MATCHES "flagBSD(;|$)" )
      add_definitions ( -DflagBSD )
    endif()
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "OpenBSD" AND NOT "\${FlagDefs}" MATCHES "flagOPENBSD(;|$)" )
    add_definitions ( -DflagOPENBSD )
    if ( NOT "\${FlagDefs}" MATCHES "flagBSD(;|$)" )
      add_definitions ( -DflagBSD )
    endif()
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "Solaris" AND NOT "\${FlagDefs}" MATCHES "flagSOLARIS(;|$)" )
    add_definitions ( -DflagSOLARIS )
    set ( REMOVE_UNUSED_CODE OFF )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "SunOS" AND NOT "\${FlagDefs}" MATCHES "flagSOLARS(;|$)" )
    add_definitions ( -DflagSOLARIS )
    set ( REMOVE_UNUSED_CODE OFF )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "Darwin" AND NOT "\${FlagDefs}" MATCHES "flagOSX(;|$)" )
    add_definitions ( -DflagOSX )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "DragonFly" AND NOT "\${FlagDefs}" MATCHES "flagDRAGONFLY(;|$)" )
    add_definitions ( -DflagDRAGONFLY )
  endif()

  if ( \${CMAKE_SYSTEM_NAME} STREQUAL "Android" AND NOT "\${FlagDefs}" MATCHES "flagANDROID(;|$)" )
    add_definitions ( -DflagANDROID )
  endif()

endif()
get_directory_property ( FlagDefs COMPILE_DEFINITIONS )

# Check supported compilation architecture environment
if ( "\${FlagDefs}" MATCHES "flagGCC32(;|$)" OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8 )
  set ( STATUS_COMPILATION "32" )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -m32 -msse2 \${PROJECT_EXTRA_COMPILE_FLAGS}" )
else()
  set ( STATUS_COMPILATION "64" )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -m64 \${PROJECT_EXTRA_COMPILE_FLAGS}" )
  set ( MSVC_ARCH "X64" )
endif()
message ( STATUS "Build compilation: \${STATUS_COMPILATION} bits" )

# Set GCC builder flag
if ( \${CMAKE_CXX_COMPILER_ID} MATCHES "GNU" )
  set ( CMAKE_COMPILER_IS_GNUCC TRUE )

  if ( "\${FlagDefs}" MATCHES "flagGNUC14(;|$)" AND NOT CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 4.9 )
    message ( FATAL_ERROR "GNU GCC version 4.9+ is required to use -std=c++14 parameter!" )
  endif()

  remove_definitions ( -DflagMSC )
  remove_definitions ( -DflagCLANG )

  if ( NOT "\${FlagDefs}" MATCHES "flagGCC(;|$)" )
    add_definitions ( -DflagGCC )
  endif()

  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()

# Set CLANG builder flag
if ( \${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" )
  set ( CMAKE_COMPILER_IS_CLANG TRUE )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -Wno-logical-op-parentheses" )

  remove_definitions ( -DflagMSC )
  remove_definitions ( -DflagGCC )

  if ( NOT "\${FlagDefs}" MATCHES "flagCLANG(;|$)" )
    add_definitions ( -DflagCLANG )
  endif()

  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()

# Set MSVC builder flags
if ( \${CMAKE_CXX_COMPILER_ID} STREQUAL "MSVC" )
  remove_definitions ( -DflagGCC )
  remove_definitions ( -DflagCLANG )

  if ( NOT "\${FlagDefs}" MATCHES "flagUSEMALLOC(;|$)" )
    add_definitions ( -DflagUSEMALLOC )
  endif()

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
  if ( (\${MSVC_VERSION} GREATER_EQUAL 1910) AND (\${MSVC_VERSION} LESS_EQUAL 1919) )
    add_definitions ( -DflagMSC15\${MSVC_ARCH} )
  endif()
  if ( (\${MSVC_VERSION} GREATER_EQUAL 1920) AND (\${MSVC_VERSION} LESS_EQUAL 1929) )
    add_definitions ( -DflagMSC16\${MSVC_ARCH} )
  endif()

  if ( "\${FlagDefs}" MATCHES "flagMP(;|$)" AND NOT \${MSVC_VERSION} LESS 1400 )
    set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -MP" )
  endif()

  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()

# Set Intel builder flag
if ( \${CMAKE_CXX_COMPILER_ID} STREQUAL "Intel" AND NOT "\${FlagDefs}" MATCHES "flagINTEL(;|$)" )
  add_definitions ( -DflagINTEL )
  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()

# Set link directories on BSD systems
if ( \${CMAKE_SYSTEM_NAME} MATCHES BSD )
    link_directories ( /usr/local/lib )
endif()

# Set debug/release compiler options
if ( "\${FlagDefs}" MATCHES "flagDEBUG(;|$)" )
  set ( CMAKE_VERBOSE_MAKEFILE 1 )
  set ( CMAKE_BUILD_TYPE DEBUG )
  add_definitions ( -D_DEBUG )

  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -O0" )

  if ( NOT "\${FlagDefs}" MATCHES "flagDEBUG(;|$)" )
      add_definitions ( -DflagDEBUG )
  endif()

  if ( MSVC )
      if ( "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14|15|16|17|19)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14|15|16|17|19)X64" )
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -debug -OPT:NOREF" )
      else()
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -incremental:yes -debug -OPT:NOREF" )
      endif()
  endif()

  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
else()
  set ( CMAKE_VERBOSE_MAKEFILE 0 )
  set ( CMAKE_BUILD_TYPE RELEASE )
  add_definitions ( -D_RELEASE )

  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -O2" )
  set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -GS-" )

  if ( NOT "\${FlagDefs}" MATCHES "flagRELEASE(;|$)" )
      add_definitions ( -DflagRELEASE )
  endif()

  if ( MSVC )
      if ( "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14|15|16|17|19)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14|15|16|17|19)X64" )
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -release -OPT:REF,ICF" )
      else()
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -incremental:no -release -OPT:REF,ICF" )
      endif()
  endif()

  get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
endif()
message ( STATUS "Build type: " \${CMAKE_BUILD_TYPE} )

if ( REMOVE_UNUSED_CODE AND ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG ) )
  message ( STATUS "Build with remove unused code: TRUE" )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -ffunction-sections -fdata-sections" )
  set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -Wl,-s,--gc-sections" )
else()
  message ( STATUS "Build with remove unused code: FALSE" )
endif()

if ( CMAKE_VERBOSE_OVERWRITE EQUAL 0 OR CMAKE_VERBOSE_OVERWRITE EQUAL 1 )
  set ( CMAKE_VERBOSE_MAKEFILE \${CMAKE_VERBOSE_OVERWRITE} )
endif()

if ( "\${FlagDefs}" MATCHES "flagDEBUG_MINIMAL(;|$)" )
  if ( NOT MINGW )
      set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -ggdb" )
  endif()
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -g1" )
  set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -Zd" )
endif()

if ( "\${FlagDefs}" MATCHES "flagDEBUG_FULL(;|$)" )
  if ( NOT MINGW )
      set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -ggdb" )
  endif()
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -g2" )
  set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -Zi" )
endif()

# Set static/shared compiler options
if ( "\${FlagDefs}" MATCHES "flagSO(;|$)" )
  set ( BUILD_SHARED_LIBS ON )
  set ( LIB_TYPE SHARED )
  if ( NOT "\${FlagDefs}" MATCHES "flagSHARED(;|$)" )
      add_definitions ( -DflagSHARED )
      get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
  endif()
endif()

if ( "\${FlagDefs}" MATCHES "flagSHARED(;|$)" )
  set ( STATUS_SHARED "TRUE" )
  set ( EXTRA_GXX_FLAGS "\${EXTRA_GXX_FLAGS} -fuse-cxa-atexit" )
else()
  set ( STATUS_SHARED "FALSE" )
  set ( BUILD_SHARED_LIBS OFF )
  set ( LIB_TYPE STATIC )
  set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -static -fexceptions" )

  if ( MINGW AND WIN32 AND "\${CMAKE_HOST_WIN32}" STREQUAL "")
    # This link options are put at the end of link command. Required for MinGW cross compilation.
    # There can be an error: "rsrc merge failure: duplicate leaf: type: 10 (VERSION) name: 1 lang: 409" => it is OK, win32 version information of libwinpthread-1 is skipped
    set ( CMAKE_CXX_STANDARD_LIBRARIES "\${CMAKE_CXX_STANDARD_LIBRARIES} -Wl,-Bstatic,--whole-archive -lpthread -Wl,--no-whole-archive" )

    # This link options are put at the beginning of link command.
    # Disadvantage of using linker flags => win32 version information of libwinpthread-1 are used in the output binary instead of win32 version information of main target
    #set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -Wl,-Bstatic,--whole-archive -lpthread -Wl,--no-whole-archive" )
  endif()

endif()
message ( STATUS "Build with flagSHARED: \${STATUS_SHARED}" )

# Precompiled headers support
if ( "\${FlagDefs}" MATCHES "flagPCH(;|$)" )
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

if ( "\${FlagDefs}" MATCHES "flagPCH(;|$)" )
  message ( STATUS "Build with flagPCH: TRUE" )
else()
  message ( STATUS "Build with flagPCH: FALSE" )
endif()

# Set compiler options
get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
if ( CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG )

  if ( "\${FlagDefs}" MATCHES "flagGNUC14(;|$)" )
    set ( EXTRA_GXX_FLAGS "\${EXTRA_GXX_FLAGS} -std=c++14" )
  endif()

  if ( CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 4.9 OR CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 4.9 OR CMAKE_COMPILER_IS_CLANG )
      set ( EXTRA_GXX_FLAGSS "\${EXTRA_GXX_FLAGS} -fdiagnostics-color")
  endif()

  if ( MINGW )
      # Set the minimum supported (API) version to Windows 7
      # add_definitions(-DWINVER=0x0601)
      # add_definitions(-D_WIN32_WINNT=0x0601)
      # get_directory_property ( FlagDefs COMPILE_DEFINITIONS )

      if ( "\${FlagDefs}" MATCHES "flagDLL(;|$)" )
          set ( BUILD_SHARED_LIBS ON )
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -shared" )
          string ( REGEX REPLACE "-static " "" CMAKE_EXE_LINKER_FLAGS \${CMAKE_EXE_LINKER_FLAGS} )
      endif()

      if ( "\${FlagDefs}" MATCHES "flagGUI(;|$)" )
          list ( APPEND main_${LINK_LIST} mingw32 )
      endif()

      # The workaround to avoid 'error: duplicate symbol: std::__throw_bad_alloc()'
      if ( CMAKE_COMPILER_IS_CLANG AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 11.0 )
          add_definitions ( -DflagUSEMALLOC )
          get_directory_property ( FlagDefs COMPILE_DEFINITIONS )
      endif()

      if ( CMAKE_COMPILER_IS_GNUCC )
          # The optimalization might be broken on MinGW - remove optimalization flag (cross compile).
          #string ( REGEX REPLACE "-O2" "" EXTRA_GCC_FLAGS \${EXTRA_GCC_FLAGS} )

          if( "\${FlagDefs}" MATCHES "flagGUI(;|$)" )
              list ( APPEND main_${LINK_LIST} mingw32 )
              set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -mwindows" )
          else()
              set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -mconsole" )
          endif()

          if( "\${FlagDefs}" MATCHES "flagMT(;|$)" )
              set ( EXTRA_GCC_FLAGS "\${EXTRA_GCC_FLAGS} -mthreads" )
          endif()
      endif()

  endif()

  set ( CMAKE_CXX_FLAGS_\${CMAKE_BUILD_TYPE} "\${CMAKE_CXX_FLAGS_\${BUILD_TYPE}} \${EXTRA_GXX_FLAGS} \${EXTRA_GCC_FLAGS}" )
  set ( CMAKE_C_FLAGS_\${CMAKE_BUILD_TYPE} "\${CMAKE_C_FLAGS_\${BUILD_TYPE}} \${EXTRA_GCC_FLAGS}" )

  set ( CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> rs <TARGET> <LINK_FLAGS> <OBJECTS>" )
  set ( CMAKE_CXX_ARCHIVE_APPEND "<CMAKE_AR> rs <TARGET> <LINK_FLAGS> <OBJECTS>" )
  set ( CMAKE_C_ARCHIVE_CREATE "<CMAKE_AR> rs <TARGET> <LINK_FLAGS> <OBJECTS>" )
  set ( CMAKE_C_ARCHIVE_APPEND "<CMAKE_AR> rs <TARGET> <LINK_FLAGS> <OBJECTS>" )

elseif ( MSVC )
  set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -nologo" )

  if ( "\${FlagDefs}" MATCHES "flagEVC(;|$)" )
      if ( NOT "\${FlagDefs}" MATCHES "flagSH3(;|$)" AND NOT "\${FlagDefs}" MATCHES "flagSH4(;|$)" )
          # disable stack checking
          set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -Gs8192" )
      endif()
      # read-only string pooling, turn off exception handling
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -GF -GX-" )
  elseif ( "\${FlagDefs}" MATCHES "flagCLR(;|$)" )
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -EHac" )
  elseif ( "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14|15|16|17|19)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9)ARM" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14|15|16|17|19)X64" )
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -EHsc" )
  else()
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -GX" )
  endif()

  if ( \${CMAKE_BUILD_TYPE} STREQUAL DEBUG )
      set ( EXTRA_MSVC_FLAGS_Mx "d" )
  endif()
  if ( "\${FlagDefs}" MATCHES "flagSHARED(;|$)" OR "\${FlagDefs}" MATCHES "flagCLR(;|$)" )
      set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -MD\${EXTRA_MSVC_FLAGS_Mx}" )
  else()
      if ( "\${FlagDefs}" MATCHES "flagMT(;|$)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14|15|16|17|19)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9)ARM" OR "\${FlagDefs}" MATCHES "flagMSC(8|9|10|11|12|14|15|16|17|19)X64" )
          set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -MT\${EXTRA_MSVC_FLAGS_Mx}" )
      else()
          set ( EXTRA_MSVC_FLAGS "\${EXTRA_MSVC_FLAGS} -ML\${EXTRA_MSVC_FLAGS_Mx}" )
      endif()
  endif()

  #,5.01 needed to support WindowsXP
  if ( NOT "\${FlagDefs}" MATCHES "(flagMSC(8|9|10|11|12|14|15|16|17|19)X64)" )
      set ( MSVC_LINKER_SUBSYSTEM ",5.01" )
  endif()

  if ( "\${FlagDefs}" MATCHES "flagMSC(8|9)ARM" )
      set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -subsystem:windowsce,4.20 /ARMPADCODE -NODEFAULTLIB:\"oldnames.lib\"" )
  else()
      if ( "\${FlagDefs}" MATCHES "flagGUI(;|$)" OR "\${FlagDefs}" MATCHES "flagMSC(8|9)ARM" )
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -subsystem:windows\${MSVC_LINKER_SUBSYSTEM}" )
      else()
          set ( CMAKE_EXE_LINKER_FLAGS "\${CMAKE_EXE_LINKER_FLAGS} -subsystem:console\${MSVC_LINKER_SUBSYSTEM}" )
      endif()
  endif()

  if ( "\${FlagDefs}" MATCHES "flagDLL(;|$)" )
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

    # Add main target defined include directories
    get_directory_property ( include_directories DIRECTORY \${CMAKE_CURRENT_SOURCE_DIR} INCLUDE_DIRECTORIES )
    foreach ( include_dir \${include_directories} )
        list ( APPEND compile_flags "-I\${include_dir}" )
    endforeach()

    # Add source directory of the precompiled header file - for quoted include files
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
      set ( output_file "\${PROJECT_BINARY_DIR}/\${CMAKE_PROJECT_NAME}/\${icppFile}.cpp" )
      file ( WRITE "\${output_file}" "#include \"\${CMAKE_CURRENT_SOURCE_DIR}/\${icppFile}\"\n" )
  endforeach()
endfunction()

# Function to create cpp source file from binary resource definition
function ( create_brc_source input_file output_file symbol_name compression symbol_append )
  if ( NOT EXISTS \${CMAKE_CURRENT_SOURCE_DIR}/\${input_file} )
      message ( FATAL_ERROR "Input file does not exist: \${CMAKE_CURRENT_SOURCE_DIR}/\${input_file}" )
  endif()
  message ( STATUS "Creating cpp source file \"\${output_file}\" from the binary resource \"\${input_file}\"" )

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
  elseif ( \${compression} MATCHES "[lL][zZ][mM][aA]" )
      find_program ( LZMA_EXEC lzma )
      if ( NOT LZMA_EXEC )
          message ( FATAL_ERROR "LZMA executable not found!" )
      endif()
      set ( COMPRESS_SUFFIX "lzma" )
      set ( COMMAND_COMPRESS \${LZMA_EXEC} \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name} )
  elseif ( \${compression} MATCHES "[lL][zZ]4" )
      find_program ( LZ4_EXEC lz4c )
      if ( NOT LZ4_EXEC )
          message ( FATAL_ERROR "LZ4 executable not found!" )
      endif()
      set ( COMPRESS_SUFFIX "lz4" )
      set ( COMMAND_COMPRESS \${LZ4_EXEC} -f \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name} \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name}.\${COMPRESS_SUFFIX} )
  elseif ( \${compression} MATCHES "[zZ][sS][tT[dD]" )
      find_program ( ZSTD_EXEC zstd )
      if ( NOT ZSTD_EXEC )
          message ( FATAL_ERROR "ZSTD executable not found!" )
      endif()
      set ( COMPRESS_SUFFIX "zst" )
      set ( COMMAND_COMPRESS \${ZSTD_EXEC} \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name} -o \${CMAKE_CURRENT_BINARY_DIR}/\${symbol_name}.\${COMPRESS_SUFFIX} )
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

  string ( REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\\\1, " hex_converted \${hex_string} )

  set ( output_string "static unsigned char \${symbol_name}_[] = {\n" )
  set ( output_string "\${output_string} \${hex_converted}0x00 }\;\n\n" )
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
    message ( STATUS "  initialize flag " \${comp_def} )
    set ( \${comp_def} 1 )
endforeach()

message ( STATUS "Project compilation flags: \${EXTRA_GCC_FLAGS}" )

EOL
# End of the cat (CMakeFiles.txt)

    local PKG_DIR=""
    local dir=""
    local dir_include=()
    local dir_add=()

    while [ ${#UPP_ALL_USES_DONE[@]} -lt ${#UPP_ALL_USES[@]} ]; do
        local process_upp="$(get_upp_to_process)"
#        echo "num of elements all : ${#UPP_ALL_USES[@]} (${UPP_ALL_USES[@]})"
#        echo "num of elements done: ${#UPP_ALL_USES_DONE[@]} (${UPP_ALL_USES_DONE[@]})"
#        echo "process_upp=\"${process_upp}\""

        if [ -n "${process_upp}" ]; then
            if [ -d "${UPP_SRC_DIR}/${process_upp}" ]; then
                PKG_DIR=${UPP_SRC_DIR}
            elif [ -d "${PROJECT_EXTRA_INCLUDE_DIR}/${process_upp}" ]; then
                PKG_DIR="${PROJECT_EXTRA_INCLUDE_DIR}"
            else
                PKG_DIR=""
                echo "ERROR"
                echo "ERROR - package \"${process_upp}\" was not foud!"
                echo "ERROR"
            fi

            if [ -d "${PKG_DIR}/${process_upp}" ]; then
                if [[ "${process_upp}" =~ '/' ]]; then
                    tmp_upp_name="$(basename "${process_upp}").upp"
                    generate_cmake_file "${PKG_DIR}/${process_upp}/${tmp_upp_name}" "${process_upp}"
                else
                    generate_cmake_file "${PKG_DIR}/${process_upp}/${process_upp}".upp "${process_upp}"
                fi

                # include directories from packages
                for dir in "${INCLUDE_SYSTEM_LIST[@]}"; do
                    dir_include+=("include_directories ( \${PROJECT_SOURCE_DIR}/${PKG_DIR}/${process_upp}/${dir} )")
                done
                dir_add+=("add_subdirectory ( ${PKG_DIR}/${process_upp} \${CMAKE_CURRENT_BINARY_DIR}/${process_upp} )")
            fi
        fi

        UPP_ALL_USES_DONE+=("${process_upp}")
    done

    echo '# Include dependent directories of the project' >> "${OFN}"
    for dir in "${dir_include[@]}"; do
        echo "$dir" >> "${OFN}"
    done

    for dir in "${dir_add[@]}"; do
        echo "$dir" >> "${OFN}"
    done

    echo "add_subdirectory ( ${main_target_dirname} \${CMAKE_CURRENT_BINARY_DIR}/${main_target_name} )" >> "${OFN}"

    local -a array_library=$(printf "%s\n" "${UPP_ALL_USES_DONE[@]}" | sort -u );
    local library_dep="${main_target_name}${LIB_SUFFIX};"
    for list_library in ${array_library[@]}; do
        library_dep+="${list_library//\//_}${LIB_SUFFIX};"
    done

    # Link dependecy correction
    library_dep="${library_dep/Core-lib;Core_SSL-lib/Core_SSL-lib;Core-lib}"
    library_dep="${library_dep/Core-lib;Core_Rpc-lib/Core_Rpc-lib;Core-lib}"
    library_dep="${library_dep//plugin_zstd-lib}"
    library_dep="${library_dep/ZstdTest-lib/ZstdTest-lib;plugin_zstd-lib}"

    # Beginning of the cat (CMakeFiles.txt)
    cat >> "${OFN}" << EOL

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

find_package(Subversion)
if ( SUBVERSION_FOUND AND EXISTS "\${CMAKE_SOURCE_DIR}/.svn" )
  Subversion_WC_INFO(\${CMAKE_SOURCE_DIR} SVN)
endif()

find_package(Git)
if ( GIT_FOUND AND EXISTS "\${CMAKE_SOURCE_DIR}/.git" )
  # Get the current working branch
  execute_process(
    COMMAND git rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY \${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  # Get the latest abbreviated commit hash of the working branch
  execute_process(
    COMMAND git log -1 --format=%h
    WORKING_DIRECTORY \${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  # Get remote tracking of actual branch
  execute_process(
    COMMAND git config --local branch.\${GIT_BRANCH}.remote
    WORKING_DIRECTORY \${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_REMOTE_TRACKING
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  # Get remote tracking URL of actual branch
  execute_process(
    COMMAND git config --local remote.\${GIT_REMOTE_TRACKING}.url
    WORKING_DIRECTORY \${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_REMOTE_URL
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
endif()

if ( GIT_COMMIT_HASH )
  file (APPEND \${BUILD_INFO_H} "#define bmGIT_REVISION \"\${GIT_COMMIT_HASH}\"\n" )
  file (APPEND \${BUILD_INFO_H} "#define bmGIT_BRANCH \"\${GIT_BRANCH}\"\n" )
  file (APPEND \${BUILD_INFO_H} "#define bmGIT_URL \"\${GIT_REMOTE_URL}\"\n" )
elseif ( SVN_WC_REVISION )
  file (APPEND \${BUILD_INFO_H} "#define bmSVN_REVISION \"\${SVN_WC_REVISION}\"\n" )
endif()

# Collect icpp files
file ( GLOB_RECURSE cpp_ini_files "\${PROJECT_BINARY_DIR}/\${CMAKE_PROJECT_NAME}/*.icpp.cpp" )

# Collect windows resource config file
if ( WIN32 )
  file ( GLOB rc_file "\${PROJECT_BINARY_DIR}/\${CMAKE_PROJECT_NAME}/*.rc" )
endif()

# Main program definition
file ( WRITE \${PROJECT_BINARY_DIR}/\${CMAKE_PROJECT_NAME}/null.cpp "" )
if ( "\${FlagDefs}" MATCHES "(flagSO)(;|$)" )
  add_library ( ${main_target_name}${BIN_SUFFIX} \${PROJECT_BINARY_DIR}/\${CMAKE_PROJECT_NAME}/null.cpp \${rc_file} \${cpp_ini_files} )
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
  add_executable ( ${main_target_name}${BIN_SUFFIX} \${PROJECT_BINARY_DIR}/\${CMAKE_PROJECT_NAME}/null.cpp \${rc_file} \${cpp_ini_files} )
endif()

# Main program dependecies
set ( ${main_target_name}_${DEPEND_LIST} "${library_dep}" )

add_dependencies ( ${main_target_name}${BIN_SUFFIX} \${${main_target_name}_${DEPEND_LIST}} )
if ( DEFINED MAIN_TARGET_LINK_FLAGS )
  set_target_properties ( ${main_target_name}${BIN_SUFFIX} PROPERTIES LINK_FLAGS \${MAIN_TARGET_LINK_FLAGS} )
endif()

# Precompiled headers processing
if ( "\${FlagDefs}" MATCHES "flagPCH(;|$)" )
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
target_link_libraries ( ${main_target_name}${BIN_SUFFIX} \${main_$LINK_LIST} \${${main_target_name}_${DEPEND_LIST}} \${PROJECT_EXTRA_LINK_FLAGS} )
if ( ${TARGET_RENAME} )
  set_target_properties ( ${main_target_name}${BIN_SUFFIX} PROPERTIES OUTPUT_NAME \${${TARGET_RENAME}} )
else()
  set_target_properties ( ${main_target_name}${BIN_SUFFIX} PROPERTIES OUTPUT_NAME ${main_target_name} )
endif()
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

    UPP_ALL_USES=()
    UPP_ALL_USES_DONE=()
}

