#!/bin/bash

direction=${1:-previous}
isSpecial=$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .specialWorkspace.name')

if [[ "$isSpecial" == special:* ]]; then
  hyprctl dispatch 'hl.dsp.workspace.toggle_special("magic")'
else
  hyprctl dispatch 'hl.dsp.focus({ workspace = "'"$direction"'" })'
fi
