#!/usr/bin/env bash
# vim: fdl=0

rlwrapCmd() { # {{{
  command rlwrap "${rlwrapOpts[@]}" -n -o -w 10 "$@" cat
} # }}}
getPrompt() { # {{{
  c="green"
  (( err == 0 )) || c="red"
  printfc "%$c:%s> " "$prompt"
} # }}}

mapfile -t rlwrapOpts < <(xargs -n1 printf -- "%s\n" <<<"$RLWRAP_OPTS")
histFile=
prompt="shell"
completionList=
err=0

while [[ -n $1 ]]; do
  case $1 in
  --hist-file) histFile="$2"; shift;;
  --prompt) prompt="$2"; shift;;
  --completion) completionList="$2"; shift;;
  --err) err="$2"; shift
  esac; shift
done

rlwrapCmd -g "---" -D 2 \
  -S "$(getPrompt)" \
  $([[ -n "$histFile" ]] && echo "-H $histFile -s -10000") \
  -f <(echo "$completionList")
