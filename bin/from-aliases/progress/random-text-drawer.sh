#!/usr/bin/env bash
# vim: fdl=0

_random-text-drawer() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -d) echo "0.01 0.05 0.1 0.3";;
    --cnt) echo "10 20 100";;
    --state | --print | --final) echo "CURRENT-STATE";;
    *) echo "-d --cnt --once --state --final --infinity --print --no-tput";;
    esac
    return 0
  fi # }}}
  local jM="$((8 + RANDOM%15))" delay=0.1 once=false state= s= ns= final=false useTput=${USE_TPUT:-true} l=0
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -d)      delay="$2"; shift;;
    --cnt)   jM="$2"; shift;;
    --once)  once=true;;
    --state) state="$2"; once=true; shift;;
    --final) final=true; state="$2"; once=true; shift;;
    --infinity) jM=0; once=true;;
    --no-tput)  useTput=false;;
    --print) # {{{
      eval "$2"
      $useTput && tput rc
      printf "%s" "$ns"
      [[ "$ns" != "$s" ]]
      return;; # }}}
    *) s="$@"; l=${#s}; shift $#; break;;
    esac; shift
  done # }}}
  [[ -z $s && ! -t 0 ]] && s="$(cat -)" && l=${#s}
  if [[ $jM -gt 0 && $jM -lt 2 ]]; then
    jM=2
  elif [[ $jM == 0 ]]; then
    once=true
  fi
  local maxJ=() j=0 i= isHex=false
  local arr_a_z="abcdefghijklmnopqrstuvwz"
  local arr_A_Z="${arr_a_z^^}"
  local arr_0_9="0123456789"
  local arr_hex="${arr_0_9}abcdef"
  local arr_special="-_=+{},.<>/?!@#%^&*()~"
  if [[ -z "$state" ]]; then # {{{
    [[ -z $s ]] && return 1
    local m=
    for ((i=0; i<l; i++)); do
      m=$jM
      if [[ $jM -gt 0 ]]; then # {{{
        case $(( i % 4 )) in
        0) m=$(( $(get-range-value $((jM/2))) ));;
        1) m=$(( $(get-range-value $((jM-4))) ));;
        2) m=$(( $(get-range-value $((jM-7))) ));;
        *) m=$(( 4 + $(get-range-value $((jM-4))) ));;
        esac
        [[ $m -le 0 || $m -ge $jM ]] && m=$((jM-1))
      fi # }}}
      maxJ[i]=$m
    done
    i=$(get-range-value $l)
    maxJ[i]=$jM
    maxJ[$(( (i + $(get-range-value $((l-2))) ) % l))]=$jM
    if [[ $s =~ ^'0x'[0-9A-F]+$ || $s =~ ^'0x'[0-9a-f]+$ ]]; then
      isHex=true
    fi
    trap "if $useTput; then  ${TPUT_USE_CVVIS:-true} && tput cvvis || reset; fi; echo >$out; return 0;" INT
    $useTput && tput sc && tput civis
    # }}}
  else # {{{
    eval "$state"
    l="${#s}"
  fi # }}}
  [[ -z $s ]] && return 1
  $final && jM=-1
  local wasRandom= startTimeUS=${EPOCHREALTIME/[,.]}
  while true; do # {{{
    sleep-precise -s
    ns= wasRandom=false
    d=$RANDOM
    if [[ ( $j != $jM || $jM == 0 ) ]] && ! $final; then
      for ((i=0; i<l; i++)); do
        local c="${s:$i:1}"
        local b=0 r=0 arr=
        if $isHex; then
          if [[ $i -le 1 ]]; then
            r=-1
          else
            arr=$arr_hex
            [[ $s =~ ^'0x'[0-9A-F]+$ ]] && arr="${arr^^}"
          fi
        fi
        if [[ $r != -1 && ( $j -le ${maxJ[i]} || $jM == 0 ) ]]; then # {{{
          wasRandom=true
          if [[ -z $arr ]]; then
            case $c in
            [A-Z]) arr=$arr_A_Z;;
            [a-z]) arr=$arr_a_z;;
            [0-9]) arr=$arr_0_9;;
            *)     arr=$arr_special;;
            esac
          fi
          r=${#arr}
          d=$(((d + $(get-range-value $r)) % r))
          c="${arr:$d:1}"
        fi # }}}
        ns+="$c"
      done
    else
      ns="$s"
    fi
    if ! $once || $final; then # {{{
      $useTput && tput rc
      echo -n "$ns"
    else
      echo "ns=\"$ns\""
    fi # }}}
    [[ $jM != -1 ]] && j=$((j+1))
    if [[ $j -gt $jM ]] || ! $wasRandom || $once; then # {{{
      break
    fi # }}}
    sleep-precise $delay
  done # }}}
  if $once && ! $final; then # {{{
    echo "s=\"$s\""
    echo "useTput=$useTput"
    declare -p maxJ
    echo "j=$j jM=$jM isHex=$isHex"
  else
    printf "\n"
    if $useTput; then
      ${TPUT_USE_CVVIS:-true} && tput cvvis || reset
    fi
    trap - INT
  fi # }}}
} # }}}
_random-text-drawer "$@"

