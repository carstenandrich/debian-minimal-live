#!/bin/sh -eux

# make apt-get not ask any questions
# https://manpages.debian.org/unstable/debconf-doc/debconf.7.en.html#Frontends
export DEBIAN_FRONTEND=noninteractive

# fetch repository index
apt-get update

# setup C locale as default
apt-get --assume-yes install locales
update-locale LANG=C.UTF-8

# systemd-boot packaged separately since Debian Bookworm/Sid (systemd >= 251.2-3)
# https://salsa.debian.org/systemd-team/systemd/-/blob/debian/251.2-3/debian/changelog
# TODO: remove after stable release of Bookworm
if [ $DEBIAN_SUITE = "bookworm" -o $DEBIAN_SUITE = "sid" ] ; then
	systemd_boot="systemd-boot"
fi

# systemd-resolved packaged separately since Debian Bookworm/Sid (systemd >= 252.3-2)
# https://salsa.debian.org/systemd-team/systemd/-/blob/debian/251.3-2/debian/systemd.NEWS
# TODO: remove after stable release of Bookworm
if [ $DEBIAN_SUITE = "bookworm" -o $DEBIAN_SUITE = "sid" ] ; then
	systemd_resolved="systemd-resolved"
fi

# installing systemd-resolved replaces /etc/resolv.conf with a symlink to
# /run/system/resolved/stub-resolv.conf. with service invocation inhibited in
# the chroot, systemd-resolved does not run and these files are missing,
# breaking DNS resolution. as a workaround, substitute these files with the
# contents of /etc/resolv.conf (expected to be a usable resolv.conf provided
# by the host)
mkdir -p /run/systemd/resolve
cat /etc/resolv.conf > /run/systemd/resolve/resolv.conf
cat /etc/resolv.conf > /run/systemd/resolve/stub-resolv.conf

# install subset of important packages plus some personal favorites
apt-get --assume-yes --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
	bsdmainutils cpio dbus dmidecode init initramfs-tools iproute2 \
	kmod mount nano netbase sensible-utils \
	systemd ${systemd_boot:-} ${systemd_resolved:-} systemd-sysv systemd-timesyncd \
	tzdata udev vim-tiny zstd \
	\
	bash-completion bubblewrap busybox cdebootstrap console-setup keyboard-configuration usb-modeswitch \
	htop less man-db manpages \
	btrfs-progs cryptsetup-bin dosfstools fdisk ntfs-3g \
	iputils-ping iputils-tracepath netcat-openbsd openssh-client openssh-server

# enable systemd services not enabled by default
systemctl enable systemd-networkd.service

# enable systemd-resolved service and use its resolv.conf on Bullseye
# TODO: remove after stable release of Bookworm
if [ $DEBIAN_SUITE = "bullseye" ] ; then
	systemctl enable systemd-resolved.service
	ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi

# configure keyboard layout
cat > /etc/default/keyboard <<-EOF
	# KEYBOARD CONFIGURATION FILE

	# Consult the keyboard(5) manual page.

	XKBMODEL="pc105"
	XKBLAYOUT="de"
	XKBVARIANT=""
	XKBOPTIONS=""

	BACKSPACE="guess"
EOF

# disable resuming (emits warning during initramfs generation and may cause
# boot delay when erroneously waiting for swap partition)
# https://manpages.debian.org/bullseye/initramfs-tools-core/initramfs-tools.7.en.html#resume
echo "RESUME=none" > /etc/initramfs-tools/conf.d/resume

# use local keymap
sed -i 's/^KEYMAP=n/KEYMAP=y/' /etc/initramfs-tools/initramfs.conf

# install kernel last, so initramfs will only be built once
apt-get --assume-yes --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
	linux-image-amd64

# create unprivileged user and set usernames as password (generate via `openssl passwd -1 -salt ""`)
useradd --create-home -d /home/user -s /bin/bash -G audio,dialout,input,sudo,video user
usermod --password '$1$$oCLuEVgI1iAqOA8pwkzAg1' root
usermod --password '$1$$ex9cQFo.PV11eSLXJFZuj.' user
