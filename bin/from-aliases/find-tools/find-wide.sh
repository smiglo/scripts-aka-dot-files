#!/usr/bin/env bash
# vim: fdl=0

_find-wide() { # {{{
  local r= sl= cnt=
  if [[ -t 0 ]]; then
    find-short "$@"
  else
    command cat -
  fi \
  | sed -e 's|^\./||' -e 's|/$||' \
  | while read r; do
    sl=${r//[^\/]}
    cnt=${#sl}
    echo "$cnt $r"
  done \
  | sort -k1,1n -k2,2 \
  | cut -d' ' -f2-
} # }}}
_find-wide "$@"

