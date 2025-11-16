#!/bin/bash

#
# Script Name: dumpfstat.sh
# Description: Generate the detailed file stat information for the files contained in the specified directory.
# Author:      David HEURTEVENT <david@heurtevent.org>
# Date:        2025-11-16
# Version:     1.0.0
# License:     MIT
#
# Usage:       ./dumpfstat.sh [options] <arguments>
#
# Purpose:     Will retrieve stat information for each filepath found in the specified directory.
#              Will output it to console or as a semi-colon quoted CSV file.
#              Excludes '.' and '..'
#
# Prerequisites: None
#
# Dependencies: stat (coreutils)
#
# Notes: use dumpfstat.sh --help
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

Generate the detailed file stat information for files contained in the specified directory.

OPTIONS:
    -P FILE              Output to FILE instead of console
    --follow-symlinks-dir  Follow directory symlinks instead of rejecting them
    --help               Display this help message and exit

ARGUMENTS:
    DIRECTORY            Directory to scan (default: current directory)

OUTPUT FORMAT:
    CSV with semicolon separator containing:
    fullpath;name;pathtype;target;perms;user;group;uid;gid;size;
    created;changed;modified;accessed

EXAMPLES:
    $0 /usr/bin                    # List /usr/bin to console
    $0 -P output.txt /usr/bin      # List /usr/bin to output.txt
    $0 --follow-symlinks-dir /path # Follow symlinked directories
    $0 --help                      # Show this help

FIELDS INCLUDED:
    filepath: file path
    name:  name
    pathtype: Path type: file, directory, ...
    target: Target for symlinks
    perms: Permissions
    user: User
    group: Group
    uid: UID
    gid: GID
    size: Size
    created: birth time
    changed: ctime
    modified: mtime
    accessed: atime

BEHAVIOR:
    - By default, rejects directory symlinks for safety
    - Use --follow-symlinks-dir to analyze symlinked directories
    - Symlinks to files are always followed for metadata collection
    - Output format is CSV with semicolon delimiter and quoted fields
    - Ignores '.' and '..'
EOF
}

# Default values
directory="."
output_file=""
follow_symlinks_dir=false

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

    # Find the first non-flag argument (directory)
    for arg in "${args[@]}"; do
        if [ "$arg" != "--follow-symlinks-dir" ] && [ "$arg" != "-P" ] && [[ "$arg" != -* ]]; then
            directory="$arg"
            break
        fi
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

# Check if the provided directory is a symlink
if [ -L "$directory" ]; then
    if [ "$follow_symlinks_dir" = false ]; then
        echo "directory '$directory' symlinks to another directory" >&2
        exit 1
    else
        # Resolve the symlink to get the actual directory
        resolved_dir=$(readlink -f "$directory")
        if [ ! -d "$resolved_dir" ]; then
            echo "Error: Symlink '$directory' points to non-directory: '$resolved_dir'" >&2
            exit 1
        fi
        directory="$resolved_dir"
    fi
fi

# Check if directory exists and is a directory
if [ ! -d "$directory" ]; then
    echo "Error: '$directory' is not a directory or does not exist" >&2
    exit 1
fi

# Function to get file information without following symlinks
get_file_info() {
    local filepath="$1"
    local name="$2"

    # Initialize variables
    local fullpath pathtype target perms user group uid gid size
    local datetimecreated datetimechanged datetimemodified datetimeaccessed

    # A. Full path is already provided

    # B. Name is already provided

    # C. Path type (using -L to detect symlinks, but not following them)
    if [ -L "$filepath" ]; then
        pathtype="symlink"
    elif [ -f "$filepath" ]; then
        pathtype="file"
    elif [ -d "$filepath" ]; then
        pathtype="directory"
    elif [ -b "$filepath" ]; then
        pathtype="block_device"
    elif [ -c "$filepath" ]; then
        pathtype="character_device"
    elif [ -p "$filepath" ]; then
        pathtype="fifo"
    elif [ -S "$filepath" ]; then
        pathtype="socket"
    else
        pathtype="unknown"
    fi

    # D. Target for symlinks (readlink doesn't follow by default)
    if [ -L "$filepath" ]; then
        target=$(readlink "$filepath")
    else
        target=""
    fi

    # E. Permissions (use -L to get symlink permissions, not target)
    perms=$(stat -L -c "%a" "$filepath" 2>/dev/null || echo "")

    # F. User (use -L to get symlink ownership, not target)
    user=$(stat -L -c "%U" "$filepath" 2>/dev/null || echo "")

    # G. Group (use -L to get symlink ownership, not target)
    group=$(stat -L -c "%G" "$filepath" 2>/dev/null || echo "")

    # H. UID (use -L to get symlink ownership, not target)
    uid=$(stat -L -c "%u" "$filepath" 2>/dev/null || echo "")

    # I. GID (use -L to get symlink ownership, not target)
    gid=$(stat -L -c "%g" "$filepath" 2>/dev/null || echo "")

    # J. Size (use -L to get symlink size, not target)
    size=$(stat -L -c "%s" "$filepath" 2>/dev/null || echo "")

    # K. Date created (birth time) - use -L for symlinks
    created=$(stat -L -c "%w" "$filepath" 2>/dev/null || echo "")
    if [ "$created" = "-" ]; then
        created=""
    fi

    # L. Date changed (ctime) - use -L for symlinks
    changed=$(stat -L -c "%z" "$filepath" 2>/dev/null || echo "")
    if [ "$datetimechanged" = "-" ]; then
        changed=""
    fi

    # M. Date modified (mtime) - use -L for symlinks
    modified=$(stat -L -c "%y" "$filepath" 2>/dev/null || echo "")
    if [ "$modified" = "-" ]; then
        modified=""
    fi

    # N. Date accessed (atime) - use -L for symlinks
    accessed=$(stat -L -c "%x" "$filepath" 2>/dev/null || echo "")
    if [ "$accessed" = "-" ]; then
        accessed=""
    fi

    # Output the information as a semicolon-separated line
    echo "\"$filepath\";\"$name\";\"$pathtype\";\"$target\";\"$perms\";\"$user\";\"$group\";\"$uid\";\"$gid\";\"$size\";\"$created\";\"$changed\";\"$modified\";\"$accessed\""
}

# Print header
header="\"filepath\";\"name\";\"pathtype\";\"target\";\"perms\";\"user\";\"group\";\"uid\";\"gid\";\"size\";\"created\";\"changed\";\"modified\";\"accessed\""

echo ""
echo "Starting the analysis for $directory"
echo ""

# Process output
if [ -n "$output_file" ]; then
    # Write to file (header + data)
    echo "$header" > "$output_file"
    for file in "$directory"/*; do
        if [ "$file" != "$directory/*" ] && [ "$(basename "$file")" != "." ] && [ "$(basename "$file")" != ".." ]; then
            get_file_info "$file" "$(basename "$file")" >> "$output_file"
        fi
    done
    echo "Output written to: $output_file"
else
    # Output to console (header + data)
    echo "$header"
    for file in "$directory"/*; do
        if [ "$file" != "$directory/*" ] && [ "$(basename "$file")" != "." ] && [ "$(basename "$file")" != ".." ]; then
            get_file_info "$file" "$(basename "$file")"
        fi
    done
fi

echo ""
echo "Task completed for $directory"
echo ""

