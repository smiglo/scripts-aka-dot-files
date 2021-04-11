#!/usr/bin/env bash
# vim: fdl=0

getKey() { # {{{
  local key= IFS=
  read -rsn${1:-1} ${@:2} key
  echo -ne "$key" | xxd -g8 | cut -d\  -f2
} # }}}
readKey() { # {{{
  local key="$(getKey)"
  case $key in
  01) echo "c-a";;
  02) echo "c-b";;
  # 03) echo "c-c";; // ctrl-c: abort
  04) echo "c-d";;
  05) echo "c-e";;
  06) echo "c-f";;
  07) echo "c-g";;
  08) echo "c-h";;
  09) echo "c-i";;
  # 0a) echo "c-j";; // enter
  0b) echo "c-k";;
  0c) echo "c-l";;
  # 0d) echo "c-m";; // enter
  0e) echo "c-n";;
  0f) echo "c-o";;
  10) echo "c-p";;
  11) echo "c-q";;
  12) echo "c-r";;
  13) echo "c-s";;
  14) echo "c-t";;
  15) echo "c-u";;
  16) echo "c-v";;
  17) echo "c-w";;
  18) echo "c-x";;
  19) echo "c-y";;
  # 1a) echo "c-z";; // ctrl-z: background
  07) echo "tab";;
  20) echo "space";;
  7f) echo "back";;
  '') echo "enter";;
  1b) # {{{
    key+="$(getKey 2 -t .1)"
    while true; do
      case $key in
      1b)     echo "esc";;
      1b5b41) echo "up";;
      1b5b42) echo "down";;
      1b5b43) echo "right";;
      1b5b44) echo "left";;
      1b4f50) echo "f1";;
      1b4f51) echo "f2";;
      1b4f52) echo "f3";;
      1b4f53) echo "f4";;
      1b5b31 | 1b5b34 | \
      1b5b32 | 1b5b33 | \
      1b5b35 | 1b5b36)
        key+="$(getKey)"; continue;;
      1b5b3135 | 1b5b3137 | 1b5b3138 | 1b5b3139 | \
      1b5b3230 | 1b5b3231 | 1b5b3233 | 1b5b3234 )
        key+="$(getKey)"; continue;;
      1b5b317e) echo "home";;
      1b5b327e) echo "ins";;
      1b5b337e) echo "del";;
      1b5b347e) echo "end";;
      1b5b357e) echo "pgup";;
      1b5b367e) echo "pgdn";;
      1b5b31357e) echo "f5";;
      1b5b31377e) echo "f6";;
      1b5b31387e) echo "f7";;
      1b5b31397e) echo "f8";;
      1b5b32307e) echo "f9";;
      1b5b32317e) echo "f10";;
      1b5b32337e) echo "f11";;
      1b5b32347e) echo "f12";;
      *) echo "?$key";;
      esac
      break
    done ;; # }}}
  *)  [[ $(echo "$(( 0x$key ))") -ge 32 ]] && echo -e "\x$key" || echo "?$key";;
  esac
} # }}}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && readKey

