#!/bin/sh -eux

# create clean rootfs from bootstrap
rm -rf --one-file-system rootfs
cp -a --reflink=auto bootstrap rootfs

# configure apt sources
echo "deb http://deb.debian.org/debian $DEBIAN_SUITE main contrib non-free" > rootfs/etc/apt/sources.list
if [ $DEBIAN_SUITE != "sid" ] ; then
	echo "deb http://security.debian.org/debian-security $DEBIAN_SUITE-security main contrib non-free" >> rootfs/etc/apt/sources.list
	echo "deb http://deb.debian.org/debian $DEBIAN_SUITE-updates main contrib non-free" >> rootfs/etc/apt/sources.list
	echo "deb http://deb.debian.org/debian $DEBIAN_SUITE-backports main contrib non-free" >> rootfs/etc/apt/sources.list
fi

# configure hostname
echo "live" > rootfs/etc/hostname
cat > rootfs/etc/hosts <<-EOF
	127.0.0.1 localhost
	127.0.1.1 live
EOF

# update resolv.conf (may have changed since bootstrapping)
cat /etc/resolv.conf > rootfs/etc/resolv.conf

# install rootfs-overlay package (overlayfs setup via initramfs scripts)
dpkg --root=rootfs --install rootfs-overlay.deb

# call chroot build script via env and bubblewrap:
#   * clears environment variables (prevents locale issues)
#   * binds /var/cache/apt/archives into chroot to cache downloaded .deb files
#   * partially isolates host system from build process (via minimally
#     populated /dev and /proc mounts)
#   * cleans up reliably (unmount everything and kill any remaining processes)
# TODO: use bwrap --clearenv when bubblewrap 0.5 is widely available
env --ignore-environment bwrap \
	--setenv DEBIAN_SUITE "$DEBIAN_SUITE" \
	--setenv HOME "$HOME" \
	--setenv PATH "/usr/sbin:/usr/bin:/sbin:/bin" \
	--setenv TERM "$TERM" \
	--setenv USER "$USER" \
	\
	--bind rootfs/ / \
	--dev /dev \
	--proc /proc \
	--tmpfs /run \
	--ro-bind /sys /sys \
	--tmpfs /tmp \
	--file 3 /tmp/rootfs_chroot.sh \
	--bind /var/cache/apt/archives /var/cache/apt/archives \
	\
	--unshare-pid --die-with-parent \
	/bin/sh -eux /tmp/rootfs_chroot.sh 3<rootfs_chroot.sh

# remove cdebootstrap helper that inhibits service invocation
dpkg --root=rootfs --purge cdebootstrap-helper-rc.d
