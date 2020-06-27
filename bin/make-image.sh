#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -x

vmlinuz=$1
rootfs_tarball=$2
modules_tarball=$3
workdir=$4

usb_image=$(mktemp $workdir/image-XXXXXXX)
mmc_image=$(mktemp $workdir/image-XXXXXXX)

function make_image () {
  local blocks image loop mountpoint
  image=$1
  blocks=$2

  # Create a sparse file for the image
  dd if=/dev/zero conv=sparse of=$image count=$blocks

  # Create the GPT partition table.
  parted --script $image mklabel gpt

  # Some scripts use 4MiB starting offset successfully, but I found the first
  # writable block on the MMC was 16384.
  parted --script -a optimal $image unit mib mkpart kernel 8 40
  parted --script -a optimal $image unit mib mkpart root 40 100%

  # Set partition parameters
  cgpt add -i 1 -t kernel -l Kernel -S 1 -T 5 -P 10 $image
  cgpt add -i 2 -t data -l Root $image

  loop=$(losetup --show --partscan --find $image)

  # Copy vmlinuz to image
  dd if=$vmlinuz of=${loop}p1

  # Format rootfs partition as ext4
  mkfs.ext4 -b 4096 -m 0 -O ^has_journal ${loop}p2

  # Mount the rootfs partition
  mountpoint=$(mktemp --directory $workdir/root-XXXXXXX)
  chmod 0755 $mountpoint
  mount ${loop}p2 $mountpoint

  # Copy rootfs to the image
  tar xpf $rootfs_tarball --numeric-owner --xattrs --acls -C $mountpoint

  # Copy kernel modules
  tar xpf $modules_tarball -C $mountpoint

  # Cleanup rootfs mount
  umount $mountpoint
  rmdir $mountpoint

  # Detach the loop device
  losetup --detach $loop

  # Make the image world readable
  chmod 0644 $image
}


# Create a sparse image for USB
make_image $usb_image 8388608 # 4 * 1024 * 1024 * 1024 / 512 (2GB with 512 blocks)

# Create a sparse image for eMMC
make_image $mmc_image 30785536  # /sys/block/mmcblk0/size on asus-c201, ~14.67GB

# Rename the temporary eMMC image
mv $mmc_image $workdir/install.img

# Mount the usb image once more in order to copy the install image onto it
loop=$(losetup --show --partscan --find $usb_image)
mountpoint=$(mktemp --directory $workdir/mount-XXXXXXX)
mount ${loop}p2 $mountpoint

cp $workdir/install.img $mountpoint/

umount $mountpoint
rmdir $mountpoint
losetup --detach $loop

# Rename the USB image
mv $usb_image $workdir/gentoo.img
