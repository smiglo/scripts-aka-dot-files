#!/usr/bin/env bash
# vim: fdl=0

_cat() { # {{{
  if [[ $1 == '@@' ]]; then
    echo "@@-f"
    return 0
  fi
  local bcUse=false bcP="--paging=auto --pager=less"
  if [[ -z $BAT_INSTALLED ]]; then # {{{
    export BAT_INSTALLED=true
    export BAT_PRG='batcat'
    $IS_MAC && BAT_PRG='bat'
    is-installed $BAT_PRG || BAT_INSTALLED=false
  fi # }}}
  bcUse=$BAT_INSTALLED
  [[ -t 1 ]] && bcP+=" --color always" || bcUse=false
  if $bcUse; then # {{{
    local f1= i= params=
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      -) f1=$1; shift; break;;
      -*) params+=" $1";;
      *) f1=$1; shift; break;;
      esac; shift
    done # }}}
    [[ -z $f1 && ! -t 0 ]] && f1="-"
    [[ -z $f1 || $f1 == '-' || -e $f1 ]] || eval $(die "File [$f1] not found")
    [[ -t 1 ]] && params+=" --terminal-width $((COLUMNS - 2))"
    if [[ -z $f1 || -d "$f1" || -h "$f1" && -d "$(readlink -f "$f1")" ]]; then # {{{
      local cmd=
      if is-installed --which fdfind; then
        cmd="fdfind --type f --type l -L --no-ignore-vcs '${f1:-.}'"
      elif is-installed --which fd; then
        cmd="fd --type f --type l -L --no-ignore-vcs '${f1:-.}'"
      elif is-installed --which ag; then
        cmd="ag --follow -g ''"
      else
        cmd="find ${f1:-.} -type f -o -type l"
      fi
      f1="$(eval $cmd | sort -f | fzf --prompt 'Select files > ' | while read i; do printf "%q " $i; done)"
      [[ -z $f1 ]] && return
    fi # }}}
    while true; do # {{{
      [[ $f1 == '-' ]] && break
      case $(head -n1 $f1) in
      '#!/bin/bash'*         | '#!/bin/sh'* | \
      '#!/usr/bin/env bash'* | '#!/usr/bin/env sh'*)
        bcP+=" -l sh" && break;;
      esac
      if [[ $f1 == *.txt ]]; then
        local nameD="$(basename "$(dirname "$(realpath "$f1")")")"
        local nameF="$(basename "$f1")"
        [[ "${nameD}-data.txt" == ${nameF#.} ]] && bcP+=" -l sh" && break
      fi
      break
    done # }}}
    $BAT_PRG $bcP $params $f1 "$@" # }}}
  else # {{{
    cat "$@"
  fi # }}}
} # }}}
_cat "$@"

