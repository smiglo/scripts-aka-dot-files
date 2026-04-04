#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == "@@" ]]; then # @@:new # {{{
  echo "--dry --verbose --silent"
  exit 0
fi # }}}

exec-verbose() { # {{{
  declare -a cmd=()
  cmd=( "$@" )
  $dry && verbose=true
  $verbose && echo "$ ${cmd[@]}"
  $dry && return
  local err=
  eval "${cmd[@]}" 2>&1
  err=$?
  (( err == 0 )) || echo "# errno: $err"
  return $err
} # }}}

verbose=true
dry=false
while [[ -n $1 ]]; do # {{{
  case $1 in
  --dry) dry=true; verbose=true;;
  --silent) verbose=false;;
  --verbose) verbose=true;;
  *) break;;
  esac; shift
done # }}}

if [[ -n $@ ]]; then # {{{
  exec-verbose "$@"
  exit 0
fi # }}}
[[ -t 0 ]] && die "no commands"
colorP=
[[ -t 1 ]] || colorP="--plain"
cat - | while read -r line; do
  case $line in
  '') continue;;
  '#'*) echo "$line";;
  *)
    exec-verbose $line || die $colorP "failed on '$line'"
    echo;;
  esac
done
