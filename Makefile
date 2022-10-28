# select Debian suite (supports bullseye, bookwork, and sid)
DEBIAN_SUITE=sid

# default target: build disk image
.PHONY: default
default: image_uefi.bin

# delete all build artifacts
.PHONY: clean
clean:
	rm -rf bootstrap rootfs image_uefi.bin rootfs-overlay.deb MemTest86

# dependency: build rootfs-overlay.deb from source files
rootfs-overlay.deb: rootfs-overlay.deb.d
	dpkg-deb -b rootfs-overlay.deb.d rootfs-overlay.deb

# dependency: extract MemTest86 EFI binaries from memtest86-usb.zip
MemTest86: memtest86-usb.zip
	rm -rf MemTest86/
	./memtest86-usb-extract.sh
	touch -r memtest86-usb.zip MemTest86/

# first step: bootstrap minimal system
# alternative to cdebootstrap if it breaks again: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=928908
#debootstrap --merged-usr --variant=minbase --include=whiptail sid bootstrap http://deb.debian.org/debian
#dpkg --root bootstrap.d --install /usr/share/cdebootstrap/cdebootstrap-helper-rc.d.deb
bootstrap:
	rm -rf bootstrap
	cdebootstrap --flavour=minimal --include=usrmerge,whiptail $(DEBIAN_SUITE) bootstrap http://deb.debian.org/debian
	rm -rf bootstrap/run/*

# second step: build rootfs from bootstrapped system
rootfs: bootstrap rootfs-overlay.deb rootfs.sh rootfs_chroot.sh
	DEBIAN_SUITE=$(DEBIAN_SUITE) ./rootfs.sh

# third step: generate UEFI disk image from rootfs
# optionally depends on MemTest86 if memtest86-usb.zip exists
image_uefi.bin: image_uefi.sh rootfs rootfs-overlay.tar.d $(if $(wildcard ./memtest86-usb.zip), MemTest86)
	./image_uefi.sh
