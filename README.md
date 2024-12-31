# Minimal Debian Live System as Unified Kernel Image (UKI)

**DISCLAIMER: If you're looking for a conventional Debian live system, go to [Debian.org](https://www.debian.org/).**
This repository builds a minimal Debian live system packed as a single file, self-contained [Unified Kernel Image (UKI)](https://uapi-group.org/specifications/specs/unified_kernel_image/).
The UKI contains a very large initrd, which comprises the entire root file system (rootfs) instead of only the components required for early boot.
This approach is **experimental** and not guaranteed to work with all UEFI implementations (tested with UEFI 2.40 (American Megatrends 5.11)).

## Features

  * Minimal live system (<200 MB size in default configuration)
    * Suitable as a self-contained recovery system on a 512M EFI system partition (ESP)
  * Pre-configured Unified Kernel Image (UKI) compliant to [Boot Loader Specification](https://uapi-group.org/specifications/specs/boot_loader_specification/)
    * No configuration required (i.e., no need to set root device on kernel cmdline, e.g., `root=UUID=DEAD-BEEF`)
    * Automatic detection with [supported boot loaders](https://wiki.archlinux.org/title/Unified_kernel_image#Booting)
    * Alternatively boots without boot loader when `EFI/BOOT/BOOTX64.EFI`
  * Supports current Debian stable (Bookworm) and unstable (Sid) on x86_64
  * UEFI boot only (legacy BIOS not supported!)
  * Easily customizable ([single shell script](./rootfs_chroot.sh) assembles live system)
  * Boot medium unpluggable after boot (initrd automatically copied into RAM)
  * Experimental [Debian installer](https://github.com/carstenandrich/debian-minimal-installer/)
    (non-interactive install of minimal Debian system in <3 minutes)
  * [Memtest86+](https://memtest.org/) compiled and included in image (can be
    selected at boot time)

## Quick Start Instructions

Clone repository including submodules:

```sh
git clone --recurse-submodules https://github.com/carstenandrich/debian-minimal-live.git
```

Install required dependencies:

```sh
sudo apt-get install \
	apt bubblewrap build-essential cdebootstrap coreutils dosfstools dpkg \
	fdisk mount systemd-ukify util-linux
```

Optional:

  * Modify [`rootfs_chroot.sh`](./rootfs_chroot.sh) to adjust list of installed
    packages.
  * Change included files in [`include.d/`](./include.d/).

Build UKI and write it onto a bootable FAT32 partition (e.g., ESP or USB drive):

```sh
sudo make
# Examples illustrating possible cp invocations. Adjust to your requirements! 
#cp -n uki.efi /boot/efi/EFI/Linux/debian-recovery-uki.efi
#cp -n uki.efi /media/usb_drive/EFI/BOOT/BOOTX64.EFI
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

**Target**  | **Description**
----------- | ---------------
`default`   | `uki.efi`
`clean`     | Delete all build artifacts
`bootstrap` | Bootstrap a minimal Debian system
`rootfs`    | Build full root filesystem (depends on `bootstrap`)
`uki.efi`   | Generate unified kernel image (depends on `rootfs`)


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


## 3. Generate UKI

**TODO**


## 4. Testing

For rapid testing of the UEFI disk image via a virtual machine, you can use
QEMU in combination with OVMF (UEFI firmware for VMs).

First install QEMU and OVMF:

```sh
sudo apt-get install qemu-system-x86 ovmf
```

Then boot the UKI EFI file via QEMU:

```sh
qemu-system-x86_64 -nodefaults -enable-kvm -machine q35 -bios /usr/share/ovmf/OVMF.fd \
	-m 1536 -vga virtio -nic user,hostfwd=tcp:127.0.0.1:2222-:22,model=virtio-net-pci \
	-kernel uki.efi
```

### Testing the Experimental Installer

To test the scripted installer, you can create a drive backed by a sparse file:

```sh
dd if=/dev/null bs=1G seek=8 of=/tmp/sda.bin
qemu-system-x86_64 -nodefaults -enable-kvm -machine q35 -bios /usr/share/ovmf/OVMF.fd \
	-m 2048 -vga virtio -nic user,hostfwd=tcp:127.0.0.1:2222-:22,model=virtio-net-pci \
	-kernel uki.efi \
	-drive file=/tmp/sda.bin,if=virtio,aio=io_uring,index=1,media=disk,format=raw
```

After installation, first power down the VM (`systemctl poweroff`), then run
QEMU without the `-drive uki.efi` argument to boot from the installation disk.


# Known Issues

## Insufficient RAM or misbehaving UEFI

As initially disclaimed, misusing an initrd to contain a whole rootfs is
experimental. The following errors may be indicative of either insufficient
RAM (experiment with `qemu-system-x86_64 -m $MEGS_OF_RAM`) or a misbehaving UEFI
implementation that copies the UKI EFI file only partially:

* `Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)`
* `Kernel panic - not syncing: No working init found.  Try passing init= option to kernel.`
