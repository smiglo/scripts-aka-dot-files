#!/usr/bin/env bash
# vim: fdl=0

import-module time-tools

_loop() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -c | --cnt) echo "1 5 10 100";;
    -m | --msg) echo "MSG";;
    --retry)    echo "1 5 30s 1m 0.5";;
    --progress-params) echo "PROGRESS-PARAMS";;
    --on-change) echo "@@-f"; get-file-list --pwd $TMP_MEM_PATH 'change-monitor.*';;
    *)
      echo "-c --cnt -m --msg -s -ss CMD --progress-params --on-change --run-first --wait --clear +time +ts --stop-on-ok +s --stop-on-err --retry"
      echo --until{,={1,5,30s,1m}}
      ;;
    esac
    return 0
  fi # }}}
  local cnt=-1 msg= cmd= stopOnErr=false stopOnOk=false silent=0 progressParams= waitOnFirst=false monitoredFile= addTime=false addTS=false clearOnStart=false retry=0
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -c | --cnt) cnt="$2"; shift;;
    -m | --msg) msg="$2"; shift;;
    --retry)    retry="$2"; shift;;
    --progress-params) progressParams+=" $2"; shift;;
    --on-change)   monitoredFile="$2"; shift;;
    --run-first)   waitOnFirst=false;;
    --wait)        waitOnFirst=true;;
    --clear)       clearOnStart=true;;
    +time)         addTime=true;;
    +ts)           addTS=true;;
    --stop-on-err) stopOnErr=true;;
    --stop-on-ok)  stopOnOk=true;;
    +s)            stopOnOk=true;;
    --until=*)     retry=${1#--until=} ;&
    --until)       stopOnOk=true; stopOnErr=false; addTime=true; [[ $retry == 0 ]] && retry=5;;
    -s)            silent=$((silent+1));;
    -ss)           silent=2;;
    *)             cmd="$@"; shift $#;;
    esac; shift
  done # }}}
  [[ -z $cmd ]] && return 1
  if [[ ! -z $monitoredFile ]]; then
    [[ $monitoredFile == 'change-monitor.'* && ! -e $monitoredFile && -e $TMP_MEM_PATH/$monitoredFile ]] && monitoredFile="$TMP_MEM_PATH/$monitoredFile"
    [[ $monitoredFile == '-' ]] && monitoredFile="${cmd%% *}"
    progressParams+=" --file-mod $monitoredFile"
  fi
  local err=0 devOut=/dev/stdout devErr=/dev/stderr
  local progr_colors=($CYellow $CPurple $CBlue $CGreen) progr_i=0
  [[ $silent -ge 1 ]] && devOut=/dev/null
  [[ $silent -ge 2 ]] && devErr=/dev/null
  if [[ -z $msg ]]; then # {{{
    msg="${cmd%% *}"
    [[ $msg == */* ]] && msg="$(basename "$msg")"
  elif [[ $msg == '-' ]]; then
    msg=
  fi # }}}
  local ts="0.000"
  getMsg() { # {{{
    local m=
    if [[ $err == 0 ]]; then
      m="$(cl ok $err)|"
    else
      m="$(cl err $err)|"
    fi
    $addTime && m+="$(cl info $(date +$TIME_FMT))|"
    $addTS && m+="$(cl ts $ts)|"
    [[ ! -z $msg ]] && m+=" $msg"
    echo "$m"
  } # }}}
  local key=
  while true; do # {{{
    ! $waitOnFirst || key="$(progress --wait $retry --key --keys "cC" --no-err --color "${progr_colors[progr_i]}" --msg "$(getMsg)" $progressParams)" || break
    progr_i="$(((progr_i+1)%${#progr_colors[*]}))"
    case $key in
    c) clear;;
    C) clear; continue;;
    *) $clearOnStart && clear;;
    esac
    waitOnFirst=true
    ts="$(get-ts)"
    eval $cmd >$devOut 2>$devErr
    err=$?
    ts="$(get-ts -o s.ms $ts)"
    if [[ $err == 0 ]]; then
      $stopOnOk && break
    else
      $stopOnErr && break
    fi
    if [[ $cnt -gt 0 ]]; then
      cnt=$((cnt - 1))
      [[ $cnt == 0 ]] && break
    fi
  done # }}}
  getMsg >&2
  return $err
} # }}}
_loop "$@"

