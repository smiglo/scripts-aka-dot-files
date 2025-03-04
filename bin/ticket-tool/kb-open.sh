#!/usr/bin/env bash
# vim: fdl=0

_kb-open() { # @@ # {{{
  local i= p=
  if [[ $1 == '@@' ]]; then # {{{
    local ret=
    for i in $KB_PATHS; do
      ret+=" ${i%%:*}"
    done
    echo "$ret ."
    return 0
  fi # }}}
  local kb=$1
  if [[ -z $kb ]]; then
    [[ -e ./.ticket-data.sh && -e ./.env ]] && kb='.'
    [[ -z $kb ]] && echo "Missing KB name" >/dev/stderr && return 1
  fi
  if [[ $kb != '.' ]]; then
    if tmux list-sessions -F '#S' | command grep -q "^${kb^^}$"; then # {{{
      tmux switch-client -t ${kb^^}
      return 0
    fi # }}}
    for i in $KB_PATHS; do # {{{
      [[ $kb == ${i%%:*} ]] && p="${i#*:}" && break
    done # }}}
    [[ -z $p ]]  && echo "Could not find path of KB [$i]" >/dev/stderr && return 1
    if [[ ! -e $p/.env ]]; then # {{{
      echo "The .env file for KB [$i] could not be found" >/dev/stderr
      cat  >$p/.env <<-EOF
				#!/bin/bash
				if [[ -n \$TICKET_TOOL_PATH && -e \$TICKET_TOOL_PATH/session-init.sh ]]; then
				  source \$TICKET_TOOL_PATH/session-init.sh "$p" "${kb^^}"
				fi
			EOF
    fi # }}}
  fi
  (
    command cd "$p"
    source .env
    r="$(alias \
      | command grep "^alias init-session=" \
      | awk -F'=' '{$1=""; print $0}' \
      | sed -e "s/^\s*'//" -e "s/'\s*$//" -e "s/'\\\''/'/g"\
    )"
    eval $r
  )
} # }}}
_kb-open "$@"

