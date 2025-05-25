#!/bin/sh -eux

# /tmp is tmpfs created by bwrap, but bwrap uses 0755 mode
# TODO: use bwrap --perms 1777 --tmpfs /tmp once bwrap 0.5 is widely available
chmod 1777 /tmp

# installing systemd-resolved replaces /etc/resolv.conf with a symlink to
# /run/system/resolved/stub-resolv.conf. with service invocation inhibited in
# the chroot, systemd-resolved does not run and these files are missing,
# breaking DNS resolution. as a workaround, substitute these files with the
# contents of /etc/resolv.conf (expected to be a usable resolv.conf provided
# by the host).
mkdir -p /run/systemd/resolve
cat /etc/resolv.conf >/run/systemd/resolve/resolv.conf
cat /etc/resolv.conf >/run/systemd/resolve/stub-resolv.conf

# make apt-get not ask any questions
# https://manpages.debian.org/unstable/debconf-doc/debconf.7.en.html#Frontends
export DEBIAN_FRONTEND=noninteractive

# fetch repository index
apt-get update

# install all packages except kernel (avoids multiple initramfs rebuilds)
apt-get --assume-yes --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
	bsdmainutils cpio dbus dmidecode init initramfs-tools iproute2 \
	kmod login mount nano netbase sensible-utils \
	systemd systemd-boot systemd-resolved systemd-sysv systemd-timesyncd \
	tzdata udev vim-tiny zstd \
	\
	bash-completion bubblewrap busybox cdebootstrap console-setup keyboard-configuration usb-modeswitch \
	htop less man-db manpages \
	btrfs-progs cryptsetup-bin dosfstools efibootmgr fdisk ntfs-3g \
	iputils-ping iputils-tracepath netcat-openbsd openssh-client openssh-server

# enable systemd services not enabled by default
if [ -f /usr/lib/systemd/system/systemd-networkd.service ] ; then
	systemctl enable systemd-networkd.service
fi

# disable resuming (emits warning during initramfs generation and may cause
# boot delay when erroneously waiting for swap partition)
# https://manpages.debian.org/unstable/initramfs-tools-core/initramfs-tools.7.en.html#resume
if [ -d /etc/initramfs-tools/conf.d ] ; then
	echo "RESUME=none" >/etc/initramfs-tools/conf.d/resume
fi

# configure initramfs generation before installing kernel
# (use local keymap in initramfs)
sed -i 's/^KEYMAP=n/KEYMAP=y/' /etc/initramfs-tools/initramfs.conf

# install kernel
apt-get --assume-yes --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
	linux-image-amd64

# remove machine-specific files (UUIDs and SSH host keys)
rm -f /etc/machine-id /etc/ssh/ssh_host_*_key /var/lib/dbus/machine-id
ln -s ../../../etc/machine-id /var/lib/dbus/machine-id
# set trigger for systemd first boot (required to regenerate SSH host keys)
# https://manpages.debian.org/unstable/systemd/machine-id.5.en.html#FIRST_BOOT_SEMANTICS
echo "uninitialized" >/etc/machine-id

# create unprivileged user
useradd --create-home -d /home/user -s /bin/bash -G audio,dialout,input,sudo,video user
# permit local logins without password
# NOTE: sshd refuses login without password unless PermitEmptyPasswords is set:
#       https://manpages.debian.org/unstable/openssh-server/sshd_config.5.en.html#PermitEmptyPasswords
sed -i 's/^root:[^:]*:/root::/' /etc/shadow
sed -i 's/^user:[^:]*:/user::/' /etc/shadow

# cleanup cache and log files (reduce image size)
# NOTE: do not use `apt-get distclean` as it deletes all cached .deb files and
#       /var/cache/apt/archives is writably bind mounted from the host
rm -f \
	/var/cache/apt/*cache.bin \
	/var/cache/debconf/templates.* \
	/var/lib/apt/lists/*_dists_* \
	/var/log/apt/* \
	/var/log/alternatives.log \
	/var/log/bootstrap.log \
	/var/log/dpkg.log
