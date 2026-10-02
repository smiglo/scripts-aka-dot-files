#!/usr/bin/env bash

if [[ $1 == "@@" ]]; then # @@:new # {{{
  case $2 in
  -m | --msg) echo "MSG";;
  -w | --wait) echo "10m 30m 1h 2h";;
  --pane) echo "PANE";;
  --pid) echo "PID";;
  --cmd) echo "CMD";;
  *) compl-get-args <$0;;
  esac; exit 0
fi # }}}

import-module time-tools

msg=
delay=
cmd=
pane=
pid=

while [[ -n $1 ]]; do # {{{
  case $1 in
  -m | --msg) msg="$2"; shift;;
  -w | --wait) delay="$2"; shift;;
  --pane) # {{{
    pane="$2"; shift
    [[ -z $msg ]] && msg="suspend blocked by pid: $2 in pane $pane"
    [[ -z $delay ]] && delay="3h";; # }}}
  --pid) # {{{
    pid="$2"; shift
    [[ -z $msg ]] && msg="suspend blocked by pid: $2"
    [[ -z $delay ]] && delay="3h";; # }}}
  --cmd) # {{{
    cmd="$2"
    [[ -z $msg ]] && msg="suspend blocked by cmd: $2"
    [[ -z $delay ]] && delay="3h"
    shift;; # }}}
  *) # {{{
    if [[ $1 =~ .*\.[0-9]+$ ]]; then
      pane=$1
      [[ -z $delay ]] && delay="3h"
    elif [[ $1 =~ ^[0-9]+$ ]] || time2s --is-hms $1; then
      delay="$1"; shift $#
    else
      pid=$($ENV_SCRIPTS/tmux/tm.sh --pids -a | awk '$3 ~ /^'"$1"'/ {print $1}' | head -n1)
      [[ -n $pid ]] || die "cannot find running command '^$1'"
      [[ -z $msg ]] && msg="suspend blocked by pid: $2/command: $1"
      [[ -z $delay ]] && delay="3h"
    fi # }}}
  esac; shift
done # }}}

[[ -n $msg ]] || msg="suspend blocked"
[[ -n $delay ]] || delay="1h"
delay=$(time2s $delay -o s)

params=(
  --no-err
  --background-cmd "systemd-inhibit --why='$msg' --who='$USER' --what=sleep sleep $((delay-3))"
)
[[ -n $pane ]] && params+=(
  --pane "$pane"
)
[[ -n $pid ]] && params+=(
  --pid "$pid"
)
[[ -n $cmd ]] && params+=(
  --check-cmd "$cmd"
)

exec progress-dot-wrapper "${params[@]}" $delay
