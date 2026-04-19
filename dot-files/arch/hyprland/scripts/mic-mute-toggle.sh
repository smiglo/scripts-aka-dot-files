#!/bin/bash

dev="@DEFAULT_AUDIO_SOURCE@"
wpctl set-mute $dev toggle

isMuted=$(wpctl get-volume $dev | grep -c "MUTED")

if (( isMuted )) then
  echo 1
else
  echo 0
fi >/sys/class/leds/*micmute/brightness
