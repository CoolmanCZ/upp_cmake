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

BIN_SUFFIX="-bin"
LIB_SUFFIX="-lib"

RE_BZIP2='[bB][zZ]2'
RE_ZIP='[zZ][iI][pP]'
RE_CPP='\.([cC]+[xXpP]{0,2})$'
RE_BRC='\.(brc)$'
RE_USES='^uses\('
RE_LINK='^link\('
RE_LIBRARY='^library\('
RE_OPTIONS='^options\('
RE_DEPEND='^uses$'
RE_FILES='^file$'
RE_SEPARATOR='separator'
RE_FILE_DOT='\.'
RE_FILE_SPLIT='(options|charset|optimize_speed|highlight)'
RE_FILE_EXCLUDE='(depends\(\))'

UPP_ALL_USES=()
UPP_ALL_USES_DONE=()

test_required_binaries()
{
    # Requirement for generating the CMakeList files
    local my_sed=$(which sed)
    local my_sort=$(which sort)
    local my_date=$(which date)

    # Requirements for building the target
    local my_zip=$(which zip)
    local my_bzip2=$(which bzip2)

    local my_mv=$(which mv)
    local my_cp=$(which cp)
    local my_mkdir=$(which mkdir)

    # Requirements for building the target - not used (see TODO)
#    local my_xxd=$(which xxd)
#    local my_ld=$(which ld)
#    local my_objcopy=$(which objcopy)

    if [ -z "${my_sed}" ] || [ -z "${my_sort}" ] || [ -z "${my_date}" ]; then
        echo "ERROR - Requirement for generating the CMakeList files failed."
        echo "ERROR - Can't continue -> Exiting!"
        echo "sed=\"${my_sed}\""
        echo "sort=\"${my_sort}\""
        echo "date=\"${my_date}\""
        exit 1
    fi

    if [ -z "${my_zip}" ] || [ -z "${my_bzip2}" ] || [ -z "${my_mv}" ] || [ -z "${my_cp}" ] || [ -z "${my_mkdir}" ]; then
        echo "WARNING - Requirements for building the target failed."
        echo "WARNING - Continue with generating the CMakeList files."
        echo "zip=\"${my_zip}\""
        echo "bzip2=\"${my_bzip2}\""
        echo "mv=\"${my_mv}\""
        echo "cp=\"${my_cp}\""
        echo "mkdir=\"${my_mkdir}\""
    fi
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

    line=`echo "${line}" | sed 's/(.*$//'`                 # Get string before the left parenthesis

    echo "${line}"
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
    if [[ "${list}" =~ "$DEPEND_LIST" ]]; then
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
    parameters=$(string_remove_comma "${parameters}")

    if [ -n "${options}" ]; then
        echo "if (${options})" >> ${OFN}
        echo "      set_target_properties ( ${target_name} PROPERTIES LINK_FLAGS ${parameters} )" >> ${OFN}
        echo "endif()" >> ${OFN}
    fi
}

options_parse()
{
    local line="${1}"
    local options=""
    local parameters=""

    echo >> ${OFN}
    echo "#${1}" >> ${OFN}

    options=$(string_get_in_parenthesis "${line}")
    options=$(if_options_parse_all "${options}")              # Parse options

    parameters=$(string_get_after_parenthesis "${line}")
    parameters=$(string_remove_comma "${parameters}")

    if [ -n "${options}" ]; then
        echo "if ($options)" >> ${OFN}
        echo "      add_definitions ( ${parameters} )" >> ${OFN}
        echo "endif()" >> ${OFN}
    fi
}

binary_resource_create_asembly()
{
    local symbol_name="${1}"
    local symbol_file_name="${2}"
    local symbol_file_name_new="${3}"
    local symbol_file_libname="${4}"
    local symbol_file_compress="${5}"
    local cust1="$6"

    local compress_bin=""
    local compress_ext=""
    local compress_command=""

    # Prepare compresses parameters
    if [[ "${symbol_file_compress}" =~ $RE_BZIP2 ]]; then
        compress_bin=$(which bzip2)
        compress_ext=".bz2"
        compress_command="COMMAND ${compress_bin} -k -f \${CMAKE_CURRENT_BINARY_DIR}/${symbol_file_name_new}"
    elif [[ "${symbol_file_compress}" =~ $RE_ZIP ]]; then
        compress_bin=$(which zip)
        compress_ext=".zip"
        compress_command="COMMAND ${compress_bin} ${symbol_file_name_new}${compress_ext} \${CMAKE_CURRENT_BINARY_DIR}/${symbol_file_name_new}"
    fi

    # Generate asembly file
    echo "# ${symbol_file_libname}${LIB_SUFFIX} library (dependecy from binary resource file)" >> ${OFN}
    echo "# Create library with binary resource (${symbol_name})" >> ${OFN}
    echo "add_custom_command ( OUTPUT \"\${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}\"" >> ${OFN}
    echo "  COMMAND mkdir -p `dirname \\${CMAKE_CURRENT_BINARY_DIR}/$symbol_file_name`" >> ${OFN}
    echo "  COMMAND cp \"\${CMAKE_CURRENT_SOURCE_DIR}/${symbol_file_name}\" \"\${CMAKE_CURRENT_BINARY_DIR}/${symbol_file_name_new}\"" >> ${OFN}
    if [ -n "${compress_command}" ]; then
        echo "  ${compress_command}" >> ${OFN}
        echo "  COMMAND mv \"${symbol_file_name_new}${compress_ext}\" \"${symbol_name}\"" >> ${OFN}
    fi
    echo ")" >> ${OFN}

    echo "file ( WRITE \${CMAKE_CURRENT_BINARY_DIR}/${symbol_file_name_new}.C \"
        .section .data
        .global ${symbol_name}_
        .type ${symbol_name}_, @object
    ${symbol_name}_:
        .incbin \\\"${symbol_name}\\\"
        .global ${symbol_name}_end
    ${symbol_name}_end:
        .byte 0
        .align  2
        .global ${symbol_name}_length
    ${symbol_name}_length:
        .int ${symbol_name}_end - ${symbol_name}_
        .align  2\"" >> ${OFN}
    echo ")" >> ${OFN}

    echo "list ( APPEND ${symbol_file_libname}_${SOURCE_LIST}_C" >> ${OFN}
    echo "  \${CMAKE_CURRENT_BINARY_DIR}/${symbol_file_name_new}.C" >> ${OFN}
    echo ")" >> ${OFN}
    echo "set_source_files_properties ( \${CMAKE_CURRENT_BINARY_DIR}/${symbol_file_name_new}.C PROPERTIES OBJECT_DEPENDS \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name} )"  >> ${OFN}
    echo "add_library ( ${symbol_file_libname}${LIB_SUFFIX}${cust1} \${${symbol_file_libname}_${SOURCE_LIST}_C} )" >> ${OFN}
    echo "set_target_properties ( ${symbol_file_libname}${LIB_SUFFIX}${cust1} PROPERTIES COMPILE_FLAGS \"-x assembler-with-cpp\" )" >> ${OFN}
    echo "set_target_properties ( ${symbol_file_libname}${LIB_SUFFIX}${cust1} PROPERTIES LINKER_LANGUAGE CXX )" >> ${OFN}

}

binary_resource_parse()
{
    local parse_file="${1}"
    local line=""

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
                    local symbol_file_libname=`echo "${symbol_file_name}" | sed 's/[\/\.]/_/g'`
                    local symbol_file_compress=`echo "${options_params[2]}" | sed 's/.*" \(.*\)$/\1/'`
                else
                    local symbol_name=$(string_trim_spaces_both "${options_params[0]}")
                    local symbol_file_name=`echo "${options_params[1]}" | sed 's/.*"\(.*\)".*$/\1/'`
                    local symbol_file_libname=`echo "${symbol_file_name}" | sed 's/[\/\.]/_/g'`
                    local symbol_file_compress=`echo "${options_params[1]}" | sed 's/.*" \(.*\)$/\1/'`
                fi

                # Parse BINARY resources
                if [ "${parameter}" == "BINARY" ]; then

                    echo >> ${OFN}
                    echo "# BINARY file" >> ${OFN}

                    # Generate asembly file
                    $(binary_resource_create_asembly "${symbol_name}" "${symbol_file_name}" "${symbol_name}" "${symbol_file_libname}" "${symbol_file_compress}")

                    # Generate cpp file
                    echo >> ${OFN}
                    echo "# Create library which provide pointer to the begin of the binary resource (${symbol_name})" >> ${OFN}
                    echo "file ( WRITE \${CMAKE_CURRENT_BINARY_DIR}/${symbol_file_libname}.cpp \"" >> ${OFN}
                    echo "  extern unsigned char ${symbol_name}_[];" >> ${OFN}
                    echo "  unsigned char *${symbol_name} = ${symbol_name}_;\"" >> ${OFN}
                    echo ")" >> ${OFN}

                    echo "list ( APPEND ${symbol_file_libname}_${SOURCE_LIST}_cpp" >> ${OFN}
                    echo "  \${CMAKE_CURRENT_BINARY_DIR}/${symbol_file_libname}.cpp" >> ${OFN}
                    echo ")" >> ${OFN}
                    echo "add_library ( ${symbol_file_libname}${LIB_SUFFIX}_cpp \${${symbol_file_libname}_${SOURCE_LIST}_cpp} )" >> ${OFN}

                    echo >> ${OFN}
                    echo "# Append created libraries to the the module library" >> ${OFN}
                    echo "list ( APPEND $LINK_LIST ${symbol_file_libname}${LIB_SUFFIX} ${symbol_file_libname}${LIB_SUFFIX}_cpp )" >> ${OFN}

                # parse BINARY_ARRAY resources
                elif [ "${parameter}" == "BINARY_ARRAY" ]; then

                    binary_array_names+=("${symbol_name}_${symbol_name_array}")

                    echo >> ${OFN}
                    echo "# BINARY_ARRAY file" >> ${OFN}

                    # Generate random file for library name
                    local cust=".$RANDOM"

                    # Store library name for DEPENDENCY LIST
                    binary_array_names_library+=("${symbol_file_libname}${LIB_SUFFIX}${cust}")

                    # Generate asembly file
                    $(binary_resource_create_asembly "${symbol_name}_${symbol_name_array}" "${symbol_file_name}" "${symbol_name}_${symbol_name_array}" "${symbol_file_libname}" "${symbol_file_compress}" "${cust}")


                # parse BINARY_MASK resources
                elif [ "${parameter}" == "BINARY_MASK" ]; then

                    local -a binary_mask_files="($(eval echo "${symbol_file_name}"))"

                    if [ -n ${binary_mask_files} ]; then
                        local all_count=0
                        local binary_file=""
                        local -a all_array_files

                        for binary_file in "${binary_mask_files[@]}"; do
                            if [ -f "${binary_file}" ]; then

                                echo >> ${OFN}
                                echo "# BINARY_MASK file" >> ${OFN}
                                echo "# file ${all_count}: ${binary_file}" >> ${OFN}

                                # Generate asembly file
                                $(binary_resource_create_asembly "${symbol_name}_${all_count}" "${binary_file}" "${symbol_name}_${all_count}" "${symbol_name}_${all_count}" "${symbol_file_compress}")

                            echo >> ${OFN}
                            echo "# Append created libraries to the the module library" >> ${OFN}
                            echo "list ( APPEND $LINK_LIST ${symbol_name}_${all_count}${LIB_SUFFIX} )" >> ${OFN}

                                all_array_files+=("$(basename "${binary_file}")")
                                (( all_count++ ))
                            fi
                        done

                        # Generate cpp file for the BINARY_MASK
                        echo >> ${OFN}
                        echo "# Create library which provide pointers to the begin of the binary resource (${symbol_name})" >> ${OFN}
                        echo "file ( WRITE \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp \"" >> ${OFN}
                        echo "  int ${symbol_name}_count = ${all_count};" >> ${OFN}

                        local i
                        for (( i=0; i<${all_count}; i++ )); do
                            echo "  extern unsigned char ${symbol_name}_${i}_[];" >> ${OFN}
                            echo "  extern int ${symbol_name}_${i}_length;" >> ${OFN}
                        done

                        echo "  unsigned char *${symbol_name}[] = {" >> ${OFN}
                        for (( i=0; i<${all_count}; i++ )); do
                            echo "      ${symbol_name}_${i}_," >> ${OFN}
                        done
                        echo "  };" >> ${OFN}

                        echo "  char const *${symbol_name}_files[] = {" >> ${OFN}
                        local binary_filename=""
                        for binary_file_name in "${all_array_files[@]}"; do
                            echo "      \\\"${binary_file_name}\\\"," >> ${OFN}
                        done
                        echo "  };" >> ${OFN}

                        echo "  int ${symbol_name}_length[] = {" >> ${OFN}
                        for (( i=0; i<${all_count}; i++ )); do
                            echo "      ${symbol_name}_${i}_length," >> ${OFN}
                        done
                        echo "  };" >> ${OFN}
                        echo "\")" >> ${OFN}

                        echo >> ${OFN}
                        echo "list ( APPEND ${symbol_name}_${DEPEND_LIST}" >> ${OFN}
                        for (( i=0; i<${all_count}; i++ )); do
                            echo " ${symbol_name}_${i}${LIB_SUFFIX}" >> ${OFN}
                        done
                        echo ")" >> ${OFN}

                        echo >> ${OFN}
                        echo "list ( APPEND ${symbol_name}_${SOURCE_LIST}_cpp" >> ${OFN}
                        echo "  \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp" >> ${OFN}
                        echo ")" >> ${OFN}
                        echo "add_library ( ${symbol_name}${LIB_SUFFIX}_cpp \${${symbol_name}_${SOURCE_LIST}_cpp} )" >> ${OFN}
                        echo "add_dependencies ( ${symbol_name}${LIB_SUFFIX}_cpp \${${symbol_name}_${DEPEND_LIST}} )" >> ${OFN}
                        echo "target_link_libraries ( ${symbol_name}${LIB_SUFFIX}_cpp \${${symbol_name}_${DEPEND_LIST}} )" >> ${OFN}

                        echo >> ${OFN}
                        echo "# Append created libraries to the the module library" >> ${OFN}
                        echo "list ( APPEND $LINK_LIST ${symbol_name}${LIB_SUFFIX}_cpp )" >> ${OFN}

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
            symbol_name="binary_array_$RANDOM"
            local -a binary_array_names_sorted
            OLD_IFS="${IFS}"; export LC_ALL=C; IFS=$'\n' binary_array_names_sorted=($(sort -u <<<"${binary_array_names[*]}")); IFS="${OLD_IFS}"

            echo "# ${binary_array_names[@]}" >> ${OFN}
            echo "# ${binary_array_names_sorted[@]}" >> ${OFN}

            local test_first_iteration
            local binary_array_name_count=0
            local binary_array_name_test
            local binary_array_name_first
            local binary_array_name_second

            echo "# Create library which provide pointers to the begin of the binary resource (${symbol_name})" >> ${OFN}
            echo "file ( WRITE \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp \"" >> ${OFN}

            for binary_array_record in "${binary_array_names_sorted[@]}"; do
                echo "  extern unsigned char ${binary_array_record}_[];" >> ${OFN}
                echo "  extern int ${binary_array_record}_length;" >> ${OFN}
            done
            echo >> ${OFN}

            for binary_array_record in "${binary_array_names_sorted[@]}"; do
                binary_array_name_split=(${binary_array_record//_/ })
                if [ ! "${binary_array_name_split[0]}" == "${binary_array_name_test}" ]; then
                    if [ -z ${test_first_iteration} ]; then
                        test_first_iteration="done"
                    else
                        echo "  int ${binary_array_name_test}_count = ${binary_array_name_count};" >> ${OFN}
                        echo -e "${binary_array_name_first}" >> ${OFN}
                        echo -e "   };\n" >> ${OFN}
                        echo -e "${binary_array_name_second}" >> ${OFN}
                        echo -e "   };\n" >> ${OFN}
                        binary_array_name_count=0
                    fi
                    binary_array_name_test=${binary_array_name_split[0]};
                    binary_array_name_first="   int ${binary_array_name_split[0]}_length[] = {"
                    binary_array_name_second="  unsigned char *${binary_array_name_split[0]}[] = {"
                fi
                (( binary_array_name_count++ ))
                binary_array_name_first+="\n    ${binary_array_record}_length,"
                binary_array_name_second+="\n   ${binary_array_record}_,"
            done
            echo "  int ${binary_array_name_test}_count = ${binary_array_name_count};" >> ${OFN}
            echo -e "${binary_array_name_first}" >> ${OFN}
            echo -e "   };\n" >> ${OFN}
            echo -e "${binary_array_name_second}" >> ${OFN}
            echo -e "   };" >> ${OFN}
            echo "\")" >> ${OFN}

            echo >> ${OFN}
            echo "list ( APPEND ${symbol_name}_${DEPEND_LIST}" >> ${OFN}
            for binary_array_name_lib in ${binary_array_names_library[@]}; do
                echo " ${binary_array_name_lib}" >> ${OFN}
            done
            echo ")" >> ${OFN}

            echo >> ${OFN}
            echo "list ( APPEND ${symbol_name}_${SOURCE_LIST}_cpp" >> ${OFN}
            echo "  \${CMAKE_CURRENT_BINARY_DIR}/${symbol_name}.cpp" >> ${OFN}
            echo ")" >> ${OFN}
            echo "add_library ( ${symbol_name}${LIB_SUFFIX}_cpp \${${symbol_name}_${SOURCE_LIST}_cpp} )" >> ${OFN}
            echo "add_dependencies ( ${symbol_name}${LIB_SUFFIX}_cpp \${${symbol_name}_${DEPEND_LIST}} )" >> ${OFN}
            echo "target_link_libraries ( ${symbol_name}${LIB_SUFFIX}_cpp \${${symbol_name}_${DEPEND_LIST}} )" >> ${OFN}

            echo >> ${OFN}
            echo "# Append created libraries to the the module library" >> ${OFN}
            echo "list ( APPEND $LINK_LIST ${symbol_name}${LIB_SUFFIX}_cpp )" >> ${OFN}
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
    local USES=()
    local HEADER=()
    local SOURCE=()
    local uses_start=""
    local files_start=""
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
                        if [[ "${list}" =~ $RE_CPP ]]; then         # C/C++ source files
                            SOURCE+=(${list})
                        elif [[ "${list}" =~ $RE_BRC ]]; then       # BRC resource files
                            $(binary_resource_parse "$list")
                            HEADER+=(${list})
                        elif [[ "${list}" =~ $RE_FILE_DOT ]]; then  # header files
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

        echo >> ${OFN}
        echo "# Module properties" >> ${OFN}
        echo "set_source_files_properties ( \${$HEADER_LIST} PROPERTIES HEADER_FILE_ONLY ON )" >> ${OFN}
        echo "create_cpps_from_icpps()" >> ${OFN}
        echo "add_library ( ${target_name}${LIB_SUFFIX} \${INIT_FILE} \${$SOURCE_LIST} \${$HEADER_LIST})" >> ${OFN}

        echo >> ${OFN}
        echo "# Module dependecies" >> ${OFN}
        echo "if (DEFINED ${target_name}_${DEPEND_LIST})" >> ${OFN}
        echo "      add_dependencies ( ${target_name}${LIB_SUFFIX} \${${target_name}_$DEPEND_LIST} )" >> ${OFN}
        echo "endif()" >> ${OFN}

        echo >> ${OFN}
        echo "# Module link" >> ${OFN}
        echo "if (DEFINED ${target_name}_${DEPEND_LIST} OR DEFINED $LINK_LIST)" >> ${OFN}
        echo "      target_link_libraries ( ${target_name}${LIB_SUFFIX} \${${target_name}_${DEPEND_LIST}} \${$LINK_LIST})" >> ${OFN}
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

        generate_cmake_from_upp "${upp_name}" "${object_name}"

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

    echo >> ${OFN}
    echo "# Read compiler definitions - used to set appropriate modules" >> ${OFN}
    echo "get_directory_property ( FlagDefs COMPILE_DEFINITIONS )" >> ${OFN}
#    echo "message ( STATUS \"FlagDefs: \" \${FlagDefs} )" >> ${OFN}

    echo >> ${OFN}
    echo "# Enable/disable verbose output" >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagDEBUG" )' >> ${OFN}
    echo "  set ( CMAKE_BUILD_TYPE Debug )" >> ${OFN}
    echo "  set ( CMAKE_VERBOSE_MAKEFILE 1 )" >> ${OFN}
    echo "else()" >> ${OFN}
    echo "  set ( CMAKE_BUILD_TYPE Release )" >> ${OFN}
    echo 'endif ()' >> ${OFN}
    echo "message ( STATUS \"Build type: \" \${CMAKE_BUILD_TYPE} )" >> ${OFN}

    echo >> ${OFN}
    echo '# Set compiler flags' >> ${OFN}
    echo 'if ( "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" )' >> ${OFN}
    echo '  set ( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-logical-op-parentheses" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo 'if ( CMAKE_COMPILER_IS_GNUCC )' >> ${OFN}
    echo '  set ( CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -std=c++11 -O3 -ffunction-sections -fdata-sections" )' >> ${OFN}
    echo '  set ( CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -std=c++11 -O0" )' >> ${OFN}
    echo 'elseif ( MSVC )' >> ${OFN}
    echo '  set ( CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -GS-" )' >> ${OFN}
    echo '  set ( CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Zi" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# The -O3 might be unreliable on MinGW. Use -Os instead.' >> ${OFN}
    echo 'if ( MINGW )' >> ${OFN}
    echo '  replace_compiler_option ( CMAKE_CXX_FLAGS_RELEASE "-O3" "-Os" )' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo '# Function to create cpp source from iccp files' >> ${OFN}
    echo 'function ( create_cpps_from_icpps )' >> ${OFN}
    echo '    file ( GLOB icpp_files RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/*.icpp" )' >> ${OFN}
    echo '    foreach ( icppFile ${icpp_files} )' >> ${OFN}
    echo '        set ( output_file "${CMAKE_CURRENT_BINARY_DIR}/${icppFile}.cpp" )' >> ${OFN}
    echo '        file ( WRITE "${output_file}" "#include \"${CMAKE_CURRENT_SOURCE_DIR}/${icppFile}\"\n" )' >> ${OFN}
    echo '    endforeach()' >> ${OFN}
    echo 'endfunction()' >> ${OFN}

    echo >> ${OFN}
    echo '# Import and set up required packages and libraries'>> ${OFN}
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
    echo '  find_package ( PNG )' >> ${OFN}
    echo '  if ( PNG_FOUND )' >> ${OFN}
    echo '      include_directories( ${PNG_INCLUDE_DIR} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${PNG_LIBRARIES} )" >> ${OFN}
    echo '  endif()' >> ${OFN}
    echo 'endif()' >> ${OFN}

    echo >> ${OFN}
    echo 'find_package ( BZip2 REQUIRED )' >> ${OFN}
    echo 'if ( BZIP2_FOUND )' >> ${OFN}
    echo '  include_directories ( ${BZIP_INCLUDE_DIRS} )' >> ${OFN}
    echo "  list ( APPEND main_${LINK_LIST} \${BZIP2_LIBRARIES} )" >> ${OFN}
    echo 'endif ()' >> ${OFN}

    echo >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagMT" )' >> ${OFN}
    echo '  find_package ( Threads REQUIRED )' >> ${OFN}
    echo '  if ( THREADS_FOUND )' >> ${OFN}
    echo '      include_directories ( ${THREADS_INCLUDE_DIRS} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${THREADS_LIBRARIES} )" >> ${OFN}
    echo '  endif ()' >> ${OFN}
    echo 'endif ()' >> ${OFN}

    echo >> ${OFN}
    echo 'if ( "${FlagDefs}" MATCHES "flagSSL" )' >> ${OFN}
    echo '  find_package ( OpenSSL REQUIRED )' >> ${OFN}
    echo '  if ( OPENSSL_FOUND )' >> ${OFN}
    echo '      include_directories ( ${OPENSSL_INCLUDE_DIRS} )' >> ${OFN}
    echo "      list ( APPEND main_${LINK_LIST} \${OPENSSL_LIBRARIES} )" >> ${OFN}
    echo '  endif ()' >> ${OFN}
    echo 'endif ()' >> ${OFN}

    echo >> ${OFN}
    echo "# Set include and library directories" >> ${OFN}
    echo "include_directories ( BEFORE \${CMAKE_CURRENT_SOURCE_DIR} )" >> ${OFN}
    echo "include_directories ( BEFORE ${UPP_SRC_DIR} )" >> ${OFN}

    echo >> ${OFN}
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
    local library_dep="${main_target_name}${LIB_SUFFIX} "
    for list_library in ${array_library[@]}; do
        library_dep+="${list_library}${LIB_SUFFIX} "
    done

    echo >> ${OFN}
    echo "# Main program properties" >> ${OFN}
    local build_date="`date '+#define bmYEAR    %y%n''#define bmMONTH   %-m%n''#define bmDAY     %-d%n''#define bmHOUR    %-H%n''#define bmMINUTE  %-M%n''#define bmSECOND  %-S%n''#define bmTIME    Time(%y, %-m, %-d, %-H, %-M, %-S)'`"
    local build_user="#define bmMACHINE \\\"`hostname`\\\""
    local build_machine="#define bmUSER    \\\"`whoami`\\\""

    echo "file ( WRITE \${PROJECT_BINARY_DIR}/inc/build_info.h \"" >> ${OFN}
    echo "${build_date}" >> ${OFN}
    echo "${build_user}" >> ${OFN}
    echo "${build_machine}\"" >> ${OFN}
    echo ")" >> ${OFN}

    echo >> ${OFN}
    echo 'file ( GLOB_RECURSE cpp_ini_files "${CMAKE_CURRENT_BINARY_DIR}/../*.icpp.cpp" )' >> ${OFN}
    echo 'file ( WRITE ${PROJECT_BINARY_DIR}/null.cpp "" )' >> ${OFN}
    echo "add_executable ( ${main_target_name}${BIN_SUFFIX} \${PROJECT_BINARY_DIR}/null.cpp \${cpp_ini_files} )" >> ${OFN}
#    echo "set_source_files_properties ( \${PROJECT_BINARY_DIR}/null.cpp PROPERTIES OBJECT_DEPENDS \${PROJECT_BINARY_DIR}/inc/build_info.h )" >> ${OFN}

    echo >> ${OFN}
    echo "# Main program dependecies" >> ${OFN}
    echo "add_dependencies ( ${main_target_name}${BIN_SUFFIX} ${library_dep})" >> ${OFN}

    echo >> ${OFN}
    echo "# Main program link" >> ${OFN}
    echo "target_link_libraries ( ${main_target_name}${BIN_SUFFIX} \${main_$LINK_LIST} ${library_dep} \${MAIN_TARGET_LINK_LIBRARY} )" >> ${OFN}

    echo >> ${OFN}
    echo "set_target_properties ( ${main_target_name}${BIN_SUFFIX} PROPERTIES OUTPUT_NAME ${main_target_name} )" >> ${OFN}

}

