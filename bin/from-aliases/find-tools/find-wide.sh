#!/usr/bin/env bash
# vim: fdl=0

_find-wide() { # {{{
  local r= sl= cnt=
  if [[ -t 0 ]]; then
    $ALIASES_SCRIPTS/find-tools/find-short.sh "$@"
  else
    command cat -
  fi \
  | awk -F'/' '{print NF-1, $0}' \
  | sort -n -k1,1 \
  | cut -d' ' -f2-
} # }}}
_find-wide "$@"

