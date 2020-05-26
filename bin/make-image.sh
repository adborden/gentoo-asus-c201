#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

vmlinuz=$1
rootfs=$2
workdir=$3

image=$(mktemp $workdir/image-XXXXXXX)

# Create a sparse image.
dd if=/dev/zero conv=sparse of=$image count=4194304  # 2 * 1024 * 1024 * 1024 / 512 (2GB with 512 blocks)

# Create the GPT partition table.
parted $image mklabel gpt
parted -a optimal $image unit mib mkpart kernel 4 65
parted -a optimal $image unit mib mkpart root 65 100%

# Set partition parameters
cgpt add -i 1 -t kernel -l Kernel -S 1 -T 5 -P 10 $image
cgpt add -i 2 -t basicdata -l Root $image

loop=$(losetup -f $image -P --show)

# Copy vmlinuz to image
dd if=$vmlinuz of=${loop}p1

# Format rootfs partition as ext4
mkfs.ext4 -O ^has_journal ${loop}p2

# Mount the rootfs partition
mountpoint=$(mktemp --directory $workdir/root-XXXXXXX)
mount ${loop}p2 $mountpoint

# Copy rootfs to the image
tar xvf $rootfs --numeric-owner --xattrs --acls -C $mountpoint
umount $mountpoint

# Detach the loop device
losetup -d $loop

mv $image $workdir/gentoo.img
chmod 0644 $workdir/gentoo.img
