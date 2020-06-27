
OUT := $(shell pwd)/work
KERNEL_DIR := /usr/armv7a-unknown-linux-gnueabihf/usr/src/linux-5.4.47-gentoo

STAGE3_VERSION := 20200509T210605Z
STAGE3 := stage3-armv7a_hardfp-$(STAGE3_VERSION).tar.xz

bootloader_target := $(OUT)/bootloader.bin
dtb_target := $(OUT)/rk3288-veyron-speedy.dtb
gentoo_img_target := $(OUT)/gentoo.img
itb_target := $(OUT)/gentoo.itb
modules_target := $(OUT)/modules.tar.xz
rootfs_target := $(OUT)/rootfs.tar.xz
stage3_digests_target := $(OUT)/$(STAGE3).DIGESTS.asc
stage3_target := $(OUT)/$(STAGE3)
stage3_verified_target := $(OUT)/stage3-verified
vmlinuz_signed_target := $(OUT)/vmlinuz.signed
zimage_target := $(OUT)/zImage


all: $(gentoo_img_target)

clean:
	rm -rf $(OUT)/*

menuconfig:
	cd $(KERNEL_DIR) && make -j 5 ARCH=arm CROSS_COMPILE=armv7a-unknown-linux-gnueabihf- menuconfig
	cp $(KERNEL_DIR)/.config kernel/config.txt

$(stage3_digests_target):
	cd $(OUT) && wget --timestamping https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/$(STAGE3_VERSION)/$(STAGE3).DIGESTS.asc

$(stage3_target):
	cd $(OUT) && wget --timestamping https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/$(STAGE3_VERSION)/$(STAGE3)

$(stage3_verified_target): $(stage3_target) $(stage3_digests_target)
	bin/verify-stage3.sh $<
	touch $@

$(rootfs_target): $(stage3_target) $(stage3_verified_target)
	bin/make-rootfs.sh $< $(OUT) 

$(bootloader_target):
	dd if=/dev/zero of=$@ bs=512 count=1 conv=sparse

$(modules_target): kernel/config.txt
	KERNEL_DIR=$(KERNEL_DIR) bin/make-kernel.sh $(OUT)

$(zimage_target): $(modules_target)
	cp $(KERNEL_DIR)/arch/arm/boot/zImage $@

$(dtb_target): $(modules_target)
	cp $(KERNEL_DIR)/arch/arm/boot/dts/rk3288-veyron-speedy.dtb $@

$(itb_target): kernel/gentoo.its $(zimage_target) $(dtb_target)
	cp $< $(OUT)/
	cd $(OUT) && mkimage -D '-I dts -O dtb -p 2048' -f gentoo.its $@

$(vmlinuz_signed_target): $(itb_target) $(bootloader_target) kernel/kernel.flags
	futility --debug vbutil_kernel --arch arm --version 1 --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --bootloader $(OUT)/bootloader.bin --config kernel/kernel.flags --vmlinuz $(OUT)/gentoo.itb --pack $@

$(gentoo_img_target): $(vmlinuz_signed_target) $(rootfs_target) $(modules_target)
	bin/make-image.sh $^ $(OUT)


.PHONY: all clean
