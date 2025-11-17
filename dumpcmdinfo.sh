#!/bin/bash

#
# Script Name: dumpcmdinfo.sh
# Description: Creates a CSV file describing commands found in /bin and /usr/bin directories.
# Author:      David HEURTEVENT <david@heurtevent.org>
# Date:        2025-11-17
# Version:     1.0.0
# License:     MIT
#
# Usage:       ./dumpcmdinfo.sh [options] <arguments>
#
# Purpose:     Will prepare an alphabetically sorted list of commands found in /bin and /usr/bin
#              Will attempt to retrieve command description and use from man page, else whatis
#              Will output it to console or as a semi-colon quoted CSV file.
#
# Prerequisites: None
#
# Dependencies: coreutils, man, whatis
#
# Notes: use dumpcmdinfo.sh --help
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
Usage: $0 [OPTIONS] [OUTPUT_FILE]

Description:
    Creates a CSV file describing commands found in /bin and /usr/bin directories.
    If no output file is specified, output is sent to console.

Options:
    --help      Show this help message and exit

Output format:
    "filepath";"name";"symlink";"man_name";"man_example"

Fields:
    filepath    - Full path to the binary
    name        - Command name (basename)
    symlink     - If symlink, the target path; empty otherwise
    man_name    - First line of NAME section from man page (else whatis)
    man_example - First line of EXAMPLES or SYNOPSIS or Synopsis or SYNTAX or Syntax

Example:
    $0 commands.csv
    $0
EOF
}

# Check for help option
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Output file (empty for console output)
OUTPUT_FILE="$1"

# Function to extract section from man page
extract_man_section() {
    local command="$1"
    local section="$2"

    # Try multiple approaches to get man page as clean text
    local man_output=""

    # Method 1: Use man with cat as pager and specify section 1 (user commands)
    if man_output=$(MANPAGER=cat man "$command" 2>/dev/null); then
        : # Success
    # Method 2: Try section 1 explicitly
    elif man_output=$(MANPAGER=cat man 1 "$command" 2>/dev/null); then
        : # Success
    # Method 3: Try with col -b as fallback
    elif man_output=$(man "$command" 2>/dev/null | col -b 2>/dev/null); then
        : # Success
    else
        echo ""
        return 1
    fi

    # Extract the specified section - more robust parsing
    local section_content=$(echo "$man_output" | awk -v section="$section" '
        BEGIN { in_section = 0; found_content = 0; line_count = 0 }

        # Section header detection - more flexible
        /^[A-Z][A-Za-z ]+$/ || /^[A-Z]+$/ {
            current_section = $1
            if (current_section == section) {
                in_section = 1
                next
            } else if (in_section && NF > 0) {
                # Check if we hit the next section
                if ($0 ~ /^[A-Z][A-Za-z ]+$/ || $0 ~ /^[A-Z]+$/) {
                    exit
                }
            } else {
                in_section = 0
            }
        }

        # Handle content within section
        in_section && NF > 0 {
            # Skip empty lines at the beginning of section
            if (!found_content) {
                # Clean up the line
                gsub(/^[[:space:]]+|[[:space:]]+$/, "")
                if (length($0) > 0) {
                    print $0
                    found_content = 1
                    line_count++
                }
            } else if (line_count < 3) {
                # Get a few more lines for context (up to 3 total)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "")
                if (length($0) > 0) {
                    print $0
                    line_count++
                }
            }
        }
        # Stop after getting some content to avoid processing entire man page
        line_count >= 3 { exit }
    ')

    # For NAME section, we want just the first line for description
    # For other sections, we can take more context
    if [[ "$section" == "NAME" ]]; then
        local first_line=$(echo "$section_content" | head -n 1)
        if [[ -n "$first_line" ]]; then
            echo "$first_line"
        else
	    # Use whatis for NAME section as a reliable fallback
            local name_info=$(whatis "$command" 2>/dev/null | head -n 1)
            if [[ -n "$name_info" ]]; then
              echo "$name_info"
            else
              echo ""
            fi
        fi
    else
        # For EXAMPLES/SYNOPSIS, take first meaningful line
        local meaningful_line=$(echo "$section_content" | grep -v '^[[:space:]]*$' | head -n 1)
        if [[ -n "$meaningful_line" ]]; then
            echo "$meaningful_line"
        else
            echo ""
        fi
    fi
}


# Function to process a single binary
process_binary() {
    local filepath="$1"
    local name=$(basename "$filepath")
    local symlink=""
    local man_name=""
    local man_example=""
    local man_command="$name"

    # Check if it's a symlink
    if [[ -L "$filepath" ]]; then
        symlink=$(readlink -f "$filepath")
        # Use target name for man page lookup if it's in standard directories
        local target_name=$(basename "$symlink")
        if [[ "$symlink" == /bin/* ]] || [[ "$symlink" == /usr/bin/* ]]; then
            man_command="$target_name"
        fi
    fi

    # Get man page sections
    man_name=$(extract_man_section "$man_command" "NAME")
    man_example=$(extract_man_section "$man_command" "EXAMPLES")

    # If no examples, try synopsis
    if [[ -z "$man_example" ]]; then
        man_example=$(extract_man_section "$man_command" "SYNOPSIS")
    fi
    # else Synopsis (e.g. groff, grog)
    if [[ -z "$man_example" ]]; then
        man_example=$(extract_man_section "$man_command" "Synopsis")
    fi
    # else try SYNTAX (e.g. evince)
    if [[ -z "$man_example" ]]; then
        man_example=$(extract_man_section "$man_command" "SYNTAX")
    fi
    # else try Syntax
    if [[ -z "$man_example" ]]; then
        man_example=$(extract_man_section "$man_command" "Syntax")
    fi


    # Clean up NAME section - more careful approach
    if [[ -n "$man_name" ]]; then
        man_name=$(echo "$man_name")
	# Keep the information after the first dash (will remove command name, etc
        man_name=$(echo "$man_name" | sed 's/^.*[[:space:]]-[[:space:]]\(.*\)$/\1/')
        # If we accidentally removed everything, restore the original
        if [[ -z "$man_name" ]]; then
           man_name=$(extract_man_section "$man_command" "NAME")
        fi
	# whatis as fallback
        if [[ -z "$man_name" ]]; then
           man_name=$(whatis "$command" 2>/dev/null | head -n 1)
        fi
    fi

    # Escape quotes in the content for CSV
    man_name=$(echo "$man_name" | sed 's/"/""/g')
    man_example=$(echo "$man_example" | sed 's/"/""/g')
    symlink=$(echo "$symlink" | sed 's/"/""/g')

    # Output the record
    echo "\"$filepath\";\"$name\";\"$symlink\";\"$man_name\";\"$man_example\""
}

# Main script
main() {
    # Write header
   header="\"filepath\";\"name\";\"symlink\";\"man_name\";\"man_example\""

   echo ""
   echo "Starting to process ..."
   echo ""
   if [[ -n "$OUTPUT_FILE" ]]; then
	echo "Writing output to $OUTPUT_FILE"
        echo "$header" > "$OUTPUT_FILE"
    else
        echo "$header"
    fi

    # Find all executables in /bin and /usr/bin
    local dirs=("/bin" "/usr/bin")

    for dir in "${dirs[@]}"; do
        echo "Starting to process $dir"
        if [[ -d "$dir" ]]; then
            while IFS= read -r -d '' filepath; do
                # Skip directories, only process regular files and symlinks
                if [[ -f "$filepath" ]] || [[ -L "$filepath" ]]; then
                    # Check if executable (by owner, group, or others)
                    if [[ -x "$filepath" ]]; then
                        record=$(process_binary "$filepath")

                        if [[ -n "$OUTPUT_FILE" ]]; then
                            echo "$record" >> "$OUTPUT_FILE"
                        else
                            echo "$record"
                        fi
                    fi
                fi
            done < <(find "$dir" -maxdepth 1 \( -type f -o -type l \) -print0 2>/dev/null | sort -z)
        fi
    done
    echo "Task completed"
    echo ""
}

# Run main function
main
