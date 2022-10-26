#!/bin/sh -eux

# see debconf(7)
export DEBIAN_FRONTEND=noninteractive

apt-get update

# setup C locale as default
apt-get --assume-yes install locales
update-locale LANG=C.UTF-8

# systemd-boot packaged separately since Debian Bookworm/Sid (systemd >= 251.2-3)
# https://salsa.debian.org/systemd-team/systemd/-/blob/debian/251.2-3/debian/changelog
# TODO: remove this workaround after stable release of Bookworm
if [ $DEBIAN_SUITE = "bookworm" -o $DEBIAN_SUITE = "sid" ] ; then
	systemd_boot="systemd-boot"
fi

# systemd-resolved packaged separately since Debian Bookworm/Sid (systemd >= 252.3-2)
# https://salsa.debian.org/systemd-team/systemd/-/blob/debian/251.3-2/debian/systemd.NEWS
# TODO: remove this workaround after stable release of Bookworm
if [ $DEBIAN_SUITE = "bookworm" -o $DEBIAN_SUITE = "sid" ] ; then
	systemd_resolved="systemd-resolved"
fi

# install subset of important packages plus some personal favorites
apt-get --assume-yes --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
	bsdmainutils cpio dbus dmidecode init iproute2 \
	kmod mount nano netbase sensible-utils \
	systemd ${systemd_boot:-} ${systemd_resolved:-} systemd-sysv systemd-timesyncd \
	tzdata udev vim-common vim-tiny

# enable systemd services not enabled by default
systemctl enable systemd-networkd.service

# install remaining packages
apt-get --assume-yes --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
	linux-image-amd64 firmware-linux firmware-realtek \
	bash-completion busybox cdebootstrap console-setup keyboard-configuration pciutils usbutils \
	file htop less lshw psmisc screen sudo man-db manpages zstd \
	\
	btrfs-progs cryptsetup-bin dosfstools fdisk mdadm ntfs-3g xfsprogs \
	\
	bind9-dnsutils ca-certificates curl ethtool iputils-arping iputils-ping iputils-tracepath \
	netcat-openbsd netsniff-ng openssh-client openssh-server socat tcpdump wget wireguard-tools \
	\
	linux-perf python3 strace usb-modeswitch \
	\
	kitty policykit-1 sway swayidle swaylock sway-backgrounds wofi

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

# use local keymap
sed -i 's/^KEYMAP=n/KEYMAP=y/' /etc/initramfs-tools/initramfs.conf
dpkg-reconfigure initramfs-tools

# create unprivileged user and set usernames as password (generate via `openssl passwd -1 -salt ""`)
useradd --create-home -d /home/user -s /bin/bash -G audio,dialout,input,sudo,video user
usermod --password '$1$$oCLuEVgI1iAqOA8pwkzAg1' root
usermod --password '$1$$ex9cQFo.PV11eSLXJFZuj.' user
