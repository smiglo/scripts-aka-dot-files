#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == "@@" ]]; then # @@:new # {{{
  case $2 in
  -0 | --ts0) echo "DATE";;
  -f | --file) get-file-list '*.log';;
  -p | --prec) echo 3 4 6 9 12;;
  -r | --reset-on) echo "REG-EXP";;
  --date-extractor) echo "CMD";;
  --round) echo {m,u,n}s none{,-{m,u,n}s};;
  esac
  exit 0
fi # }}}

cleanup() { # {{{
  exec {DATE_PROC[1]}>&- 2>/dev/null
  exec {DATE_PROC[0]}<&- 2>/dev/null
  kill "$DATE_PROC_PID" 2>/dev/null
  wait "$DATE_PROC_PID" 2>/dev/null || true
} # }}}
dateExtractorDefault() { # {{{
  read -r aDate rest <<<"$line"
} # }}}
getTS() { # {{{
  local input="$1" resp
  echo "$input" >&"${DATE_PROC[1]}"
  if read -r resp <&"${DATE_PROC[0]}"; then
    if [[ $resp =~ ^[0-9]+$ ]]; then
      REPLY="$resp"
      return 0
    fi
  fi
  REPLY=""
  return 1
} # }}}
putLine() { # {{{
  local diff="$1" rest="$3"
  if $addTS || [[ -z $diff ]]; then
    rest="$2 $3"
  fi
  if [[ -n $diff ]]; then
    if (( decPoint > 0 )); then
      if (( ${#diff} > decPoint )); then
        diff="${diff:0:-$decPoint}.${diff:$((${#diff}-$decPoint))}"
      else
        printf -v diff "0.%0${decPoint}d" $diff
      fi
    fi
    printf "%${prec}s %s\n" "$diff" "$rest"
  else
    printf "%${prec}s %s\n" " " "$rest"
  fi
} # }}}

add=false
addTS=false
dateExtractor="dateExtractorDefault"
diffEach=false
file=
prec=
resetOn=
skipInvalid=false
timeConverted=false
ts0=
tsRound="ms"
verbose=false

while [[ -n $1 ]]; do # {{{
  case $1 in
  -0 | --ts0) [[ $2 == ^[0-9]+$ ]] && ts0=$(date +"%s%N" -d "@$2") || ts0=$(date +"%s%N" -d "$2"); shift;;
  -f | --file) file=$2; shift;;
  -p | --prec) prec=$2; shift;;
  -r | --reset-on) resetOn="$2"; shift;;
  -v | --verbose) verbose=true;;
  --add) addTS=true;;
  --date-extractor) dateExtractor="$2"; shift;;
  --diff-each) diffEach=true;;
  --skip) skipInvalid=true;;
  --round) tsRound="$2"; shift;;
  --time-converted) timeConverted=true;;
  *) file="$1"; break;;
  esac; shift
done # }}}

[[ -z $file ]] && [[ ! -t 0 ]] && file="/dev/stdin"
[[ -e $file ]] || die "input not specified"

case $tsRound in
ms | none-ms | none)
  decPoint=3; decDiv=1000000;;
us | none-us)
  decPoint=6; decDiv=1000;;
ns | none-ns)
  decPoint=9; decDiv=1;;
*)
  die "wrong round format '$tsRound'";;
esac
[[ -n $prec ]] || prec=$((decPoint+3))
if [[ $tsRound == none* ]]; then
  decPoint=0
else
  ((prec+=1))
fi

declare -i tsLine=

coproc DATE_PROC { stdbuf -oL date +"%s%N" -f - 2>&1; }
trap cleanup EXIT


while read -r line; do
  [[ -n $line ]] || continue
  aDate= rest=
  $dateExtractor
  [[ -n $aDate ]] || continue
  tsLine=-1
  if $timeConverted; then
    tsLine=$aDate
  elif getTS "$aDate"; then
    tsLine=$REPLY
  fi
  if (( $tsLine == -1 )); then # {{{
    if ! $skipInvalid; then
      echoe $verbose "cannot get ts from '$aDate $rest'"
      putLine "" "$aDate" "$rest"
    fi
    continue
  fi # }}}
  tsLine=tsLine/decDiv
  [[ -n $resetOn && $rest =~ $resetOn ]] && ts0=
  if [[ -z $ts0 ]]; then
    ts0=$tsLine
    putLine "0" "$aDate" "$rest"
  else
    putLine "$((tsLine - ts0))" "$aDate" "$rest"
  fi
  if $diffEach; then
    ts0=$tsLine
  fi
done <$file
