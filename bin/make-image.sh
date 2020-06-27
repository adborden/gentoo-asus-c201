#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -x

vmlinuz=$1
rootfs_tarball=$2
modules_tarball=$3
workdir=$4

image=$(mktemp $workdir/image-XXXXXXX)

# Create a sparse image.
dd if=/dev/zero conv=sparse of=$image count=4194304  # 2 * 1024 * 1024 * 1024 / 512 (2GB with 512 blocks)

# Create the GPT partition table.
parted $image mklabel gpt

# Some scripts use 4MiB starting offset successfully, but I found the first
# writable block on the MMC was 16384.
parted -a optimal $image unit mib mkpart kernel 8 72
parted -a optimal $image unit mib mkpart root 72 100%

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
tar xpf $rootfs_tarball --numeric-owner --xattrs --acls -C $mountpoint

# Copy kernel modules
tar xpf $modules_tarball -C $mountpoint

umount $mountpoint
rmdir $mountpoint

# Detach the loop device
losetup -d $loop

mv $image $workdir/gentoo.img
chmod 0644 $workdir/gentoo.img
