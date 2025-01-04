#!/bin/sh -eux

rm -f initrd.zst uki.efi

# get UID and GID of the user account (current owner of rootfs/home/user/)
UID_USER=$(stat -c %u rootfs/home/user/)
GID_USER=$(stat -c %g rootfs/home/user/)

# pack contents of rootfs/ and include.d/ into one cpio file (the initrd.img).
# the latter directory requires additional effort to ensure file ownership is
# correct, as the git repo will retain file mode, but not ownership.
# here, we generate three separate cpio images, which are concatenated in-place
# through a list of grouped commands, and subsequently piped through zstd.
# NOTE: while the Linux kernel will unpack concatenated cpio archies, `cpio -t`
#       will only list the contents of the first archive (cpio has no option
#       equivalent to `tar --ignore-zeros`, so use the following instead:
#       `unzstd -c initrd.zst | { while cpio -t -v ; do :; done }`
{
	find rootfs/ -path 'rootfs/boot/*' -o -path 'rootfs/vmlinuz*' -o -path 'rootfs/initrd.img*' -o -printf '%P\0' \
		| cpio --create --quiet -0 -H newc -D rootfs/ ;
	find include.d/ -path 'include.d/home/*' -prune -o -printf '%P\0' \
		| cpio --create --quiet -0 -H newc -D include.d/ --owner=+0:+0 ;
	find include.d/ -path 'include.d/home/*' -printf '%P\0' \
		| cpio --create --quiet -0 -H newc -D include.d/ --owner=+$UID_USER:+$GID_USER ;
} | zstd -15 -T0 -o initrd.zst

# get kernel uname from rootfs/vmlinuz symlink
UNAME=$(readlink rootfs/vmlinuz)
UNAME=${UNAME#boot/vmlinuz-}
# suffix .osrel NAME to facilitate distinguishing between UKI and installation
sed -E 's,^((PRETTY_)?NAME=".+)",\1 Live/Recovery UKI",g' rootfs/etc/os-release >uki-os-release
# assemble kernel and initrd into unified kernel image (UKI)
# https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html
ukify build --linux=rootfs/vmlinuz --initrd=initrd.zst --cmdline=rdinit=/lib/systemd/systemd --uname="$UNAME" --os-release=@uki-os-release --output=uki.efi
rm uki-os-release
