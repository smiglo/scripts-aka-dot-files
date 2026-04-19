#!/usr/bin/env bash
# vim: fdl=0

_man() { # {{{
  if [[ ! -t 1 ]]; then
    man "$@"
    return
  fi
  local list="$@" loop=false
  [[ -z $list ]] && loop=true
  local batLang="-l man"
  ${MAN_USE_BAT:-true} || batLang=
  while true; do
    if $loop; then
      list="$(man -k . \
        | sort -k2,2 -k1,1 \
        | fzf \
            --prompt 'man> ' \
            --no-sort \
            --preview="echo {1,2} | sed 's/^\([^ ]\+\) *(\([^)]\+\)).*/-S \2 \1/' | xargs man" \
        | sed 's/^\([^ ]\+\) *(\([^)]\+\)).*/-S \2 \1/')"
      [[ -z $list ]] && return 0
    fi
      echo "$list" | while read -r l; do
        if man $l >/dev/null 2>&1; then
          man $l
        elif is-installed $l; then
          $l --help 2>&1
        fi \
        | { if $BAT_INSTALLED; then $BAT_PRG $batLang -p --theme "$BAT_THEM2";
            else less;
            fi;
          }
      done
    $loop || break
  done
  return 0
} # }}}
_man "$@"

