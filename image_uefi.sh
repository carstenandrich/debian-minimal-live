#!/bin/sh -eux

# register function for reliable cleanup when script exits (both regular exit
# and premature termination due to errors, signals, etc.)
cleanup()
{
	# unmount ESP
	if mountpoint -q image_uefi.mnt ; then
		umount image_uefi.mnt
	fi

	# detach image loop device
	if [ -b "${DEV:-}" ] ; then
		losetup -d ${DEV}
	fi

	# delete mountpoint directory
	if [ -d image_uefi.mnt ] ; then
		rmdir image_uefi.mnt
	fi
}
trap "cleanup" EXIT INT

# delete old artifacts
rm -f rootfs.squashfs image_uefi.bin

# cleanup rootfs (reduce image size)
rm -rf --one-file-system rootfs/var/cache/apt/*
rm -rf --one-file-system rootfs/var/lib/apt/lists/*
rm -rf --one-file-system rootfs/var/log/*

# create compressed rootfs archive
mksquashfs rootfs rootfs.squashfs -comp zstd -e boot -e initrd.img -e initrd.img.old -e vmlinuz -e vmlinuz.old
SQUASHFS_SIZE=$(stat -c %s rootfs.squashfs)

# create sparse file for disk image that fits squashfs + 64 MiB
dd if=/dev/null of=image_uefi.bin bs=1M seek=$(($SQUASHFS_SIZE / 1024 / 1024 + 64))
# create MBR partition table with single EFI system parititon (ESP)
sfdisk image_uefi.bin <<-EOF
	label: mbr
	2048 + U *
EOF

# mount disk image as loop device and format with FAT32
DEV=$(losetup --find --show --partscan image_uefi.bin)
mkfs.vfat -F32 ${DEV}p1
UUID=$(blkid -s UUID -o value ${DEV}p1)

# mount FAT32 partition
mkdir -p image_uefi.mnt
mount ${DEV}p1 image_uefi.mnt

# get kernel version
KERNEL=$(readlink rootfs/vmlinuz)
KERNEL_VERSION=${KERNEL#boot/vmlinuz-}

# create systemd-boot configuration
mkdir -p image_uefi.mnt/EFI/BOOT/ image_uefi.mnt/loader/entries/ image_uefi.mnt/EFI/memtest86+/
cp rootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi image_uefi.mnt/EFI/BOOT/BOOTX64.EFI
cp memtest86plus/build64/memtest.efi image_uefi.mnt/EFI/memtest86+/memtest86+.efi
cat > image_uefi.mnt/loader/loader.conf <<-EOF
	default  debian.conf
	timeout  3
EOF
cat > image_uefi.mnt/loader/entries/debian.conf <<-EOF
	title   Debian Linux $KERNEL_VERSION (copy to ramdisk, boot medium unpluggable)
	linux   /vmlinuz-$KERNEL_VERSION
	initrd  /initrd.img-$KERNEL_VERSION
	options root=UUID=$UUID ro rootfs-overlay=2
EOF
cat > image_uefi.mnt/loader/entries/debian-nocopy.conf <<-EOF
	title   Debian Linux $KERNEL_VERSION (load from boot medium)
	linux   /vmlinuz-$KERNEL_VERSION
	initrd  /initrd.img-$KERNEL_VERSION
	options root=UUID=$UUID ro rootfs-overlay=1
EOF
cat > image_uefi.mnt/loader/entries/memtest.conf <<-EOF
	title   Memtest86+
	efi     /EFI/memtest86+/memtest86+.efi
EOF

# copy kernel, initramfs, and squashfs on boot partition
cp rootfs/boot/initrd.img-$KERNEL_VERSION rootfs/boot/vmlinuz-$KERNEL_VERSION image_uefi.mnt/
cp --no-target-directory rootfs.squashfs image_uefi.mnt/rootfs.squashfs
rm rootfs.squashfs

# create overlay tarball with appropriate file attributes
tar -cf rootfs-overlay.tar --owner=root:0    --group=root:0    -C rootfs-overlay.tar.d/ etc/ root/
tar -rf rootfs-overlay.tar --owner=user:1000 --group=user:1000 -C rootfs-overlay.tar.d/ home/user/
gzip -c rootfs-overlay.tar > image_uefi.mnt/rootfs-overlay.tar.gz
rm rootfs-overlay.tar

# cleanup() will be called by EXIT trap
