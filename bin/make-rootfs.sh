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

# Install packages from sysroot
armv7a-unknown-linux-gnueabihf-emerge --sysroot=$rootfs --root=$rootfs -quN --usepkgonly @system
armv7a-unknown-linux-gnueabihf-emerge --sysroot=$rootfs --root=$rootfs -quN --oneshot --nodeps --usepkgonly net-libs/glib-networking || true  # TODO glib-networking attempts to update gio modules and fails :(
armv7a-unknown-linux-gnueabihf-emerge --sysroot=$rootfs --root=$rootfs -quN --usepkgonly @asus-c201

# Add system groups
cat <<EOF >> $rootfs/etc/group
polkitd:x:240:
messagebus:x:238:
EOF

# Add system users https://bugs.gentoo.org/541406
cat <<EOF >> $rootfs/etc/passwd
polkitd:x:108:240:System user; polkitd:/var/lib/polkit-1:/sbin/nologin
messagebus:x:110:238:System user; messagebus:/dev/null:/sbin/nologin
EOF

# Add password information for shadow
cat <<EOF >> $rootfs/etc/shadow
polkitd:*:18393::::::
messagebus:*:18393::::::
EOF


# Add gentoo user
useradd --root $rootfs --create-home gentoo

# Set the root password as `gentoo`.
sed -i 's/root\:\*/root\:\$6\$I9Q9AyTL\$Z76H7wD8mT9JAyrp\/vaYyFwyA5wRVN0tze8pvM\.MqScC7BBm2PU7pLL0h5nSxueqUpYAlZTox4Ag2Dp5vchjJ0/' $rootfs/etc/shadow


# tar it up
tar cpf $workdir/rootfs.tar.xz --numeric-owner --use-compress-program="xz --threads 4" --acls --xattrs -C $rootfs .
