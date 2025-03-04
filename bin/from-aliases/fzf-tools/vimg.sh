#!/usr/bin/env bash
# vim: fdl=0

_vimg() { # {{{
  local search= ret= max="${VIMG_MAX:-250000}"
  while [[ ! -z $1 ]]; do
    case $1 in
    -n) shift; max="$1";;
    *)  break;
    esac
    shift
  done
  search="${@:-$VIMG_SEARCH}"
  [[ -z $search ]] && search="^"
  ret=($(ag --nobreak --noheading $search \
    | sort -t ':' -k1,1 -k2,2n \
    | head -n $max \
    | fzf --query="$VIMG_QUERY" --no-sort --multi --select-1 --exit-0 \
    | awk -F: '{print $1, $2}'))
  if [[ -n $ret ]]; then
    local i=0 file= line= params= v=
    if [[ $BASH_VERSINFO -ge 4 ]]; then
      declare -A retMap
      while [[ $i -lt ${#ret[*]} ]]; do
        file="${ret[$i]}" line="${ret[$(($i+1))]}" v="${retMap[$file]}"
        [[ -z $v || $line -lt $v ]] && retMap[$file]="$line" # Can "or" condition even happen?
        i="$(($i+2))"
      done
      for i in ${!retMap[*]}; do
        file="$i" line="${retMap[$file]}"
        [[ -z $params ]] && params+=" $file +$line" || params+=" +\"tabnew +$line $file\""
        params+=" -c 'normal! zv'"
      done
      unset retMap
    else
      while [[ $i -lt ${#ret[*]} ]]; do
        file="${ret[$i]}" line="${ret[$(($i+1))]}"
        [[ -z $params ]] && params+=" $file +$line" || params+=" +\"tabnew +$line $file\""
        params+=" -c 'normal! zv'"
        i="$(($i+2))"
      done
    fi
    params+=" +tabfirst"
    [[ ! -z $params ]] && _vim $params
  fi
} # }}}
_vimg "$@"

