#!/usr/bin/env bash
# vim: fdl=0

# INIT # {{{
if [[ $1 == '@@' ]]; then
  echo "--fix --start --fix"
  exit 0
fi

if [[ "$BASH_SOURCE" == "$0" ]]; then
  echor "Script has to be sourced!"
  echor
  echor "Usage:"
  echor "  source $0 [--fix | --start | --fix-tmux]"
  echor "(copied)"
  echor
  echo "source $0 --start" | xc
  exit 0
fi

SSH_PATH="$BASHRC_RUNTIME_PATH/ssh/$(hostname)"
SSH_ENV="$SSH_PATH/environment"
LINK_PATH="$SSH_PATH/ssh_auth_sock"
# }}}
# Functions # {{{
fix_tmux() { # {{{
  [[ -z $SSH_AUTH_SOCK ]] && return 0
  tmux set-environment -g 'SSH_AUTH_SOCK' $LINK_PATH
} # }}}
fix_ssh_agent() { # {{{
  [[ ! -e $SSH_PATH ]] && return 1
  if [[ -z $SSH_AUTH_SOCK ]]; then
    [[ -f $SSH_ENV ]] && source $SSH_ENV >/dev/null
    [[ -z $SSH_AUTH_SOCK ]] && return 1
  fi
  [[ $SSH_AUTH_SOCK == $LINK_PATH && -e $LINK_PATH ]] && return 0
  [[ -e $(readlink -f $LINK_PATH) ]] && SSH_AUTH_SOCK=$LINK_PATH && return 0
  rm -f $LINK_PATH
  ln -sf $SSH_AUTH_SOCK $LINK_PATH
  chmod 600 $LINK_PATH 2>/dev/null
  export SSH_AUTH_SOCK=$LINK_PATH
} # }}}
start_agent() { # {{{
  local err=0 i=0 stderr="$SSH_PATH/stderr"
  while [[ $i -le 1 ]]; do
    command mkdir -p $SSH_PATH >/dev/null && chmod 700 $SSH_PATH
    if ssh-agent -a "$SSH_PATH/bind" -s 2>$stderr | sed 's/^echo/#echo/' >$SSH_ENV && [[ ! -s $stderr ]]; then
      chmod 600 $SSH_ENV
      source $SSH_ENV >/dev/null
      err=0; break
    else
      rm $SSH_ENV
      err=$?
    fi
    rm -rf $SSH_PATH
    i=$(($i+1))
  done
  rm -f $stderr
  if [[ $err != 0 ]]; then
    echo "Failed to start ssh-agent ($err)" >/dev/stderr
  fi
  return $err
} # }}}
start_if_needed() { # {{{
  [[ -n "$SSH_CLIENT" ]] && [[ $(who | grep -v "(:" | sort -k5,5 -u | wc -l) == 0 ]] && unset SSH_CLIENT SSH_TTY
  [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && return 0
  local start_ssh=true
  if [[ -f $SSH_ENV ]]; then
    source $SSH_ENV >/dev/null
    [[ ! -z $SSH_AGENT_PID ]] && pidof ssh-agent | grep -q "\<$SSH_AGENT_PID\>" && start_ssh=false
  fi
  if $start_ssh; then
    start_agent || return 1
  fi
  fix_ssh_agent
} # }}}
# }}}
# MAIN # {{{
cmd="--start"
[[ ! -z $1 ]] && cmd="$1" && shift
case $cmd in
--start)    start_agent "$@";;
--start-if) start_if_needed "$@";;
--fix)      fix_ssh_agent "$@";;
--fix-tmux) fix_tmux "$@";;
esac
# }}}
# Cleaning # {{{
unset cmd SSH_PATH SSH_ENV LINK_PATH
unset fix_ssh_agent fix_tmux start_if_needed start_agent
# }}}

