#!/usr/bin/env bash
# vim: fdl=0

_vimf() { # {{{
  local pattern="${1:-.*}" files=() vim_p=
  set +f
  [[ $pattern == '*'.* ]] && pattern=".${pattern//./\\.}$"
  [[ $pattern == '*'* ]] && pattern=".$pattern"
  if [[ -t 0 ]]; then # {{{
    files="$(
      { eval $FZF_DEFAULT_COMMAND; } \
      | grep "$pattern" | fzf --prompt="Files> " --multi --select-1 --exit-0
    )" # }}}
  else # {{{
    local out= i=
    while read i; do
      [[ -f "${i%%:*}" ]] && out+="$i\n"
    done <<<"$(cat - | tr '\0' '\n' | sort)"
    [[ -z $out ]] && return 0
    files="$(
      { echo -en "$out"; } \
      | grep "$pattern" | fzf --prompt="Files> " --multi --select-1 --exit-0
    )"
    [[ -z $files ]] && return 0
    out=
    rm -f $TMP_MEM_PATH/vimf-$$.txt
    while read i; do
      echo "$i" >>$TMP_MEM_PATH/vimf-$$.txt
      out+="${i%%:*}\n"
    done <<<"$(echo -e "$files")"
    files="$(echo -e "$out" | awk '!seen[$0] {print} {++seen[$0]}')"
    files="$TMP_MEM_PATH/vimf-$$.txt\n$files"
    vim_p="-c 'tabnext 2'"
  fi # }}}
  if [[ -n "$files" ]]; then # {{{
    eval vim $vim_p $(echo -e "$files") </dev/tty
    rm -f $TMP_MEM_PATH/vimf-$$.txt
  fi # }}}
} # }}}
_vimf "$@"

