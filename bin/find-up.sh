#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # @@:new # {{{
  echo "--up-to -n --pwd"
  exit 0
fi # }}}
upTo=$HOME what= cwd=$PWD silent=true steps=-1 i=
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --up-to) upTo="${2%/}"; shift;;
  -n)      steps="$2"; upTo=; shift;;
  --pwd)   cwd="$2"; shift;;
  *)       what+=" $1";;
  esac; shift
done # }}}
[[ ! -z $what ]] || die 10 "nothing to looking for"
[[ -e $cwd ]] || die 10 "cwd [$cwd] not exist"
[[ $cwd == $upTo/* || $cwd == $upTo ]] || die 10 "cwd [$cwd] outside of up-to [$upTo]"
while [[ ( $steps == -1 && ( $cwd == $upTo/* || $cwd == $upTo ) ) || $steps -gt 0 ]]; do
  [[ $steps -gt 0 ]] && steps=$((steps - 1))
  for i in $what; do
    [[ -e $cwd/$i ]] && echo "$cwd/$i" && exit 0
  done
  cwd="${cwd%/*}"
done
die "'$(echo "$what" | xargs)' not found"
