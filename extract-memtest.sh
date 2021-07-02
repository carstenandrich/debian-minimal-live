#!/bin/sh -eu

MEMTEST_ZIP="memtest86-usb.zip"
MEMTEST_DIR="MemTest86"

if [ ! -e "$MEMTEST_ZIP" ] ; then
	echo "$MEMTEST_ZIP not found. Download it from: https://www.memtest86.com/" >&2
	exit 1
fi

if [ -e "$MEMTEST_DIR" ] ; then
	echo "$MEMTEST_DIR exists. Remove it before running this script."
	exit 1
fi

# register trap to reliably cleanup after ourselves
cleanup()
{
	if mountpoint -q $TMPDIR/mnt ; then
		umount $TMPDIR/mnt
	fi

	if [ -b "$LOOPDEV" ] ; then
		losetup --detach $LOOPDEV
	fi

	if [ -d "$TMPDIR" ] ; then
		rm -rf $TMPDIR
	fi
}
trap "cleanup" EXIT INT

# create temporary directory and
TMPDIR=$(mktemp --directory --tmpdir memtest-dl.XXXXXXXXXX)

# download and extract memtest zip archive
unzip -q $MEMTEST_ZIP -d $TMPDIR

# mount memtest usb image file
mkdir $TMPDIR/mnt
LOOPDEV=$(losetup --find --partscan --read-only --show $TMPDIR/memtest86-usb.img)
mount -o ro ${LOOPDEV}p1 $TMPDIR/mnt

# copy memtest
cp -r $TMPDIR/mnt/EFI/BOOT/ $MEMTEST_DIR

echo "Successfully extracted MemTest86."
