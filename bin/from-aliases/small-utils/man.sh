#!/usr/bin/env bash
# vim: fdl=0

_man() { # {{{
  if [[ ! -t 1 ]]; then
    man "$@"
    return
  fi
  local list="$@" loop=false
  [[ -z $list ]] && loop=true
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
        batLang="-l man"
        ${MAN_USE_BAT:-true} || batLang=
        manInfo="$(man $l 2>/dev/null)"
        if (( $? != 0 )) && is-installed $l; then
          manInfo="$($l --help)"
          batLang="-l man"
        fi
        echo "$manInfo" | \
        { if $BAT_INSTALLED; then $BAT_PRG $batLang -p --theme "$BAT_THEM2";
          else less;
          fi; }
      done
    $loop || break
  done
  return 0
} # }}}
_man "$@"

