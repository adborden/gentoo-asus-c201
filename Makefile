
OUT := $(shell pwd)/work
KERNEL_DIR := /usr/armv7a-unknown-linux-gnueabihf/usr/src/linux-5.4.47-gentoo

STAGE3_VERSION := 20200509T210605Z
STAGE3 := stage3-armv7a_hardfp-$(STAGE3_VERSION).tar.xz


all: $(OUT)/gentoo.img

clean:
	rm -rf $(OUT)/*

menuconfig:
	cd $(KERNEL_DIR) && make -j 5 ARCH=arm CROSS_COMPILE=armv7a-unknown-linux-gnueabihf- menuconfig
	cp $(KERNEL_DIR)/.config kernel/config.txt

$(OUT)/$(STAGE3).DIGESTS.asc:
	cd $(OUT) && wget --timestamping https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/$(STAGE3_VERSION)/$(STAGE3).DIGESTS.asc

$(OUT)/$(STAGE3):
	cd $(OUT) && wget --timestamping https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/$(STAGE3_VERSION)/$(STAGE3)

$(OUT)/stage3-verified: $(OUT)/$(STAGE3) $(OUT)/$(STAGE3).DIGESTS.asc
	bin/verify-stage3.sh $<
	touch $@

$(OUT)/rootfs.tar.xz: $(OUT)/$(STAGE3) $(OUT)/stage3-verified
	bin/make-rootfs.sh $< $(OUT) 

$(OUT)/bootloader.bin:
	dd if=/dev/zero of=$@ bs=512 count=1 conv=sparse

$(OUT)/modules.tar.xz: kernel/config.txt
	KERNEL_DIR=$(KERNEL_DIR) bin/make-kernel.sh $(OUT)

$(OUT)/zImage: $(OUT)/modules.tar.xz
	cp $(KERNEL_DIR)/arch/arm/boot/zImage $@

$(OUT)/rk3288-veyron-speedy.dtb: $(OUT)/modules.tar.xz
	cp $(KERNEL_DIR)/arch/arm/boot/dts/rk3288-veyron-speedy.dtb $@

$(OUT)/gentoo.itb: kernel/gentoo.its $(OUT)/zImage $(OUT)/rk3288-veyron-speedy.dtb
	cp kernel/gentoo.its $(OUT)/
	cd $(OUT) && mkimage -D '-I dts -O dtb -p 2048' -f gentoo.its $@

$(OUT)/vmlinuz.signed: $(OUT)/gentoo.itb kernel/kernel.flags $(OUT)/bootloader.bin
	futility --debug vbutil_kernel --arch arm --version 1 --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --bootloader $(OUT)/bootloader.bin --config kernel/kernel.flags --vmlinuz $(OUT)/gentoo.itb --pack $@

$(OUT)/gentoo.img: $(OUT)/vmlinuz.signed $(OUT)/rootfs.tar.xz $(OUT)/modules.tar.xz
	bin/make-image.sh $^ $(OUT)


.PHONY: all clean
