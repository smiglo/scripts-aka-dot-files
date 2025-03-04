#!/usr/bin/env bash
# vim: fdl=0

__util_ssh_getParams() { # {{{
  local host= user= port= i= params= host_alias="$1"
  if [[ $host_alias == *@* ]]; then
    host=${host_alias/*@}
    host=${host/:$}
    user=${host_alias/@*}
    [[ $user == $host_alias ]] && user=
    port=${host_alias/*:}
    [[ $port == $host_alias ]] && port=
    host_alias=$host
  fi
  for i in $BASH_PROFILES_FULL; do
    [[ -e $i/aliases ]] || continue
    host="$($i/aliases __util_ssh_getHost $host_alias)"
    [[ ! -z $host ]] || continue
    [[ -z $user ]] && user="$($i/aliases __util_ssh_getParams --user $host $host_alias)"
    params="$($i/aliases __util_ssh_getParams --params $host $host_alias)"
    break
  done
  [[ -z $host ]] && host=$host_alias
  if [[ -z $user ]]; then
    for i in $BASH_PROFILES_FULL; do
      [[ -e $i/aliases ]] || continue
      user="$($i/aliases __util_ssh_getParams --user $host $host_alias)"
      [[ ! -z $user ]] || continue
      params="$($i/aliases __util_ssh_getParams --params $host $host_alias)"
      break
    done
  fi
  [[ -z $port ]] && port='22'
  [[ ! -z $user ]] && user+='@'
  if [[ ! -z $2 ]]; then
    $i/aliases __util_ssh_getParams --pre $host $host_alias >/dev/stderr || return 1
    echo "ssh -A $params -p $port ${user}${host}"
    return 0
  fi
  echo "$host $user $port"
} # }}}
__util_ssh_getHosts() { # {{{
  local hosts_vars="${!HOST_*}"
  local i= hosts=
  for i in $BASH_PROFILES_FULL; do
    [[ -e $i/aliases ]] && hosts+=" $($i/aliases __util_ssh_getHosts)"
  done
  echo $hosts
} # }}}
_sshh() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $2 in
    1) echo "$(__util_ssh_getHosts)";;
    2) echo "-key -cp -? cat";;
    3) # {{{
        for i in $BASH_PROFILES_FULL; do
          [[ -e $i/aliases ]] || continue
          host="$($i/aliases __util_ssh_getHost $4)"
          [[ ! -z $host ]] || continue
          $i/aliases __util_ssh_getParams @@ $host $4
          break
        done ;; # }}}
    esac
    return 0
  fi # }}}
  local host="$SSHH_DEFAULT_HOST" cmd= src= dst= params= useShhClip=${SSH_USE_SSHC:-true}
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    +clip) useShhClip=true;;
    -clip) useShhClip=false;;
    -key) # {{{
      src=~/.ssh/id_rsa.pub
      [[ ! -z $2 && $2 != -* ]] && src=$2 && shift
      [[ ! -e $src ]] && echormf 0 "Public key ($src) does not exist" && return 1
      if [[ $2 == '-hosts' ]]; then
        shift
        while [[ ! -z $2 ]]; do
          sshh $2 -key $src
          [[ $? != 0 ]] && return $?
          shift
        done
        return 0
      fi
      params=( $(__util_ssh_getParams $host) )
      dst="/home/${params[1]}/.ssh/authorized_keys"
      cmd="cat $src | ssh -p ${params[2]} ${params[1]}@${params[0]} cat \">>\" $dst"
      ;; # }}}
    -cp) # {{{
      [[ -z $2 ]] && echormf 0 "Source is missing" && return 1
      src=$2 && shift
      [[ ! -e $src ]] && echormf 0 "Source ($src) does not exist" && return 1
      cmd="tar czf - $src | $cmd \"tar xzvpf -\""
      ;; # }}}
    -\?) # {{{
      echormf 0 "USAGE:"
      echormf 0 "\tsshh [ HOST ]"
      echormf 0 "\tsshh [ HOST ] -key [ KEY_FILE ]"
      echormf 0 "\tsshh -key [ KEY_FILE ] -hosts LIST_OF_HOSTS"
      echormf 0 "\tsshh [ HOST ] -cp SRC"
      echormf 0 "\tsshh -?"
      echormf 0 "\t---"
      echormf 0 "\tDefault host=($SSHH_DEFAULT_HOST)"
      return 0
      ;; # }}}
    -?*) # {{{
      params+=" $1";; # }}}
    *) # {{{
      host="$1"
      cmd=$(__util_ssh_getParams $host true)
      [[ -z $cmd ]] && return 1
      shift
      cmd+=" $@"
      break;; # }}}
    esac
    shift
  done # }}}
  cmd="${cmd/ssh /ssh -q $params }"
  $useShhClip && cmd="${cmd/ssh /sshc }"
  local params= oldTitle= err=
  [[ -n $TMUX && $(tmux display-message -p -t $TMUX_PANE -F '#{window_panes}') == 1 ]] && params+=" --set-pane --set-window --unlock-force" && oldTitle="$(tmux display-message -p -t $TMUX_PANE -F '#W')"
  set-title $params "ssh: $host"
  echormf "$cmd"
  eval $cmd
  err=$?
  [[ ! -z $oldTitle ]] && set-title --set-window "$oldTitle"
  return $err
} # }}}
_sshh "$@"

