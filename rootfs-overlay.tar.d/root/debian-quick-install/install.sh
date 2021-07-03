#!/bin/sh -eux

# apt install btrfs-progs cdebootstrap dosfstools

# configure
APT_MIRROR="http://deb.debian.org/debian"
DEBIAN_SUITE="bullseye"
HOSTNAME="debian"
HOSTNAME_FQDN=""
DEV="/dev/nvme0n1"
DEV_ESP="/dev/nvme0n1p1"
ROOT_DEV="/dev/nvme0n1p2"
ROOT_MOUNT="/mnt/root"
XKBMODEL="pc105"
XKBLAYOUT="de"

unmount()
{
        # unmount bind mounts created by build process
        for mount in "$ROOT_MOUNT/@root/boot/efi" "$ROOT_MOUNT/@root/mnt/root" "$ROOT_MOUNT/@root/proc" "$ROOT_MOUNT/@root/sys/firmware/efi/efivars" "$ROOT_MOUNT/@root/sys" "$ROOT_MOUNT/@root/dev/pts" "$ROOT_MOUNT/@root/dev" ; do
                if mountpoint -q "$mount" ; then
                        umount "$mount"
                fi
        done
}

# don't touch
INSTALL_ROOT="$ROOT_MOUNT/@root"

# call and trap register unmount()
unmount
trap "unmount" EXIT INT

# create partition table
sfdisk $DEV <<-EOF
	label: gpt

	name=esp,  size=1G, type=uefi, bootable
	name=root, size=4G, type=linux
EOF

# wait for devices to be created
while [ ! -e $DEV_ESP ] ; do
	sleep 0.1
done
while [ ! -e $ROOT_DEV ] ; do
	sleep 0.1
done
# workaround for spurious mkfs.fat failures due to missing device
sleep 1

# create EFI system partition
mkfs.fat -F 32 $DEV_ESP
UUID_ESP=$(blkid --match-tag UUID --output value $DEV_ESP)

# create btrfs filesystem, mount it, and create default subvolume
mkfs.btrfs --label root --metadata single $ROOT_DEV
ROOT_UUID=$(blkid --match-tag UUID --output value $ROOT_DEV)
mkdir -p $ROOT_MOUNT
mount $ROOT_DEV $ROOT_MOUNT
btrfs subvolume create $ROOT_MOUNT/@root
btrfs subvolume set-default $ROOT_MOUNT/@root

# setup read-only btrfs snapshots
mkdir -p $ROOT_MOUNT/.snapshots/root
cat >$ROOT_MOUNT/mksnapshot_root.sh <<-EOF
	#!/bin/sh -eux

	btrfs subvol snapshot -r $ROOT_MOUNT/@root $ROOT_MOUNT/.snapshots/root/@\$(date --utc +%Y-%m-%dT%H%M%SZ)
EOF
chmod 700 $ROOT_MOUNT/mksnapshot_root.sh $ROOT_MOUNT/.snapshots $ROOT_MOUNT/.snapshots/root

# bootstrap system
cdebootstrap --flavour=minimal --include=whiptail $DEBIAN_SUITE $ROOT_MOUNT/@root $APT_MIRROR | tee bootstrap.log 2>&1
$ROOT_MOUNT/mksnapshot_root.sh

# replace debootstrap's /etc/apt/sources.list with more complete alternative
if [ "$DEBIAN_SUITE" = "sid" ] ; then
	echo "deb http://deb.debian.org/debian/ sid main contrib non-free" > $ROOT_MOUNT/@root/etc/apt/sources.list
else
	echo "deb http://deb.debian.org/debian $DEBIAN_SUITE main contrib non-free" > $ROOT_MOUNT/@root/etc/apt/sources.list
	echo "#deb http://security.debian.org/ $DEBIAN_SUITE/updates main contrib non-free" >> $ROOT_MOUNT/@root/etc/apt/sources.list
	echo "#deb http://deb.debian.org/debian $DEBIAN_SUITE-updates main contrib non-free" >> $ROOT_MOUNT/@root/etc/apt/sources.list
	echo "#deb http://deb.debian.org/debian $DEBIAN_SUITE-backports main contrib non-free" >> $ROOT_MOUNT/@root/etc/apt/sources.list
fi

# create /etc/hostname and /etc/hosts
echo "127.0.0.1 localhost" > $ROOT_MOUNT/@root/etc/hosts
if [ -n "$HOSTNAME_FQDN" ] ; then
	echo "$HOSTNAME_FQDN" > $ROOT_MOUNT/@root/etc/hostname
	echo "127.0.1.1 $HOSTNAME_FQDN $HOSTNAME" >> $ROOT_MOUNT/@root/etc/hosts
else
	echo "$HOSTNAME" > $ROOT_MOUNT/@root/etc/hostname
	echo "127.0.1.1 $HOSTNAME" >> $ROOT_MOUNT/@root/etc/hosts
fi

# create /etc/fstab
cat >$ROOT_MOUNT/@root/etc/fstab <<-EOF
	UUID="$ROOT_UUID" /         btrfs relatime,ssd            0 0
	UUID="$ROOT_UUID" /mnt/root btrfs relatime,ssd,subvolid=5 0 0
	UUID="$UUID_ESP"                            /boot/efi vfat  relatime                0 0
	tmpfs                                       /tmp      tmpfs mode=1777               0 0
EOF

# configure keyboard layout
cat > $ROOT_MOUNT/@root/etc/default/keyboard <<-EOF
	# KEYBOARD CONFIGURATION FILE

	# Consult the keyboard(5) manual page.

	XKBMODEL="$XKBMODEL"
	XKBLAYOUT="$XKBLAYOUT"
	XKBVARIANT=""
	XKBOPTIONS=""

	BACKSPACE="guess"
EOF

# create /etc/kernel/cmdline
echo "root=UUID=$ROOT_UUID ro" > $ROOT_MOUNT/@root/etc/kernel/cmdline

# untar includes
tar -xf include.tar.gz -C $ROOT_MOUNT/@root

# bind mount
mkdir $ROOT_MOUNT/@root/mnt/root $ROOT_MOUNT/@root/boot/efi
mount $DEV_ESP $ROOT_MOUNT/@root/boot/efi
mount --bind /dev $ROOT_MOUNT/@root/dev
mount --bind /dev/pts $ROOT_MOUNT/@root/dev/pts
mount --bind /sys $ROOT_MOUNT/@root/sys
mount --bind /sys/firmware/efi/efivars $ROOT_MOUNT/@root/sys/firmware/efi/efivars
mount --bind /proc $ROOT_MOUNT/@root/proc
mount --bind $ROOT_MOUNT $ROOT_MOUNT/@root/mnt/root

# call chroot build script with clean environment (to prevent locale issues, etc.)
cp install_chroot.sh $ROOT_MOUNT/@root/
env --ignore-environment \
	PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
	TERM="$TERM" USER="$USER" \
	chroot $ROOT_MOUNT/@root /install_chroot.sh
rm $ROOT_MOUNT/@root/install_chroot.sh

# install hook that updates systemd-boot loader configs on installation of kernel images
dpkg --root=$ROOT_MOUNT/@root --install update-systemd-boot.deb

# unmount
unmount

# remove chroot helper that disables service invocation
dpkg --root=$ROOT_MOUNT/@root --purge cdebootstrap-helper-rc.d

# create snapshot and unmount
$ROOT_MOUNT/mksnapshot_root.sh
umount $ROOT_MOUNT
