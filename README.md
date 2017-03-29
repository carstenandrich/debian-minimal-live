Debian Live System Builder
==========================

This collection of scripts is used to build a minimal Debian System for Live
deployment on (read-only) USB-/SD-storage. It relies on a compressed SquashFS 
read-only root file system combined with an OverlayFS (requires Linux 3.18+)
for volatile run-time write access.

The present configuration relies heavily on recent systemd features (it uses
Debian Sid due to its contemporary systemd and kernel versions) and disables
legacy features like cron and syslog, using systemd and journald instead.

This system must be considered experimental!

!!! READ AND UNDERSTAND THE SOURCE CODE BEFORE USING IT !!!


Prerequisites (debian package names)
------------------------------------

	apt-get install \
		apt cdebootstrap coreutils dpkg mount util-linux \
		dosfstools parted squashfs-tools syslinux \
		qemu-system-x86


Build instructions
------------------

### 1.) # ./bootstrap

Runs cdebootstrap to bootstrap a Debian system. To speed up a repetitive build
process, the result is cached in bootstrap.d.

### 2.) # ./build

Copies and customizes the bootstrapped system (does not touch bootstrap.d) in
directory build.d. Software installation is conducted via chroot (see file
build.chroot). It bind mounts your /var/cache/apt/archives to cache downloaded
packages. If the build fails the bind must be unmounted manually.
The contents of build.include.pre.d will be copied into build.d before
chrooting, the contents of build.include.post.d afterwards.

### 3a.) # ./image.mbr

Builds an MBR partitioned disk image (image.mbr.bin) which can be dumped on any
bootable storage medium, using a partition for the compressed SquashFS image
and a FAT32 partition for bootloader (syslinux) and offline configuration.
The configuration will be initially populated from the directory
image.config.default.d and copied into the root file system during early boot
(initramfs), allowing to configure the boot process without re-building the
SquashFS.

### 3b.) # ./image.qemu

Builds only the SqushFS image (image.squashfs) and runs qemu on it.
Mainly designed for quick tests of OS and/or initramfs.
