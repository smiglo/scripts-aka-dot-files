#!/usr/bin/env bash
# vim: fdl=0

_status-wait-for() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "-s --check-last --loop -e"
    echo "-f -i --shared"
    return 0
  fi # }}}
  local l= expected= statusP="-i" n="-0" silent=false loop=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -s)           silent=true;;
    --check-last) n="-1";;
    --loop)       loop=true;;
    -e)           expected="$2"; shift;;
    *) # {{{
      if [[ -z $expected ]]; then
        expected="$1"
      else
        statusP="$@"; shift $#
      fi;; # }}}
    esac; shift
  done # }}}
  [[ -z $expected ]] && return 1
  $loop && silent=false
  (
    while IFS= read -r l; do
      [[ "$l" =~ $expected ]] || continue
      $silent || echo "$l"
      $loop   || break
    done < <(eval status --out -n $n $statusP)
  )
} # }}}
_status-wait-for "$@"

