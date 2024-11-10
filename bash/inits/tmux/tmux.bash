#!/usr/bin/env bash
# vim: fdl=0

defaults() { # {{{
  # Windows numbering # {{{
  if [[ $TMUX_VERSION -gt 20 ]]; then
    tmux set -qg renumber-windows on
  fi # }}}
  # Use UTF8 # {{{
  if [[ $TMUX_VERSION -lt 24 ]]; then
    tmux set -qg utf8
    tmux set -qg status-utf8 on
    tmux set-window-option -qg utf8 on
  fi # }}}
  # Mouse # {{{
  if [[ $TMUX_VERSION -gt 20 ]]; then
    tmux set -qg mouse on
    tmux set -qg mouse-resize-pane on
    tmux set -qg mouse-select-pane on
    tmux set -qg mouse-select-window on
  fi # }}}
  # Make clipboard works in vim under tmux (OS/X) # {{{
  ${IS_MAC:-false} && ${TMUX_MAC_USE_REATTACH:-true} && tmux set -qg default-command "reattach-to-user-namespace -l bash"
  # }}}
  # Lock & CMatrix # {{{
  [[ $UID != 0 ]] && type cmatrix >/dev/null 2>&1 && tmux set -qg lock-command "$ALIASES sshh-add --lock --tmux ${TMUX_LOCK_PRE_TIMEOUT:-60}"
  tmux set -g lock-after-time ${TMUX_LOCK_TIMEOUT:-0}
  # }}}
  if [[ $TMUX_VERSION -ge 24 ]]; then
    tmux bind-key -T prefix      '?'     display-message "2nd key(h)..." \\\; switch-client -T ext1-help
    tmux bind-key -n             'M-/'   switch-client -T ext1-help
    tmux bind-key -T ext1-help   '?'     list-keys -T prefix
    tmux bind-key -T ext1-help   'r'     list-keys -T root
    tmux bind-key -T ext1-help   'c'     list-keys -T copy-mode-vi
    tmux bind-key -T ext1-help   'p'     display-panes
    tmux bind-key -T ext1-help   'h'     list-keys -T ext1-help
    tmux bind-key -T ext1-help   'R'     display-message "Reloading..." \\\; source-file ~/.tmux.conf
    tmux unbind   -T prefix   'R'
  else
    tmux bind-key '?' list-keys
  fi
  if [[ $TMUX_VERSION -lt 26 ]]; then
    tmux bind-key 's' choose-tree
    tmux bind-key '=' run-shell '~/.tmux.bash smarter_nest "=" "choose-buffer"'
  else
    tmux bind-key 's' choose-tree -sN
    tmux bind-key '=' run-shell '~/.tmux.bash smarter_nest --no-eval "=" "choose-buffer -O name -NF ##{buffer_sample}"'
  fi
  tmux set -g @mark_auto true
  local i=
  tmux show-environment | command grep "^TMUX_SB.*update_time" | while read i; do
    tmux set-environment  ${i%%=*} "$(echo "${i#*=}" | sed -e 's/update_time=[0-9]*;/update_time=0;/')"
  done
  tmux show-environment -g | command grep "^TMUX_SB.*update_time" | while read i; do
    tmux set-environment  -g ${i%%=*} "$(echo "${i#*=}" | sed -e 's/update_time=[0-9]*;/update_time=0;/')"
  done
} # }}}
progress_drawer() { # {{{
  [[ -z $1 ]] && return
  local env="TMUX_SB_PROGRESS_INFO_${1^^}"
  local v="|/-\\" idx=0 stopped=false do_stop= useDots=true
  shift
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    start) tmux set-environment -g -u "$env" 2>/dev/null; return;;
    end)   tmux set-environment -g -u "$env" 2>/dev/null; return;;
    stop)  do_stop=true;;
    cont)  do_stop=false;;
    --dots)    useDots=true;;
    --no-dots) useDots=false;;
    esac
    shift
  done # }}}
  if ${TMUX_PROGRESS_USE_EXTRA_CHARS:-true}; then
    if $useDots; then
      v="${UNICODE_EXTRA_CHARS[progress_dots]}"
    else
      v="${UNICODE_EXTRA_CHARS[progress_bar]}"
    fi
  fi
  local sb_info="$(tmux show-environment -g "$env" 2>/dev/null)"
  sb_info="${sb_info#*=}"
  [[ ! -z $sb_info ]] && eval "$sb_info"
  [[ ! -z "$do_stop" ]] && stopped="$do_stop"
  if $stopped; then
    $useDots && idx="$((${#v}-1))" || idx="7"
  elif [[ ! -z $sb_info ]]; then
    $useDots && idx=$(((idx+1+$RANDOM%(${#v}-2))%(${#v}-1))) || idx="$(((idx+1)%${#v}))"
  fi
  tmux set-environment -g "$env" "idx=\"$idx\";stopped=\"$stopped\""
  printf "%b" "${v:$idx:1}"
  $testing && echo
} # }}}
progress_bar_worker() { # {{{
  local dir="$TMP_MEM_PATH" f_prefix="tmux_sb_progress_" f= ret=
  for f in $(ls $dir/${f_prefix}*.sh 2>/dev/null); do # {{{
    local entry="${f##$TMP_MEM_PATH/$f_prefix}" && entry="${entry%.sh}" && entry="${entry^^}"
    local interval= params= now="${EPOCHSECONDS:-$($ALIASES epochSeconds)}" lastChange= delta=30 mod_delta=$((15*60)) progress=
    local state='cont' color= text= doNext= useProgress=true extraParams= expire=
    [[ ! -e "$f" ]] && continue
    source "$f"
    [[ "$state" != *'end'* && ! -z $expire && $expire != 0 && "$expire" -lt "$now" ]] && state="err-end" && sed -i 's/^state="\(.*\)\"$/state="'$state'"/' "$f"
    [[ "$state" != *'end'* && $expire != 0 && "$(stat -c "%Y" "$f")" -lt "$(($now - $mod_delta))" ]] && state="err-end" && sed -i 's/^state="\(.*\)\"$/state="'$state'"/' "$f"
    case $doNext in
    remove) rm -f "$f";;
    esac
    [[ ! -e "$f" ]] && continue
    if [[ -z $color ]]; then # {{{
      case $state in
      err*) color="124";;
      *end) color="4";;
      *)    color="11";;
      esac
    fi # }}}
    case $state in
    cont) # {{{
      params="cont"
      if [[ ! -z $lastChange && "$lastChange" != "0" ]]; then
        echo "lastChange=\"0\"" >>"$f"
      fi ;; # }}}
    *end-now) # {{{
      params="stop"
      progress_drawer "$entry" $extraParams end
      tmux set -qg status-interval "${interval:-$TMUX_SB_INTERVAL}"
      [[ -z $doNext ]] && echo "doNext=\"remove\"" >>"$f"
      return 0;; # }}}
    *end) # {{{
      params="stop"
      if [[ -z $lastChange || "$lastChange" == "0" ]]; then
        lastChange="$now"
        echo "lastChange=\"$lastChange\"" >>"$f"
      elif [[ "$now" -gt "$((lastChange + delta))" ]]; then
        progress_drawer "$entry" $extraParams end
        tmux set -qg status-interval "${interval:-$TMUX_SB_INTERVAL}"
        [[ -z $doNext ]] && echo "doNext=\"remove\"" >>"$f"
        return 0
      fi;; # }}}
    err*) # {{{
      params="stop" ;; # }}}
    esac
    $useProgress && [[ "$text" != *"%s"* ]] && text+="%s"
    progress="$(progress_drawer "$entry" $extraParams $params)"
    out="$(printf "#[fg=colour%s]%s" "$color" "$text")"
    $useProgress && out="$(printf "$out" "$progress")"
    if [[ -z $interval ]]; then # {{{
      interval="$(tmux show-options -vg status-interval)"
      [[ $interval == "1" ]] && interval="$TMUX_SB_INTERVAL"
      echo "interval=\"$interval\"" >>"$f"
    fi # }}}
    [[ "$(tmux show-options -vg status-interval)" != "1" ]] && tmux set -qg status-interval 1
    ret+=" ${out}#[fg=default,none]"
  done # }}}
  echo "${ret:1}"
} # }}}
progress_bar() { # @@ # {{{
  local dir="$TMP_MEM_PATH" f_prefix="tmux_sb_progress_" f=
  if [[ $1 == '@@' ]]; then # {{{
    [[ $2 == 1 ]] && echo "--help"
    case $3 in
    purge) echo 'all all-all';;
    *)     echo --{text,color,delta,dir,expire,no-draw} {start,end{,-now},err,cont} purge;;
    esac
    return 0
    # }}}
  elif [[ $1 == '--help' || $1 == '-h' ]]; then # {{{
    echo
    echo "./$(basename $0) progress_bar ENTRY [--text T] [--color C] [--delta D] [--dir D [--no-link]] [--expire E] [--no-draw] [--params P] [state]"
    echo "./$(basename $0) progress_bar purge [all|all-all]"
    echo
    echo "  State: start, end|end-now [ERR], err, cont"
    echo
    return 0
    # }}}
  elif [[ $1 == 'purge' ]]; then # {{{
    local cur_time=${EPOCHSECONDS:-$($ALIASES epochSeconds)} delta=$((15*60))
    for f in $(ls $dir/${f_prefix}*.sh 2>/dev/null); do
      command grep -q '^state=".*end"$' "$f" && sed -i 's/^state="\(.*end\)\"$/state="\1-now"/' "$f" && continue
      if [[ ( $2 == 'all-all' ) || ( $2 == 'all' && "$(stat -c "%Y" "$f")" -lt "$(($cur_time - $delta))" ) ]]; then
        sed -i 's/^state="\(.*\)\"$/state="end-now"/' "$f" && continue
      fi
    done
    return 0
  fi # }}}
  local entry="${1,,}"
  [[ -z $entry ]] && return 1
  shift
  local dir="$TMP_MEM_PATH" f_prefix="tmux_sb_progress_" makeLink=false c=
  local state= color= delta= text= expire= useProgress= extraParams=
  source "$UNICODE_EXTRA_CHARS_FILE"
  [[ -z $1 ]] && set -- 'start'
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    start) ;;
    end | end-now) c=$1; [[ ! -z $2 && $2 =~ ^[0-9]+$ && $2 != "0" ]] && { shift; state="err-$c"; } || state="$c";;
    err | cont) state="$1";;
    --text)     text="$2"; text="${text#\"}"; text="${text%\"}"; shift;;
    --color)    color="$2"; shift;;
    --delta)    delta="$2"; shift;;
    --dir)      dir="$2"; shift; makeLink=true;;
    --no-link)  makeLink=false;;
    --no-draw)  useProgress=false;;
    --expire) # {{{
      expire=$($ALIASES time2s "$2" -o abs-s)
      shift
      ;; # }}}
    --params)   extraParams="$2"; shift;;
    esac
    shift
  done # }}}
  f="$dir/${f_prefix}${entry}.sh"
  $makeLink && touch "$f" && ln -sf "$f" "$TMP_MEM_PATH/"
  if [[ -z $state || $state == 'start' ]]; then # {{{
    rm -f "$f"
    progress_drawer $entry 'start'
    state="cont"
    [[ "$(tmux show-options -vg status-interval)" != "1" ]] && tmux set -qg status-interval 1
  fi # }}}
  (
    echo "state=\"$state\""
    [[ ! -z $color ]]       && echo "color=\"$color\""
    [[ ! -z $text ]]        && echo "text=\"$text\""
    [[ ! -z $delta ]]       && echo "delta=\"$delta\""
    [[ ! -z $expire ]]      && echo "expire=\"$expire\""
    [[ ! -z $useProgress ]] && echo "useProgress=\"$useProgress\""
    [[ ! -z $extraParams ]] && echo "extraParams=\"$extraParams\""
  ) >>"$f"
} # }}}
add_to_result() { # {{{
  [[ ! -z "$1" ]] && ret+=" $1"
} # }}}
status_right_extra() { # @@ # {{{
  [[ -z "$TMUX_STATUS_RIGHT_EXTRA_SORTED" ]] && printf " " && return 0
  source "$UNICODE_EXTRA_CHARS_FILE"
  local tm_info="$1" tm_time="$2"
  [[ -e $TMP_MEM_PATH/.tz.changed ]] && tm_time= # force to use current TZ
  [[ -z $tm_info ]] && tm_info="$(tmux display-message -pF '#S:#I.#P')"
  [[ -z $tm_time ]] && tm_time="$(command date +'%H:%M')"
  local session="${tm_info%%:*}" l= ret=
  local cur_time=${EPOCHSECONDS:-$($ALIASES epochSeconds)} update_time= value= do_update= out=
  local logtime_params="$(tmux show-environment -t $session "TMUX_SB_LOGTIME_PARAMS" 2>/dev/null)"
  logtime_params="${logtime_params#*=}"
  [[ -z $TMUX_SB_WORKER ]] && return 0
  source <($TMUX_SB_WORKER --get-all-values)
  if [[ -z ${data["_last_update"]} || ${data["_last_update"]} -lt $((${EPOCHSECONDS:-$($ALIASES epochSeconds)} - 3 * 60)) ]] && ! ${TMUX_SB_WORKER_IGNORE:-false}; then
    ret+="#[bg=colour124]#[fg=colour226,bold] W$($ALIASES getUnicodeChar 'exclamation') #[bg=default,none]"
  fi
  local list="$($TMUX_SB_WORKER --list)"
  for l in $TMUX_STATUS_RIGHT_EXTRA_SORTED; do # {{{
    if [[ -v "data[$l]" ]]; then # {{{
      out="${data[$l]}"
      if ! ${dbg:-false}; then
        add_to_result "$out"
      else
        ret+=" $l:[$out]"
      fi # }}}
    elif [[ " $list " == *" $l "* ]]; then # {{{
      : # }}}
    else # {{{
      case $l in # {{{
      progress_bar) add_to_result "$(progress_bar_worker)";;
      tmux_info)    ret+=" #[fg=colour244]$($HOME/.tmux.bash get_marked_pane)";;
      time)         [[ $logtime_params != 'hidden' ]] && ret+=" #[fg=colour12]$tm_time";;
      logtime) # {{{
        [[ $logtime_params == 'false' ]] && continue
        [[ ! -e $BIN_PATH/misc/log-last.sh ]] && continue
        if [[ $logtime_params == 'hidden' ]]; then # {{{
          local delta="$((10 * 60))" time_params="$(tmux show-environment -g "TMUX_SB_TIME_PARAMS" 2>/dev/null)"
          time_params="${time_params#*=}"
          [[ ! -z $time_params ]] && eval "$time_params"
          if [[ $cur_time -ge $(( $update_time + $delta )) || -z "$value" ]] || $testing; then
            value=$($BIN_PATH/misc/log-last.sh --tmux %)
            value="${value/*\#\[fg=/\#\[fg=}"
            value=${value/]*/]}
            tmux set-environment -g "TMUX_SB_TIME_PARAMS" "update_time=$cur_time;value=\"$value\""
          fi
          value="${value}${tm_time}"
          # }}}
        else # {{{
          local params="$logtime_params" delta="$((1 * 60))"
          do_update=true
          if [[ $logtime_params == *\|* ]]; then
            params="${logtime_params#*|}"
            [[ $params == *%* ]] && delta=$((5*60))
            eval "${logtime_params%%|*}"
            if [[ $cur_time -ge $(( $update_time + $delta )) || -z "$value" ]] || $testing; then
              value=$($BIN_PATH/misc/log-last.sh --tmux --passed --store $params)
            else
              do_update=false
            fi
          fi
          $do_update && tmux set-environment -t $session "TMUX_SB_LOGTIME_PARAMS" "update_time=$cur_time;value=\"$value\"|$params"
        fi # }}}
        ret+=" $value"
        ;; # }}}
      *) # {{{
        local i=
        for i in $BASH_PROFILES_FULL; do
          [[ -e $i/aliases ]] && out="$($i/aliases __util_tmux_extra $l)"
          [[ ! -z $out ]] && break
        done
        if ! ${dbg:-false}; then
          add_to_result "$out"
        else
          ret+=" $l:[$out]"
        fi
        ;; # }}}
      esac # }}}
    fi # }}}
  done # }}}
  printf "%b" "$ret "
  return 0
} # }}}
status_right_refresh() { # @@ # {{{
  tmux show-environment | command grep "^TMUX_SB.*update_time" | while read i; do
    tmux set-environment  ${i%%=*} "$(echo "${i#*=}" | sed -e 's/update_time=[0-9]*;/update_time=0;/')"
  done
  tmux show-environment -g | command grep "^TMUX_SB.*update_time" | while read i; do
    tmux set-environment  -g ${i%%=*} "$(echo "${i#*=}" | sed -e 's/update_time=[0-9]*;/update_time=0;/')"
  done
} # }}}
status_right() { # {{{
  [[ ! -z $TMUX_SB_INTERVAL ]] && tmux set -qg status-interval "$TMUX_SB_INTERVAL"
  tmux set -qg status-right "#[fg=colour10,bold] | #[fg=colour12,none]#S:#I.#P#($HOME/.tmux.bash status_right_extra '#S:#I.#P' '%H:%M')"
} # }}}
status_left_extra() { # {{{
  local format='#[fg=colour12]' end='#[fg=colour10,bold]|' overSSH=false icon= default=false info= sName=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --format)    printf "%s" "$format"; return 0;;
    --end)       printf "%s" "$end"; return 0;;
    --default)   default=true;;
    --icon)      icon="$2"; shift;;
    -s)          sName="$2"; shift;;
    *)           break;;
    esac
    shift
  done # }}}
  if [[ -n $SSH_CLIENT ]] || ( which pstree >/dev/null 2>&1 && [[ -n $TMUX ]] ); then # {{{
    if $IS_MAC; then
      pstree -p $(tmux display-message -pF '#{client_pid}') | command grep -q ' sshd\($\| \)' && overSSH=true
    else
      pstree -A -s $(tmux display-message -pF '#{client_pid}') | command grep -q -e '---sshd---' && overSSH=true
    fi
  fi # }}}
  TMUX_STATUS_LEFT_EXTRA_MAP= # Temporarily disabled
  [[ ! -z $TMUX_STATUS_LEFT_EXTRA_MAP ]] && info="$(echo -e "$TMUX_STATUS_LEFT_EXTRA_MAP" | sed -n '/^'$sName':/s/^'$sName'://p')"
  if [[ -z $info ]] || $default; then
    [[ -z $info ]] && info="$TMUX_HOSTNAME"
    [[ -z $info ]] && info="$($ALIASES getUnicodeChar "${icon:-${TMUX_ICON_HOST:-localhost}}")"
    if ${TMUX_SB_SHOW_HOSTNAME:-false}; then
      [[ -z $icon && -z $info ]] && info="$(hostname | tr '[a-z]' '[A-Z]' | sed 's/\..*//')"
    else
      [[ -e $TMP_MEM_PATH/tmux.cfg ]] && source $TMP_MEM_PATH/tmux.cfg
      [[ ! -z $TMUX_SB_LEFT ]] && info="$TMUX_SB_LEFT"
    fi
    [[ -z "$info" ]] && info="$(hostname | tr '[a-z]' '[A-Z]' | sed 's/\..*//')"
  fi
  [[ $info != '#'* ]] && info="$format$info"
  $overSSH && info+="$($ALIASES getUnicodeChar "ssh")"
  printf " %b %s " "$info" "$end"
} # }}}
status_left() { # {{{
  if [[ $1 == --extra ]]; then
    tmux set -qg status-left "#($HOME/.tmux.bash status_left_extra -s '#S')"
    return 0
  fi
  local info="$1"
  local format="${2:-$(status_left_extra --format)}"
  if [[ -z "$info" ]]; then
    info="$(status_left_extra --default)"
  else
    info=" $format$info$(status_left_extra --end) "
  fi
  tmux set -qg status-left "$(printf "%b" "$info")"
} # }}}
window_status_flags() { # {{{
  local flags="$1"
  flags="${flags/\*}"
  flags="${flags/-}"
  if [[ $flags == *M* ]]; then
    flags="${flags/M}"
  fi
  if [[ $flags == *Z* ]]; then
    flags="${flags/Z}"
    flags="$($ALIASES getUnicodeChar 'zoom')$flags"
  fi
  printf "%b" "$flags"
} # }}}
plugins() { # {{{
  [[ $TMUX_VERSION -le 16 ]] && return 0
  tmux set -qg @tpm_plugins 'tmux-plugins/tpm tmUx-plugins/tmux-yank morantron/tmux-fingers'
  tmux set -qg @copy_mode_yank_wo_newline '!'
  tmux set -qg @copy_mode_yank 'Enter'
  tmux set -qg @copy_mode_put 'C-y'
  tmux set -qg @copy_mode_yank_put 'M-y'
  local i= cnt=0
  for i in $TMUX_FINGERS_REGEX; do
    tmux set -qg @fingers-pattern-$cnt "$i"
    cnt="$(($cnt+1))"
  done
  tmux set -qg @fingers-key "f"
  tmux set -qg @fingers-ctrl-action "tmux paste-buffer"
  tmux run-shell ~/.tmux/plugins/tpm/tpm
} # }}}
copy_mode() { # {{{
  local table="-t vi-copy"
  local prefix=
  [[ $TMUX_VERSION -ge 24 ]] && table="-T copy-mode-vi" && prefix="send-keys -X"
  tmux bind-key $table \|  $prefix start-of-line
  tmux bind-key $table v   $prefix begin-selection
  tmux bind-key $table Y   $prefix copy-end-of-line
  tmux bind-key $table C-v $prefix rectangle-toggle
  tmux bind-key $table [   $prefix page-up
  tmux bind-key $table ]   $prefix page-down
  if [[ $TMUX_VERSION -ge 24 ]]; then
    tmux bind-key $table a   $prefix append-selection
    tmux bind-key $table c   $prefix copy-selection
    tmux bind-key $table C   $prefix copy-selection-and-cancel
  elif [[ $TMUX_VERSION -gt 20 ]]; then
    tmux bind-key $table a   append-selection -x
    tmux bind-key $table c   copy-selection   -x
  fi
} # }}}
edit_mode() { # {{{
  [[ $TMUX_VERSION -ge 24 ]] && return 0
  tmux bind-key -ct vi-edit \|  start-of-line
  tmux bind-key -ct vi-edit C-a start-of-line
  tmux bind-key -ct vi-edit C-e end-of-line
} # }}}
splitting() { # {{{
  getSizeParam() {
    if [[ $TMUX_VERSION -ge 34 ]]; then
      echo "-l $1%"
    else
      echo "-p $1"
    fi
  }
  local params=
  [[ $TMUX_VERSION -gt 16 ]] && params="-c \"#{pane_current_path}\""
  tmux bind-key \| run-shell "~/.tmux.bash smarter_nest -z#{window_zoomed_flag} '|'  'split-window -h $(getSizeParam 25) $params'"
  tmux bind-key -  run-shell "~/.tmux.bash smarter_nest -z#{window_zoomed_flag} '-'  'split-window -v $(getSizeParam 20) $params'"
  tmux bind-key \\ run-shell "~/.tmux.bash smarter_nest -z#{window_zoomed_flag} '\\' 'split-window -h       $params'"
  tmux bind-key _  run-shell "~/.tmux.bash smarter_nest -z#{window_zoomed_flag} '_'  'split-window -v       $params'"
  # tmux bind-key p  run-shell "~/.tmux.bash smarter_nest --dbg=$TMP_MEM_PATH/tm-bash.log -z#{window_zoomed_flag} 'p'  'split-window -v -p 20 $params'"
} # }}}
new_window() { # {{{
  local params=
  [[ $TMUX_VERSION -gt 16 ]] && params="-c \"#{pane_current_path}\""
  tmux bind-key Enter   run-shell "~/.tmux.bash smarter_nest 'Enter' 'new-window -a $params'"
  tmux bind-key c       run-shell "~/.tmux.bash smarter_nest 'c'     'new-window -a $params\\; split-window -v -p 20 -d $params'"
  tmux bind-key M-Enter new-window -a $params
  tmux bind-key K       choose-window -F 'Kill: #W (#{window_panes})' 'kill-window -t %%'
} # }}}
get_marked_pane() { # {{{
  local pane=
  local auto_check_nest=$(tmux show-options -wqv @mark_auto)
  [[ -z $auto_check_nest ]] && auto_check_nest=$(tmux show-options -gqv @mark_auto)
  if [[ $auto_check_nest == 'true' ]]; then
    pane="$($ALIASES getUnicodeChar 'smart')"
  fi
  printf "%b" "$pane"
} # }}}
select_marked_pane() { # @@ # {{{
  local paneId="$(tmux list-panes -F '#D #S:#W.#D' | awk '/^'"$1 "'/ {print $2}')"
  [[ -z $paneId ]] && return 1
  local markedPaneId="$(tmux list-panes -F '#{pane_marked} #S:#W.#D' | awk '/^1/ {print $2}')"
  if [[ -z $markedPaneId ]]; then
    local firstPaneId="$(tmux list-panes -F '#P #S:#W.#D' | awk '/^1 / {print $2}')"
    tmux select-pane -t $paneId -m
    if [[ $firstPaneId == $paneId ]]; then
      tmux last-pane -Z
    else
      tmux select-pane -t 1
    fi
    return 0
  fi
  if [[ $paneId == $markedPaneId ]]; then
    markedPaneId=
  fi
  if [[ -z $markedPaneId ]]; then
    tmux select-pane -t $paneId -m
    tmux last-pane -Z
  else
    tmux select-pane -t $paneId -m
    tmux switch-client -t $markedPaneId
  fi
} # }}}
mark_toggle() { # {{{
  local delay= delayed=false local_set=false zoom=0
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -D)  delayed=true;;
    -d*) delay=${1/-d}; [[ -z $delay ]] && delay=3;;
    -l)  local_set=true;;
    -z0 | -z1) zoom=${1#-z};;
    esac
    shift
  done # }}}
  local auto_check_nest=$(tmux show-options -wqv @mark_auto) auto_check_nest_g=$(tmux show-options -gqv @mark_auto)
  if [[ $zoom == 1 && $auto_check_nest == 'false' && $auto_check_nest_g == 'true' ]]; then
    auto_check_nest=true
  fi
  [[ -z $auto_check_nest ]] && auto_check_nest=$auto_check_nest_g
  if $local_set; then # {{{
    case $auto_check_nest in
    true)           tmux set-option -w @mark_auto false;;
    false|toggling) tmux set-option -wqu @mark_auto;;
    esac
    # }}}
  else # {{{
    case $auto_check_nest in
    true)     ! $delayed && [[ -z $delay ]] && tmux set-option -g @mark_auto false;;
    false)    ! $delayed && tmux set-option -g @mark_auto true;;
    toggling) $delayed && tmux set-option -g @mark_auto true;;
    esac
  fi # }}}
  if [[ ! -z $delay ]]; then # {{{
    [[ $auto_check_nest == 'true' ]] && tmux set-option -g @mark_auto toggling
    tmux run-shell -b "sleep $delay; ~/.tmux.bash mark_toggle -D"
  fi # }}}
  local interval=$(tmux show-options -gqv status-interval)
  tmux set -qg status-interval 1
  tmux run-shell -b "sleep 1; tmux set -qg status-interval $interval"
} # }}}
smarter_nest_allowed() { # {{{
  [[ "$(tmux display-message -pF '#{window_panes}')" == 1 ]] || return 1
  case "$1" in
  *split-window*)    return 1;;
  *next-window*)     return 1;;
  *previous-window*) return 1;;
  esac
  return 0;
} # }}}
smarter_nest_docker_toggle() { # {{{
  local checkDocker=$(tmux show-options -wqv @mark_auto_docker)
  [[ -z $checkDocker ]] && checkDocker=${TMUX_SMART_CHECK_DOCKER:-true}
  if $checkDocker; then
    tmux set-option -w @mark_auto_docker false
    tmux display-message "Smart nest for docker disabled"
  else
    tmux set-option -w @mark_auto_docker true
    tmux display-message "Smart nest for docker enabled"
  fi
} # }}}
smarter_nest() { # @@ # {{{
  local send_prefix= key= version= do_eval=true dbg=false log_f='/dev/stderr' err= zoom= keep_zoom=false
  if [[ -e $TMP_MEM_PATH/tmux.dbg ]]; then
    dbg=true
    source $TMP_MEM_PATH/tmux.dbg
  fi
  [[ $1 == --dbg ]] && dbg=true && shift
  [[ $1 == --dbg=* ]] && dbg=true && log_f="${1#--dbg=}" && shift
  $dbg && [[ $log_f != '/dev/stderr' ]] && exec 2>>$log_f
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --no-prefix) send_prefix='NONE';;
    --ver)       shift; version=$1;;
    --no-eval)   do_eval=false;;
    -z0 | -z1)   zoom=${1#-z};;
    -Z0 | -Z1)   zoom=${1#-Z}; keep_zoom=true;;
    --keep-zoom) keep_zoom=true;;
    *)           key=$1; shift; break;;
    esac; shift
  done # }}}
  $dbg && echo "key=[$key]" >>$log_f
  [[ ! -z $version && $TMUX_VERSION -le $version ]] && return 0
  [[ -z $send_prefix ]] && send_prefix=${TMUX_PREFIX_2:-$(tmux show-options -gv prefix2)} || send_prefix=
  local pane_info= auto_check_nest=$(tmux show-options -wqv @mark_auto) auto_check_nest_g=$(tmux show-options -gqv @mark_auto)
  if ! $auto_check_nest && ( [[ $zoom == 1 ]] || smarter_nest_allowed "$@" ); then
    [[ $auto_check_nest_g == 'false' || $auto_check_nest_g == 'toggling' ]] && auto_check_nest=false || auto_check_nest=true
  fi
  [[ -z $auto_check_nest ]] && auto_check_nest=$auto_check_nest_g
  if [[ $auto_check_nest == 'true' ]] && ! ${TMUX_SMART_IGNORE:-false}; then # {{{
    local checkDocker=$(tmux show-options -wqv @mark_auto_docker)
    [[ -z $checkDocker ]] && checkDocker=${TMUX_SMART_CHECK_DOCKER:-true}
    pane_info=$(tmux display-message -p -t $TMUX_PANE -F '#P:#{pane_pid}')
    if ! $IS_MAC; then
      local ps_out="$(command ps -o args -g ${pane_info/*:})"
    else
      local ps_out="$(command pstree ${pane_info/*:} | sed "s/.*= [0-9]\+ $USER //")"
    fi
    local dockerInclude="^--------------nop"
    $checkDocker && dockerInclude="^docker-compose|^docker attach|^docker run"
    if echo "$ps_out" | command grep -q -P "^tmux|^ssh +((-\S+ *)|(-p *\d+ *))* *(\S+@)?(\w+|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+)?$|$dockerInclude"; then
      if echo "$ps_out" | command grep -q "^\(sh -c \)\{0,1\}vlock\|^git\|^scp\|^rsync"; then
        pane_info=
      else
        if [[ ! -z $TMUX_SMART_BLACKLIST_SSH ]] && echo "$ps_out" | command grep "ssh" | command grep -q "$TMUX_SMART_BLACKLIST_SSH"; then
          pane_info=
        elif $checkDocker && [[ ! -z $TMUX_SMART_BLACKLIST_DOCKER ]] && echo "$ps_out" | command grep -q -P "$dockerInclude" ; then
          local dockerCmd="$(echo "$ps_out" | command grep -P "$dockerInclude" | head -n1)"
          local dockerName="$dockerCmd"
          [[ $dockerCmd == "docker attach "* ]] && dockerName=$(docker ps -a | command grep "^${dockerCmd#* attach }")
          if [[ ! -z $dockerName ]] && echo "$dockerName" | command grep -q "$TMUX_SMART_BLACKLIST_DOCKER"; then
            pane_info=
          fi
        fi
      fi
    else
      pane_info=
    fi
  fi # }}}
  [[ $auto_check_nest_g == 'toggling' ]] && tmux set-option -g @mark_auto true
  $dbg && echo "pane_info=[$pane_info]" >>$log_f
  if [[ ! -z $pane_info ]]; then # {{{
    pane_info=${pane_info/:*}
    [[ ! -z $send_prefix ]] && tmux send-keys -t .$pane_info $send_prefix
    tmux send-keys -t .$pane_info $key
    # }}}
  else # {{{
    if [[ ! -z $1 ]]; then
      todo="$@"
      todo="${todo//@TMUX_PATH@/\"$(tmux show -v @tmux_path)\"}"
      todo="${todo//@@/\'}"
      $dbg && set -xv
      if [[ ! -z $zoom ]] && $keep_zoom; then
        preserve_zoom $(! $do_eval && echo "--no-eval") $zoom $todo
      elif $do_eval; then
        eval tmux $todo
      else
        tmux $todo
      fi
      err=$?
      $dbg && set +xv
      [[ $err == 0 ]] || tmux display-message "Cannot do '$todo'"
    elif [[ ! -z $CMD ]]; then
      eval tmux $CMD
      err=$?
      [[ $err == 0 ]] || tmux display-message "Cannot do '$CMD'"
    fi
  fi # }}}
  $dbg && echo "---" >>$log_f
  return 0
} # }}}
lock_toggle() { # @@ # {{{
  local verbose=true mode='toggle' changed=false
  [[ -z $1 ]] && set - ssh
  while [[ ! -z $1 ]]; do
    case $1 in
    -q) verbose=false;;
    --lock)   mode='lock';;
    --unlock) mode='unlock';;
    --lock-allowed) # {{{
      local w_status="$(tmux show-option -qv @lock_allowed)" g_status="$(tmux show-option -gqv @lock_allowed)" new_status=
      case $w_status in
      false) # {{{
        [[ "$mode" == 'lock' ]] && shift && continue
        $verbose && tmux display-message "Locking changed to global value ($( ${g_status:-true} && echo 'ENABLED' || echo 'DISABLED'))"
        tmux set-option -uq @lock_allowed
        changed=true;; # }}}
      *) # {{{
        case $g_status in
        false) # {{{
          [[ "$mode" == 'lock' ]] && shift && continue
          new_status='true';; # }}}
        *) # {{{
          [[ "$mode" == 'unlock' ]] && shift && continue
          new_status='false';; # }}}
        esac
        $verbose && tmux display-message "Locking $( $new_status && echo 'ENABLED' || echo 'DISABLED') $( [[ $1 == -g ]] && echo 'globally' || echo 'locally')"
        tmux set-option $( [[ $1 == -g ]] && echo '-g' ) @lock_allowed $new_status
        changed=true;; # }}}
      esac;; # }}}
    --ssh) # {{{
      local lockCmd="$(tmux show-options -vg 'lock-command')"
      if [[ "$lockCmd" == *'sshh-add'* && $UID != 0 ]]; then
        local timeout="${TMUX_LOCK_PRE_TIMEOUT:-60}"
        case $lockCmd in
        *\ --tmux\ -1) # {{{
          [[ "$mode" == 'unlock' ]] && shift && continue
          $verbose && tmux display-message "SSH Agent lock after ${TMUX_LOCK_PRE_TIMEOUT:-60}s";; # }}}
        *\ --tmux\ *) # {{{
          [[ "$mode" == 'lock' ]] && shift && continue
          $verbose && tmux display-message "SSH Agent lock DISABLED"; timeout=-1;; # }}}
        esac
        tmux set -qg lock-command "$ALIASES sshh-add --lock --tmux $timeout"
        changed=true
      fi;;# }}}
    --screen) # {{{
      local timeout="${TMUX_LOCK_TIMEOUT:-300}"
      case "$(tmux show-options -vg 'lock-after-time')" in
      0) # {{{
        [[ "$mode" == 'unlock' ]] && shift && continue
        $verbose && tmux display-message "Screen saver after ${timeout}s";; # }}}
      *) # {{{
        [[ "$mode" == 'lock' ]] && shift && continue
        $verbose && tmux display-message "Screen saver DISABLED"; timeout=0;; # }}}
      esac
      tmux set -g 'lock-after-time' $timeout
      changed=true;; # }}}
    esac
    shift
  done
  $changed && return 0 || return 1
} # }}}
toggle_show_pane_info() { # {{{
  local state="$(tmux show-window-option -gv pane-border-status)"
  case $state in
  off)        state='top';;
  top|bottom) state='off';;
  esac
  tmux set-window-option -qg pane-border-status "$state"
} # }}}
switch_client() { # {{{
  local current_s= i= dst= src=
  current_s="$(tmux display-message -p -t $TMUX_PANE -F '#S')"
  for i in $TMUX_SWITCH_CLIENT_MAP; do
    src="${i%:*}" dst="${i##*:}"
    [[ "$src" == '*' || "$src" == "$current_s" ]] || continue
    [[ "$dst" != "$current_s" ]] || continue
    tmux switch-client -t "$dst"
    return 0
  done
  tmux switch-client -l
  return 0
} # }}}
switch_window() { # {{{
  local current_s= current_w= i= dst= src= local switch_to_last=false
  current_s="$(tmux display-message -p -t $TMUX_PANE -F '#S')"
  current_s="${current_s^^}" && current_s="${current_s//-/_}"
  current_w="$(tmux display-message -p -t $TMUX_PANE -F '#I')"
  for i in $(eval echo \$TMUX_SWITCH_WINDOW_${current_s}_MAP); do
    src="${i%:*}" dst="${i##*:}"
    case $src in
    '*') ;;
    @*)  src="${src#@}";;
    *)   src="$(tmux list-windows -F '#I. @#W' | sed -n -e "/\. @$src$/s/\. .*//p" | head -n1)";;
    esac
    [[ ! -z $src ]] || continue
    [[ "$src" == '*' || "$src" == "$current_w" ]] || continue
    [[ $dst == @* ]] \
      && dst="${dst#@}" \
      || dst="$(tmux list-windows -F '#I. @#W' | sed -n -e "/\. @$dst$/s/\. .*//p" | head -n1)"
    [[ ! -z $dst ]] || continue
    [[ "$dst" != "$current_w" ]] || { switch_to_last=true; continue; }
    tmux select-window -t ":$dst"
    return 0
  done
  if [[ $(tmux display-message -p -t $TMUX_PANE -F '#I') == '1' ]] || $switch_to_last; then
    tmux last-window
  else
    tmux select-window -t :1
  fi
  return 0
} # }}}
scratch_pane() { # @@ # {{{
  local cwd="$1" params="$2" pane_id=
  [[ -z $params ]] && params="-h -p 50"
  [[ -e "$cwd" ]] && params+=" -c \"$cwd\""
  pane_id="$(eval tmux split-window $params -P -F "'#{pane_id}'")"
  sleep 0.5
  tmux send-keys -t $pane_id "pt hn; clear"
} # }}}
pasteKey_worker() { # @@ # {{{
  source ~/.bashrc --do-basic
  local auto=$1 buff="$2" query="$3" v= keys="$(keep-pass.sh --list-all-keys)"
  if [[ ! -z $query ]]; then
    local m="$(echo "$keys" | command grep "$query")"
    [[ $(echo "$m" | wc -l) == 1 ]] && v="$m" && auto=true
  fi
  if [[ -z $v ]]; then
    v="$( \
      echo "$keys" \
      | eval fzf \
        --preview="\"keep-pass.sh --key '{1}' --no-intr\"" \
        +m --prompt="\"Key> \"" $([[ ! -z $query ]] && echo "--query=\"$query\"") -0 \
    )"
    [[ $? == 0 && ! -z "$v" ]] || return 1
  fi
  v="$(keep-pass.sh --key "$v")"
  [[ ! -z $v ]] || return 1
  if $auto; then
    [[ $v == *'..' ]] && v="${v%..}" || v+=""
  fi
  tmux set-buffer -b $buff "$v"
} # }}}
pasteKey() { # @@ # {{{
  local buff="key.$$" pane_src=$(tmux display-message -p -F '#D') pane_id= auto=true key= res=
  pane_src=${pane_src#%}
  local f="$TMP_MEM_PATH/keep-pass.$pane_src.key"
  while [[ ! -z $1 ]]; do
    case $1 in
    --set-key) # {{{
      shift
      local pDelta= pKeep= pCount=
      while [[ ! -z 1 ]]; do
        case $1 in
        --delta)    pDelta=$2; shift;;
        --keep-for) pKeep=$2; pDelta=$2; shift;;
        --keep)     pCount=999; pDelta=0; shift;;
        --count)    pCount=$2; pDelta=0; shift;;
        *)          echo "$1" >"$f"; break;;
        esac
        shift
      done
      [[ ! -z $pDelta ]] && echo "delta=$pDelta" >>"$f"
      [[ ! -z $pKeep  ]] && echo "keep=$pKeep"   >>"$f"
      [[ ! -z $pCount ]] && echo "count=$pCount" >>"$f"
      return 0;; # }}}
    --delete-key) # {{{
      rm -f "$f"
      return 0;; # }}}
    -m) # {{{
      auto=false;; # }}}
    --pane) # {{{
      pane_src=${2#%}; f=${f%.*.key}.$pane_src.key; shift;; # }}}
    esac
    shift
  done
  if [[ -e "$f" ]]; then # {{{
    local delta=30 keep= count= fTime="$(stat -c "%Y" "$f")" cTime="${EPOCHSECONDS:-$($ALIASES epochSeconds)}"
    source <(cat "$f" | command grep "^\(delta\|keep\|count\)=")
    if [[ true == true \
      && ( $delta == 0 || $fTime -gt $((cTime-delta)) ) \
      && ( -z $keep    || $fTime -gt $((cTime-keep)) ) \
      && ( -z $count   || $count -gt 0 ) \
       ]]; then
      key="$(cat "$f" | head -n1)"
      if [[ ! -z $count ]]; then
        count=$((count-1))
        [[ $count -gt 0 ]] && sed -i -e '/^count=/s/=.*/='$count'/' "$f"
      fi
    fi
    if [[ false == true \
      || ( -z $keep   && -z $count ) \
      || ( ! -z $keep && $fTime -lt $((cTime-keep)) ) \
      || ( $count == 0 ) \
       ]]; then
      rm -f "$f"
    fi
  fi # }}}
  tmux delete-buffer -b "$buff" >/dev/null 2>&1
  pane_id="$(tmux split-window -h -p 50 -P -F '#{pane_id}' "$HOME/.tmux.bash pasteKey_worker $auto '$buff' '$key'")"
  while true; do
    res=$(tmux display-message -p -t "$pane_id" -F '#{pane_id}' 2>/dev/null)
    [[ -z $res ]] && break
    sleep 0.5
  done
  tmux list-buffers -F '#{buffer_name}' | command grep -q "^$buff$" \
    && tmux paste-buffer -d -b "$buff"
  return 0
} # }}}
preserve_zoom() { # {{{
  local do_eval=true zoomed=0
  [[ $1 == "--no-eval" ]] && do_eval=false && shift
  zoomed="$1"; shift
  if $do_eval; then
    if [[ $zoomed == 0 ]]; then
      eval tmux "$@"
    else
      eval tmux "$@" \\\; resize-pane -Z
    fi
  else
    if [[ $zoomed == 0 ]]; then
      tmux "$@"
    else
      tmux "$@" \; resize-pane -Z
    fi
  fi
} # }}}

[[ -z $TMUX_VERSION ]] && TMUX_VERSION="$(tmux -V | sed 's/\.//' | cut -c6-7)"
export testing=false
case $1 in
@@) # {{{
  case ${4:-$3} in
  --dbg | --dbg2 | --test | --time) # {{{
    sed -n 's/^\([a-z].*\)() { # @@ .*/\1/p' tmux.bash
    ;; # }}}
  *) # {{{
    echo --{dbg{,2},test,time};; # }}}
  esac;; # }}}
--dbg  |  --dbg2 | --test | --time) # {{{
  export dbg=true
  dbgFull=false sTime=false testing=false
  source "$UNICODE_EXTRA_CHARS_FILE"
  while true; do
    case $1 in
    --test) testing=true;;
    --time) sTime=true;;
    --dbg2) dbgFull=true;;
    --dbg)  ;;
    *)      break;;
    esac
    shift
  done
  export testing
  (
    echo "$@"
    $dbgFull && set -xv
    cur_time=${EPOCHSECONDS:-$($ALIASES epochSeconds)}
    $sTime && { time "$@"; } || { $@; }
    echo
  ) 2>&1
  ;; # }}}
*) "$@";;
esac

