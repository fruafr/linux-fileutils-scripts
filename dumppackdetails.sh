#!/bin/bash

#
# Script Name: dumppackdetails.sh
# Description: Dump package details for a Linux system to a quoted CSV file.
# Author:      David HEURTEVENT <david@heurtevent.org>
# Date:        2025-11-16
# Version:     1.0.0
# License:     MIT
#
# Usage:       ./dumppackdetails.sh [options] <arguments>
#
# Purpose:     Will prepare the alphabetically sorted list of packages installed on the system.
#              Will attempt to determine the version, architecture and description, if available.
#              Will output it to console or as a semi-colon quoted CSV file.
#              Support the major modern Linux distribution families : Debian, RedHat, Arch, OpenSuse, Alpine
#
# Prerequisites: None
#
# Dependencies: coreutils, distribution package installer
#
# Notes: use dumppackdetails.sh --help
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
Usage: dumppackdetails.sh [OPTIONS] OUTPUT_FILE

Dump package details for a Linux system to a quoted CSV file.

OPTIONS:
    --help    Show this help message

OUTPUT_FILE:
    Path to the file where the package details will be saved

SUPPORTED DISTRIBUTIONS:
    - Debian/Ubuntu (dpkg)
    - Red Hat/Fedora/RHEL clones (rpm)
    - openSUSE (rpm)
    - Arch Linux (pacman)
    - Alpine Linux (apk)

OUTPUT FORMAT:
    "name";"version";"description"

EXAMPLE:
    dumppackdetails.sh packdetails.txt
EOF
}

# Function to detect the current Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Function to handle Debian/Ubuntu systems (dpkg)
dump_dpkg() {
    local output_file="$1"

    # Write header
    echo '"name";"version";"description"' > "$output_file"

    # Process dpkg output
    dpkg -l | awk '
    NR>=6 {
        # Extract fields from dpkg -l output
        status = $1
        name = $2
        version = $3
        # Description starts from $5 onwards
        description = ""
        for (i=5; i<=NF; i++) {
            description = description (i==5 ? "" : " ") $i
        }

        # Only include packages that are installed (starts with "ii")
        if (status == "ii") {
            # Escape quotes in description
            gsub(/"/, "\"\"", description)
            printf "\"%s\";\"%s\";\"%s\"\n", name, version, description
        }
    }' >> "$output_file"
}

# Function to handle RPM-based systems (Red Hat, Fedora, AlmaLinux, openSUSE)
dump_rpm() {
    local output_file="$1"

    # Write header
    echo '"name";"version";"description"' > "$output_file"

    # Process rpm output
    rpm -qa --queryformat '"%{NAME}";"%{VERSION}-%{RELEASE}";"%{SUMMARY}"\n' | \
    sed 's/""/"/g' >> "$output_file"
}

# Function to handle Arch Linux (pacman)
dump_pacman() {
    local output_file="$1"

    # Write header
    echo '"name";"version";"description"' > "$output_file"

    # Process pacman output using a temporary file for awk script
    pacman -Q | awk '
    {
        name = $1
        version = $2
        description = "No description available"

        # Build and execute command to get description
        cmd = "pacman -Qi " name " 2>/dev/null | awk -F: '\''/^Description/ {print substr(\\$0, index(\\$0,\\\":\\\")+2)}'\''"
        cmd | getline description
        close(cmd)

        # Escape quotes in description
        gsub(/"/, "\"\"", description)
        printf "\"%s\";\"%s\";\"%s\"\n", name, version, description
    }' >> "$output_file"
}

# Alternative function for Arch Linux that's more reliable
dump_pacman_alternative() {
    local output_file="$1"

    # Write header
    echo '"name";"version";"description"' > "$output_file"

    # Get list of packages
    pacman -Q > /tmp/pacman_packages.txt

    # Process each package
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        version=$(echo "$line" | awk '{print $2}')

        # Get description using pacman -Qi
        description=$(pacman -Qi "$name" 2>/dev/null | grep -i '^Description' | cut -d':' -f2- | sed 's/^ *//' 2>/dev/null)
        if [ -z "$description" ]; then
            description=""
        fi

        # Escape quotes in description
        description=$(echo "$description" | sed 's/"/""/g')

        echo "\"$name\";\"$version\";\"$description\"" >> "$output_file"
    done < /tmp/pacman_packages.txt

    # Clean up
    rm -f /tmp/pacman_packages.txt
}

# Function to handle Alpine Linux (apk)
dump_apk() {
    local output_file="$1"

    # Write header
    echo '"name";"version";"description"' > "$output_file"

    # Process apk output
    apk info -v | while read -r package; do
        # Extract package name and version
        name=$(echo "$package" | sed 's/-[0-9].*//')
        version=$(echo "$package" | grep -o '[0-9].*')
        description=""

        # Try to get description
        desc=$(apk info "$name" 2>/dev/null | head -1)
        if [ -n "$desc" ]; then
            description="$desc"
        fi

        # Escape quotes in description
        description=$(echo "$description" | sed 's/"/""/g')

        echo "\"$name\";\"$version\";\"$description\"" >> "$output_file"
    done
}

# Main script logic
main() {
    # Check for help flag
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi

    # Check if output file argument is provided
    if [ $# -ne 1 ]; then
        echo "Error: Output file argument is required" >&2
        echo "Usage: $0 OUTPUT_FILE" >&2
        echo "Use --help for more information" >&2
        exit 1
    fi

    local output_file="$1"

    # Check if output directory exists and is writable
    local output_dir=$(dirname "$output_file")
    if [ ! -d "$output_dir" ] && [ "$output_dir" != "." ]; then
        echo "Error: Output directory '$output_dir' does not exist" >&2
        exit 1
    fi

    if [ ! -w "$output_dir" ] && [ "$output_dir" != "." ]; then
        echo "Error: No write permission for directory '$output_dir'" >&2
        exit 1
    fi

    # Detect distribution
    local distro=$(detect_distro)

    echo ""
    echo "Detected distribution: $distro" >&2
    echo "Generating package details to: $output_file" >&2

    # Call appropriate function based on distribution
    case "$distro" in
        debian|ubuntu|linuxmint)
            if command -v dpkg >/dev/null 2>&1; then
                dump_dpkg "$output_file"
            else
                echo "Error: dpkg not found on $distro system" >&2
                exit 1
            fi
            ;;
        rhel|centos|fedora|almalinux|rocky|opensuse*|sles)
            if command -v rpm >/dev/null 2>&1; then
                dump_rpm "$output_file"
            else
                echo "Error: rpm not found on $distro system" >&2
                exit 1
            fi
            ;;
        arch|manjaro)
            if command -v pacman >/dev/null 2>&1; then
                # Use the alternative version which is more reliable
                dump_pacman_alternative "$output_file"
            else
                echo "Error: pacman not found on $distro system" >&2
                exit 1
            fi
            ;;
        alpine)
            if command -v apk >/dev/null 2>&1; then
                dump_apk "$output_file"
            else
                echo "Error: apk not found on $distro system" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unsupported distribution: $distro" >&2
            echo "Supported distributions: Debian, Ubuntu, Red Hat, Fedora, AlmaLinux, openSUSE, Arch, Alpine" >&2
            exit 1
            ;;
    esac

    echo "Package details successfully saved to $output_file" >&2
    echo ""
}

# Run main function with all arguments
main "$@"
