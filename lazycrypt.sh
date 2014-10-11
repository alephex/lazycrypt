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

VERSION="0.1.1"

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

  echo "LazyCrypt Version $VERSION"
  echo -e "\nUsage:\n\
    \t$0 -n file [-s size]\tMake a new file system of size GB (default 1)\n\
    \t$0 -o file\t\t\tOpen an existing encrypted file system\n\
    \t$0 -c file\t\t\tClose an existing encrypted file system\n\
    Eg: create a new 10GB encrypted filesystem in a file called mysecret.txt\n\
    \t$0 -n mysecret.txt -s 10\n\
    NOTES:\n\
    \tOnly integer file sizes are allowed for now.\n\
    \tCryptsetup will prompt you for a passphrase to encrypt the volume\n"
  exit 1

}

# Check for the tools we need. Most distros should have them in their 
# base install.
function check_tools {

echo "Checking tools ..."

  tools="cryptsetup losetup dd mkfs"
  tool_status=0
  tool_missing=""
  for t in $tools; do 
    which $t &> /dev/null
    if [ $? = 0 ]; then 
      echo "$t ... OK"
    else
      echo "$t ... not found"
      tool_status=1
      tool_missing="$tool_missing $t"
    fi
  done

  if [ $tool_status = 1 ]; then
    echo "Please install the missing tools: $tool_missing"
    exit 1
  fi

}

# Create a new container file
function new_file {

# Test if the file exists
  full_path=$(readlink -f $1)
  if [ -f $full_path ]; then 
    echo "File $full_path exists. Overwrite? [y/n]"
    read overwrite
    if [ "$overwrite" != y ]; then 
      echo "Quitting"
      exit 0
    fi
    rm -f $full_path
  fi

  # Create the file
  echo "Creating $full_path ..."

  # Check the size given, set to 0 as default
  test $2 -eq 0 2>/dev/null
  if [ $? -eq 2 ]; then
    echo "Invalid size given. Setting to 1GB."
    size="1G"
  else
    size=$2"G"
  fi

  # Create an empty file
  dd of=$full_path bs=$size count=0 seek=1 &> /dev/null
  if [ $? = 0 ]; then 
    echo -e "\tDone"
  else
    echo -e "\tCould not create $full_path"
    exit 1
  fi

  # Set permissions
  echo "Setting file permissions to 600 ..."
  chmod 600 $full_path &> /dev/null
  if [ $? = 0 ]; then 
    echo -e "\tDone"
  else
    echo -e "\tCould not set permissions on $full_path"
    exit 1
  fi

  # Change owner
  echo "Setting owner to $SUDO_USER ..."
  chown $SUDO_USER $full_path &> /dev/null
  if [ $? = 0 ]; then 
    echo -e "\tDone"
  else
    echo -e "\tCould not change ownership of $full_path"
    exit 1
  fi

  # Set up loopback
  echo "Setting up loopback ..."
  losetup /dev/loop0 $full_path &> /dev/null
  if [ $? = 0 ]; then 
    echo -e "\tDone"
  else
    echo -e "\tCould not set up loop for $full_path"
    exit 1
  fi

  # Encrypt device and print status
  echo "Setting up encryption ..."
  fsname=$(basename $full_path)
  cryptsetup --verify-passphrase luksFormat /dev/loop0
  echo -e "\nThis is the same passphrase:"
  cryptsetup luksOpen /dev/loop0 $fsname
  cryptsetup status $fsname

  # Zero device
  echo "Zeroing device ..."
  dd if=/dev/zero of=/dev/mapper/$fsname &> /dev/null
  # This is supposed to return 1
  if [ $? = 1 ]; then 
    echo -e "\tDone"
  else
    echo -e "\tCould not zero $full_path"
    exit 1
  fi

  # Make a filesystem on device
  echo "Creating filesystem on $full_path ..."
  mkfs.ext4 /dev/mapper/$fsname &> /dev/null
  if [ $? = 0 ]; then 
    echo -e "\tDone"
  else
    echo -e "\tCould not set up a file system on $full_path"
    exit 1
  fi

  # Mount the device
  mkdir /mnt/lazycrypt /mnt/lazycrypt/$fsname &> /dev/null
  mount /dev/mapper/$fsname /mnt/lazycrypt/$fsname &> /dev/null
  if [ $? = 0 ]; then 
    echo "Encrypted filesystem available at /mnt/lazycrypt/$fsname"
  else
    echo -e "\tCould not mount $fsname"
    exit 1
  fi
  chown -R $SUDO_USER /mnt/lazycrypt/$fsname &> /dev/null
  if [ $? = 0 ]; then 
    echo -e "\tEncrypted filesystem /mnt/lazycrypt/$fsname is owned by $SUDO_USER"
    exit 0
  else
    echo -e "\tCould not change owner for $fsname"
    exit 1
  fi

}

# Open an existing file
function open_file {

  # Test if the file exists
  full_path=$(readlink -f $1)
  if [ -f $full_path ]; then 
    # Get the filename
    fsname=$(basename $full_path)

    # Setup loop device
    losetup /dev/loop0 $full_path

    # Cryptsetup on our loop device
    echo -e "\nPassphrase required:"
    cryptsetup luksOpen /dev/loop0 $fsname

    # Make a directory and mount the device there
    mkdir /mnt/lazycrypt /mnt/lazycrypt/$fsname &> /dev/null
    mount /dev/mapper/$fsname /mnt/lazycrypt/$fsname &> /dev/null
    if [ $? = 0 ]; then 
      echo "Encrypted filesystem available at /mnt/lazycrypt/$fsname"
    else
      echo "Could not mount $fsname"
      exit 1
    fi
    chown -R $SUDO_USER /mnt/lazycrypt/$fsname &> /dev/null
    if [ $? = 0 ]; then 
      echo -e "Encrypted filesystem /mnt/lazycrypt/$fsname is owned by $SUDO_USER"
      exit 0
    else
      echo "Could not change owner for $fsname"
      exit 1
    fi
  fi

}

# Close an open file
function close_file {

  # Get file info
  full_path=$(readlink -f $1)
  fsname=$(basename $full_path)

  # Unmount
  umount /mnt/lazycrypt/$fsname
  rm -rf /mnt/lazycrypt/$fsname

  # Clear /dev/mapper
  cryptsetup luksClose $fsname

  # Release our loop deice back into the wild
  losetup -d /dev/loop0

  echo "Closed file $1"

}

# Get command line args
# Default file size in GB
fsize=1
while getopts "hn:o:c:s:" opt; do
  case "$opt" in
    h)  usage
        ;;
    s)  fsize=$OPTARG
        ;;
    n)  new_file $OPTARG $fsize
        ;;
    o)  open_file $OPTARG
        ;;
    c)  close_file $OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

# Fin
