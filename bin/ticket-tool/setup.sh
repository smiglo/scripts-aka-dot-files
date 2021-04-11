#!/usr/bin/env bash
# vim: fdl=0

if [[ -z $TICKET_PATH ]]; then # {{{
  echo "Env[TICKET_PATH] not defined (tt-S)" >/dev/stderr
  [[ "${BASH_SOURCE[0]}" == "$0" ]] && exit || return
fi # }}}
[[ -z $TICKET_LIST ]] && export TICKET_LIST="$TICKET_TOOL_PATH/list-basic.sh" && ${dbg:-false} && echo "TICKET_LIST set to default setter" >/dev/stderr
open=false layout=false
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --open)   open=true;;
  --layout) layout=true;;
  *)      break;
  esac
  shift
done # }}}
ISSUES="$@"
if [[ -z $ISSUES ]]; then # {{{
  if [[ ! -e $TICKET_LIST ]]; then # {{{
    echo "Issue file does not exist ! (tt-S)" >/dev/stderr
    [[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 1 || { unset open; return 1; }
  fi # }}}
  ISSUES="$($TICKET_LIST)"
  if [[ -n $TICKET_CURRENT_TICKETS ]]; then # {{{
    [[ ! -e $TICKET_CURRENT_TICKETS ]] && command mkdir -p $TICKET_CURRENT_TICKETS
    list="@$(echo ${ISSUES,,} | sed -e 's/:[^ ]*//g' -e 's/ /@\\|@/')@"
    for i in $(cd $TICKET_CURRENT_TICKETS; ls); do
      [[ $i == "0.all" ]] && continue
      ! echo "@$i@" | command grep -q "${list}" && rm -rf $TICKET_CURRENT_TICKETS/$i
    done
    unset list
  fi # }}}
  # }}}
elif [[ $ISSUES == '-' ]]; then # {{{
  wnd_name=  path_issue= ext=
  wnd_name="$(tmux display-message -p -t $TMUX_PANE -F '#W' | sed 's/--.*//')"
  wnd_name="${wnd_name,,}"
  ISSUES=
  if [[ $wnd_name == *-* ]]; then # {{{
    for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
      path_issue=$($ext --ticket-path "$wnd_name")
      [[ ! -z $path_issue ]] && break
    done # }}}
    if [[ ! -e $path_issue ]]; then
      wnd_name="$(echo $wnd_name | cut -d'-' -f1,2)"
      if [[ $wnd_name == *-* ]]; then
        for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
          path_issue=$($ext --ticket-path "$wnd_name")
          [[ ! -z $path_issue ]] && break
        done # }}}
      fi
    fi
  fi # }}}
  [[ -e $path_issue ]] && ISSUES="$wnd_name"
  unset wnd_name  path_issue ext
  if [[ -z $ISSUES && $PWD == $TICKET_PATH/* ]]; then # {{{
    p="$PWD" last=
    while [[ $p == $TICKET_PATH/* ]]; do
      last="${p##*/}"
      [[ -e "$p/${last}-data.txt" ]] && ISSUES="$last" && break
      p="$(command cd $p/..; pwd)"
    done
    unset p last
  fi # }}}
fi # }}}
for i in $ISSUES; do # {{{
  i="${i,,}"
  i="${i%%:*}"
  [[ "${BASH_SOURCE[0]}" == "$0" ]] && ${dbg:-false} && echo "Shall be sourced to source env for [$i]" >/dev/stderr
  source $TICKET_TOOL_PATH/ticket-setup.sh $($open && echo '--open') $($layout && echo '--layout') "$i"
  if [[ -n $TICKET_CURRENT_TICKETS && ! -e "$TICKET_CURRENT_TICKETS/$i" && ( ! -n $TMUX || $(tmux display-message -p -t $TMUX_PANE -F '#P') == '1' ) ]]; then
    t="$(command find $TICKET_PATH -maxdepth 4 -name "$i" | head -n1)"
    [[ ! -z $t ]] && ln -sf "$t" "$TICKET_CURRENT_TICKETS/$i"
  fi
done # }}}
unset i s open layout ISSUES

# ----------------------------
# Aditional, could be implemented:
# tmux-startup-pre.sh: # {{{
# TMUX_--TICKET_TMUX_SESSION-NAME--_ENV_SETUP() { # {{{
#   setup=()
#   local ISSUES="$@" i= p=
#   [[ -z $ISSUES && -e "$TICKET_LIST" ]] && ISSUES="$($TICKET_LIST)"
#   source "$TICKET_TOOL_PATH/setup.sh"
#   for i in $ISSUES; do
#     i="${i,,}"
#     p="$TICKET_PATH/$i"
#     [[ -z $p || ! -e $p/${i}-data.txt ]] && echo "Issue [$i] not present" >/dev/stderr && continue
#     setup+=("${i^^}:$p")
#   done
#   true
# } # }}}
# ---------------------------- }}}
# ----------------------------
