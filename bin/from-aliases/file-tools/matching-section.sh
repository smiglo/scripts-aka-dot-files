#!/usr/bin/env bash
# vim: fdl=0

_matching-section() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -f | --f) echo "@@-f";;
    -p | --prefix) echo "---";;
    *) echo "-f --file -p --prefix -m{ -m\\( -m \\< -m\\[ vim-fold";;
    esac
    return 0
  fi # }}}
  local file= prefix= method='vim-fold'
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -f | --file)   file="$2"; shift;;
    -p | --prefix) prefix="$2"; shift;;
    --vim-fold)    method='vim-fold';;
    { | \( | \< | \[ | \
    -m{ | -m\( | -m\< | -m\[)
      method="${1#-m}";;
    *) break;;
    esac; shift
  done # }}}
  [[ -z $prefix ]] && return 1
  [[ ! -t 1 && -z $file ]] && file='-'
  [[ -e $file || $file == '-' ]] || return 1
  __pcregrep() { # {{{
    if is-installed pcregrep; then
      pcregrep -aMo "$@"
    else
      grep -azPo "$@"
    fi
  } # }}}
  local err=
  cat $file | \
    case $method in # {{{
    vim-fold) __pcregrep "$prefix"' *# \{\{(\{([^{}]++|(?1))*(# )?\})\}\}' ;;
    '{')      __pcregrep "$prefix"' *(\{([^{}]++|(?1))*\})';;
    '(')      __pcregrep "$prefix"' *(\(([^()]++|(?1))*\))';;
    '<')      __pcregrep "$prefix"' *(<([^<>]++|(?1))*>)';;
    '[')      __pcregrep "$prefix"' *(\[([^\[\]]++|(?1))*\])';;
    esac # }}}
  err=$?
  unset -f __pcregrep
  return $?
} # }}}
_matching-sections "$@"

