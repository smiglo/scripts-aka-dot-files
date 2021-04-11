#!/usr/bin/env bash
# vim: fdl=0

# INIT {{{
if [[ $1 == '@@' ]]; then
  echo "fix_ssh_agent start_if_needed fix_tmux"
  exit 0
fi

[[ "$BASH_SOURCE" == "$0" ]] && echo "Script has to be sourced!" && exit 1

SSH_PATH="$TMP_MEM_PATH/.ssh/$(hostname)"
SSH_ENV="$SSH_PATH/environment"
LINK_PATH="$SSH_PATH/ssh_auth_sock"
# }}}
# Functions {{{
fix_ssh_agent() { # {{{
  [[ -z $SSH_AUTH_SOCK ]] && return 0
  [[ ! -e $SSH_PATH ]] && command mkdir -p $SSH_PATH
  [[ -e $LINK_PATH && $SSH_AUTH_SOCK == $LINK_PATH ]] && return 0
  [[ $SSH_AUTH_SOCK == $LINK_PATH ]] && return 1
  [[ ! -e $LINK_PATH ]] && ln -sf $SSH_AUTH_SOCK $LINK_PATH
  chmod 600 $LINK_PATH 2>/dev/null
  export SSH_AUTH_SOCK=$LINK_PATH
} # }}}
fix_tmux() { # {{{
  [[ -z $SSH_AUTH_SOCK ]] && return 0
  tmux set-environment -g 'SSH_AUTH_SOCK' $LINK_PATH
} # }}}
start_agent() { # {{{
  local stderr="$SSH_PATH/stderr"
  ssh-agent -a "$SSH_PATH/bind" -s 2>$stderr | sed 's/^echo/#echo/' >$SSH_ENV
  if [[ -s $stderr ]]; then
    echo "Failed to start ssh-agent !" >/dev/stderr
    rm $SSH_ENV
  else
    chmod 600 $SSH_ENV
    source $SSH_ENV > /dev/null
  fi
  rm -f $stderr
} # }}}
start_if_needed() { # {{{
  [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && return 0
  [[ ! -e $SSH_PATH ]] && command mkdir -p $SSH_PATH
  chmod 700 $SSH_PATH
  local start_ssh=true
  if [[ -f $SSH_ENV ]]; then
    source $SSH_ENV > /dev/null
    [[ ! -z $SSH_AGENT_PID ]] && command ps -ef | command grep -e $SSH_AGENT_PID | command grep -qe 'ssh-agent' && start_ssh=false
  fi
  $start_ssh && start_agent
  fix_ssh_agent
} # }}}
# }}}
# MAIN {{{
cmd="start_if_needed"
[[ ! -z $1 ]] && cmd="$1" && shift
case $cmd in
fix_ssh_agent|start_if_needed|fix_tmux) $cmd $@;;
esac
# }}}
# Cleaning {{{
unset cmd
unset SSH_PATH
unset SSH_ENV
unset LINK_PATH
unset fix_ssh_agent
unset fix_tmux
unset start_if_needed
unset start_agent
# }}}

