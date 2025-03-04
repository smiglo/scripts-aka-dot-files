#!/usr/bin/env bash
# vim: fdl=0

_kill-rec() { # @@ # {{{
  if [[ "$1" == '@@' ]]; then # {{{
    pids="$(ps --no-headers -o pid,comm)"
    echo "$pids" | grep -v "$$"
    echo "-SIGTERM -SIGKILL -SIGABRT -9 --dbg"
    return 0
  fi # }}}
  local signal='-SIGTERM' verbose=false i=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --dbg)        verbose=true;;
    -*)           signal="$1";;
    *)            break;;
    esac; shift
  done # }}}
  [[ -z $1 ]] && echor "PID needed" && return 1
  for i; do
    local pids=$(pid-tree $i)
    echor -c $verbose "pids: [$pids]"
    kill $signal $pids >/dev/null 2>&1
    wait $pids >/dev/null 2>&1
  done
  return 0
} # }}}
_kill-rec "$@"

