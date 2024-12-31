# select Debian suite (supports bookwork and sid)
DEBIAN_SUITE=sid

# default target: build disk image
.PHONY: default
default: uki.efi

# delete all build artifacts
.PHONY: clean
clean:
	rm -rf bootstrap rootfs initrd.zst uki.efi
	make -C memtest86plus/build64 clean

# dependency: build rootfs-overlay.deb from source files
linux-initramfs-tool-noop.deb: linux-initramfs-tool-noop.deb.d
	dpkg-deb -b $@.d $@

# dependency: build memtest86+ x86_64 efi binary
memtest86plus/build64/memtest.efi: memtest86plus
	make -C memtest86plus/build64 memtest.efi

# first step: bootstrap minimal system
# alternative to cdebootstrap if it breaks again: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=928908
#debootstrap --merged-usr --variant=minbase --include=whiptail sid bootstrap http://deb.debian.org/debian
#dpkg --root bootstrap.d --install /usr/share/cdebootstrap/cdebootstrap-helper-rc.d.deb
bootstrap:
	rm -rf bootstrap
	cdebootstrap --flavour=minimal --include=usrmerge,usr-is-merged,whiptail $(DEBIAN_SUITE) bootstrap http://deb.debian.org/debian
	rm -rf bootstrap/run/*
	# remove usrmerge and its dependencies after /usr has been merged
ifeq ($(DEBIAN_SUITE),bookworm)
	dpkg --root=bootstrap --purge usrmerge perl perl-modules-5.36 libfile-find-rule-perl libnumber-compare-perl libperl5.36 libtext-glob-perl
else
	# FIXME: will break on perl major version upgrade
	dpkg --root=bootstrap --purge usrmerge perl perl-modules-5.40 libfile-find-rule-perl libnumber-compare-perl libperl5.40 libtext-glob-perl
endif

# second step: build rootfs from bootstrapped system
rootfs: bootstrap rootfs.sh rootfs_chroot.sh linux-initramfs-tool-noop.deb
	DEBIAN_SUITE=$(DEBIAN_SUITE) ./rootfs.sh

# third step: build unified kernel image (UKI) from roofs/ and include.d/
uki.efi: rootfs include.d uki.sh
	./uki.sh
