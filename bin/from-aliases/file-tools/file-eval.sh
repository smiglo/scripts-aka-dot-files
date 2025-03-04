#!/usr/bin/env bash
# vim: fdl=0

_file-eval() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -f) # {{{
      get-file-list '*.log'; get-file-list '*.txt' ;; # }}}
    --prefix) # {{{
      echo "##\\ TB]\\ II";; # }}}
    *) # {{{
      echo "-f --prefix --stop-on-fail";; # }}}
    esac
    return 0
  fi # }}}
  local f= l= prefix= stopOnFail=false ev= evR=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -f)             f="$2"; shift;;
    --prefix)       prefix="${2% } "; shift;;
    --stop-on-fail) stopOnFail=true;;
    esac; shift
  done # }}}
  [[ -z $f && ! -t 0 ]] && f="-"
  [[ -z $f ]] && return 1
  [[ ! -e $f && $f != '-' ]] && return 1
  cat "$f" | \
  while read l; do
    if [[ $l =~ ' ## eval '(.*) ]]; then
      ev="${BASH_REMATCH[1]}"
      evR="$(eval "$ev")"
      if [[ $? == 0 ]]; then
        l="${l%% ## eval *} $prefix$evR"
      else
        echormf 0 "e: [$ev]"
        $stopOnFail && break
      fi
    fi
    echo "$l"
  done
  return 0
} # }}}
_file-eval "$@"

