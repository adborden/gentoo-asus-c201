# gentoo-asus-c201

https://wiki.gentoo.org/wiki/Creating_bootable_media_for_depthcharge_based_devices


## Boot medium


Create an empty 2GB image.

    $ dd if=/dev/zero conv=sparse of=gentoo.img count=$(( 2 * 1024 * 1024 * 1024 / 512 ))

Format as GPT.

    $ parted gentoo.img mklabel gpt
    $ parted -a optimal gentoo.img unit mib mkpart kernel 1 65
    $ parted -a optimal gentoo.img unit mib mkpart root 65 100%

Set special (GPT?) parameters to identify the kernel partition. Specify the
first partition (`-i 1`) with the kernel partition type guid (`-t kernel`), with
successful flag (`-S 1`), 5 tries (`-T 5`), and priority 15 (`-P 15`). _I think
the successful flag refers to the A/B partition marked as a successful boot e.g.
known good._

    $ cgpt add -i 1 -t kernel -S 1 -T 5 -P 15 gentoo.img

Add a loopback device.

    $ sudo losetup -f gentoo.img -P --show

_Note the loop device (e.g. loop0), yours may be different and should be used
for the following steps._

Create an ext4 filesystem.

    $ sudo mkfs.ext4 /dev/loop0p2

Mount the ext4 filesystem.

    $ sudo mount /dev/loop0p2 /mnt/disk

Grab an arm7a hard float stage3 tarball.

    $ wget https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/20200509T210605Z/stage3-armv7a_hardfp-20200509T210605Z.tar.xz
    $ wget https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/current-stage3-armv7a_hardfp/stage3-armv7a_hardfp-20200509T210605Z.tar.xz.DIGESTS.asc

    $ wget --timestamping --span-hosts --no-clobber --no-directories --recursive --no-parent --accept 'stage3-armv7a_hardfp-*.tar.xz.DIGESTS.asc' --accept 'stage3-armv7a_hardfp-*.tar.xz' https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/current-stage3-armv7a_hardfp/

Extract the stage3 tarball.

    $ sudo tar xvpf stage3-armv7a_hardfp-20200509T210605Z.tar.xz --numeric-owner --acls --xattrs -C /mnt/disk 

Configure portage for arm.

    $ sudo sh -c 'echo ACCEPT_KEYWORDS="~arm" >> /mnt/disk/etc/portage/make.conf'
    $ sudo sh -c 'echo MAKEOPTS="-j4" >> /mnt/disk/etc/portage/make.conf'

Set the root password as `gentoo`.

    $ sudo sed -i 's/root\:\*/root\:\$6\$I9Q9AyTL\$Z76H7wD8mT9JAyrp\/vaYyFwyA5wRVN0tze8pvM\.MqScC7BBm2PU7pLL0h5nSxueqUpYAlZTox4Ag2Dp5vchjJ0/' /mnt/disk/etc/shadow

Unmount the root filesystem.

    $ sudo umount /mnt/disk


## Kernel

Create a cross-toolchain with crossdev.

    $ sudo crossdev --stable  --ov-output /usr/local/portage --target arm-linux-gnueabihf
    $ sudo crossdev --stable  --ov-output /usr/local/portage --target arm-linux-eabi

Build the kernel.

    $ cd /usr/src/linux
    $ sudo ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j5 zImage dtbs

Copy kernel files to working directory.

    $ cp /usr/src/linux/arch/arm/boot/zImage kernel/
    $ cp /usr/src/linux/arch/arm/boot/dts/rk3288-veyron-speedy.dtb kernel/

Generate U-Boot Flattened Image Tree.

    $ mkimage -D '-I dts -O dtb -p 2048' -f kernel/gentoo.its kernel/gentoo.itb

Create an empty bootloader.

    $ dd if=/dev/zero of=bootloader.bin bs=512 count=1

Sign and pack the kernel.

    $ futility --debug vbutil_kernel --arch arm --version 1 --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --bootloader bootloader.bin --config kernel/kernel.flags --vmlinuz kernel/gentoo.itb --pack kernel/vmlinuz.signed

Write the signed kernel to the kernel partition.

    $ sudo dd if=kernel/vmlinuz.signed of=/dev/loop0p1

Detach the loop device.

    $ sudo losetup -d /dev/loop0

Write the image to another medium for booting.

    $ sudo dd if=gentoo.img of= ...


## References

- [Devsus](https://github.com/dimkr/devsus)
