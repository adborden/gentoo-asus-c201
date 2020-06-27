# Using crossdev

Not all packages can be cross compiled. In some cases we use a qemu-chroot to
compile "broken" packages under qemu.

https://wiki.gentoo.org/wiki/Cross_build_environment


## Setup toolchain

Use crossdev to build the toolchain.

    $ crossdev ...

Cross-compile as many system dependencies as possible.

    $ armv7a-unknown-linux-gnueabihf-emerge -avuDN --keep-going @system

If there are failures, cross-compile as many build dependencies as possible for
the qemu chroot. These will be installed when running emerge in the chroot, but
it's faster to cross-compile.

    $ armv7a-unknown-linux-gnueabihf-emerge -avuDN --keep-going --root-deps @system  # This doesn't actually work :/
    $ CROSS_CMD=emerge armv7a-unknown-linux-gnueabihf-emerge -avuDN --keep-going --root-deps @system  # This doesn't actually work :/

Or you can determine build-time dependencies in the qemu-chroot and manually
install them with cross-emerge.

Once you have the base system compiled, you can start adding your own packages.
I prefer to add packages to a set so I can reference this when installing to my
target root.

    $ mkdir /usr/armv7a-unknown-linux-gnueabihf/etc/portage/sets
    $ cp asus-c201 /usr/armv7a-unknown-linux-gnueabihf/etc/portage/sets/
    $ armv7a-unknown-linux-gnueabihf-emerge -avuDN --keep-going @asus-c201

In practice, you encounter a variety of build failures. In most cases, it's
easiest to compile the breaking package in the qemu-chroot manually, then
continue building with cross-emerge.


## Configure Qemu for chroot

https://wiki.gentoo.org/wiki/Embedded_Handbook/General/Compiling_with_qemu_user_chroot

Install binfmt (using systemd)

    /etc/binfmt.d/qemu-arm.conf

Activate the chroot.

    $ sudo ./chroot

This script overrides a few portage variables, since the make.conf assumes
cross-emerge from outside the sysroot, these variables are incorrect within the
chroot.

Once in the chroot, run a few initial setup commands.

    $ localegen

Each time you enter the chroot, run these commands.

    $ env-update
    $ source /etc/profile
    $ export PS1="(chroot) $PS1"

Any emerge commands in the chroot should be run with the updated ROOT (make.conf
is configured for cross-emerge).

Qemu doesn't support pid-sandbox or netowrk-sandbox in FEATURES.


## misc

Not sure why most Perl modules show up in errors e.g. XML::Parser not found. The
module _is_ installed, but something about the install is broken. Usually
re-emerging resolves the issue (even from the x86_64 host). Maybe with the qemu
binfmt setup, some step works when it didn't before.

elibtoolize https://bugs.gentoo.org/572038


## Installing to root

Create the production root.

    $ sudo mkdir /mnt/asus-c201-gentoo

Install the world from packages.

    $ sudo armv7a-unknown-linux-gnueabihf-emerge --usepkg --sysroot=/mnt/asus-c201-gentoo/ --root=/mnt/asus-c201-gentoo/ -auv --binpkg-respect-use=n @asus-c201

Rebuild the shared library cache.

    $ sudo ldconfig -r /mnt/asus-c201-gentoo
