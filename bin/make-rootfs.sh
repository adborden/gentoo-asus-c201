#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -x

stage3=$1
workdir=$2

rootfs=$(mktemp --directory $workdir/rootfs-XXXXXXX)

function cleanup () {
  rm -rf $rootfs
}

trap cleanup EXIT

# Start with the stage3 base
tar xpf $stage3 --numeric-owner --acls --xattrs -C $rootfs

# Configure portage for arm
cat <<EOF >> $rootfs/etc/portage/make.conf
ACCEPT_KEYWORDS="~arm"
MAKEOPTS="-j4"
EOF

# Set the root password as `gentoo`.
sed -i 's/root\:\*/root\:\$6\$I9Q9AyTL\$Z76H7wD8mT9JAyrp\/vaYyFwyA5wRVN0tze8pvM\.MqScC7BBm2PU7pLL0h5nSxueqUpYAlZTox4Ag2Dp5vchjJ0/' $rootfs/etc/shadow


# tar it up
tar cpJf $workdir/rootfs.tar.xz --numeric-owner --acls --xattrs -C $rootfs .
rm -rf $rootfs
