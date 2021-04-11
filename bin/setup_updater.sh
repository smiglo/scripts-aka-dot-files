#!/usr/bin/env bash
# vim: fdl=0

# INIT {{{
DATE_FILE=$TMP_PATH/.date-update
MIN_DELTA="${BASH_UPDATE_TIME:-"$((7*60*60*24))"}"
created=false
forced=false
do_install=false
currentTime=0
# }}}
# Functions {{{
do_update() { # {{{
  pwd=$PWD
  local i
  for i in $BASH_UPDATE_REPOS; do
    [[ ! -e $i ]] && echo "Repository ($i) does not exist" && continue
    cd $i
    git sync --interactive --skip-backup
  done
  cd $pwd
} # }}}
saveTime() { # {{{
  [[ $currentTime == 0 ]] && currentTime="$(date +"%s")"
  echo $currentTime > $DATE_FILE
} # }}}
checkTime() { # {{{
  local lastUpdateTime=
  currentTime="$(date +"%s")"
  [[ ! -e $DATE_FILE ]] && echo "0" > $DATE_FILE
  lastUpdateTime="$(cat $DATE_FILE)"
  lastUpdateTime=$(($lastUpdateTime+$MIN_DELTA))
  $forced && lastUpdateTime="0"
  [[ $currentTime -lt $lastUpdateTime ]] && return 1
  return 0
} # }}}
waitForLan() { # {{{
  local delay=1
  local cnt=5
  local msg=false
  while [[ $cnt > 0 ]]; do
    ping -c 1 8.8.8.8 >/dev/null 2>&1 && return 0
    ! $msg && echo "Wait for LAN..." && msg=true
    sleep $delay
    cnt=$(($cnt-1))
  done
  echo "No ethernet connection"
  return 1
} # }}}
check() { # {{{
  [[ $BASH_UPDATE_TIME == 0 ]] && return 1
  [[ -z $BASH_UPDATE_REPOS ]] && return 1
  checkTime || return 1
  echo "Environment auto-update"
  waitForLan || return 1
  return 0
} # }}}
start() { # {{{
  check || return 1
  source $SCRIPT_PATH/bash/aliases.d/mutex-locking
  mutex_init "setup-update" --auto-clean-after $((10*60))
  mutex_lock || return 1
  local key=
  if [[ ! -n "$SSH_CLIENT" ]]; then
    local KEY_PATH=$SETUP_UPDATER_KEY
    [[ ! -e $KEY_PATH ]] && echo "Could not add ssh key" && return 1
    if ! ssh-add -l | command grep $(ssh-keygen -lf $KEY_PATH | cut -d' ' -f2 ) >/dev/null; then
      key=$KEY_PATH
      ssh-add $key >/dev/null 2>&1
    fi
  fi
  saveTime
  do_update
  [[ ! -z $key ]] && ssh-add -d $key >/dev/null 2>&1 || true
  $do_install && $MY_PROJ_PATH/scripts/bin/mk_install_scripts.sh --all-no --silent --no-exec
} # }}}
# }}}
# MAIN {{{
while [[ ! -z $1 ]]; do
  case $1 in
  --force|-f) forced=true;;
  --install)  do_install=true;;
  --saveTime) saveTime; exit 0;;
  esac
  shift
done

start
# }}}

