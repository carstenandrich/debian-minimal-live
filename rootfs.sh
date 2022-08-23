#!/bin/sh -eux

unmount()
{
	# unmount bind mounts created by build process
	for mount in "rootfs/var/cache/apt/archives" "rootfs/dev" "rootfs/proc" "rootfs/sys" ; do
		if mountpoint -q "$mount" ; then
			umount "$mount"
		fi
	done
}

# call and trap register unmount()
unmount
trap "unmount" EXIT INT

# create clean rootfs from bootstrap.d
rm -rf --one-file-system rootfs
cp -a --reflink=auto bootstrap rootfs

# add apt mirror
echo "deb http://deb.debian.org/debian sid main contrib non-free" > rootfs/etc/apt/sources.list

# configure hostname
echo "live" > rootfs/etc/hostname
cat > rootfs/etc/hosts <<-EOF
	127.0.0.1 localhost
	127.0.1.1 live
EOF

# bind mount current system into rootfs (read-only where possible)
mount -o bind,ro /dev rootfs/dev
mount -o bind,ro /proc rootfs/proc
mount -o bind,ro /sys rootfs/sys
mount --bind /var/cache/apt/archives rootfs/var/cache/apt/archives

# install rootfs-overlay package (handles overlayfs setup via initramfs scripts)
dpkg --root=rootfs --install rootfs-overlay.deb

# call chroot build script with clean environment (to prevent locale issues, etc.)
cp rootfs_chroot.sh rootfs/
chmod +x rootfs/rootfs_chroot.sh
env --ignore-environment PATH="/usr/sbin:/usr/bin:/sbin:/bin" TERM="$TERM" USER="$USER" chroot rootfs /rootfs_chroot.sh
rm -rf rootfs/rootfs_chroot.sh

# remove cdebootstrap helper that disables service invocation
dpkg --root=rootfs --purge cdebootstrap-helper-rc.d

# unmount() will be called by EXIT trap
