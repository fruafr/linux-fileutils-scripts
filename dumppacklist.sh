#!/bin/bash

#
# Script Name: dumppacklist.sh
# Description: Dump the list of installed packages to a file.
# Author:      David HEURTEVENT <david@heurtevent.org>
# Date:        2025-11-17
# Version:     1.0.1
# License:     MIT
#
# Usage:       ./dumppacklist.sh [options] <arguments>
#
# Purpose:     Will prepare an alphabetically sorted list of packages.
#
# Prerequisites: None
#
# Dependencies: coreutils, distribution package installer
#
# Notes: use dumppacklist.sh --help
#        AI assisted code generation (Deekseek v.3.2)
#
# Changelog:
#   2025-11-17 - Version 1.0.1 - Changed help
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
Usage: $0 [OPTIONS] OUTPUT_FILE

Dump the list of installed packages to a file.

Supported package managers:
  - dpkg (Debian, Ubuntu)
  - rpm (RedHat, Fedora, RH clones, OpenSUSE)
  - pacman (Arch Linux)
  - apk (Alpine Linux)

OPTIONS:
  -h, --help    Show this help message and exit

ARGUMENTS:
  OUTPUT_FILE   Path to the file where the package list will be saved

Examples:
  $0 packages.txt
  $0 --help
EOF
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Check if output file argument is provided
if [[ $# -eq 0 ]]; then
    echo "Error: No output file specified"
    echo "Usage: dumppacklist.sh OUTPUT_FILE"
    echo "Use --help for more information"
    exit 1
fi

output_file="$1"

# Function to detect package manager
detect_package_manager() {
    if command -v dpkg >/dev/null 2>&1 && dpkg -l >/dev/null 2>&1; then
        echo "dpkg"
    elif command -v rpm >/dev/null 2>&1 && rpm -qa >/dev/null 2>&1; then
        echo "rpm"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# Function to dump packages based on package manager
dump_packages() {
    local pkg_manager="$1"
    local output="$2"

    case "$pkg_manager" in
        "dpkg")
            echo "# Package list generated using dpkg on $(date)" > "$output"
            echo "# System: $(lsb_release -ds 2>/dev/null || echo "Unknown Debian-based system")" >> "$output"
            dpkg-query -f '${Package}\n' -W >> "$output"
            ;;
        "rpm")
            echo "# Package list generated using rpm on $(date)" > "$output"
            echo "# System: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' 2>/dev/null || echo "Unknown RPM-based system")" >> "$output"
            rpm -qa --queryformat '%{NAME}\n' | sort >> "$output"
            ;;
        "pacman")
            echo "# Package list generated using pacman on $(date)" > "$output"
            echo "# System: Arch Linux" >> "$output"
            pacman -Qq >> "$output"
            ;;
        "apk")
            echo "# Package list generated using apk on $(date)" > "$output"
            echo "# System: Alpine Linux $(cat /etc/alpine-release 2>/dev/null)" >> "$output"
            apk info | sort >> "$output"
            ;;
        *)
            echo "Error: Unsupported package manager or unable to detect system"
            exit 1
            ;;
    esac
}

# Main execution
pkg_manager=$(detect_package_manager)

echo ""
echo "Task starting"
echo ""

if [[ "$pkg_manager" == "unknown" ]]; then
    echo "Error: Could not detect a supported package manager"
    echo "Supported systems: Debian/Ubuntu, RedHat/Fedora/RH Clones/OpenSUSE, Arch Linux, Alpine Linux"
    exit 1
fi

echo "Detected package manager: $pkg_manager"
echo "Dumping package list to: $output_file"

# Dump packages to file
dump_packages "$pkg_manager" "$output_file"

# Verify the operation was successful
if [[ $? -eq 0 ]] && [[ -s "$output_file" ]]; then
    package_count=$(grep -v '^#' "$output_file" | wc -l)
    echo "Successfully dumped $package_count packages to $output_file"
else
    echo "Error: Failed to dump package list"
    exit 1
fi
