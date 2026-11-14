#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  echo "-v -vv --cmd --cnt"
  exit 0
fi # }}}
c= cmd= verbose=0
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -v)    ((++verbose));;
  -vv)   verbose=2;;
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
[[ -z $c   ]] && die "number of iterations not set"
[[ -z $cmd ]] && die "command not set"
echoe $((verbose >= 0)) -f "cnt: $c, cmd: $cmd"
n= err=0
for ((n=0; n<$c; n++)); do
  eval "$cmd" || { err=$?; break; }
done
return $err
