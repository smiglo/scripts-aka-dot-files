#!/usr/bin/env bash
# vim: fdl=0

_bck() { # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -s | --suffix) echo "~ _ __";;
    *) echo "-f -s --suffix"
    esac
    return 0
  fi # }}}
  local src= dst= suffix='~' force=false f= err=0
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -f) force=true;;
    -s | --suffix) suffix="$2"; shift;;
    *) break;;
    esac; shift
  done # }}}
  [[ ! -z $1 ]] || eval $(die "file missing")
  for f; do
    f="${f%/}"
    if [[ "$f" == *"$suffix" ]]; then
      src="$f"; dst="${f%$suffix}"
    elif [[ -e "$f$suffix" && ! -e "$f" ]]; then
      src="$f$suffix"; dst="$f"
    else
      src="$f"; dst="$f$suffix"
    fi
    $force && echo rm -f "$dst"
    [[ ! -e "$dst" ]] || { err=1; eval $(die -c "dst exists [$dst]"); }
    [[   -e "$src" ]] || { err=1; eval $(die -c "src not exists [$src]"); }
    mv "$src" "$dst" || err=2
  done
  return $err
} # }}}
_bck "$@"

