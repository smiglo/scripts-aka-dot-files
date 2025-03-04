#!/usr/bin/env bash
# vim: fdl=0

_tmux-popup() { # @@ # {{{
  [[ -n $TMUX ]] || return 1
  [[ $TMUX_VERSION -gt 30 ]] || eval $(die "tmux >= 3.0 is required (vs $(tmux -V))")
  local popupPath="${TMUX_POPUP_PATH:-$APPS_CFG_PATH/tmux/popup}"
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    --title) echo "TITLE";;
    *) echo "-E -EE -e -t --title CMD"
      declare -A TMUX_POPUP_CMD
      [[ -e $popupPath/.cmds ]] && source $popupPath/.cmds
      echo "n r ${!TMUX_POPUP_CMD[*]}";;
    esac
    return 0
  fi # }}}
  [[ -e $popupPath ]] || mkdir -p $popupPath >/dev/null
  local tp=$TMUX_PANE cmd= params= silent=false showCmd=true name= addWait=
  source-basic
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -E | -EE) params="$1";;
    -e) params="-e";;
    -t) tp=$2; shift;;
    -c) shift; cmd="${@:-help}"; shift $#;;
    --title) name="$2"; shift;;
    --no-wait) addWait=false;;
    *)  cmd="$@"; shift $#;;
    esac; shift
  done # }}}
  if [[ ! -z $cmd ]]; then # {{{
    declare -A TMUX_POPUP_CMD
    TMUX_POPUP_CMD[gg]="git cba 1"
    TMUX_POPUP_CMD[gb]="git backup"
    TMUX_POPUP_CMD[gc]="git cba"
    TMUX_POPUP_CMD[gl]="git l ## log"
    TMUX_POPUP_CMD[gs]="git sync --reset"
    TMUX_POPUP_CMD[gst]="git-cmds.sh gitst -v # @W"
    if is-installed --which htop; then
      TMUX_POPUP_CMD[h]="htop"
    fi
    TMUX_POPUP_CMD[n]="net --loop"
    TMUX_POPUP_CMD[N]="net -ll"
    if is-installed reminder; then
      TMUX_POPUP_CMD[r]="reminder # @W"
      TMUX_POPUP_CMD[rrm]="reminder -rm"
    fi
    TMUX_POPUP_CMD[pid]="tmux list-panes -F \"#P :: #T :: #{pane_pid} :: #{pane_current_command} :: #{pane_current_path}\" | column -t # @-W @C"
    [[ -e $popupPath/.cmds ]] && source $popupPath/.cmds
    local waitTimeout="-t5 -n1"
    case $cmd in
    help) # {{{
      color-cache-init
      local i= once=true
      name=select
      showCmd=false
      params="-EE"
      (
        waitCmd="{ echo; echorm --name popup -n 0 \"press a key...\"; read -s; }"
        echo "source \$HOME/.bashrc --do-basic"
        echo "list=\"\$(cat <<-EOF"
        for i in $(echo "${!TMUX_POPUP_CMD[*]}" | tr ' ' '\n' | sort); do
          echo "	$(printf "$(get-color info)%-5s$(get-color off)" "$i") : ${TMUX_POPUP_CMD[$i]}"
        done
        echo "EOF"
        echo ")\""
        echo "err=0"
        echo "once=$once"
        echo "wait=false"
        echo "while true; do"
        echo "  action=\"\$(echo -e \"\$list\" | fzf --ansi | sed -e 's/[^:]*: //' -e 's/ ## .*//')\""
        echo "  [[ -z \"\$action\" ]] && { err=255; break; }"
        echo "  [[ \"\$action\" == *' # @W'* ]] && wait=true"
        echo "  action=\"\${action%% # *}\""
        echo "  eval \"\$action\" || { err=1; break; }"
        echo "  \$once && break"
        echo "done"
        echo "\$wait && $waitCmd"
        echo "exit \$err"
      ) >$TMP_MEM_PATH/tmux-popup.sh
      chmod +x $TMP_MEM_PATH/tmux-popup.sh
      cmd="$TMP_MEM_PATH/tmux-popup.sh"
      ;; # }}}
    *) # {{{
      if [[ -z $name ]]; then
        name=${cmd%% *}
        if [[ ! -z ${TMUX_POPUP_CMD[$name]} ]]; then
          if [[ "$name" != "$cmd" ]]; then
            cmd="${TMUX_POPUP_CMD[$name]} ${cmd#* }"
          else
            cmd=${TMUX_POPUP_CMD[$name]}
          fi
          name=${cmd%% *}
        fi
      fi
      [[ $cmd == *sleep* ]] || addWait=${addWait:-true}
      ;; # }}}
    esac
    local c="$cmd" shell=$SHELL
    [[ $IS_MAC ]] && shell=bash
    [[ $c == *' # '*'@W'* ]] && addWait=true
    [[ $c == *' # '*'@-W'* ]] && addWait=true && waitTimeout=""
    [[ $c == *' # '*'@C'* ]] && showCmd=false
    local waitCmd="{ echo; echorm --name popup -n 0 \"press a key...\"; read -s $waitTimeout; }"
    c="${c%% # *}"
    cmd="$shell -i -c '"
    $showCmd && cmd+="(echorm --name popup 0 \"${c//\"/\\\"}\"; echo; );"
    cmd+=" $c; err=\$?;"
    cmd+=" [[ \$err != 0 && \$err != 255 ]] && { ( echorm --name popup 0 \"\$(cl err fail)\" ); };"
    $addWait && cmd+=" [[ \$err == 0 ]] && $waitCmd;"
    cmd+=" [[ \$err == 0 || \$err == 255 ]];"
    cmd+="'"
    [[ -z $params ]] && params="-EE"
    silent=true
  else
    [[ -z $params ]] && params="-E"
  fi # }}}
  [[ $params == '-e' ]] && params=
  local p="$(tmux display-message -t $tp -p -F '#{pane_current_path}')"
  local d="$popupPath/mem"
  mkdir -p $TMP_MEM_PATH/${popupPath//\//-} >/dev/null
  [[ -e $d ]] || ln -sf $TMP_MEM_PATH/${popupPath//\//-} $d
  [[ -e $popupPath/notes.txt ]] || touch $popupPath/notes.txt
  [[ -e $d/notes.txt ]] || ln -sf $popupPath/notes.txt $d/notes.txt
  tmux display-popup -t $tp $params -d "$p" -w 75% -h 75% -T " ${name:-shell} " \
    -e "TMUX_POPUP=true" \
    -e "TMUX_POPUP_SILENT=$silent" \
    -e "DISPLAY=$DISPLAY" \
    -e "s=$p" \
    -e "d=$d" \
    -e "spane=$TMUX_PANE" \
    "$cmd"
  unset cmd
  return 0
}
alias tp='tmux-popup' # }}}
_tmux-popup "$@"

