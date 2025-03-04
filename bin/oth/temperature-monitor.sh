#!/usr/bin/env bash
# vim: fdl=0

pidFile="$TMP_MEM_PATH/.temperature.pid"
delay=30
logFile=
append=true
doPrint=false
oneShot=true
rawFormat=false
rawFormatFirst=false
isRunning=false
printHeader=
printHeaderL2=true
isStdout=true
out2dev=false
colorsOn=true
loopCnt=0

threshold_default=${TEMPERATURE_MONITOR_THRESHOLD_DEFAULT:-10}
if [[ -z $TEMPERATURE_MONITOR_THRESHOLDS ]]; then
  declare -A thresholds=(
    [acpitz]=$threshold_default
    [int3400]="-"
    [sen1]=$threshold_default
    [sen2]=$threshold_default
    [sen3]=$threshold_default
    [sen4]=$threshold_default
    [pch_cannonlake]=$threshold_default
    [b0d4]="-"
    [iwlwifi_1]=25
    [x86_pkg_temp]="-"
  )
else
  eval declare -A thresholds=($TEMPERATURE_MONITOR_THRESHOLDS)
fi

printer() { # {{{
  declare -a zone=(- $(cat /sys/class/thermal/thermal_zone*/type | sed 's/\([^ ]*\)\( .*\)\?/\L\1/' ) )
  declare -A maxs maxsT minsT maxsAt minsAt avg
  local lineNo=1 cnt=0 len=${#zone[*]}
  local l= i= ts= change= v= t= tUp= tDown= vs=
  while read l; do # {{{
    [[ $lineNo -gt 1 ]] || [[ $l =~ [a-zA-Z] ]] || lineNo=999
    if [[ $lineNo -le 2 ]] ; then # {{{
      lineNo=$((lineNo + 1))
      readarray -td' ' vs < <(echo "$l" | tr -s '[ ]')
      l=$(printfc "%ts:${vs[0]} ")
      for ((i=1; i<len; i++)); do
        [[ ${thresholds[${zone[i]}]} != '-' ]] || continue
        l+="${vs[i]} "
      done
      echo "$l"
      continue
    fi # }}}
    cnt=$((cnt + 1))
    readarray -td' ' vs < <(echo "$l")
    ts=${vs[0]} && ts=${ts%: }
    change=false
    declare -A entry=([TS]=${vs[0]})
    for ((i=1; i<len; i++)); do # {{{
      v=${vs[i]} && z=${zone[i]} && t=${thresholds[$z]}
      [[ $t == '-' ]] && continue
      [[ -z $t ]] && t=$threshold_default && thresholds[$z]=$t
      tUp=$t tDown=$t
      [[ $t == *:* ]] && tUp=${t%:*} && $tDown=${t#*:}
      avg[$z]=$((${avg[$z]:-0} + v))
      if [[ $v -gt $((${maxs[$z]:-0} + tUp)) || $v -lt $((${maxs[$z]:-200} - tDown)) ]]; then # {{{
        entry[$z]=$v
        maxs[$z]=$v
        change=true
      fi # }}}
      if [[ $v -le ${minsT[$z]:-200} ]]; then # {{{
        minsT[$z]=$v
        minsAt[$z]=$ts
      fi # }}}
      if [[ $v -gt ${maxsT[i]:-0} ]]; then # {{{
        maxsT[$z]=$v
        maxsAt[$z]=$ts
      fi # }}}
    done # }}}
    $change || continue
    l="$(printfc %ts:${entry[TS]}) "
    for ((i=1; i<len; i++)); do # {{{
      z=${zone[i]} && t=${thresholds[$z]}
      [[ ${thresholds[$z]} != '-' ]] || continue
      l+="$(printf "%2s " "${entry[$z]}")"
    done # }}}
    echo "$l"
  done # }}}
  printf "\n"
  (
    printf "maxs: " # {{{
    for ((i=1; i<len; i++)); do
      z=${zone[i]}
      [[ ! -z ${maxsT[$z]} ]] || continue
      printf "%s " "${maxsT[$z]}@${maxsAt[$z]}"
    done; printf "\n" # }}}
    printf "mins: " # {{{
    for ((i=1; i<len; i++)); do
      z=${zone[i]}
      [[ ! -z ${minsT[$z]} ]] || continue
      printf "%s " "${minsT[$z]}@${minsAt[$z]}"
    done; printf "\n" # }}}
    printf "avg: " # {{{
    for ((i=1; i<len; i++)); do
      z=${zone[i]}
      [[ ! -z ${avg[$z]} ]] || continue
      printf "%s " "$((${avg[$z]} / cnt))"
    done; printf "\n" # }}}
  ) | { [[ -t 1 ]] && column -t || cat; }
} # }}}
getGradientColor() { # {{{
  $isStdout || return
  $colorsOn || return
  [[ $1 == '-' ]] && get-color 'off' && return
  declare -A colors=(
    [40]="blue"
    [55]="green"
    [70]="yellow"
    [80]="HLSearch"
    [200]="red"
  )
  local t=$1 v=
  for v in $(echo ${!colors[*]} | tr ' ' '\n' | sort -n); do
    [[ $t -le $v ]] && get-color "${colors[$v]}" && return
  done
  get-color "white"
} # }}}

[[ -e $pidFile ]] && ps -p "$(cat $pidFile)" >/dev/null && isRunning=true
[[ -t 1 ]] || isStdout=false

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --raw) rawFormat=true; oneShot=true;;
  -1)    rawFormat=true; oneShot=true; rawFormatFirst=true;;
  -l  | --loop)      oneShot=false; colorsOn=false;;
  -h  | header)      printHeader=true;;
  -nh | --no-header) printHeader=false;;
  -c) append=false;;
  --log-file) logFile="$2"; shift;;
  --loop-cnt) loopCnt="$2"; shift;;
  -o1 | -o2) oneShot=false; printHeader=true; printHeaderL2=false; out2dev=true # {{{
    case $1 in
    -o1) logFile="/dev/stdout"; [[ -t 1 ]] || colorsOn=false;;
    -o2) logFile="/dev/stderr"; [[ -t 2 ]] || colorsOn=false;;
    esac;; # }}}
  -d) delay=$2; shift;;
  -p) doPrint=true;;
  -k) # {{{
    $isRunning || exit 0
    kill-rec $(cat $pidFile)
    rm -f $pidFile
    exit 0;; # }}}
  *) break;;
  esac; shift
done # }}}

if [[ -z $logFile ]]; then # {{{
  if $oneShot; then
    logFile=/dev/stdout
  else
    logFile="$TMP_MEM_PATH/.temperature.log"
  fi
fi # }}}

if ! $doPrint && ! $oneShot && ! $out2dev; then # {{{
  if $isRunning; then
    echor "Already running, so printing"
    doPrint=true
  elif [[ ! -t 0 ]]; then
    doPrint=true
  fi
fi # }}}
if $doPrint; then # {{{
  if [[ ! -t 0 ]]; then
    cat -
  elif [[ ! -e $logFile ]]; then
    exit 1
  elif $isRunning; then
    tail --pid $(cat $pidFile) -f $logFile
  else
    cat $logFile
  fi | printer -
  exit 0
fi # }}}

if $oneShot; then # {{{
  $isStdout || colorsOn=false
  if [[ -z $printHeader ]]; then # {{{
    printHeader=true
    $isStdout || printHeader=false
    $rawFormat && printHeader=false
  fi # }}}
  dbg --init -o1 --prefix=hide --ts=hide --colors=$colorsOn # }}}
else # {{{
  ! $isRunning || { echor "already running"; exit 1; }
  $out2dev || echo $$ >$pidFile
  [[ ! -e $logFile ]] || $append || rm $logFile
  if [[ -z $printHeader ]]; then # {{{
    printHeader=true
    [[ -e $logFile ]] && printHeader=false
  fi # }}}
  dbg --init -o1 --prefix=hide --ts-abs --colors=$colorsOn
fi # }}}

(
  sp=8
  if $printHeader; then # {{{
    l1= l2=
    for i in $(cat /sys/class/thermal/thermal_zone*/type | sed 's/\([^ ]*\)\( .*\)\?/\L\1/'); do
      [[ ${thresholds[$i]} != '-' ]] || continue
      l1+="$(printf "%-${sp}s " "${i:0:$sp}")"
      l2+="$(printf "%-${sp}s " "${thresholds[$i]}")"
    done
    dbg "$l1"
    $oneShot || ! $printHeaderL2 || dbg "$l2"
  fi # }}}
  while true; do # {{{
    sleep-precise -s
    readarray -t ty <<<$(cat /sys/class/thermal/thermal_zone*/type | sed 's/\([^ ]*\)\( .*\)\?/\L\1/')
    readarray -t te <<<$(cat /sys/class/thermal/thermal_zone*/temp | sed 's/...$//')
    if $rawFormat; then # {{{
      for i in ${!te[*]}; do
        [[ ${thresholds[${ty[i]}]} != '-' ]] || continue
        echo "${te[i]} ${ty[i]}"
      done \
      | sort -k1,1rn \
      | { if $rawFormatFirst; then head -n1; else cat -; fi } \
      | while read ite ity; do
        dbg "$(getGradientColor $ite)$ite $ity$(getGradientColor '-')"
      done
      break # }}}
    else # {{{
      l=
      for i in ${!te[*]}; do
        [[ ${thresholds[${ty[i]}]} != '-' ]] || continue
        l+="$(printf "%b%-${sp}s%b " "$(getGradientColor ${te[i]})" "${te[i]}" "$(getGradientColor '-')")"
      done
      dbg "$l"
      $oneShot && break
      if [[ $loopCnt -gt 0 ]]; then
        loopCnt=$((loopCnt - 1))
        [[ $loopCnt == 0 ]] && break
      fi
      sleep-precise $delay
    fi # }}}
  done # }}}
) >>$logFile

