#!/usr/bin/env bash
# vim: fdl=0

_man() { # {{{
  if [[ ! -t 1 ]]; then
    man "$@"
    return
  fi
  local list="$@" loop=false
  [[ -z $list ]] && loop=true
  local batLang="-l man" fallback=false
  [[ -n $GROFF_NO_SGR ]] || fallback=true
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
      hasMan=false
      if [[ -n "$(man -w $l 2>/dev/null)" ]]; then
        COLUMNS=$(($(tput cols)-3))
        [[ " $LESS " =~ " -N " ]] && ((COLUMNS-=8))
        if ! $fallback; then
          man $l
          continue
        fi
        hasMan=true
      fi
      if $hasMan; then
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
