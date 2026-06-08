#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # @@:new # {{{
  echo "+f"
  exit 0
fi # }}}

cmd="fd" params=

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  +f) cmd="find"; shift; break;;
  *) break;;
  esac; shift
done # }}}

out() { # {{{
  fzf --prompt "find> " -m --sort --ansi
} # }}}

case $cmd in
fd) params+=" --type file --type symlink";;
*)
esac

if [[ -t 1 ]]; then # {{{
  case $cmd in
  fd) params+=" --color=always";;
  esac
else
  out() { cat -; }
fi # }}}

$cmd $params "$@" | out
