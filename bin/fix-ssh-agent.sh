#!/usr/bin/env bash
# vim: fdl=0

# INIT # {{{
if [[ $1 == '@@' ]]; then
  echo "--fix --start --start-if --start-iff -f --force"
  exit 0
fi

if [[ "$BASH_SOURCE" == "$0" ]]; then
  echoe -w "Script has to be sourced!"
  echoe
  echoe -w "Usage:"
  echoe -w "  source $0 [-f | --force] [--start-if | --start-iff | --fix]"
  echoe
  exit 0
fi

SSH_PATH="$BASHRC_RUNTIME_PATH/ssh/$HOSTNAME"
SSH_ENV="$SSH_PATH/environment"
LINK_PATH="$SSH_PATH/ssh_auth_sock"
# }}}
# Functions # {{{
fix-ssh-agent() { # {{{
  [[ -e $SSH_PATH ]] || return 1
  [[ -f $SSH_ENV ]] || return 1
  source $SSH_ENV
  [[ -e $SSH_AUTH_SOCK ]] || return 1
  rm -f $LINK_PATH
  ln -sf $SSH_AUTH_SOCK $LINK_PATH
  chmod 600 $LINK_PATH 2>/dev/null
  export SSH_AUTH_SOCK=$LINK_PATH
  if [[ -n $TMUX ]]; then
    tmux set-environment -g 'SSH_AUTH_SOCK' $LINK_PATH
  fi
  return 0
} # }}}
start-agent() { # {{{
  local err=0
  command mkdir -p $SSH_PATH && chmod 700 $SSH_PATH
  [[ ! -e $SSH_PATH/bind ]] || rm -rf $SSH_PATH/bind
  ssh-agent -a "$SSH_PATH/bind" -s | sed '/^echo/d' >$SSH_ENV
  err=${PIPESTATUS[0]}
  [[ $err == 0 ]] || { rm -f $SSH_ENV; eval $(die $err "Failed to start ssh-agent ($err)"); }
  chmod 600 $SSH_ENV
  source $SSH_ENV
  [[ ! -z $SSH_KEYS ]] && sshh-add --keys $SSH_KEYS
  return 0
} # }}}
start-if-needed() { # {{{
  [[ -n "$SSH_CLIENT" ]] && ! w | grep -q ${SSH_CLIENT%% *} && unset SSH_CLIENT SSH_TTY
  if ! $force; then
    [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && { echoe "remote session, nothing to do"; return 0; }
  fi
  local start_ssh=true
  if [[ -f $SSH_ENV ]]; then
    source $SSH_ENV
    pidof ssh-agent | command grep -q "\<$SSH_AGENT_PID\>" && start_ssh=false
  fi
  if $start_ssh; then
    start-agent || return 1
  fi
  fix-ssh-agent
} # }}}
# }}}
# MAIN # {{{
force=${SSH_AGENT_FIX_FORCE:-false} cmd="fix"
while [[ -n $1 ]]; do
  case $1 in
  -f | --force) force=true;;
  *) cmd=$1; shift; break;;
  esac; shift
done
case $cmd in
start-if)   start-if-needed "$@";;
start-iff)  force=true; start-if-needed "$@";;
fix)        fix-ssh-agent "$@";;
esac
__fsa_err=$?
# }}}
# Cleaning # {{{
unset force cmd SSH_PATH SSH_ENV LINK_PATH
unset -f fix-ssh-agent start-if-needed start-agent
# }}}
return $__fsa_err
