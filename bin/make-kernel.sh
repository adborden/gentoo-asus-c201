#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -x

workdir=$1
modules_dir=$(mktemp --directory $workdir/modules-XXXXXXX)

KERNEL_DIR=${KERNEL_DIR:-/usr/src/linux}

function kmake () {
  make -j5 ARCH=arm CROSS_COMPILE=armv7a-unknown-linux-gnueabihf- "$@"
}

cp kernel/config.txt $KERNEL_DIR/.config

(
  cd $KERNEL_DIR
  kmake clean
  kmake olddefconfig
  kmake zImage dtbs modules
  kmake INSTALL_MOD_PATH=$modules_dir modules_install
)

tar cJf $workdir/modules.tar.xz -C $modules_dir .
rm -rf $modules_dir
