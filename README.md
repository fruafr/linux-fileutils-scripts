# linux-fileutils-scripts
Linux file utils scripts 

The scripts in this package are useful to collect information on the system being used for future reference (e.g. in a AI RAG system).

## Package listing
- [dumppacklist.sh](dumppacklist.sh): Dump the list of installed packages to a file. (BASH)
- [dumppackdetails.sh](dumppackdetails.sh): Dump package details for a Linux system to a quoted CSV file. (BASH)

## /usr/bin utilities listing
- [dumpcmdinfo.sh](dumcmdinfo.sh): Creates a CSV file describing commands found in /bin and /usr/bin directories. (BASH)
- [dumpcmdpackinfo.sh](dumpcmdpackinfo.sh): Generate the list of files and symlinks found in /usr/bin and determine the package used to install it. (BASH)
- [dumpmanpages.sh](dumpmanpages.sh): Dump man pages for all binaries found in /bin and /usr/bin as text files. (BASH)

## File system directory content listing
- [dumpfstat.sh](dumpfstat.sh): Generate the detailed file stat information for the files contained in the specified directory. (BASH)

## Notes
- Last updated: 2025-11-17
- License: This repo including its files is [MIT licensed](LICENSE) = Free to use and reuse.
- Author: David HEURTEVENT <david@heurtevent.org> (fruafr)

