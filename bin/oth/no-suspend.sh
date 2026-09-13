#!/usr/bin/env bash

if [[ $1 == "@@" ]]; then # @@:new # {{{
  case $2 in
  -m | --msg) echo "MSG";;
  -t | --timeout) echo "10m 30m 1h 2h";;
  --pid) echo "PID";;
  --cmd) echo "CMD";;
  *) compl-get-args <$0;;
  esac; exit 0
fi # }}}

msg=
timeout=
cmd=
pane=
pid=
while [[ -n $1 ]]; do
  case $1 in
  -m | --msg) msg="$2"; shift;;
  -t | --timeout) timeout="$2"; shift;;
  --pane) # {{{
    pane="$2"; shift
    [[ -z $msg ]] && msg="suspend blocked by pid: $2 in pane $pane"
    [[ -z $timeout ]] && timeout="3h";; # }}}
  --pid) # {{{
    pid="$2"; shift
    [[ -z $msg ]] && msg="suspend blocked by pid: $2"
    [[ -z $timeout ]] && timeout="3h";; # }}}
  --cmd) # {{{
    cmd="$2"
    [[ -z $msg ]] && msg="suspend blocked by cmd: $2"
    [[ -z $timeout ]] && timeout="3h"
    shift;; # }}}
  *) timeout="$1"; shift $#;;
  esac; shift
done

import-module time-tools

[[ -n $msg ]] || msg="suspend blocked"
[[ -n $timeout ]] || timeout="1h"
timeout=$(time2s $timeout -o s)

params=(
  --no-err
  --background-cmd "systemd-inhibit --why='$msg' --who='$USER' --what=sleep sleep $((timeout-3))"
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

exec progress-dot-wrapper "${params[@]}" $timeout
