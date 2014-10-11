#!/bin/bash

# LazyCrypt automates the creation, mounting and unmounting of file 
# based LUKS encrypted filesystems.
# Copyright (C) 2014  Mike Dunne <mike@nullcipher.eu>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Reset getopts
OPTIND=1

# We need to be uid 0 to play in /dev
if [[ $UID != 0 ]]; then
  echo "We need to sudo to use device files."
  sudo $0 $*
  exit 1
fi

# Print usage
function usage {
  echo -e "\nUsage:\n\
    \t$0 -n file\tMake a new encrypted file system\n\
    \t$0 -o file\tOpen an existing encrypted file system\n\
    \t$0 -c file\tClose an existing encrypted file system\n"
  exit 1
}


