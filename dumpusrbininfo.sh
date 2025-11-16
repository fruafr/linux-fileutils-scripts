#!/bin/bash

#
# Script Name: dumpusrbininfo.sh
# Description: Generate the list of files and symlinks found in /usr/bin and determine the package used to install it.
# Author:      David HEURTEVENT <david@heurtevent.org>
# Date:        2025-11-16
# Version:     1.0.0
# License:     MIT
#
# Usage:       ./dumpusrbininfo.sh [options] <arguments>
#
# Purpose:     Will prepare an alphabetically sorted list of files and symlinks from /usr/bin.
#              Will determine for each file the package used to install it.
#              Will output it to console or as a semi-colon quoted CSV file.
#              Excludes '.' and '..'
#
# Prerequisites: None
#
# Dependencies: coreutils, distribution package installer
#
# Notes: use dumpusrbininfo.sh --help
#        AI assisted code generation (Deekseek v.3.2)
#
# Changelog:
#   2025-11-16 - Version 1.0.0 - Initial release.
#
# Exit Codes:
#   0 - Success
#
####
# MIT License
#
# Copyright (c) 2025 David HEURTEVENT <david@heurtevent.org> (frua.fr)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
####


# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Generate the list of files and symlinks found in /usr/bin and determine the package used to install it.

OPTIONS:
    -P FILE              Output to FILE instead of console
    --help               Display this help message and exit

ARGUMENTS:
    None

OUTPUT FORMAT:
    CSV with semicolon separator containing:
    filepath;name;pathtype;target;package

EXAMPLES:
    $0 -P output.txt               # List /usr/bin to output.txt
    $0 --help                      # Show this help

FIELDS INCLUDED:
    filepath: file path
    name:  name
    pathtype: Path type: file or symlink
    target: Target for symlinks
    package: Package used to install the utility

BEHAVIOR:
    - Output format is CSV with semicolon delimiter and quoted fields
    - Will use the package manager to attempt to determine the package (dpkg for Debian, rpm for RedHat, etc)
    - Ignores '.' and '..'
EOF
}

# Default values
output_file=""

# Parse command line arguments
if [ $# -gt 0 ]; then

    # Store arguments in array for easier processing
    args=("$@")

    # Check for help first
    for arg in "${args[@]}"; do
        case "$arg" in
            --help)
                show_help
                exit 0
                ;;
        esac
    done

    # Check for flags first
    for arg in "${args[@]}"; do
        case "$arg" in
            --follow-symlinks-dir)
                follow_symlinks_dir=true
                ;;
        esac
    done

    # Check for -P flag
    for ((i=0; i<${#args[@]}; i++)); do
        if [ "${args[i]}" = "-P" ]; then
            if [ $((i+1)) -lt ${#args[@]} ]; then
                output_file="${args[i+1]}"
            else
                echo "Error: -P requires an output file path" >&2
                exit 1
            fi
        fi
    done

fi


# Function to determine package
determine_package() {
    local filepath="$1"

    # Check if it's executable
    if [[ ! -x "$filepath" ]]; then
        echo ""
        return
    fi

    # Try dpkg (Debian/Ubuntu)
    if command -v dpkg >/dev/null 2>&1; then
        local pkg=$(dpkg -S "$filepath" 2>/dev/null | cut -d: -f1)
        if [[ -n "$pkg" ]]; then
            echo "$pkg"
            return
        fi
    fi

    # Try rpm (RedHat/CentOS/Fedora)
    if command -v rpm >/dev/null 2>&1; then
        local pkg=$(rpm -qf "$filepath" 2>/dev/null)
        if [[ $? -eq 0 && -n "$pkg" ]]; then
            echo "$pkg"
            return
        fi
    fi

    # Try pacman (Arch Linux)
    if command -v pacman >/dev/null 2>&1; then
        local pkg=$(pacman -Qo "$filepath" 2>/dev/null | awk '{print $5}')
        if [[ -n "$pkg" ]]; then
            echo "$pkg"
            return
        fi
    fi

    # Try apk (Alpine Linux)
    if command -v apk >/dev/null 2>&1; then
        local pkg=$(apk info --who-owns "$filepath" 2>/dev/null | cut -d' ' -f1)
        if [[ -n "$pkg" ]]; then
            echo "$pkg"
            return
        fi
    fi

    echo "COULD-NOT-BE-DETERMINED"
}


###

echo ""
echo "Starting the analysis of /usr/bin"
echo ""

# Create arrays to store file information
declare -a filepaths
declare -a names

echo "Collecting all files and sorting by name"
# Collect all files and sort by name
while IFS= read -r -d '' filepath; do
    name=$(basename "$filepath")
    filepaths+=("$filepath")
    names+=("$name")
done < <(find /usr/bin -maxdepth 1 \( -type f -o -type l \) -print0 | sort -z)
echo "Done"
echo ""

echo "Processing files to dermine package"

echo "Output:"
echo ""

# Print CSV header to the appropriate output
if [[ -n "$output_file" ]]; then
    echo "\"filepath\";\"name\";\"pathtype\";\"target\";\"package\"" > "$output_file"
    echo "Writing output to $output_file ..."
else
    echo "\"filepath\";\"name\";\"pathtype\";\"target\";\"package\""
fi

# Now process in sorted order
for i in "${!filepaths[@]}"; do
    filepath="${filepaths[i]}"
    name="${names[i]}"

    # Determine path type
    if [[ -L "$filepath" ]]; then
        pathtype="symlink"
        target=$(readlink -f "$filepath")
    elif [[ -f "$filepath" ]]; then
        pathtype="file"
        target=""
    else
        continue  # Skip if not file or symlink
    fi

    # Determine package (only for executable files)
    if [[ -x "$filepath" && "$pathtype" == "file" ]]; then
        package=$(determine_package "$filepath")
    else
        package=""
    fi

    # Output the record to the appropriate destination
    if [[ -n "$output_file" ]]; then
        echo "\"$filepath\";\"$name\";\"$pathtype\";\"$target\";\"$package\"" >> "$output_file"
    else
        echo "\"$filepath\";\"$name\";\"$pathtype\";\"$target\";\"$package\""
    fi
done

echo ""
echo "Task completed"
echo ""
