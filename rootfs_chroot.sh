#!/bin/sh -eux

# see debconf(7)
export DEBIAN_FRONTEND=noninteractive

apt-get update

# setup C locale as default
apt-get --assume-yes install locales
update-locale LANG=C.UTF-8

# install subset of important packages plus some personal favorites
# FIXME: as of systemd package version 251.2-3, systemd-boot was split off into separate package, see:
#        https://salsa.debian.org/systemd-team/systemd/-/blob/debian/251.2-3/debian/changelog
#        the systemd-boot package does not exist on current Debian stable (Bullseye) or prior versions
apt-get --assume-yes --no-install-recommends install \
	bsdmainutils cpio dbus dmidecode init iproute2 \
	kmod mount nano netbase sensible-utils \
	systemd systemd-boot systemd-sysv systemd-timesyncd \
	tzdata udev vim-common vim-tiny

# install remaining packages
apt-get --assume-yes --no-install-recommends install \
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


# install systemd-resolved last (breaks DNS resolution)
# FIXME: as of systemd package version 252.3-2 systemd-resolved was split off into separate package, see:
#        https://salsa.debian.org/systemd-team/systemd/-/blob/debian/251.3-2/debian/systemd.NEWS
#        the systemd-resolved package does not exist on current Debian stable (Bullseye) or prior versions
# FIXME: installing systemd-resolved overwrites /etc/resolv.conf, breaking DNS
#        resolution, because resolved won't be running inside the chroot
#        (service invocation is inhibited) and may not be running outside of it.
apt-get --assume-yes --no-install-recommends install \
	systemd-resolved

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

# use systemd services
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
systemctl enable systemd-timesyncd.service
# TODO: link to stub-resolv.conf instead?
ln -fs /run/systemd/resolve/resolv.conf /etc/resolv.conf
