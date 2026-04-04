#!/usr/bin/env bash
# vim: fdl=0

case $1 in
--clean-up)
  printf "\e[r"
  tput cup $(tput lines) 0
  echo ""
  exit 0;;
esac

msg="$1"
lines="$(( $(echo -e "$msg" | wc -l) + 1))"

printf "\e[$lines;r"
printf "\e[H"
echo -e "$msg"
printf "\e[$lines;1H"
