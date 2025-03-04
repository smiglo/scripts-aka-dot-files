#!/usr/bin/env bash
# vim: fdl=0

_date-pipe() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    +) echo "%Y-%m-%d %Y.%m.%d %H%M%S";;
    *) echo "+ -d +t +d +dt --orig --ts --ts-earliest -s --sort --colors";;
    esac
    return 0
  fi # }}}
  local p="$DATE_FMT" showOrig=false addTs=false removeTs=false findEarliest=false c=$(get-color ts) c2=$CGreen coff=$COff sort=false autoColors=true
  [[ -z $1 && -t 0 ]] && eval date +$p && return
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    +t)       p="$TIME_FMT";;
    +d)       p="$DATE2_FMT";;
    +dt)      p="$DATE_FMT";;
    +)        shift; p="$1";;
    +*)       p="${1#+}";;
    --orig)   showOrig=true;;
    --ts)     addTs=true; removeTs=false;;
    --ts-earliest) addTs=true; removeTs=false; findEarliest=true;;
    -s | --sort)   sort=true; ! $addTs && removeTs=true; addTs=true;;
    --colors) autoColors=false;;
    *)        break;;
    esac
    shift
  done # }}}
  [[ -t 0 ]] && { date "+$p" "$@"; return; }
  [[ ! -t 1 ]] && $autoColors && c= && c2= && coff=
  local l= n= i= dFirst=0 dLast=0
  cat - | while IFS= read -r l; do
    n="$l"
    dLast=$dFirst
    dFirst=0
    for i in $(echo "$l" | grep -o "\<[1-9][0-9]\{8,12\}\(\.[0-9]\+\)\?s\?\>" | sed 's/\(.*\)\..*/\1/'); do
      is=${i/s}
      if [[ $dFirst == 0 ]] || ( $findEarliest && [[ $is -lt $dFirst ]] ); then
        dFirst=$is
      fi
      local dd="$(date "+$p" -d @$is)"
      n=$(echo "$n" | sed 's/'$i'/'$c$dd$coff'/g');
      [[ ! -z $c ]] && l=$(echo "$l" | sed 's/'$i'/'$c$i$coff'/g');
    done
    [[ $dFirst == 0 ]] && dFirst=$dLast
    echo "$($addTs && [[ $dFirst != 0 ]] && echo "$c$dFirst$coff : ")$($showOrig && echo "$l :: ")$n" >/dev/stdout
  done \
    | { if $sort; then sort -k1,1n; else cat -; fi; } \
    | { if $removeTs; then cut -d' ' -f3-; else cat -; fi; } \
    | { if [[ ! -z $c2 ]]; then sed 's/\<[0-9]\{8\}-\?[0-9]\{6\}\>/'$c2'\0'$coff'/g'; else cat -; fi; }
} # }}}
_date-pipe "$@"

