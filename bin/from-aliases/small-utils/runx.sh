#!/usr/bin/env bash
# vim: fdl=0

import-module echor

_runx() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "-v -vv --cmd --cnt"
    return 0
  fi # }}}
  local c= cmd=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -v)    echormf -M + 1;;
    -vv)   echormf -M + 2;;
    --cmd) shift; cmd="$1"; break;;
    --cnt) shift; c="$1";;
    *) # {{{
      if [[ -z $c ]]; then
        c="$1"
      else
        cmd="${@@Q}"
        break
      fi;; # }}}
    esac; shift
  done # }}}
  [[ -z $c   ]] && echormf 0 "number of iterations not set" && return 1
  [[ -z $cmd ]] && echormf 0 "command not set" && return 1
  echormf "cnt: $c, cmd: $cmd"
  local n= err=0
  for ((n=0; n<$c; n++)); do
    eval "$cmd" || { err=$?; break; }
  done
  return $err
} # }}}
_runx "$@"

