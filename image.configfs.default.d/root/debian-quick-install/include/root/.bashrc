# source default .bashrc
. /etc/skel/.bashrc

# PROMPT

CL_NULL="\[\033[00m\]"
CL_RED="\[\033[01;31m\]"
CL_GREEN="\[\033[01;32m\]"
CL_YELLOW="\[\033[01;33m\]"
CL_BLUE="\[\033[01;34m\]"
CL_MAGENTA="\[\033[01;35m\]"
CL_CYAN="\[\033[01;36m\]"
CL_WHITE="\[\033[01;37m\]"

PS1="${CL_RED}\u${CL_YELLOW}@${CL_GREEN}\h ${CL_YELLOW}\w ${CL_RED}\\$ ${CL_NULL}"

if [[ "$TERM" == "xterm" || "$TERM" == "xterm-256color" || "$TERM" == "screen" || "$TERM" == "screen-256color" ]] ; then
	PROMPT_COMMAND='printf "\033]0;%s@%s %s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}"'
fi


# ALIASES

alias d='ls -aFhl --color=auto'
