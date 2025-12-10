#!/bin/sh -eux

# create clean rootfs from bootstrap
rm -rf --one-file-system rootfs
cp -a --reflink=auto bootstrap rootfs

# configure apt sources
rm -f rootfs/etc/apt/sources.list
if [ "$DEBIAN_SUITE" = "sid" ] ; then
	cat >rootfs/etc/apt/sources.list.d/debian.sources <<-EOF
		Types: deb
		URIs: http://deb.debian.org/debian/
		Suites: sid
		Components: main contrib non-free non-free-firmware
		Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
	EOF
else
	cat >rootfs/etc/apt/sources.list.d/debian.sources <<-EOF
		Types: deb
		URIs: http://deb.debian.org/debian/
		Suites: ${DEBIAN_SUITE} ${DEBIAN_SUITE}-updates ${DEBIAN_SUITE}-backports
		Components: main contrib non-free non-free-firmware
		Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

		Types: deb
		URIs: http://security.debian.org/debian-security/
		Suites: ${DEBIAN_SUITE}-security
		Components: main contrib non-free non-free-firmware
		Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
	EOF
fi

# configure hostname
echo "live" >rootfs/etc/hostname
cat >rootfs/etc/hosts <<-EOF
	127.0.0.1 localhost
	127.0.1.1 live
EOF

# update resolv.conf (may have changed since bootstrapping)
cat /etc/resolv.conf >rootfs/etc/resolv.conf

# install rootfs-overlay package (overlayfs setup via initramfs scripts)
dpkg --root=rootfs --install rootfs-overlay.deb

# call chroot build script via env and bubblewrap:
#   * clears environment variables (prevents locale issues)
#   * binds /var/cache/apt/archives into chroot to cache downloaded .deb files
#   * partially isolates host system from build process (via minimally
#     populated /dev and /proc mounts)
#   * cleans up reliably (unmount everything and kill any remaining processes)
bwrap --clearenv \
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
	--perms 1777 --tmpfs /tmp \
	--file 3 /tmp/rootfs_chroot.sh \
	--bind /var/cache/apt/archives /var/cache/apt/archives \
	\
	--unshare-pid --die-with-parent \
	/bin/sh -eux /tmp/rootfs_chroot.sh 3<rootfs_chroot.sh

# remove cdebootstrap helper that inhibits service invocation
dpkg --root=rootfs --purge cdebootstrap-helper-rc.d
