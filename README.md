# LazyCrypt

Lazycrypt is a bash script which automates the creation, mounting and unmounting of encrypted filesystems. 

By using standard linux tools, we can produce something roughly similar to TrueCrypt's encrypted volumes. 
An empty file is created which is associated with a loopback device. This device can then be encrypted 
using cryptsetup and luks. The device can then be formatted with a filesystem and used the same way as 
any other file system.

The end result is a file which appears to be full of random data. The file can be mounted as a filesystem 
and used as per usual. All the heavy lifting is done by dd, losetup and cryptsetup.

Currently, just the default settings for cryptsetup are used (256 bit aes in cbc mode).

## Usage

### To create a 10MB filesystem called mysecret.dat
`./lazycrypt.sh -n ~/mysecret.dat -s 10`

You will now have a 10MB file called *mysecret.dat* in your current directory. You will also have a 10MB 
encrypted filesystem mounted at */mnt/lazycrypt/mysecret.dat*

### To close mysecret.dat
`./lazycrypt.sh -c ~/mysecret.dat`

### To open a previous volume
`./lazycrypt.sh -o ~/my_old_secret.dat`
