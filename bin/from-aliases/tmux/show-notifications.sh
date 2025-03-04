#!/usr/bin/env bash
# vim: fdl=0

_show-notifications() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    local ret='-r -s -i --no-reset --silent --interactive --check --rerun --first --last 1 2 3 5 10'
    case "$3" in # {{{
    --last | --first) ret="$(date +"%H:%M" -d "hour ago")";;
    esac # }}}
    echo "$ret"
    return 0
  fi # }}}
  notification_handler() { # {{{
    local main_file="$1" ntf_file="$2" ntf_file_tmux="$3"
    if [[ ! -e "$main_file" ]]; then
      echo "#!/bin/bash"                      >"$main_file"
      echo ""                                >>"$main_file"
      echo "export handler_pid=\"-1\""       >>"$main_file"
      echo "export main_file=\"$main_file\"" >>"$main_file"
      echo "export ntf_file=\"$ntf_file\""   >>"$main_file"
      rm -f "$ntf_file"
    fi
    sed -i "s/^export handler_pid=.*/export handler_pid=\"$BASHPID\"/" "$main_file"
    touch -d '' "$ntf_file"
    source "$main_file"
    $TMUX_NOTIFICATION_PRODUCER | while read l; do
      l="$(date +"$DATE_FMT"): $l"
      echo "$l" >>"$ntf_file"
      $TMUX_NOTIFICATION_PRODUCER --for-tmux "$l" && echo "$l" >>"$ntf_file_tmux"
    done
  } # }}}
  check_if_running() { # {{{
    local main_file="$TMP_MEM_PATH/notifications.sh"
    local ntf_file="$1" shift
    local rerun=false
    while [[ ! -z $1 ]]; do
      case $1 in
      -r) rerun=$2; shift;;
      esac
      shift
    done
    type $TMUX_NOTIFICATION_PRODUCER >/dev/null 2>&1 || { echo "Producer not present [$TMUX_NOTIFICATION_PRODUCER]" >/dev/stderr; return 1; }
    local handler_pid=-1
    if [[ -e "$main_file" ]]; then # {{{
      source "$main_file"
      if ps ax | grep -q "^\s*${handler_pid}.*notification_handler"; then
        ! $rerun && return 0
        pkill -P $handler_pid
        ps ax | grep "${TMUX_NOTIFICATION_PRODUCER##*/}" | awk '{print $1}' | xargs -r kill
      fi
      # }}}
    else # {{{
      sleep .$((1 + $RANDOM % 5))
      [[ ! -e "$main_file" ]] || return 0
    fi # }}}
    export -f notification_handler
    bash -c "notification_handler '$main_file' '$ntf_file' '$ntf_file_tmux'" &
    local j=`jobs`
    disown
    sleep .5
    if [[ -z "$j" ]] || echo "$j" | grep -q "Done"; then
      echo "Handler has not started" >/dev/stderr
      return 1
    fi
    return 0
  } # }}}
  local ntf_file="${NOTIFICATION_FILE:-$TMP_MEM_PATH/notifications.txt}" ntf_file_tmux="${NOTIFICATION_FILE_TMUX:-$TMP_MEM_PATH/notifications-tmux.txt}"
  local cnt=10 reset=true interactive=false rerun=false check=true first_time= last_time=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -r | --no-reset)    reset=false;;
    -s | --silent)      cnt=0;;
    -i | --interactive) interactive=true;;
    --first)            first_time="$(date +"%H%M%S" $([[ $2 != '.' ]] && echo "-d $2"))"; shift;;
    --last)             last_time="$( date +"%H%M%S" $([[ $2 != '.' ]] && echo "-d $2"))"; shift;;
    --no-check)         check=false;;
    --rerun)            rerun=true; check=true;;
    *)                  cnt=$1;;
    esac
    shift
  done # }}}
  if $check; then # {{{
    check_if_running "$ntf_file" -r $rerun || { unset check_if_running notification_handler; return 1; }
  fi # }}}
  unset check_if_running notification_handler
  [[ ! -e "$ntf_file" ]] && return 1
  if ! $interactive; then # {{{
    if [[ $cnt -gt 0 ]]; then
      local today=$(date +"%Y%m%d") l=
      tail -n ${cnt} "$ntf_file" | while read l; do
        echo "$l" | grep -q "^$today" || continue
        echo "$l"
      done
    fi
    $reset && touch -d '' "$ntf_file" "$ntf_file_tmux"
    # }}}
  else # {{{
    touch -d '' "$ntf_file_tmux"
    local today=$(date +"%Y%m%d") l= key= last_5m= refresh_time=
    [[ -z "$first_time" ]] && first_time="000000"
    [[ -z "$last_time"  ]] && last_time="$(date +"%H%M%S")"
    source $BASH_PATH/colors
    local tmux_pane= prev_msgs= prev_show=false
    [[ -n $TMUX ]] && tmux_pane="$(tmux display-message -p -t $TMUX_PANE -F '#S:#I.#P')"
    set-title "Notifications"
    while true; do
      [[ ! -z $tmux_pane ]] && tmux clear-history -t "$tmux_pane"
      clear
      last_5m="$(date +"%H%M%S" -d "5 minutes ago")"
      echo -n "Events since ["
      echo -n "${CGreen}$(date +"%H:%M" -d "${first_time:0:4}")${COff}"
      [[ $last_time != $first_time ]] && echo -n "/${CSearch}${last_time:0:2}:${last_time:2:2}${COff}"
      [[ "1$last_5m" -gt "1$last_time" ]] && echo -n "/${CRed}${last_5m:0:2}:${last_5m:2:2}${COff}"
      echo -n "]: "
      progress --dots --cnt 10 --no-err --msg '' --end-msg ':'
      local last_msgs= add_msg=false
      while read l; do # {{{
        echo "$l" | grep -q "^$today" || continue
        local n_time="$(echo "$l" | sed 's/^[0-9]*-\([0-9]*\):.*/\1/')" for_tmux="$($TMUX_NOTIFICATION_PRODUCER --for-tmux "$l" && echo "true" || echo "false")"
        [[ "1$n_time" -lt "1$first_time" ]] && continue
        local color="${CGreen}"
        ! $add_msg && [[ ! -z $refresh_time && "1$n_time" -gt "1$refresh_time" ]] && add_msg=true
        if $for_tmux || $TMUX_NOTIFICATION_PRODUCER --highlight "$l"; then
          [[ "1$n_time" -gt "1$last_time" ]] && color="${CSearch}"
          [[ "1$n_time" -gt "1$last_5m" && "1$last_5m" -gt "1$last_time" ]] && color="${CRed}"
        fi
        echo "$l" | sed -e "s/[0-9]*-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\(:.*\)/$color\1:\2$COff\4/"
        if $add_msg && $for_tmux; then # {{{
          l="$($TMUX_NOTIFICATION_PRODUCER --convert-message "$l")"
          [[ ! -z $l ]] && last_msgs="$l,$last_msgs"
        fi # }}}
      done < <(cat "$ntf_file" | awk '!x[$0]++' | tail -n 20) # }}}
      [[ ! -z $last_msgs ]] && last_msgs="$(echo "$last_msgs" | cut -d',' -f 1-5)" && last_msgs="${last_msgs%,}"
      if [[ ( ! -z $last_msgs || ! -z $prev_msgs ) && -n $TMUX ]]; then # {{{
        if [[ ! -z $last_msgs ]]; then
          tmux display-message "$last_msgs"
          prev_msgs="Prev: $last_msgs"
        elif $prev_show; then
          [[ ! -z $prev_msgs ]] && tmux display-message "$prev_msgs"
          prev_show=false
        fi
      fi # }}}
      refresh_time=
      read -t $((5*60)) key
      if [[ $? == 0 ]]; then # {{{
        case $key in # {{{
        q) break;;
        r | R | rr) # {{{
          touch -d '' "$ntf_file" "$ntf_file_tmux"
          refresh_time="$last_time"
          last_time="$(date +"%H%M%S")";;& # }}}
        R) first_time="$(date +"%H%M%S")";;&
        rr | R) prev_msgs=;;
        r) prev_show=true;;
        esac # }}}
      fi # }}}
      local t="$(date +"%Y%m%d")"
      if [[ "$today" != "$t" ]]; then # {{{
        today="$t"
        last_time="$(date +"%H%M%S")"
        first_time="000000"
        prev_msgs=""
        touch -d '' "$ntf_file" "$ntf_file_tmux"
      fi # }}}
    done
  fi # }}}
  return 0
} # }}}
_show-notifications "$@"

