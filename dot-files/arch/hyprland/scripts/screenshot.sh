#!/bin/bash

if which flameshot >/dev/null 2>&1; then
  flameshot gui
else
  file="$HOME/Pictures/screenshots/s-$(date +%Y%m%d-%H%M%S).png"
  mkdir -p "${file%/*}"
  grim -g "$(slurp)" "$file" && wl-copy <"$file"
fi
