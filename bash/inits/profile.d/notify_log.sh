#!/usr/bin/env bash

if [[ ! -z $SSH_CLIENT ]]; then
  sender="sshd@localhost"
  recepients="root"
  for u in $PERS_USERS; do
    command grep -q "^$u:" /etc/passwd && recepients+=" $u"
  done
  subject="[SSH] User '$(whoami)' from [${SSH_CLIENT/ *}]"
  logger -p auth.warning -t 'ssh-login' "TB] $subject"
  t=
  t+="SSH Access:\n"
  t+="$(echo "$(env)" | sed 's/^/  /')"
  for r in $recepients; do
    echo -e "$t" | mail -s "$subject" -r "$sender" "$r"
  done
fi

