# source default .profile
. /etc/skel/.profile

if [ -x "$(which sway)" -a "$(tty)" = "/dev/tty1" ] ; then
	export XDG_SESSION_TYPE=wayland

	# enable Wayland on various toolkits
	# https://wiki.archlinux.org/index.php/Wayland#GUI_libraries
	export CLUTTER_BACKEND=wayland
	export QT_QPA_PLATFORM=wayland
	export SDL_VIDEODRIVER=wayland

	exec sway
fi
