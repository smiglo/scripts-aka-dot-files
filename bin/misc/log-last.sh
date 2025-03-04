#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  if [[ $3 == '--cmd' ]]; then
    echo 'quit margin comment check st backup sync fetch pause pause-toggle pause-mod store plot plot-full stats stats-full reschedule'
    echo 'suspend end e! shutdown End E! refresh r reset R pna pnl pni'
    exit 0
  fi
  ret_val=
  ret_val+=' --today --first --full --percentage --tmux --passed --store --store-force --clear --stats --stats-full'
  ret_val+=' --toggle --show-end --show-left --logins --remaining --clear-screen --loop --show-current-time --shutdown'
  ret_val+=' --plot --plot-full --suspend --shutdown --cmd --force-new-day --default --nested --nested-default'
  # noes= i=
  # for i in $ret_val; do
  #   noes+=" --no-${i/--}"
  # done
  extra='% +%'
  echo $ret_val $noes $ret_$extra
  exit 0
fi # }}}
is_to_be_done() { # {{{
  [[ " $to_do $to_do_extra " == *\ $1\ * ]]
} # }}}
reset_vars() { # {{{
  end_at=
  end_margin=0
  extra_added=false
  extra_comment=
  extra_margin=
  inactivity_pause=false
  inactivity_pause_allowed=${LOGLAST_USE_INACTIVITY_PAUSE:-true}
  inactivity_pause_not_allowed_end=0
  inactivity_ts=0
  overtime_msg_sent=false
  pause_auto_unpause=true
  pause_buffer=15
  pause_locked=false
  pause_margin=0
  pause_msg_show=false
  paused=false
  paused_last_time=
  paused_time=
  startup_margin=0
  user_comment=
  user_margin=0
} # }}}
save_info() { # {{{
  local mem_file=$MEM_KEEP/work_time.nfo list=
  list+=" user_margin user_comment paused paused_time paused_last_time pause_margin pause_buffer extra_added end_at"
  list+=" overtime_msg_sent pause_auto_unpause"
  list+=" inactivity_pause inactivity_ts inactivity_pause_allowed inactivity_pause_not_allowed_end"
  (
    for i in $list; do
      declare -p $i
    done
  ) >$mem_file
  rsync $mem_file $FILE_DATA
} # }}}
reschedule() { # {{{
  local schedule_f="$APPS_CFG_PATH/log-last/schedule.txt"
  [[ -e "$schedule_f" ]] || return 1
  local days=( [1]="pn" [2]="wt" [3]="sr" [4]="czw" [5]="pt" )
  local dow=$(date +'%w') today=$((10#$(date +%m%d)))
  local dbg=false
  local t= w= cond= action= checkForRemval= extraLLCmd=
  cat "$schedule_f" | sed -n -e '/^\s*#/d' -e '/^'"${days[dow]}"':/,/^[^ ]/p' | sed -e '/^[^ ]/d' | \
  while read t w; do
    [[ -z $t ]] && continue
    checkForRemval= extraLLCmd=
    w="$(echo $w | tr -s ' ')"
    cond=true
    w="${w% # *}"
    case $w in
    *\ if\ *) # {{{
      cond="[[ ${w#* if } ]]"
      cond="${cond// >= / -ge }"
      cond="${cond// > / -gt }"
      cond="${cond// <= / -le }"
      cond="${cond// < / -lt }"
      w="${w% if *}";; # }}}
    *\ on\ *) # {{{
      checkForRemval=${w#* on }
      cond="[[ $today == $((10#${w#* on })) ]]"
      w="${w% on *}";; # }}}
    *\ until\ *) # {{{
      checkForRemval=${w#* until }
      cond="[[ $today -le $((10#${w#* until })) ]]"
      w="${w% until *}";; # }}}
    *\ after\ *) # {{{
      cond="[[ $today -gt $((10#${w#* after })) ]]"
      w="${w% after *}";; # }}}
    esac
    $dbg && echorv -nl t w cond
    if [[ $w == *' @:'* ]]; then # {{{
      extraLLCmd="${w##* @:}" && extraLLCmd="${extraLLCmd# }"
      w="${w% @:*}" # }}}
    elif [[ $w == *' @'* ]]; then # {{{
      extraLLCmd="pni ${w##* @}"
      w="${w% @*}"
    fi # }}}
    case $w in
    @\ *) # {{{
      w="${w#@ }"
      if [[ "$extraLLCmd" == "pni"* ]]; then
        w+="@${extraLLCmd#pni }"
        extraLLCmd=
      fi
      action="--no-at ll-pni.sh '$w'";; # }}}
    \!\ *)  w="${w#! }" ; action="'$w'";;
    GH\ *)  w="${w#GH }"; action="go-home.sh '$w'";;
    P\ *)   w="${w#P }" ; action="pause.sh '$w'";;
    *)      action="pause.sh '$w'";;
    esac
    $dbg && echorv -nl w action extraLLCmd
    if ! eval "$cond"; then # {{{
      $dbg && echor "cond-NOK"
      if [[ ! -z $checkForRemval && $today -gt $checkForRemval ]]; then
        local name="Fix-schedule-${days[dow]}-$t"
        do-action "reminder -s '$name' '$(time2s 10m)'" if-not-found "$name\$" 'in' "reminder --list"
      fi
      continue
    fi # }}}
    if do-action "reminder -s $action '$t'" if-not-found "$w\$" 'in' "reminder --list" && [[ ! -z $extraLLCmd ]]; then
      [[ $extraLLCmd == *@* ]] && t="${extraLLCmd#*@}" && extraLLCmd="${extraLLCmd%%@*}"
      reminder -s $0 --cmd $extraLLCmd "$t"
    fi
  done
} # }}}
__util_loglast_extra() { # {{{
  local cmd="$1" && shift
  case $cmd in
  @@) # {{{
    echo "reset suspend" ;; # }}}
  set-comment) # {{{
    local DEF_COMMENT= c= comment=
    [[ -e $APPS_CFG_PATH/log-last/log-last.cfg ]] && source $APPS_CFG_PATH/log-last/log-last.cfg
    for i in $BASH_PROFILES_FULL; do
      [[ -e "$i/aliases" ]] && c="$($i/aliases __util_loglast_extra "$cmd" "$DEF_COMMENT" $@)"
      [[ ! -z $c ]] && comment+=", $c"
    done
    comment="${comment#, }"
    echo "${comment:-$DEF_COMMENT}"
    return 0;; # }}}
  suspend) # {{{
    tm --b-dump
    tm --l-dump --all --file "susp-$(date +"$DATE_FMT").layout";; # }}}
  reset) # {{{
    local resetFile="$TMP_MEM_PATH/log-last-reset.tmp"
    if [[ ! -e $resetFile || "$(stat -c %y "$resetFile" | awk '{print $1}')" != "$(date +"%Y-%m-%d")" ]]; then
      $BASH_PATH/runtime --force --clean-tmp-silent
      touch -d '' "$resetFile"
    fi
    if [[ -n $TMUX ]]; then
      $HOME/.tmux.bash status_right_refresh
    fi;; # }}}
  new-day) # {{{
    $BASH_PATH/runtime --force --clean-tmp-silent
    __util_loglast_extra 'reset'
    reschedule
    ;; # }}}
  help) # {{{
    ;; # }}}
  esac
  for i in $BASH_PROFILES_FULL; do
    [[ -e "$i/aliases" ]] && $i/aliases __util_loglast_extra "$cmd" $@
  done
  [[ -e $APPS_CFG_PATH/log-last/extra-work.sh ]] && $APPS_CFG_PATH/log-last/extra-work.sh "$cmd" $@
} # }}}
loglast() { # {{{
  local LOGLAST_FILE=$APPS_CFG_PATH/log-last/work_time.default
  [[ -e $APPS_CFG_PATH/log-last/conf.sh ]] && source $APPS_CFG_PATH/log-last/conf.sh
  local FILE_DATA=${LOGLAST_FILE}.nfo CMD_FILE=$TMP_MEM_PATH/.loglast.cmd
  [[ ! -e "$(dirname $LOGLAST_FILE)" ]] && mkdir -p "$(dirname $LOGLAST_FILE)"
  local LOOP_TIME=60
  local CMsg='[38;5;8m'
  local to_do='' to_do_extra=''
  local margin_s= TODAY= TODAY_YMD= end_delay= end_delay_ask=15 i=
  local colors=true force_new_day=false isDbg=false isRlWrap=true
  local pause_msg_last_time=0
  local inactivity_delta=$((15*60)) pause_lock_delta=$((15*60)) pause_msg_delta=$((10*60)) paused_suspend_delta=$((30*60)) overtime_delta=$((20*60))
  local inactivity_f=$MEM_KEEP/locks/ssh-lock
  local pause_char="$(get-unicode-char 'pause')" normal_char="$(get-unicode-char 'play')"
  local iconOk="$(get-unicode-char 'icon-ok')" iconNok="$(get-unicode-char 'icon-err')"
  is-installed rlwrap || isRlWrap=false
  # Vars cleared in reset_vars() # {{{
  local end_at end_margin extra_added extra_comment extra_margin
  local inactivity_pause inactivity_pause_allowed inactivity_pause_not_allowed_end inactivity_ts
  local overtime_msg_sent
  local pause_auto_unpause pause_buffer pause_locked pause_margin pause_msg_show paused paused_last_time paused_time
  local startup_margin user_comment user_margin
  reset_vars
  # }}}
  [[ ! -t 1 ]] && colors=false
  [[ -z $1 ]] && set -- --default
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --full    | \
    --logins  | --remaining   | \
    --toggle  | --show-end    | --show-left | --percentage | --passed | \
    --store   | --store-force | \
    --stats   | --stats-full  | \
    --loop    | --show-current-time | \
    --first   | --today    | \
    --suspend | --shutdown | \
    --plot | \
    --clear-screen)     to_do+=" ${1/--}";;&
    --loop)             [[ $2 =~ ^[0-9]+$ ]] && LOOP_TIME=$(( $2 * 60 )) && shift;;&
    --default | --loop) to_do+=" logins first remaining passed show-left show-end show-current-time" ;;
    --stats-full)       to_do+=' stats';&
    --stats)            to_do+=' stats-main';;
    --store-force)      to_do+=' store';&
    --store)            to_do+=' stats-main';;
    --logins)           to_do+=' highlight';;
    --remaining)        to_do+=' show-left';;
    +%)                 to_do+=' percentage';;
    %)                  to_do+=' percentage';;&
    --percentage|%)     to_do=${to_do//'show-left'}; to_do=${to_do//'show-end'};;
    --tmux)             to_do='  tmux remaining show-left';;
    --nested-default)   to_do='logins first full';;&
    --nested | \
    --nested-default)   to_do+=' nested';;
    --no-colors)        colors=false;;
    --force-new-day)    force_new_day=true;;
    --no-*)             to_do=${to_do//${1/'--no-'}};;
    --clear)            to_do=''; cmd='';;
    --cmd)              shift; echo "$@" >>$CMD_FILE; return 0;;
    esac
    shift
  done # }}}
  to_do=" $to_do "
  source $RUNTIME_FILE
  if ! $colors; then
    export colorsOn=false
    unset $($BASH_PATH/colors --list)
    CMsg=""
  fi
  [[ -e $TMP_PATH/.log-last.today ]] && source $TMP_PATH/.log-last.today
  [[ -e $TMP_MEM_PATH/log-last.new-day ]] && force_new_day=true && rm $TMP_MEM_PATH/log-last.new-day
  ! is_to_be_done 'nested' && ! is_to_be_done 'tmux' && set-title 'Working Time'
  ! is_to_be_done 'nested' && mutex-init "work-time" --auto-clean-after 60 --no-trap
  while true; do # {{{
    if [[ $((10#$(date +%H%M))) -gt 2330 ]]; then # {{{
      if is_to_be_done 'tmux'; then
        echo -n "#[fg=yellow]H$pause_char#[fg=white]"
        return 0
      else
        notify-send 'Time Tracker: Quite late, holding for safety' -u 'critical'
        touch $TMP_MEM_PATH/log-last.new-day
        while true; do
          local key=
          read -t 60 -p 'Say "cont" to continue... ' key && [[ ${key,,} == 'cont' ]] && break
        done
      fi
    fi # }}}
    local new_today="$(LC_TIME=en_US.UTF-8 date +'%b %_d' | tr -s ' ')"
    $force_new_day && TODAY= && force_new_day=false
    local dow=$(date +'%w')
    if [[ "$new_today" != "$TODAY" ]]; then # {{{
      if ! is_to_be_done 'nested' && [[ -z $(loglast --nested-default | cut -c8-12) ]]; then # {{{
        progress \
          --dots --no-err \
          --msg "Waiting for login time..." --color "${CGold}" \
          --cmd "! test -z \$(loglast --nested-default | head -n1 | cut -c8-12)"
      fi # }}}
      TODAY=$new_today
      TODAY_YMD="$(date +"%Y%m%d")"
      (
        echo "export TODAY='$TODAY'"
        echo "export TODAY_YMD='$TODAY_YMD'"
      ) >$TMP_PATH/.log-last.today
      reset_vars
      if [[ -n $LOGLAST_MARGIN ]]; then # {{{
        [[ ${#LOGLAST_MARGIN[*]} == 1 ]] && startup_margin=$LOGLAST_MARGIN || startup_margin=${LOGLAST_MARGIN[$dow]}
        sm="${startup_margin/*:}"
        extra_comment+=", $sm"
        startup_margin=${startup_margin/:*}
      fi # }}}
      if [[ -z $startup_margin ]]; then # {{{
        case $dow in
        1) startup_margin=${LOGLAST_SMARGIN_MON:-5};;
        *) startup_margin=${LOGLAST_SMARGIN:-3};;
        esac
      fi # }}}
      case $dow in # {{{
      6) extra_comment+=", sat";;&
      0) extra_comment+=", sun";;&
      0 | 6) paused=true ;;
      esac # }}}
      if is_to_be_done 'loop'; then # {{{
        __util_loglast_extra 'new-day'
        ec="$(__util_loglast_extra 'set-comment')"
        if [[ ! -z $ec ]]; then
          extra_margin="${ec%%:*}"
          extra_comment+=", ${ec#*:}"
          extra_comment="${extra_comment#, }" && extra_comment="${extra_comment%, }"
        fi
        to_do_extra+=" store-force stats-main send "
        if [[ ! -e $FILE_DATA || $(date -ud "@$(stat -c %Y $FILE_DATA)" +"%Y%m%d") != $TODAY_YMD ]]; then
          save_info
        fi
      fi # }}}
    fi # }}}
    [[ -e $FILE_DATA ]] && source $FILE_DATA
    extra_comment="${extra_comment#, }" && extra_comment="${extra_comment%, }"
    if ! $extra_added; then # {{{
      [[ ! -z $extra_margin ]] && user_margin=$((user_margin+extra_margin))
      [[ ! -z $extra_comment && $user_comment != *"$extra_comment"* ]] && user_comment="$(echo "$user_comment, $extra_comment")"
      user_comment="${user_comment#, }" && user_comment="${user_comment%, }"
      extra_added=true extra_margin= extra_comment=
      save_info
    fi # }}}
    case $dow in
    0 | 6) # {{{
      if is_to_be_done 'tmux'; then
        echo -n "#[fg=yellow]W$pause_char#[fg=white]"
        return 0
      elif ! is_to_be_done 'loop'; then
        return 0
      fi
      if ! $pause_msg_show; then
        is_to_be_done 'clear-screen' && clear
        notify-send 'Time Tracker: Weekend, tracking is ignored' -u 'critical'
        pause_msg_show=true
      else
        echo -e "${CMsg}---${Coff}  ${CYellow}Weekend time${COff}  ${CMsg}---${COff}"
        while true; do
          local key=
          read -t $((2*60*60)) -p "Press a key... [Q:quit] " -s key \
          &&  case ${key,,} in
              q) return 0;;
              esac
          case $(date +'%w') in
          0 | 6);;
          *) continue 2;;
          esac
        done
      fi
      ;; # }}}
    esac
    margin_s=$(( ( $startup_margin + $end_margin + $user_margin - $pause_margin ) * 60))
    echorm "today=[$TODAY]" >/dev/stderr # DBG
    local cmd=""
    if is_to_be_done 'first' || is_to_be_done 'today'; then # {{{
      if ! $IS_MAC; then
        cmd+=" | grep '^$TODAY'"
      else
        cmd+=" | grep -e '$TODAY'"
      fi
      to_do=${to_do//'highlight'}
      ! is_to_be_done 'nested' && cmd+=" | cut -c8-"
      if is_to_be_done 'first'; then
        cmd+=" | head -n1"
      fi
    fi # }}}
    if is_to_be_done 'logins'; then # {{{
      if ! $IS_MAC; then
        local gr_cmd= resOk=false
        if false && ! is_to_be_done 'full'; then # {{{
          gr_cmd="zgrep -a -h \"gkr-pam: unlocked login keyring\|gdm-fingerprint.*: gkr-pam: no password is available for user\" $(ls -rt /var/log/auth.log*)"
          if is_to_be_done 'first' || is_to_be_done 'today'; then
            local _cmd="$gr_cmd | tr -s ' ' $cmd"
            local res="$(eval $_cmd)"
            [[ -z $res ]] && resOk=false
          fi
        fi # }}}
        if is_to_be_done 'full' || ! $resOk; then # {{{
          gr_cmd="zgrep -a -h \"gkr-pam: unlocked login keyring\|New session .\+ of user $USER\|gdm-fingerprint.*: gkr-pam: no password is available for user\" $(ls -rt /var/log/auth.log*)"
        fi # }}}
        is_to_be_done 'full' || gr_cmd+=" | cut -c-12"
        cmd="$gr_cmd | tr -s ' ' $cmd"
      else
        cmd="last $USER $cmd"
      fi
      is_to_be_done 'highlight' && cmd+=" | hl +cY '$TODAY.*'"
    fi # }}}
    is_to_be_done 'clear-screen' && ! $isDbg && clear
    echorm "[$to_do] [$to_do_extra]" >/dev/stderr # DBG
    local d_cur=$(date +"%H:%M")
    if $paused; then
      [[ -z $paused_time ]] && paused_time=$d_cur
      d_cur=$paused_time
    fi
    local d_cur_s=$(date -d "$d_cur" '+%s')
    if is_to_be_done 'show-current-time'; then # {{{
      printf 'Time: %6s ' $d_cur
      if $paused; then
        printf "${CRed}%s${COff}" "$pause_char"
        ! $pause_locked && printf " %b" "$iconOk" || printf " %b" "$iconNok"
        printf "%b" "$(get-unicode-char 'padlock')"
        $pause_auto_unpause && printf " %b" "$iconOk" || printf " %b" "$iconNok"
        printf "%b" "$(get-unicode-char 'play')"
        if [[ ! -z $paused_last_time && $paused_last_time != -1 ]]; then
          printf " ${CYellow}@ $(date +"%H:%M" -d @"$(($paused_last_time+$paused_suspend_delta))")${COff}"
        fi
      else
        printf "${CGreen}%s${COff}" "$normal_char"
        if ! $inactivity_pause_allowed; then
          printf " %b%b" "😴 " "$iconNok"
          if [[ $inactivity_pause_not_allowed_end != 0 ]]; then
            local ed="$(time2s $inactivity_pause_not_allowed_end)"
            printf "/${ed%:*}"
          fi
        fi
        if [[ ! -z $paused_last_time && $paused_last_time != -1 ]]; then
          printf " ${CRed}!!! $(date +"%H:%M" -d @"$(($paused_last_time+$paused_suspend_delta))")${COff}"
        fi
      fi
      local reminderTime= reminderWhat= reminderRest=
      reminder --list | while read reminderTime reminderWhat reminderRest; do
        local reminderNext="$reminderTime $reminderWhat $reminderRest"
        local reminderChar="$(get-unicode-char 'bell') " llCmd=
        case $reminderWhat in
        C) continue;;
        -) continue;;
        P)  reminderChar="$(get-unicode-char 'pause')"; reminderNext="$reminderTime $reminderRest";;
        GH) reminderChar="$(get-unicode-char 'home')";  reminderNext="$reminderTime $reminderRest";;
        ll-*) # {{{
          if [[ $reminderNext =~ ([0-9:]*)': ll-'(.*)'@'(.*) ]]; then
            llCmd=${BASH_REMATCH[2]%% *}
            reminderNext="${BASH_REMATCH[1]}: ${BASH_REMATCH[2]/ /: }(${BASH_REMATCH[3]})"
          elif [[ $reminderNext =~ ([0-9:]*):' ll-'(.*) ]]; then
            reminderNext="${BASH_REMATCH[1]}: ${BASH_REMATCH[2]/ /: }"
            llCmd=${BASH_REMATCH[2]%% *}
          fi
          if [[ ! -z $llCmd ]]; then
            local reminderChar=$(get-unicode-char "ll-$llCmd")
            [[ -z $reminderChar ]] && llChar=$(get-unicode-char 'disk')
          fi;; # }}}
        esac
        printf " %b ${CMsg}%s${COff}" "$reminderChar" "${reminderNext%: }"
        break
      done
      printf "\n"
      printf -- "${CMsg}------------${COff}\n"
    fi # }}}
    if is_to_be_done 'logins'; then # {{{
      echorm "cmd=[$(echo $cmd | tr '\n' ' ')]" >/dev/stderr # DBG
      ! is_to_be_done 'nested' && is_to_be_done 'first' && printf "Start: ${CGold}"
      local str="$(eval $cmd | sed -e 's/\([A-Z][a-z][a-z]\)\s\+\([0-9]\) /\1  \2 /')"
      while [[ ${#str} -lt 5 ]]; do str="0$str"; done
      printf "%s" "$str"
      is_to_be_done 'nested' && printf "\n" || printf "${COff}\n"
    fi # }}}
    is_to_be_done 'nested' && return 0
    local update_file=false
    if is_to_be_done 'remaining' || is_to_be_done 'store'; then # {{{
      local d_log=$(loglast --nested-default | cut -c8-12)
      local d_log_s=$(date -d "$d_log" '+%s')
      local d_end_s=$((d_log_s - $margin_s + 8 * 60 * 60))
      if is_to_be_done 'remaining'; then # {{{
        local percentage=$(( ( ($d_cur_s - $d_log_s + $margin_s) * 100) / (8 * 60 * 60) ))
        local color_tmux='white'
        local color_term=${CWhite}
        if   [[ $percentage -lt 25 ]]; then # {{{
          color_tmux='colour196'
          color_term='[38;5;196m'
        elif [[ $percentage -lt 50 ]]; then
          color_tmux='colour202'
          color_term='[38;5;202m'
        elif [[ $percentage -lt 75 ]]; then
          color_tmux='colour208'
          color_term='[38;5;208m'
        elif [[ $percentage -lt 97 ]]; then
          color_tmux='colour226'
          color_term='[38;5;226m'
        elif [[ $percentage -lt 102 ]]; then
          color_tmux='colour118'
          color_term='[38;5;118m'
        else
          color_tmux='colour6'
          color_term='[38;5;6m'
        fi # }}}
        ! $colors && color_term=
        if is_to_be_done 'tmux'; then # {{{
          echo -n "#[fg=$color_tmux]"
        else
          echo -e "${CMsg}------------${COff}"
        fi # }}}
        if is_to_be_done 'percentage'; then # {{{
          local tmp_perc=$percentage
          ! is_to_be_done 'passed' && [[ $tmp_perc -ge 100 ]] && tmp_perc=100
          ! is_to_be_done 'tmux' && echo -n "Passed: ${color_term}"
          printf "%3d%%" $tmp_perc
          ! is_to_be_done 'tmux' && echo    "${COff}"
        fi # }}}
        if ! $paused && ! $overtime_msg_sent && [[ $(($d_end_s + $overtime_delta)) -lt $d_cur_s ]] && ! is_to_be_done 'tmux'; then # {{{
          overtime_msg_sent=true
          save_info
          notify-send 'Time Tracker: Overtime' -u 'critical'
        fi # }}}
        if is_to_be_done 'show-left' || is_to_be_done 'show-end' || is_to_be_done 'toggle'; then # {{{
          if is_to_be_done 'toggle'; then # {{{
            to_do=${to_do//'show-end'}
            to_do=${to_do//'show-left'}
            local m=$(echo ${d_cur/*:} | sed 's/^0//')
            [[ $(( $m % 2 )) == 0 ]] && to_do+=' show-left ' || to_do+=' show-end '
          fi # }}}
          if is_to_be_done 'show-left'; then # {{{
            ! is_to_be_done 'tmux' && echo -n "Left:  ${color_term}"
            if [[ $d_end_s -gt $d_cur_s ]]; then
              echo -n "$(date -d "0 $(($d_end_s - $d_cur_s)) seconds" '+%H:%M')"
            else
              if is_to_be_done 'passed'; then
                ! is_to_be_done 'tmux' && echo -en "\b"
                echo -n "-$(date -d "0 $(($d_cur_s - $d_end_s)) seconds" '+%H:%M')"
              else
                printf "%5s" 'END'
              fi
            fi
            ! is_to_be_done 'tmux' && echo -n "${COff}"
          fi # }}}
          if is_to_be_done 'show-end'; then # {{{
            local d_print="$(date -u -d "$(echo $(date +'%z') | cut -c2-) $d_end_s seconds" '+%H:%M')"
            if ! is_to_be_done 'tmux'; then
              echo
              echo -en "End:   ${CGreen}$d_print${COff}"
              if [[ ! -z $end_at ]]; then
                echo -n " ${CMsg}"
                local diff=$(($(date +%s -d $end_at) - $(date +%s -d $d_print))) sign="+"
                if [[ $diff -ge -120 && $diff -le 120 ]]; then
                  echo -n "@"
                else
                  [[ $diff -lt 0 ]] && sign="-" && diff=$((-diff))
                  echo -n " $sign$(date +%H:%M -d @$diff --utc)"
                fi
                echo -n "${COff}"
              fi
            else
              echo -n "$d_print"
            fi
          fi # }}}
        fi # }}}
        if is_to_be_done 'tmux'; then
          $paused && echo -n "#[fg=red]$pause_char"
        else
          echo && echo -e "${CMsg}------------${COff}" && echo
        fi
      fi # }}}
      if is_to_be_done 'store'; then # {{{
        local d_mod_s=0
        [[ -e $LOGLAST_FILE ]] && d_mod_s="$(stat -c %Y $LOGLAST_FILE)"
        local DELTA=5 # {{{
        if   [[ $percentage -lt $(( ( 4 * 100 +  0 ) * 125 / 10 / 100 )) ]]; then     # < 4h00m
          DELTA=30
        elif [[ $percentage -lt $(( ( 6 * 100 + 50 ) * 125 / 10 / 100 )) ]]; then     # < 6h30m
          DELTA=15
        elif [[ $percentage -lt $(( ( 7 * 100 + 25 ) * 125 / 10 / 100 )) ]]; then     # < 7h15m
          DELTA=5
        else                                                                          # > 7h15m
          DELTA=2
        fi # }}}
        if [[ $d_cur_s -ge $(( d_mod_s + $DELTA * 60 )) ]] || is_to_be_done 'store-force'; then # {{{
          if mutex-lock 3; then
            update_file=true
            if [[ ! -z $LOGLAST_BACKUP_FILE && ( ! -e $LOGLAST_BACKUP_FILE || $d_cur_s -ge $(( $(stat -c %Y $LOGLAST_BACKUP_FILE) + 3 * 60 * 60 )) ) ]] || is_to_be_done 'store-force'; then
              to_do_extra+=" send "
            fi
            local over=
            if [[ $d_end_s -gt $d_cur_s ]]; then
              over="-$(date -d "0 $(($d_end_s - $d_cur_s)) seconds" '+%H:%M')"
            else
              over=" $(date -d "0 $(($d_cur_s - $d_end_s)) seconds" '+%H:%M')"
            fi
            local entry="$TODAY_YMD: $(date -d "0 $(($d_cur_s - $d_log_s + $margin_s)) seconds" '+%H:%M') | $over | $d_log -> $d_cur"
            local comment=
            [[ ! -z $user_comment ]] && comment+="${user_comment#, } "
            [[ $user_margin != 0 ]] && comment+="M($user_margin) "
            [[ $pause_margin != 0 ]] && comment+="P($pause_margin) "
            comment=$(echo "$comment" | xargs)
            [[ ! -z $comment ]] && entry+=" # $comment"
            if [[ -e $LOGLAST_FILE ]] && grep -q "^$TODAY_YMD:" $LOGLAST_FILE; then
              sed -i "s/^$TODAY_YMD:.*/$entry/" $LOGLAST_FILE
            else
              echo "$entry" >>$LOGLAST_FILE
            fi
            mutex-unlock
          fi
        fi # }}}
      fi # }}}
    fi # }}}
    if is_to_be_done 'stats-main' && [[ -e $LOGLAST_FILE ]]; then # {{{
      local pos=
      local sum=0
      local cnt=0
      local lines="$(wc -l $LOGLAST_FILE | cut -d ' ' -f1)"
      # Find last sum of time in LOGLAST_FILE # {{{
      local file_cmd="cat $LOGLAST_FILE"
      local last_sum_line="$(grep -n '@' $LOGLAST_FILE | tail -n2 | head -n1 | cut -d ':' -f1)"
      if [[ ! -z $last_sum_line && $last_sum_line -lt $lines ]]; then
        file_cmd="tail -n +$last_sum_line $LOGLAST_FILE"
      else
        last_sum_line=
      fi
      # }}}
      # Sum times # {{{
      while read line; do # {{{
        local t=
        if [[ ! -z $last_sum_line ]]; then
          last_sum_line=
          t=$(echo $line | sed 's/.* @ //')
        else
          t=$(echo $line | tr -s ' ' | cut -d' ' -f4)
        fi
        t=${t/':'/ }
        t=($(echo $t))
        pos=1
        [[ ${t[0]} == -* ]] && pos=-1 && t[0]=${t[0]/'-'}
        t[0]=$(echo ${t[0]} | sed 's/^0//')
        t[1]=$(echo ${t[1]} | sed 's/^0//')
        sum=$(( $sum + $pos * ( ${t[0]} * 60 + ${t[1]} ) ))
        cnt=$(( $cnt + 1 ))
      done < <($file_cmd) # }}}
      sum=$(( $sum * 60 ))
      pos=1
      [[ $sum -lt 0 ]] && pos=-1 && sum=$((-$sum))
      local sum_time="$(printf '%02d:%02d' $(($sum / 3600)) $(($sum % 3600 / 60)))"
      # }}}
      if $update_file; then # {{{
        local sum_time2=" $sum_time"
        [[ $pos == -1 ]] && sum_time2="-$sum_time"
        sed -i -e "s/^\($TODAY_YMD: [^#@]*\)\( | @..[0-9][0-9]:[0-9][0-9]\)\?\( # .*\)\?/\1 | @ $sum_time2\3/" $LOGLAST_FILE
      fi # }}}
      if is_to_be_done 'stats'; then # {{{
        echo 'Stats:'
        echo -n $CMsg
        echo '------------------------------------------------------'
        local max_lines=3
        if ! is_to_be_done 'stats-full'; then # {{{
          [[ $cnt -gt $max_lines ]] && echo '  ...'
          lines=$(( $max_lines - 2 ))
        else
          max_lines="+1"
          lines=$(( $lines - 2 ))
        fi # }}}
        # local sed_params_extra=
        # ! is_to_be_done 'stats-full' && sed_params_extra="-e \"s/ @.*//\""
        tail -n $max_lines $LOGLAST_FILE | head -n $lines | eval sed -e \"s/^/\ \ /\" # $sed_params_extra
        tail -n 2 $LOGLAST_FILE                           | eval sed -e \"s/^/\ \ /\" # ${sed_params_extra/@/\#}
        echo  '------------------------------------------------------'
        echo -n "${CCyan}                     "
        [[ $pos == -1 ]] && echo -en '\b-'
        echo -n "${sum_time}${CMsg} | ${COff}"
        if [[ $pos == -1 ]]; then # {{{
          local d_cur_stats=$(tail -n1 $LOGLAST_FILE | tr -s ' ' | cut -d' ' -f8)
          local d_cur_s_stats=$(date -d "$d_cur_stats" '+%s')
          echo -n "         ${CCyan}$(date -u -d "$(echo $(date +'%z' | cut -c2-)) $(( $d_cur_s_stats + $sum )) seconds" +'%H:%M')"
        fi # }}}
        echo
        echo  "${CMsg}------------------------------------------------------${COff}"
      fi
      # }}}
    fi # }}}
    if is_to_be_done 'send'; then # {{{
      [[ ! -z $LOGLAST_BACKUP_FILE ]] && save-in-backup -s "$LOGLAST_FILE" -d "$LOGLAST_BACKUP_FILE"
      __util_loglast_extra 'send' >/dev/null
    fi # }}}
    if is_to_be_done 'plot' || is_to_be_done 'plot-full'; then # {{{
      ! type gnuplot 1>/dev/null 2>&1 && echo "\"gnuplot\" not installed" >/dev/stderr && return 1
      local FILE_PLOT=$TMP_MEM_PATH/work-plot.data line= i= res= full_plot='cat -'
      is_to_be_done 'plot' && full_plot='tail -n100'
      printf "%6s %2s %6s %6s\n" 'No' '8h' 'W' 'A' >$FILE_PLOT
      cat $LOGLAST_FILE | $full_plot | sed '$,$ d' | tr -s ' ' | cut -d' ' -f 2,11 | sed -e 's/^0//g' -e 's/ 0/ /g' -e 's/:0/:/g' -e 's/-0/-/g' | while read line; do
        printf "%-6s" '8'
        for i in $line; do
          local res="$(calc -q -- ${i/:*}+${i/*:}/60 | sed -e 's/~//' -e 's/\s//' | cut -c-5)"
          if [[ $res != -* ]]; then
            printf " %-6s" "$res"
          else
            printf "%-7s" "$res"
          fi
        done
        echo
      done | cat -n >> $FILE_PLOT
      gnuplot -p -e "set term wxt size 2300,1100; plot for[col=2:4] '$FILE_PLOT' using 1:col title columnheader(col) with lines" 2>/dev/null
    fi # }}}
    if is_to_be_done 'suspend' || is_to_be_done 'shutdown'; then # {{{
      [[ -z $end_delay ]] && end_delay=${LOGLAST_END_DELAY:-10}
      paused_last_time=
      if [[ ! -z $(pgrep -x ssh) ]]; then # {{{
        echo "The following ssh sessions are going to be termianted:"
        echo  "${CMsg}------------------------------------------------------${COff}"
        pgrep -x ssh | xargs -n1 -- bash -c "pstree -la -s \$1 | tail -n2 | sed -e '1s/^ *\`-\(.*\)/$CGold* $CMsg\1$COff/' -e 's/bash [^ ]*\///' -e '2s/^ *\`-\(.*\)/  $CMsg└ $CCyan\1$COff/'" --
        echo  "${CMsg}------------------------------------------------------${COff}"
        echo
      fi # }}}
      local was_break=false param="--err-on-timeout"
      local cImp=$(get-color imp) cErr=$(get-color err) cWrn=$(get-color wrn) cOk=$(get-color ok) cInfo=$(get-color info) cOff=$COff fridayAfternoon=false
      [[ $(date +%w) == 5 && $(date +%H%M) -gt 1520 ]] && fridayAfternoon=true
      $fridayAfternoon && param="--no-err"
      case $(__util_loglast_extra ask-for-shutdown) in
      1) # {{{
        if progress --wait $end_delay_ask $param --msg "${cOk}Long uptime${cOff}, maybe ${cImp}shutdown${cOff}?"; then
          to_do_extra="${to_do_extra/suspend/shutdown}"
        fi;; # }}}
      2) # {{{
        if progress --wait $end_delay_ask $param --msg "${cWrn}It is getting serious${cOff} - long uptime, ${cImp}shutdown${cOff} highly suggested"; then
          to_do_extra="${to_do_extra/suspend/shutdown}"
        fi;; # }}}
      3) # {{{
        case $(progress --wait $end_delay_ask --keys 'Q' --msg "${cErr}It got too serious${cOff} - long uptime, doing ${cImp}shutdown${cOff} (almost-Q) without an ask") in
        Q)
          if $fridayAfternoon && progress --wait $end_delay_ask --no-err --msg "Well, it is Friday, sorry, shutting down anyway"; then
            to_do_extra="${to_do_extra/suspend/shutdown}"
          fi;;
        *) to_do_extra="${to_do_extra/suspend/shutdown}";;
        esac;; # }}}
      0 | *) # {{{
        local uptimeTime="$(cat /proc/uptime | awk '{print $1}' | sed 's/\..*//')"
        if [[ $(date +%w) == 5 && $uptimeTime -gt $(( 1 * 24 * 60 * 60 )) ]]; then
          if progress --wait $end_delay_ask --no-err --msg "${cOk}It's Friday${cOff}, maybe ${cImp}shutdown${cOff}?"; then
            to_do_extra="${to_do_extra/suspend/shutdown}"
          fi
        elif [[ $end_delay != '-' ]] && ! progress --wait $end_delay --no-err --msg "Going into $(is_to_be_done "suspend" && echo "${cOk}sleep${cOff}" || echo "${cImp}shutdown${cOff}") in $end_delay seconds..."; then
          was_break=true
        fi;; # }}}
      esac
      end_delay=
      if ! $was_break; then # {{{
        __util_loglast_extra 'suspend'
        pkill -x -u $USER 'ssh'
        paused_last_time=-1
        if [[ ! -z $end_at ]]; then
          local diff=$(($EPOCHSECONDS - $(date +%s -d $end_at)))
          if [[ $diff -ge -300 ]]; then
            end_at=""
            save_info
          fi
        fi
        if is_to_be_done 'suspend'; then # {{{
          local suspendTime_s=$(date '+%s')
          while true; do
            if [[ ! -z $RUN_AS_ROOT ]]; then
              $RUN_AS_ROOT suspend
            else
              sudo systemctl suspend
            fi
            local cnt= suspendDelay=10 lastUnlock_time= lastUnlock_s=
            for ((cnt=0; cnt<60; cnt+=suspendDelay)); do
              sleep $suspendDelay
              lastUnlock_time="$(loglast --nested --logins --today | tail -n1)"
              [[ -z $lastUnlock_time || $lastUnlock_time =~ ^0+$ ]] && continue
              lastUnlock_s=$(date -d "$lastUnlock_time" '+%s' 2>/dev/null)
              [[ $? != 0 ]] && continue
              [[ $lastUnlock_s -ge $((suspendTime_s - 60)) ]] && break 2
            done
          done
          reset
          [[ -e "$inactivity_f" ]] && touch "$inactivity_f"
          to_do_extra=" store store-force send"
          end_margin=0
          __util_loglast_extra 'suspend-post'
          continue # }}}
        else # {{{
          if [[ ! -z $RUN_AS_ROOT ]]; then
            $RUN_AS_ROOT shutdown -y
          else
            sudo shutdown now
          fi
        fi # }}}
      else
        to_do_extra=
        echo "unpause" >>$CMD_FILE
      fi # }}}
    fi # }}}
    if is_to_be_done 'tmux'; then # {{{
      break
    fi # }}}
    if $paused; then # {{{
      local pt_s=$(date -d "$paused_time" '+%s')
      local lastUnlock_time="$(loglast --nested --logins --today | tail -n1 | cut -c8-12)"
      local lastUnlock_s=$(date -d "$lastUnlock_time" '+%s')
      ! $inactivity_pause && [[ -e "$inactivity_f" ]] && inactivity_pause_allowed=false
      if $inactivity_pause && [[ ! -e "$inactivity_f" ]]; then # {{{
        local ts="$((EPOCHSECONDS - pt_s))"
        local tsHMS="$(time2s --to-hms $ts)"
        inactivity_pause=false
        echo "unpause" >>$CMD_FILE
        if [[ $((EPOCHSECONDS - inactivity_ts - inactivity_delta)) -le 300 ]]; then
          [[ $ts -gt 60 ]] && echo "pause-mod -$((ts / 60))" >>$CMD_FILE
        else
          notify-send "Time Tracker: Unpaused after $tsHMS due to inactivity" -u 'critical'
          local currId=$(tm --switch --get $(tmux list-panes -a -F '#S:#I.#P :: #{pane_title} :: #{pane_id}' | sed -n '/^MAIN.* :: Working Time :: /s/.* :: //p' | head -n1))
          if ! progress --wait 20s --key --msg "Accept a pause of $tsHMS due to inactivity" --no-err; then
            [[ $ts -gt 60 ]] && echo "pause-mod -$((ts / 60))" >>$CMD_FILE
          fi
          tm --switch $currId
        fi # }}}
      elif [[ $lastUnlock_s -gt $pt_s ]]; then # {{{
        if $pause_auto_unpause; then
          echo "unpause" >>$CMD_FILE
          notify-send 'Time Tracker: Unpaused' -u 'critical'
        fi # }}}
      else # {{{
        local now=$EPOCHSECONDS
        if $pause_msg_show && ! $inactivity_pause; then # {{{
          if [[ $(($pause_msg_last_time + $pause_msg_delta)) -lt $now ]]; then
            notify-send 'Time Tracker: PAUSED' -u 'critical'
            pause_msg_last_time=$now
            pause_msg_show=false
          fi
        fi # }}}
        if ! $pause_locked; then # {{{
          if [[ $(($pt_s + $pause_lock_delta)) -lt $now ]]; then
            pause_locked=true
            gnome-screensaver-command -l
          fi
        fi # }}}
        [[ -z $paused_last_time ]] && paused_last_time=$now
        if [[ $paused_last_time != -1 ]]; then # {{{
          if [[    $(($paused_last_time + $paused_suspend_delta)) -lt $now \
                && $(($paused_last_time + $paused_suspend_delta)) -gt $(($now-5*60)) ]]; then
            paused_last_time=-1
            echo "suspend" >>$CMD_FILE
          fi
        fi # }}}
      fi # }}}
    fi # }}}
    # Handle loop # {{{
    ! is_to_be_done 'loop' && break
    to_do_extra=
    local key= keyFromKbd=false wasEnterPressed=false prompt=' > '
    local waitForKey=10
    export cmdsCompl="p pm pna pnl pni m c C s e e! E E! q st bck sync fetch r R help plot rsch"
    cmdsCompl+=" $(__util_loglast_extra @@ | sed -e 's/^/ /' -e 's/\s\+$//' -e 's/\s\s\+/ /' -e 's/ / extra-/g')"
    local stopAtTS=$((EPOCHSECONDS + LOOP_TIME)) isInactivePause=false
    tput sc
    while true; do # Wait for a key or input LOGLAST_FILE # {{{
      tput rc
      if [[ -e $CMD_FILE ]]; then # {{{
        key="$(cat $CMD_FILE)"
        rm -rf $CMD_FILE
        [[ ! -z $key ]] && break
      fi # }}}
      if ! $paused; then # {{{
        if ! $inactivity_pause_allowed && [[ $inactivity_pause_not_allowed_end != 0 ]]; then # {{{
          if [[ $inactivity_pause_not_allowed_end -lt $EPOCHSECONDS ]]; then
            inactivity_pause_not_allowed_end=0
            inactivity_pause_allowed=${LOGLAST_USE_INACTIVITY_PAUSE:-true}
          fi
        fi # }}}
        if $inactivity_pause_allowed && [[ -e "$inactivity_f" ]]; then # {{{
          local inactivity_ts=$(file-stat "$inactivity_f" 2>/dev/null) || inactivity_ts=0
          if [[ $inactivity_ts != 0 && $((inactivity_ts + inactivity_delta)) -lt $EPOCHSECONDS ]]; then
            local t=$(time2s $inactivity_ts)
            notify-send "Time Tracker: ${t%:*}: Autopause due to inactivity" -u 'critical'
            isInactivePause=true
            key="pause"
            break
          fi
        fi # }}}
      fi # }}}
      if $isRlWrap; then # {{{
        key=$(run-for-some-time --wait $waitForKey:10 \
          --cmd "rlwrap $RLWRAP_OPTS -o -S '$prompt' -w 0 -C log-last -H /dev/null --histsize -1 -f <(echo '$cmdsCompl') cat -")
      else
        read -t $waitForKey key
      fi && \
        if [[ -z $key ]] && ! $wasEnterPressed; then
          wasEnterPressed=true
          prompt=' >> '
        else
          keyFromKbd=true
          break
        fi # }}}
      [[ $EPOCHSECONDS -ge $stopAtTS ]] && __util_loglast_extra "empty-loop" && continue 2
    done # }}}
    if $isDbg; then # {{{
      isDbg=false
      set +xv
    fi # }}}
    case $key in
    . | '') __util_loglast_extra "new-loop";;
    esac
    # Handle input # {{{
    set -- ${key}
    while [[ ! -z $1 ]]; do
      local cmd="$1" cmdOrig="$1" cmds= already_paused=false value= doLock= doUnpause=
      shift
      # Handle aliases/shortchuts # {{{
      case $cmd in
      pm | pm[0-9\-]*)
                    value="${cmd#pm}"
                    cmd='pause-mod';;
      m  | m[0-9\-]*)
                    value="${cmd#m}"
                    cmd='margin';;
      q)            cmd='quit';;
      p)            cmd='pause-toggle';;
      pna)          cmd='pause'; doUnpause=false;;
      pnl)          cmd='pause'; doLock=false;;
      P)            cmd='Pause';;
      p-msg)        cmd='pause-message';;
      c|C)          cmd='comment';;
      s)            cmd='store';;
      e|e!|end)     cmd='suspend';;
      E|E!|End)     cmd='shutdown';;
      chk|st)       cmd='check';;
      bck|b)        cmd='backup';;
      r)            cmd='refresh';;
      rsch)         cmd='reschedule';;
      R)            cmd='reset';;
      h)            cmd='help';;
      *)            cmd="$cmd";;
      esac # }}}
      # Handle additional actions # {{{
      case $cmd in
      pause-toggle) # {{{
        if $paused; then
          cmd='unpause'
        else
          cmd='pause'
        fi;;& # }}}
      pause-toggle | pause | unpause | pause-mod | margin | comment) # {{{
        cmds="$cmd store"
        case $cmd in
        pause-toggle | pause | unpause)
          cmds+=' refresh';;
        esac;; # }}}
      suspend | shutdown) # {{{
        [[ $cmdOrig != *! ]] && cmds+=" check"
        doUnpause=false
        cmds+=" unpause $cmd pause store";; # }}}
      reset) # {{{
        cmds="$cmd refresh";; # }}}
      *) # {{{
        cmds="$cmd";; # }}}
      esac # }}}
      for cmd in $cmds; do # {{{
        case $cmd in # {{{
        help) # {{{
          echo "Pause-Mod V C | pmV C | pm V C     - Adjust pause time (Value, Comment)"
          echo "Margin V C    | mV  C | m  V C     - Adjust margin (Value, Comment)"
          echo "Quit          | q                  - Quit"
          echo "Pause-Toggle  | p                  - Toggle pause"
          echo "              | pna                - Toggle pause with NO-auto-unpause"
          echo "              | pnl                - Toggle pause with NO-lock"
          echo "              | pni                - Toggle inactivity pause"
          echo "Pause-Message | p-msg              - Hide pause message"
          echo "Unpause                            - Unpause"
          echo "Pause         | pause | P          - Pause"
          echo "Comment C     | c C                - Add a Comment"
          echo "Store         | s                  - Store"
          echo "Suspend       | e | e! | end       - Suspend (! - no check, no delay)"
          echo "Shutdown      | E | E! | End       - Shutdown (! - no check, no delay)"
          echo "Check         | chk | st           - Check git repos"
          echo "Backup        | bck | b            - Do a backup of git repos"
          echo "Sync                               - Sync git repos"
          echo "Fetch                              - Fetch git repos"
          echo "Refresh       | r                  - Refresh"
          echo "Reset         | R                  - Reset"
          echo "Reschedule    | rsch               - Reschedule"
          echo "Plot          | Plot-full          - Draw chart"
          echo "Stats         | Stats-full         - Show entries"
          echo "Help          | h                  - Help"
          echo "+T Msg        | +[+-]...           - Set a reminder with a message or action (gh, p)"
          echo "                                     - +         - shutdown on end time"
          echo "                                     - ++T | +-T - shutdown with an offset (e.g. +-5m)"
          echo "Extra V                            - Extra tasks:"
          while read v vv; do
            printf "  %-32s - %s\n" "$v" "$vv"
          done <<< "$(__util_loglast_extra "help")"
          read key
          ;; # }}}
        quit) # {{{
          break 3;; # }}}
        dbg) # {{{
          set -xv
          isDbg=true;; # }}}
        margin) # {{{
          [[ -z $value ]] && value="$1" && shift
          user_margin="$value"
          case $user_margin in # {{{
          r|R)
            user_margin=-15; user_comment+=', Rower';;
          '')
            user_margin=0;;
          esac # }}}
          [[ ! -z $1 ]] && user_comment+=", $@" && shift $#
          ;; # }}}
        comment) # {{{
          if [[ $cmdOrig == 'C' ]]; then
            user_comment="$@"
          else
            user_comment+=", $@"
          fi
          shift $#;; # }}}
        check) # {{{
          local waitCnt=5s
          echo 'System check:'
          echo '  Repositories:'
          $BIN_PATH/git-cmds.sh gitst | grep -v 'UP-TO-DATE' | sed 's/^/    /'
          if [[ ${PIPESTATUS[0]} == 0 ]]; then
            waitCnt=1s
          elif [[ $cmd != check ]]; then
            waitCnt=3s
          fi
          case $(progress --dots --msg 'Ack' --wait $waitCnt) in
          255) break;;
          esac;; # }}}
        backup) # {{{
          git backup --all;; # }}}
        sync) # {{{
          git sync   --all --reset;; # }}}
        fetch) # {{{
          git sync   --all --skip-backup;; # }}}
        pni) # {{{
          if $inactivity_pause_allowed || [[ ! -z $1 ]] || ! $keyFromKbd; then
            inactivity_pause_allowed=false
            if [[ ! -z $1 ]]; then
              local mode='s'
              [[ $1 == *:* ]] && mode='delta'
              inactivity_pause_not_allowed_end=$((EPOCHSECONDS + $(time2s $1 -o $mode)))
              shift
            fi
          else
            inactivity_pause_allowed=${LOGLAST_USE_INACTIVITY_PAUSE:-true}
            inactivity_pause_not_allowed_end=0
          fi;; # }}}
        unpause) # {{{
          if $paused; then
            already_paused=true
            inactivity_pause=false
            if [[ ! -e "$inactivity_f" ]]; then
              inactivity_pause_allowed=${LOGLAST_USE_INACTIVITY_PAUSE:-true}
              inactivity_pause_not_allowed_end=0
            else
              inactivity_pause_allowed=false
              touch "$inactivity_f"
              inactivity_pause_not_allowed_end=$((EPOCHSECONDS + 5*60))
            fi
            pause_auto_unpause=true
            d_cur=$(date +"%H:%M")
            d_cur_s=$(date -d "$d_cur" '+%s')
            local lastUnlock_time="$(loglast --nested --logins --today | tail -n1 | cut -c8-12)"
            local lastUnlock_s=$(date -d "$lastUnlock_time" '+%s')
            local pt_s=$(date -d "$paused_time" '+%s')
            [[ $lastUnlock_s -gt $pt_s ]] && d_cur_s=$lastUnlock_s
            pt_s=$((($d_cur_s - $pt_s)/60))
            if [[ $pt_s -gt 2 ]]; then
              pause_margin=$(($pause_margin + $pt_s))
              if [[ $pause_buffer -gt 0 ]]; then
                pause_margin=$(($pause_margin - $pause_buffer))
                pause_buffer=0
                [[ $pause_margin -lt 0 ]] && pause_buffer=$((-$pause_margin))
              fi
              [[ $pause_margin -lt 0 ]] && pause_margin=0
            fi
            paused=false
            pause_msg_show=false
            pause_locked=false
            paused_last_time=-1
          fi;; # }}}
        reschedule) # {{{
          reschedule;; # }}}
        pause-mod) # {{{
          [[ -z $value ]] && value="$1" && shift
          pause_margin=$(($pause_margin + $value))
          [[ $pause_margin -lt 0 ]] && pause_margin=0
          [[ ! -z $1 ]] && user_comment+=", $@" && shift $#
          ;; # }}}
        suspend | shutdown) # {{{
          end_margin=${LOGLAST_EMARGIN:-3}
          pause_auto_unpause=false
          case $cmdOrig in # {{{
          e!|E!) # {{{
            end_delay=3;; # }}}
          *) # {{{
            echo $1 | grep -q '[0-9]\+' && end_delay=$1 && shift
            if ! $already_paused && ${LOGLAST_END_WAIT_FULL_MINUTE:-true}; then
              local left=$((59 - 10#$(date +"%S")))
              [[ $left -lt 5 ]] && left=5
              if ! progress --wait $left --color "${CGreen}" --msg "${CBlue}Waiting ${left}s for full minute...${COff}"; then
                echo -e "${CGold}Waiting has been skipped${COff}"
                sleep 2
              fi
            fi;; # }}}
          esac # }}}
          to_do_extra+=" $cmd";; # }}}
        Pause) # {{{
          paused_last_time=;;& # }}}
        pause) # {{{
          paused_last_time=-1;;& # }}}
        pause | Pause) # {{{
          if ! $paused; then
            ${doLock:-true} && pause_locked=false || pause_locked=true
            if $isInactivePause; then
              inactivity_pause=true
            elif $inactivity_pause; then
              inactivity_pause=false
            fi
            pause_auto_unpause=${doUnpause:-true}
            paused_time=$(date +"%H:%M")
            paused=true
            pause_msg_show=true
            pause_msg_last_time=$EPOCHSECONDS
            [[ $paused_last_time != -1 ]] && paused_last_time=$pause_msg_last_time
            if [[ $cmd == 'pause' ]]; then
              [[ ! -z $1 ]] && user_comment+=", $@" && shift $#
            fi
          else
            if [[ ! -z $doLock ]]; then
              $doLock && pause_locked=false || pause_locked=true
            fi
            if [[ ! -z $doUnpause ]]; then
              pause_auto_unpause=$doUnpause
            fi
            ! $isInactivePause && $inactivity_pause && inactivity_pause=false
          fi;; # }}}
        pause-message) # {{{
          pause_msg_show=false
          ;; # }}}
        reset) # {{{
          __util_loglast_extra 'reset'
          ;; # }}}
        refresh) # {{{
          __util_loglast_extra 'refresh'
          ;; # }}}
        store) # {{{
          to_do_extra+=" store store-force send";; # }}}
        extra) # {{{
          local scmd="$1" && shift
          __util_loglast_extra "$scmd" $@
          shift
          ;; # }}}
        extra-*) # {{{
          __util_loglast_extra "${cmd#extra-}" $@
          ;; # }}}
        + | +*) # {{{
          local onTime="${cmd#+}"
          [[ $cmd == '+' && $1 =~ ^[0-9:hms]*$ ]] && onTime="$1" && shift
          local endTime="$(loglast --remaining --show-end | awk '/^End:/ {print $2}')"
          local delta=$((5*60)) curTime_s="$EPOCHSECONDS" onTime_before=
          case $onTime in
          '' | -) # {{{
            onTime="$(date -d "$endTime" +"%s")"
            if [[ $onTime -le $((curTime_s+60)) ]]; then
              onTime="$(date -d @$((curTime_s+60)) +"%H:%M")"
            else
              onTime="$endTime"
            fi ;; # }}}
          *) # {{{
            d=$onTime
            [[ $d == -* || +* ]] && d="${d:1}"
            if time2s --is-hms $d; then
              d=$(time2s $d -o s)
              [[ $onTime == +* ]] && d="-$d"
            fi
            onTime_before="$(($(date -d "$endTime" +"%s") - d))"
            if [[ $onTime_before -gt $((curTime_s+60)) ]]; then
              onTime="$(date -d @$onTime_before +"%H:%M")"
            else
              progress --msg "Reminder is in the past [${CRed}$(date -d @$onTime_before +"%H:%M")${COff}]" --wait 5s
              shift $#; continue
            fi
            ;; # }}}
          esac
          arg="$1" && shift
          case $arg in
          '') # {{{
            onTime_before="$(date -d "$onTime" +"%s")"
            onTime_before="$((onTime_before - delta))"
            if [[ $onTime_before -gt $((curTime_s+60)) ]]; then
              onTime_before="$(date -d @$onTime_before +"%H:%M")"
              reminder -s "-Going home in 5m..." $onTime_before
            fi
            arg='go-home.sh';; # }}}
          'gh')  arg='go-home.sh';;
          'p' )  arg='pause.sh';;
          'pni') arg='ll-pni.sh';;
          esac
          [[ "$arg" == 'go-home.sh' ]] && end_at="$onTime"
          reminder -s $arg $@ $onTime
          progress --msg "$onTime: $arg" --wait 5s
          shift $#
          ;; # }}}
        *) # {{{
          to_do_extra+=" $key";; # }}}
        esac # }}}
      done # }}}
    done # }}}
    to_do_extra=" $to_do_extra "
    save_info # }}}
  done # }}}
  mutex-deinit
  unset is_to_be_done
} # }}}
export -f loglast

export DBG_ID=loglast
dbgF --init --all=show
loglast "$@"

