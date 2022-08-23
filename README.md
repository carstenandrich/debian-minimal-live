# Minimalistic Debian Live System Builder and Installer

**If you're looking for a Debian live system and/or installer, go to [Debian.org](https://www.debian.org/).**
This repository addresses _advanced_ Debian users with extensive knowledge of
partitioning, filesystems, bootstrapping, system installation, essential Debian
packages, APT, DPKG, fdisk, systemd, UEFI, etc.
**Use of anything in this repository can cause irreversible data loss without prior warning!**
**ABSOLUTELY NO WARRANTY AND/OR LIABILITY OF ANY KIND!**

Development rationale is simplicity ([KISS](https://en.wikipedia.org/wiki/KISS_principle)),
minimalism (no bloat) and the use of cutting-edge technology.
Both live and installed systems use systemd for everything (booting, network
configuration, logging) and traditional alternatives (syslogd, cron, etc.) are
not installed by default.


## Live System Builder

A collection of shell scripts to build an easily customizable Debian live image
(both stable and unstable are supported) for deployment on (read-only)
USB-/SD-storage.
The live system relies on a compressed SquashFS read-only root file system
combined with an OverlayFS for volatile run-time write access.
The OverlayFS is initialized from a compressed .tar file during early boot (in
initramfs), enabling retroactively customized replication of a single live image
for deployment on multiple systems that require different configurations.

Systemd-boot is used as boot loader, so only UEFI is supported.
When manually downloaded, [MemTest86](https://www.memtest86.com/) will be
included in the live image.

See **Usage** for details on the process of building the live image.


## Scripted Installer

The live image contains an [customizable, scripted installer](rootfs-overlay.tar.d/root/debian-quick-install/)
based on the live image builder.
Feautures:

  * Non-interactive network installation of a minimal Debian system within a few
    minutes (<3 depending on the system performance and internet connection)
  * Btrfs as root filesystem configured for snapshots
  * Systemd-boot as minimalistic boot loader (usable since systemd package
    version 251.2-3, which split systemd-boot off into separate package)

For details see the [installer README.md](rootfs-overlay.tar.d/root/debian-quick-install/README.md),
which is work-in-progress.



# Installation

No installation required. Simply clone this repository.
The following Debian packages are required by the scripts:

```sh
apt-get install \
	apt coreutils debootstrap dpkg fakeroot mount util-linux \
	dosfstools fdisk squashfs-tools
```



# Usage

**WARNING: READ AND UNDERSTAND THE SOURCE CODE BEFORE RUNNING ANYTHING!**

The build process is implemented by multiple, compartmentalized shell scripts.
A [Makefile](./Makefile) is used to orchestrate the build including dependency
tracking for partial rebuilds after modifying build scripts.

The following targets are supported:

**Target**       | **Description**
---------------- | ---------------
`default`        | `image_uefi.bin`
`clean`          | Delete all build artifacts
`bootstrap`      | Bootstrap a minimal Debian system
`rootfs`         | Build full root filesystem (depends on `bootstrap`)
`image_uefi.bin` | Generate disk image for UEFI boot (depends on `rootfs`)

Most steps of the build process require root permissions.


## 1. Bootstrap

First, a minimal Debian system is bootstrapped via (c)debootstrap into
the directory `bootstrap/`. As bootstrapping is slower than regular package
installation and typically implies downloading the required packages from Debian
mirrors, the bootstrapping result is cached to accelerate subsequent rebuilds.
It shouldn't be necessary to modify the bootstrapping process to customize the
live system.


## 2. Build Root Filesystem

To build the full root filesystem, [`rootfs.sh`](./rootfs.sh) will first copy
the bootstrapped system, minimally configure it, and read-only bind mount
`/dev`, `/proc`, and `/sys` into it. The host system's `/var/cache/apt/archives`
is writably bind mounted to enable caching of Debian packages downloaded during
the build process.

The actual installation process of the full Debian system is handled by
[`rootfs_chroot.sh`](./rootfs_chroot.sh). It is called from `rootfs.sh` via
chroot into the `rootfs/` directory. Modify `rootfs_chroot.sh` to customize the
list of installed packages and configure the system to suit your needs.


## 3. Generate UEFI Disk Image

[`image_uefi.sh`](./image_uefi.sh) generates a bootable, MBR partitioned disk
image file (`image_uefi.bin`).
The image contains a FAT32 UEFI system partition (ESP) with
([systemd-boot](https://www.freedesktop.org/software/systemd/man/systemd-boot.html)
as UEFI boot loader.
**Legacy BIOS boot is not supported!**

The previously built root filesystem in `rootfs/` is packed into a SquashFS
image (`rootfs.squashfs`) and the initial contents of the OverlayFS are packed
from the directory `rootfs-overlay.tar.d/` into `rootfs-overlay.tar.gz`. Both
files are copied onto the ESP. `rootfs-overlay.tar.gz` can be easily replaced
retroactively to change the live system without re-packing the SquashFS.
As the overlay is initialized during early boot (from initramfs), this will also
affect the regular boot process performed by systemd.

If you want [MemTest86](https://www.memtest86.com/) included in the disk image,
download `memtest86-usb.zip` and run
[`memtest86-usb-extract.sh`](./memtest86-usb-extract.sh) to extract the EFI
binary before running `image_uefi.sh` (either manually or implicitly via make).

Use `dd` to dump the disk image on any bootable storage medium (e.g., USB-stick
or SD-card):

```sh
dd if=image_uefi.bin of=/dev/sdX bs=4K status=progress
```

By default the disk image file is only marginally larger than the SquashFS.
You can grow the partition after dumping it on a storage medium via `fdisk` and
[`fatresize`](https://manpages.debian.org/stable/fatresize/fatresize.1.en.html).


## 4. Testing

For rapid testing of the UEFI disk image via a virtual machine, you can use
QEMU in combination with OVMF (UEFI firmware for VMs).

First install QEMU and OVMF:

```sh
apt-get install qemu-system-x86 ovmf
```

Then boot the UEFI disk image via QEMU.
Works without root permissions if the image is writable:

```sh
sudo chmod 666 image_uefi.bin
qemu-system-x86_64 -enable-kvm -machine q35 -bios /usr/share/ovmf/OVMF.fd -m 1024 -vga std -drive file=image_uefi.bin,index=0,media=disk,format=raw
```

To test the scripted installer, you can create an additional disk backed by a
sparse file:

```sh
sudo chmod 666 image_uefi.bin
dd if=/dev/null bs=1G seek=8 of=/tmp/sdb.bin
qemu-system-x86_64 -enable-kvm -machine q35 -bios /usr/share/ovmf/OVMF.fd -m 1024 -vga std -drive file=image_uefi.bin,index=0,media=disk,format=raw -drive file=/tmp/sdb.bin,index=1,media=disk,format=raw
```

After installation, simply reboot the VM and it should boot from the install
disk and not the live image.
