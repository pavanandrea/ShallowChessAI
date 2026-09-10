#!/bin/bash
#-------------------------------------------------------------------------------
#   This script compiles and runs all the tests in the current folder.
#
#   How to run:
#   ./run_tests.sh
#
#   Author: Andrea Pavan
#   License: MIT
#-------------------------------------------------------------------------------

#compile all C files in the current directory that include "test" in the name
C_FILES=*test*.c
for cfile in $C_FILES; do
    #compile
    filename="${cfile%.c}"
    echo ""
    echo "--- TEST ${filename} ---"
    echo ""
    gcc "$cfile" -o "${filename}" -lm -Wall -Wextra
    if [ $? -ne 0 ]; then
        echo "Compilation of ${cfile} failed."
        exit 1
    fi

    #run test and remove executable
    ./${filename}
    if [ $? -ne 0 ]; then
        echo "Test ${filename} failed."
        exit 1
    fi
    rm -f "${filename}"
done
