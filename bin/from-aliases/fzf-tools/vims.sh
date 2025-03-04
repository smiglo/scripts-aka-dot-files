#!/usr/bin/env bash
# vim: fdl=0

_vims() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -t) fzf-exe @@ - --pane;;
    *)  echo "@@-f -t -v";;
    esac
    return 0
  fi # }}}
  __vims__find_files() { # {{{
    local l= path= d=
    while read l; do
      if [[ -e $l ]]; then
        echo "$l"
      elif [[ $l != /* && ( -z $path || -e $path/$l ) ]]; then
        if [[ -z $path ]]; then # {{{
          path=$PWD d=
          while [[ $path != / ]]; do
            path=$(cd $path/.. && pwd)
            d+="../"
            [[ -e $path/$l ]] && break
          done
          [[ ! -e $path/$l ]] && path=
        fi # }}}
        [[ ! -z $path && -e $path/$l ]] && echo "${d%/}/$l"
      fi
    done
  } # }}}
  local dst='.1' f= verb=false
  while [[ ! -z $1 ]]; do
    case $1 in
    -v) verb=true;;
    -t) dst="$2"; shift;;
    *)  f="$@"; shift $#;;
    esac; shift
  done
  [[ $dst =~ .*\..* ]] || dst+=".1"
  if [[ ! -t 0 ]]; then
    f="$(cat - | xargs -n1 | __vims__find_files | fzf)"
  elif [[ -z $f ]]; then
    f="$(fzf -m -1 -0 --prompt='vim> ')"
  fi
  [[ $? != 0 || -z $f ]] && return 0
  for i in $f; do
    if [[ -e "$i" ]]; then
      fzf-exe -c pane --pane $dst -f "$i"
    elif $verb; then
      echo "File [$f] does not exist" >/dev/stderr
    fi
  done
  true
} # }}}
_vims "$@"

