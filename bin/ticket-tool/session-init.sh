#!/usr/bin/env bash
# vim: fdl=0

# Has to be sourced in '.env' with 2 args: KB's path and its tmux name, e.g.:
# source $TICKET_TOOL_PATH/session-init.sh "$HOME/projects/kb" "KB"

[[ -z $1 || -z $2 ]] && return 1
[[ -e $1 ]] || return 0
sessionDir="$1" sessionName="$2"
if [[ "$TMUX_SESSION" == "$sessionName" ]]; then # {{{
  export TICKET_TMUX_SESSION="$sessionName"
  [[ $TICKET_PATH != "$sessionDir" ]] || return 0
  unset $(echo ${!TICKET_*} | sed 's/TICKET_TOOL_PATH//')
  export TICKET_PATH="$sessionDir"
  # }}}
elif [[ -z $TMUX_SESSION ]] || ! tmux list-sessions -F '#S' | command grep -q "^$sessionName\$"; then # {{{
  __init_session() { # {{{
    local sessionDir="$1" sessionName="$2"
    ! tmux list-sessions -F '#S' | command grep -q "^$sessionName\$" || return 0
    [[ "$TMUX_SESSION" != "$sessionName" ]] || return 0
    [[ "$PWD" == "$sessionDir" ]] || return 0
    [[ -e '.ticket-data.sh' ]] || ln -sf $TICKET_TOOL_PATH/ticket-data.sh .ticket-data.sh
    tmux \
      new-session -d -s "$sessionName" -c "$sessionDir" \; \
      set -q -t "$sessionName" @tmux_path "$sessionDir" \; \
      send-keys -t "${sessionName}:1.1" " \$TICKET_TOOL_PATH/j-cmd.sh --init; clear"
    $ALIASES set_title --from-tmux "${sessionName}:1.1" "Main"
    local TMUX=
    [[ -z $TMUX_SESSION ]] && tmux attach-session -t "$sessionName" || tmux switch-client -t "$sessionName"
  } # }}}
  alias init-session="__init_session '$sessionDir' '$sessionName' && unset __init_session && unalias init-session"
  __deinit_session() { # {{{
    local sessionName="$1"
    tmux list-sessions -F '#S' | command grep -q "^$sessionName\$" || return 0
    tmux kill-session -t "$sessionName"
  } # }}}
  alias deinit-session-${sessionName,,}="__deinit_session '$sessionName' && unset __deinit_session && unalias deinit-session-${sessionName,,}"
fi # }}}
unset sessionDir sessionName

