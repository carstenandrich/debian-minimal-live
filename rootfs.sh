#!/bin/sh -eux

# TODO: derive this from bootstrapped system
DEBIAN_SUITE="sid"

unmount()
{
	# unmount bind mounts created by build process
	for mount in "rootfs/var/cache/apt/archives" "rootfs/dev/pts" "rootfs/dev" "rootfs/proc" "rootfs/run" "rootfs/sys" "rootfs/tmp" ; do
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
mount -o bind,ro /dev/pts rootfs/dev/pts
mount -o bind,ro /proc rootfs/proc
mount -o bind,ro /sys rootfs/sys
mount -o bind,rw /var/cache/apt/archives rootfs/var/cache/apt/archives
# mount empty tmpfs on /run and /tmp
mount -t tmpfs -o rw,nosuid,nodev,noexec,mode=755 tmpfs rootfs/run
mount -t tmpfs -o rw,mode=1777 tmpfs rootfs/tmp

# installing systemd-resolved inside chroot will replace /etc/resolv.conf with
# symlink to /run/systemd/resolve/stub-resolv.conf. with systemd-resolved not
# running inside the chroot, this breaks DNS resolution.
# Workaround: provide suitable *resolv.conf files in /run/systemd/resolve/
mkdir -p rootfs/run/systemd/resolve/
cat /etc/resolv.conf > rootfs/run/systemd/resolve/resolv.conf
cat /etc/resolv.conf > rootfs/run/systemd/resolve/stub-resolv.conf

# install rootfs-overlay package (handles overlayfs setup via initramfs scripts)
dpkg --root=rootfs --install rootfs-overlay.deb

# call chroot build script with clean environment (to prevent locale issues, etc.)
cp rootfs_chroot.sh rootfs/
chmod +x rootfs/rootfs_chroot.sh
env --ignore-environment \
		DEBIAN_SUITE="$DEBIAN_SUITE" \
		PATH="/usr/sbin:/usr/bin:/sbin:/bin" \
		TERM="$TERM" \
		USER="$USER" \
	chroot rootfs /rootfs_chroot.sh
rm -rf rootfs/rootfs_chroot.sh

# remove cdebootstrap helper that disables service invocation
dpkg --root=rootfs --purge cdebootstrap-helper-rc.d

# unmount() will be called by EXIT trap
