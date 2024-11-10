#!/usr/bin/env bash

params="$RSYNC_DEFAULT_PARAMS"
params+=" --del"
params+=" --exclude=*.swp"
params+=" --exclude=*.swo"
params+=" --exclude=Session.vim"

delay="20"
src="."
dst=
fileTrigger=BUILDER_MAKE_BUILD_TRIGGER
cmdAfter=

if [[ $1 == '@@' ]]; then
  ret="--delay --src --dst --params --trigger --cmd"
  case $3 in
    --src|--dst) ret="@@-f";;
    --trigger)   ret="@@-f";;
    --params)    ret="";;
    --delay)     ret="1 3 5 10 15 20 30 45 60 120 300 600";;
    --cmd) ret="@@-W";;
  esac
  echo $ret
  exit 0
fi

while [[ ! -z $1 ]]; do
  case $1 in
    --delay)   shift; delay="$1";;
    --src)     shift; src="$1";;
    --dst)     shift; dst="$1";;
    --params)  shift; params="$1";;
    --trigger) shift; fileTrigger="$1";;
    --cmd)     shift; cmdAfter="$1";;
  esac
  shift
done

[[ -z $dst ]] && echo "Destination not specified" && exit 1

params+=" --exclude=$fileTrigger"

cmd="rsync $params $src $dst"

sha=0
shaOld=0
timeout=false
wasTheSame=false
wasOk=false
displayFull=false

shopt -s expand_aliases

while true; do
  time=$(date +"%H:%M:%S")
  sha=$(find $src -type f ! \( -iname *.swp -or -iname *.swo -or -iname Session.vim -or -iname $fileTrigger \) -print0 | sort -z | xargs -0 shasum | shasum | sed 's/  -$//')
  if [[ $sha != $shaOld ]]; then
    ( $timeout || $wasTheSame ) && echo
    $displayFull && echo -n "$CGreen$time$COff: $cmd" || echo -n "$CGreen$time$COff: rsync $src $dst"
    eval $cmd >/dev/null 2>&1
    [[ $? == 0 ]] && wasOk=true || wasOk=false
    if $wasOk && [[ ! -z $cmdAfter ]]; then
      eval $cmdAfter
      [[ $? == 0 ]] && wasOk=true || wasOk=false
    fi
    if $wasOk; then
      shaOld=$sha
      wasTheSame=false
      echo "  [${CGold}DONE${COff}]"
    else
      echo "  [${CRed}FAIL${COff}]"
    fi
  else
    if ! $wasTheSame; then
      echo -n "$(tput sc)"
      wasTheSame=true
    else
      echo -n "$(tput rc)"
      echo -n "$CRed$time$COff: The same"
      read -s -t 1
      echo -n "$(tput rc)"
    fi
    echo -n "$CGreen$time$COff: The same"
  fi
  key=
  [[ ! -z $fileTrigger && -e $fileTrigger ]] && rm -f $fileTrigger
  read -s -t $delay key
  [[ $? == 0 ]] && timeout=false || timeout=true
  if $timeout; then
    [[ ! -z $fileTrigger && -e $fileTrigger ]] && timeout=false && key="f"
  fi
  if ! $timeout; then
    case $key in
    q|Q) break;;
    f|F) shaOld=0;;
    esac
  fi
done
echo

