# source default .profile
. /etc/skel/.profile

# set locale
export LANG="C.UTF-8"

# enable Wayland on various toolkits
# https://wiki.archlinux.org/index.php/Wayland#GUI_libraries
export CLUTTER_BACKEND=wayland
export GDK_BACKED=wayland
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland

# autostart sway if this is the first login
#if [ "$(tty)" == "/dev/tty1" -a ! -e "$XDG_RUNTIME_DIR/sway_autostart_done" ] ; then
#	touch "$XDG_RUNTIME_DIR/sway_autostart_done"
#	sway
#fi
