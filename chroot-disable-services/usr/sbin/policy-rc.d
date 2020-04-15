#!/bin/sh

# policy-rc.d script that denies all init operations through invoke-rc.d
# https://manpages.debian.org/buster/init-system-helpers/invoke-rc.d.8.en.html

echo "********* INVOKE-RC.D ACTION DENIED BY CHROOT-DISABLE-SERVICES PACKAGE *********" >&2
echo $0 $* >&2
echo "********* INVOKE-RC.D ACTION DENIED BY CHROOT-DISABLE-SERVICES PACKAGE *********" >&2

exit 101
