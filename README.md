# Minimalistic Debian Live System Image Builder

**If you're looking for a regular Debian live system, go to [Debian.org](https://www.debian.org/).**
This repository addresses _advanced_ Debian users in need of a minimalistic
and/or easily customizable live system image builder.

## Features

  * Builds minimalistic read-only live image (<300 MB image size without GUI)
  * Supports current Debian stable (Bookworm) and unstable (Sid) on x86_64
  * UEFI boot only (legacy BIOS not supported)
  * Easily customizable (single shell script assembles live system)
  * Boot medium unpluggable after boot (image copied into RAM)
  * Retroactive configuration without rebuilding image (OverlayFS populated
    from .tar file during early boot)
  * Experimental [installer](https://github.com/carstenandrich/debian-minimal-installer/)
    (non-interactive install of minimal Debian system in <3 minutes)
  * [Memtest86+](https://memtest.org/) compiled and included in image (can be
    selected at boot time)

## Quick Start Instructions

Clone repository including submodules:

```sh
git clone --recurse-submodules https://github.com/carstenandrich/debian-minimal-live.git
cd debian-minimal-live
```

Install required dependencies:

```sh
sudo apt-get install \
	apt bubblewrap build-essential cdebootstrap coreutils dosfstools dpkg \
	fdisk mount squashfs-tools util-linux
```

Optional:

  * Modify [`rootfs_chroot.sh`](./rootfs_chroot.sh) to adjust list of installed
    packages.
  * Change included files in [`rootfs-overlay.tar.d/`](./rootfs-overlay.tar.d/).

Build image and write it onto bootable storage medium (e.g., USB drive):

```sh
sudo make
sudo dd if=image_uefi.bin of=/dev/sdX bs=4K status=progress
```

Note that running the build process on a tmpfs is likely to significantly
accelerate the build process compared to a disk-backed filesystem.


# Usage and Implementation Details

Development rationale is simplicity ([KISS](https://en.wikipedia.org/wiki/KISS_principle)),
minimalism (no bloat) and the use of cutting-edge technology.
Both live and installed systems use systemd for everything (booting, network
configuration, logging) and traditional alternatives (syslogd, cron, etc.) are
not installed by default.

The live system relies on a compressed SquashFS read-only root file system
combined with an OverlayFS for volatile run-time write access.
The OverlayFS is initialized from a compressed .tar file during early boot (in
initramfs), enabling retroactively customized replication of a single live image
for deployment on multiple systems that require different configurations.
Systemd-boot is used as boot loader, so only UEFI is supported.

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
[systemd-boot](https://www.freedesktop.org/software/systemd/man/systemd-boot.html)
as UEFI boot loader.
**Legacy BIOS boot is not supported!**

The previously built root filesystem in `rootfs/` is packed into a SquashFS
image (`rootfs.squashfs`) and the initial contents of the OverlayFS are packed
from the directory `rootfs-overlay.tar.d/` into `rootfs-overlay.tar.gz`. Both
files are copied onto the ESP. `rootfs-overlay.tar.gz` can be easily replaced
retroactively to change the live system without re-packing the SquashFS.
As the overlay is initialized during early boot (from initramfs), this will also
affect the regular boot process performed by systemd.

Use `dd` to dump the disk image on any bootable storage medium (e.g., USB-stick
or SD-card):

```sh
sudo dd if=image_uefi.bin of=/dev/sdX bs=4K status=progress
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
qemu-system-x86_64 -bios /usr/share/ovmf/OVMF.fd\
	-m 1G -machine q35,accel=kvm -cpu host -smp 2 \
	-vga virtio -device qemu-xhci -device usb-tablet -device usb-kbd \
	-nic user,hostfwd=tcp:127.0.0.1:2222-:22,model=virtio-net-pci \
	-drive file=image_uefi.bin,aio=io_uring,cache=none,index=0,media=disk,format=raw,discard=unmap
```

To test the scripted installer, you can create an additional disk backed by a
sparse file:

```sh
sudo chmod 666 image_uefi.bin
dd if=/dev/null bs=1G seek=8 of=/tmp/sdb.bin
qemu-system-x86_64 -bios /usr/share/ovmf/OVMF.fd \
	-m 1G -machine q35,accel=kvm -cpu host -smp 2 \
	-vga virtio -device qemu-xhci -device usb-tablet -device usb-kbd \
	-nic user,hostfwd=tcp:127.0.0.1:2222-:22,model=virtio-net-pci \
	-drive file=image_uefi.bin,aio=io_uring,cache=none,index=0,media=disk,format=raw,discard=unmap \
	-drive file=/tmp/sdb.bin,if=virtio,cache=none,aio=io_uring,index=1,media=disk,format=raw,discard=unmap
```

After installation, simply reboot the VM and it should boot from the install
disk and not the live image. If not, remove the `-drive file=image_uefi.bin`
parameter to enforce booting from the installation disk. This step is required
if QEMU/OVMF do not retain NVRAM contents between boots.
