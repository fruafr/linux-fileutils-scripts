#!/bin/bash

#
# Script Name: dumpmanpages.sh
# Description: Dump man pages for all binaries found in /bin and /usr/bin as text files.
# Author:      David HEURTEVENT <david@heurtevent.org>
# Date:        2025-11-16
# Version:     1.0.1
# License:     MIT
#
# Usage:       ./dumpmanpages.sh [options] <arguments>
#
# Purpose:     Will create a text file containing the content of man [command] for each command found in /bin and /usr/bin
#
# Prerequisites: None
#
# Dependencies: coreutils (man)
#
# Notes: use dumpmanpages.sh --help
#        AI assisted code generation (Deekseek v.3.2)
#
# Changelog:
#   2025-11-16 - Version 1.0.0 - Initial release.
#
# Exit Codes:
#   0 - Success
#   1 - Not a directory
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
Usage: $0 [OPTIONS] DIRECTORY

Dump man pages for all binaries found in /bin and /usr/bin as text files.

OPTIONS:
    --help    Show this help message and exit

ARGUMENTS:
    DIRECTORY  Target directory where man pages will be dumped as text files

EXAMPLES:
    $0 ./manpages          # Dump man pages to ./manpages directory
    $0 /path/to/man_docs   # Dump man pages to /path/to/man_docs directory

NOTES:
    - Only processes binaries from /bin and /usr/bin
    - For symlinks, uses the target command name (e.g., egrep -> grep.txt)
    - Does not create separate files for symlinks
    - Output format: man [command] | col -b > DIRECTORY/[command].txt
EOF
}

# Check for help flag
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Check if directory argument is provided
if [[ $# -ne 1 ]]; then
    echo "Error: Directory argument required" >&2
    echo "Usage: $0 DIRECTORY" >&2
    echo "Use '$0 --help' for more information" >&2
    exit 1
fi

TARGET_DIR="$1"

# Verify that the argument is a directory
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a directory or does not exist" >&2
    exit 1
fi

# Make sure target directory is writable
if [[ ! -w "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' is not writable" >&2
    exit 1
fi

# Function to get the target command name from a symlink
get_target_command() {
    local symlink="$1"

    # Read the symlink target
    local target=$(readlink "$symlink")

    if [[ -n "$target" ]]; then
        # Extract just the command name from the target path
        basename "$target"
    else
        echo ""
    fi
}

# Function to process a directory of binaries
process_directory() {
    local bin_dir="$1"

    if [[ ! -d "$bin_dir" ]]; then
        echo "Warning: Directory '$bin_dir' not found, skipping..." >&2
        return
    fi

    echo "Processing binaries in: $bin_dir"

    # Create an associative array to track processed commands
    declare -A processed_commands

    # Process all items in the directory
    for item in "$bin_dir"/*; do
        # Skip if no files found or item doesn't exist
        [[ -e "$item" ]] || continue

        local cmd_name=""

        if [[ -f "$item" && ! -L "$item" ]]; then
            # Regular file - use its name
            cmd_name=$(basename "$item")
        elif [[ -L "$item" ]]; then
            # Symlink - get the target command name
            cmd_name=$(get_target_command "$item")
            if [[ -z "$cmd_name" ]]; then
                echo "Warning: Could not determine target for symlink '$item'" >&2
                continue
            fi
            echo "Processing symlink: $(basename "$item") -> $cmd_name"
        else
            # Skip directories and other types
            continue
        fi

        # Skip if we've already processed this command
        if [[ -n "${processed_commands[$cmd_name]}" ]]; then
            echo "Skipping duplicate: $cmd_name (already processed)" >&2
            continue
        fi

        # Check if man page exists for this command
        if man -w "$cmd_name" >/dev/null 2>&1; then
            local output_file="${TARGET_DIR}/${cmd_name}.txt"
            echo "Dumping man page for: $cmd_name"

            # Dump man page using col -b to remove formatting
            if ! man "$cmd_name" | col -b > "$output_file" 2>/dev/null; then
                echo "Warning: Failed to dump man page for '$cmd_name'" >&2
                # Remove empty file if creation failed
                [[ -f "$output_file" && ! -s "$output_file" ]] && rm -f "$output_file"
            else
                # Mark this command as processed
                processed_commands["$cmd_name"]=1
            fi
        else
            echo "Skipping '$cmd_name': no man page found" >&2
            # Mark as processed to avoid retrying
            processed_commands["$cmd_name"]=1
        fi
    done
}

# Main execution
echo ""
echo "Starting man page dump to: $TARGET_DIR"

# Process both directories
process_directory "/bin"
process_directory "/usr/bin"

echo "Man page dump completed to: $TARGET_DIR"
echo "Total files created: $(find "$TARGET_DIR" -name "*.txt" -type f | wc -l)"
echo ""
