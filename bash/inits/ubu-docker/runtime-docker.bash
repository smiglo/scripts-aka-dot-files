#!/usr/bin/env bash
# vim: fdl=0

export BASH_PHISTORY_FILE=$RUNTIME_PATH/phistory.no-git
export PS1_STATUS="short_git:default"
export TMUX_ICON_HOST="docker"
[[ -e $HOME/tools.docker/fzf/bin/fzf ]] && export FZF_PATH="$HOME/tools.docker/fzf/bin"
[[ -e $HOME/tools.docker/pwndbg/gdbinit.py ]] && export GDB_PWNDBG_INIT="$HOME/tools.docker/pwndbg/gdbinit.py"
export HOST_IP="$(ip addr show eth0 2>/dev/null | sed -n '/inet /s/.*inet \([^/]\+\).*/\1/p')"
[[ ! -z $HOST_IP ]] && HOST_IP="${HOST_IP%.*}.1" || echor "cannot obtain host IP"

