#!/usr/bin/env bash
# vim: fdl=0

# INIT # {{{
DATE_FILE=$TMP_PATH/.repo-update
MIN_DELTA="${BASH_UPDATE_TIME:-"$((7*60*60*24))"}"
created=false
forced=false
ask=true
do_install=false
currentTime=0
# }}}
! declare -f echorm >/dev/null 2>&1 && [[ -e $ECHOR_PATH/echor ]] && source $ECHOR_PATH/echor
# Functions # {{{
if ! declare -f epochSeconds >/dev/null 2>&1; then # {{{
  epochSeconds() {
    date +%s
  }
fi # }}}
do_update() { # {{{
  pwd=$PWD
  local i
  for i in $BASH_UPDATE_REPOS; do
    [[ ! -e $i ]] && echor "Repository ($i) does not exist" && continue
    cd $i
    git sync --interactive --skip-backup
  done
  cd $pwd
} # }}}
saveTime() { # {{{
  [[ $currentTime == 0 ]] && currentTime="${EPOCHSECONDS:-$(epochSeconds)}"
  if [[ -e $DATE_FILE ]] && grep -q '^tLastUpdateTime=' $DATE_FILE; then
    sed -i 's/^tLastUpdateTime=.*/tLastUpdateTime='$currentTime'/' $DATE_FILE
    return
  fi
  echo "tLastUpdateTime=$currentTime" >> $DATE_FILE
} # }}}
checkTime() { # {{{
  local tLastUpdateTime="0"
  currentTime="${EPOCHSECONDS:-$(epochSeconds)}"
  [[ ! -e $DATE_FILE ]] && echo "tLastUpdateTime=0" > $DATE_FILE
  $forced && return 0
  if ${SETUP_UPDATER_ASK_EVERYDAY:-true}; then
    local lastMod=0
    [[ -e $DATE_FILE ]] && lastMod="$(date +%Y%m%d -d @$(stat -c %Y $DATE_FILE))"
    [[ "$(date +%Y%m%d)" == "$lastMod" ]] && return 1
    if $ask; then
      local msg="$(echor --colors=force -1 "Update repos [Yn]")"
      $ALIASES progress --wait 5s --key --no-err --msg "$msg" --out /dev/stderr || return 1
    fi
  else
    source $DATE_FILE
    tLastUpdateTime=$(($tLastUpdateTime+$MIN_DELTA))
    [[ $currentTime -lt $tLastUpdateTime ]] && return 1
  fi
  return 0
} # }}}
check() { # {{{
  [[ $BASH_UPDATE_TIME == 0 ]] && return 1
  [[ -z $BASH_UPDATE_REPOS ]] && return 1
  checkTime || return 1
  echor "Environment auto-update"
  net --wait=5s || return 1
  return 0
} # }}}
start() { # {{{
  check || return 1
  mutex-init "setup-update" --auto-clean-after $((10*60))
  mutex-lock || return 1
  local key=$SETUP_UPDATER_KEY
  if [[ ! -n "$SSH_CLIENT" && ! -z $key ]]; then
    [[ $key == /* ]] || key="$HOME/.ssh/keys/$key"
    [[ ! -e $key ]] && echor "Updater key not set" && return 1
    if ! ssh-add -l | grep $(ssh-keygen -lf $key | cut -d' ' -f2 ) >/dev/null; then
      ssh-add $key >/dev/null 2>&1
    fi
  fi
  saveTime
  do_update
  [[ ! -z $key ]] && ssh-add -d $key >/dev/null 2>&1 || true
  mutex-unlock
  mutex-deinit
  if $do_install; then
    $MY_PROJ_PATH/scripts/bin/mk_install_scripts.sh --all-no --silent --no-exec
  fi
} # }}}
# }}}
# MAIN # {{{
echorm --name repo-update -M +
while [[ ! -z $1 ]]; do
  case $1 in
  --force|-f) forced=true;;
  --install)  do_install=true;;
  --saveTime) saveTime; exit 0;;
  -y)         ask=false;;
  esac
  shift
done

start
# }}}

