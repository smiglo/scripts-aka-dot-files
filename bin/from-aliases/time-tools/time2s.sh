#!/usr/bin/env bash
# vim: fdl=0

_time2s() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    local t="now 0:00 15:00 @${EPOCHSECONDS:-$(epochSeconds)} 5m2s @"
    case $3 in
    --out | -o) echo "s abs abs-s delta";;
    --now)      echo "- 15:00 15h";;
    -s)         echo "$t";;
    --to-hms)   echo "$t";;
    --to-HMS)   echo "--utc --no-utc";;
    -c) # {{{
      if type color-list >/dev/null >&1; then
        color-list
      else
        echo $COLORS_BASIC_LIST
      fi;; # }}}
    *) # {{{
      case ${4:-$3} in
      --diff) echo "$t";;
      *)      echo "-s --diff --diff-HMS --is-hms --to-hms --to-HMS --now -o --out --hms-only -c $t 5m 1h2m3s";;
      esac;; # }}}
    esac
    return 0
  fi # }}}
  local colorP= color= coff=
  while [[ ! -z $1 ]]; do
    case $1 in
    -c) # {{{
      colorP=$2; shift
      color=$(get-color "$colorP")
      [[ ! -z $color ]] && coff=$COff;;# }}}
    -s) # {{{
      if time2s --is-hms $2; then
        time2s $([[ ! -z $colorP ]] && echo "-c $colorP") $2 -o s
      else
        echo "${color}$(date '+%s' -d "${2:-now}")${coff}"
      fi
      return 0;; # }}}
    --diff-HMS) # {{{
      [[ -z $2 ]] && return 1
      local diff=$(time2s --diff $2)
      time2s $([[ ! -z $colorP ]] && echo "-c $colorP") --to-HMS --utc $diff
      return 0;; # }}}
    --diff) # {{{
      local d1=$2
      local d2=$3
      [[ -z $d2 && ! -z $d1 ]] && d2=$d1 && d1="now"
      if [[ -z $d1 ]]; then
        d1="${EPOCHSECONDS:-$(epochSeconds)}"
      elif [[ $d1 == @* || $d1 =~ ^([0-9]{7,})$ ]]; then
        d1="${d1#@}"
      else
        d1="$(time2s -s "$d1")"
      fi
      if [[ -z $d2 ]]; then
        d2="$(time2s -s "today 0:00")"
      elif [[ $d2 == @* || $d2 =~ ^([0-9]{7,})$ ]]; then
        d2="${d2#@}"
      else
        d2="$(time2s -s "$d2")"
      fi
      echo "${color}$((d1-d2))${coff}"
      return 0;; # }}}
    --is-hms) # {{{
      [[ $2 =~ ^([0-9]+h){0,1}([0-9]+m){0,1}([0-9]+s){0,1}$ ]]
      return $?;; # }}}
    --to-HMS) # {{{
      shift
      local dateP="--utc"
      case $1 in
      --utc)    dateP="--utc"; shift;;
      --no-utc) dateP=""; shift;;
      '')       dateP="";;
      esac
      local s=${1:-${EPOCHSECONDS:-$(epochSeconds)}} dir=
      [[ $s == -* ]] && dir='-' && s=${s#-}
      echo "${color}$dir$(date $dateP +'%H:%M:%S' -d @$s)${coff}"
      return 0;; # }}}
    --to-hms) # {{{
      local s=$2 h= m= dir=
      [[ $s == *:* || $s == @* ]] && s=$(time2s --diff "$s")
      [[ $s == -* ]] && dir='-' && s=${s#-}
      h=$((s/3600)) && s=$((s-h*3600))
      m=$((s/60))   && s=$((s-m*60))
      [[ $h != 0 ]] && h="${h}h" || h=
      [[ $m != 0 ]] && m="${m}m" || m=
      [[ $s != 0 || ( -z $h && -z $m ) ]] && s="${s}s" || s=
      echo "${color}$dir$h$m$s${coff}"
      return 0;; # }}}
    *) break;;
    esac; shift
  done
  local ts= outForm= h= m= s= out= now=${EPOCHSECONDS:-$(epochSeconds)} dir=1 hms_is=false hms_only=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    @)          echo $now; return 0;;
    --out | -o) outForm=$2; shift;;
    --now)      [[ $2 != - ]] && now=${EPOCHSECONDS:-$(epochSeconds)}; shift;;
    --hms-only) hms_only=true;;
    *)          ts=$1; [[ $ts == -* ]] && dir=-1 && ts=${ts#-};;
    esac
    shift
  done # }}}
  [[ -z $ts ]] && ts='now' && [[ -z $outForm ]] && outForm='s'
  [[ -z $outForm ]] && outForm='abs'
  if [[ $ts =~ ^([0-9]+h){0,1}([0-9]+m){0,1}([0-9]+s){0,1}$ ]]; then # {{{
    h="${BASH_REMATCH[1]%h}" m="${BASH_REMATCH[2]%m}" s="${BASH_REMATCH[3]%s}"
    out="$((${h:-0}*60*60 + ${m:-0}*60 + ${s:-0}))"
    hms_is=true
    # }}}
  elif [[ $ts =~ ^([0-9]+)$ ]]; then # {{{
    if [[ $ts =~ ^([0-9]{7,})$ ]]; then
      now=$(time2s -s '0:00')
      out=$(time2s --diff "@$ts" "@$now")
    else
      out="$ts"
    fi # }}}
  else # {{{
    now=$(time2s -s '0:00')
    out=$(time2s --diff "$ts" "@$now")
  fi # }}}
  $hms_only && ! $hms_is && return 0
  case $outForm in # {{{
  s)      echo "${color}$out${coff}";;
  abs)    echo "${color}$(date +$TIME_FMT -d "@$((now+dir*out))")${coff}";;
  abs-s)  echo "${color}$(date +%s        -d "@$((now+dir*out))")${coff}";;
  delta)  echo "${color}$(time2s --diff "@$((now+dir*out))" "now")${coff}";;
  *)      echo "Unknown output form [$outForm]" >/dev/stderr && return 1;;
  esac # }}}
} # }}}
_time2s "$@"

