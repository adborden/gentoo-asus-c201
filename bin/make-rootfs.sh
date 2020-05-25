#!/bin/bash

set -o errexit
set -o pipefail

stage3=$1
workdir=$2
rootfs=$(mktemp --directory $workdir/rootfs-XXXXXXX)

function cleanup () {
  rm -rf $rootfs
}

trap cleanup EXIT

tar xvpf $workdir/stage3-armv7a_hardfp-20200509T210605Z.tar.xz --numeric-owner --acls --xattrs -C $rootfs

# Configure portage for arm
cat <<EOF >> $rootfs/etc/portage/make.conf
ACCEPT_KEYWORDS="~arm"
MAKEOPTS="-j4"
EOF

# Set the root password as `gentoo`.
sed -i 's/root\:\*/root\:\$6\$I9Q9AyTL\$Z76H7wD8mT9JAyrp\/vaYyFwyA5wRVN0tze8pvM\.MqScC7BBm2PU7pLL0h5nSxueqUpYAlZTox4Ag2Dp5vchjJ0/' $rootfs/etc/shadow

# Copy kernel modules
tar xvpf $workdir/modules.tar.xz -C $rootfs

# Copy firmware
cp -a /lib/firmware $rootfs/lib/firmware

# tar it up
tar cpvJf $workdir/rootfs.tar.xz --numeric-owner --acls --xattrs -C $rootfs .
rm -rf $rootfs
