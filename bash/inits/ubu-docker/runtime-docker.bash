#!/usr/bin/env bash
# vim: fdl=1

export BASH_PHISTORY_FILE=$RUNTIME_PATH/phistory.no-git
export PS1_STATUS="short_git:default"
export TMUX_ICON_HOST="docker"
[[ -z $KEEP_PASS_MASTER_KEY ]] && export KEEP_PASS_MASTER_KEY="$MEM_KEEP/keep-pass.mkey"
if $BASHRC_FULL_START; then # {{{
  mkdir -p $HOME/.ssh >/dev/null
  [[ ! -e /host/.ssh/authorized_keys || -e $HOME/.ssh/authorized_keys ]] || ln -sf /host/.ssh/authorized_keys $HOME/.ssh/
  for i in Downloads Desktop .dedoc $DOCKER_HOST_LINKS; do # {{{
    [[ -e /host/$i && ! -e $HOME/$i ]] || continue
    if [[ $i == */* ]]; then
      mkdir -p "$(dirname $HOME/$i)" >/dev/null || continue
    fi
    ln -sf /host/$i $HOME/$i
  done
  unset i # }}}
  if [[ ! -s $KEEP_PASS_MASTER_KEY ]] && ${KEEP_PASS_MASTER_KEY_SET:-false}; then # {{{
    $HOME/.bin/misc/keep-pass.sh --set-master-key
  fi # }}}
  if [[ -z $HOST_IP ]]; then # {{{
    export HOST_IP="$(ip addr show eth0 2>/dev/null | sed -n '/inet /s/.*inet \([^/]\+\).*/\1/p')"
    [[ ! -z $HOST_IP ]] && HOST_IP="${HOST_IP%.*}.1" || echor "cannot obtain host IP"
  fi # }}}
  if ${BASHRC_DOCKER_SSH_START:-true}; then # {{{
    service ssh restart
  fi # }}}
fi # }}}

