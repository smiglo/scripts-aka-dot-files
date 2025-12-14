#!/usr/bin/env bash
# vim: fdl=0

export PS1_STATUS="short_git:default"
[[ -z $TMUX_ICON_HOST ]] && export TMUX_ICON_HOST="docker"
[[ ! -z $TZ ]] || export TZ="Europe/Warsaw"

bindList="Downloads Desktop Documents $VIRTOS_HOST_LINKS"
if $IS_DOCKER; then # {{{
  bindList+=" .dedoc"
  export BASH_PHISTORY_FILE=$RUNTIME_PATH/phistory.no-git
  if $BASHRC_FULL_START; then # {{{
    [[ -e $HOME/.ssh ]] || mkdir -p $HOME/.ssh >/dev/null
    [[ ! -e /home/host/.ssh/authorized_keys || -e $HOME/.ssh/authorized_keys ]] || ln -sf /home/host/.ssh/authorized_keys $HOME/.ssh/
    if [[ ! -s $KEEP_PASS_MASTER_KEY ]] && ${KEEP_PASS_MASTER_KEY_SET:-false}; then # {{{
      $HOME/.bin/misc/keep-pass.sh --set-master-key
    fi # }}}
    if [[ -z $HOST_IP ]]; then # {{{
      export HOST_IP="$(ip addr show eth0 2>/dev/null | sed -n '/inet /s/.*inet \([^/]\+\).*/\1/p')"
      [[ ! -z $HOST_IP ]] && HOST_IP="${HOST_IP%.*}.1" || echoe -s "cannot obtain host IP"
    fi # }}}
    ${BASHRC_DOCKER_SSH_START:-true} && service ssh restart
  fi # }}} # }}}
elif $IS_WSL; then # {{{
  :
fi # }}}
if $BASHRC_FULL_START; then # {{{
  if [[ -e /home/host ]]; then
    for i in $bindList; do
      s="/home/host/$i" d=$i
      [[ $i == *:* ]] && s=${i%%:*} && d=${i#*:}
      [[ -e $s && ! -e $HOME/$d ]] || continue
      if [[ $d == */* ]]; then
        mkdir -p "$(dirname $HOME/$d)" >/dev/null || continue
      fi
      ln -sf $s $HOME/$d
    done
    unset i s d
  else
    echoe -s "/home/host not exist"
  fi
fi # }}}
unset bindList

