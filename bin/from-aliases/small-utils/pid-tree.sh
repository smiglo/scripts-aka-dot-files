#!/usr/bin/env bash
# vim: fdl=0

_pid-tree() { # {{{
  local p= pp= pids=
  declare -A childs
  walk() { # {{{
    echo "$pids" | grep -q "^\s*$1\s" || return
    echo $1
    local p=
    for p in ${childs[$1]}; do
      walk $p
    done
  } # }}}
  pids="$(ps -e -o pid=,ppid=)"
  while read p pp; do
    [[ $p != $BASHPID ]] || continue
    childs[$pp]+="$p "
  done <<<"$pids"
  for p in "${@:-$$}"; do
    walk $p
  done
} # }}}
_pid-tree "$@"


