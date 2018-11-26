#!/bin/bash

__ticket_title() {
  local title="$issue" f=
  [[ -e $path_issue/.${issue}-data.txt ]] && f="$path_issue/.${issue}-data.txt"
  [[ -e $path_issue/${issue}-data.txt ]] && f="$path_issue/${issue}-data.txt"
  [[ -z $f ]] && echo "$title" && return 0
  title="$(sed -n '/^# j-info:/s/.*TITLE:\s*\([^, ]*\).*/\1/p' $f)"
  echo "${title:-$issue}"
}

export -f __ticket_title

