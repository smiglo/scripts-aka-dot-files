#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  if [[ $3 == '--cmd' ]]; then
    echo 'quit margin comment check st backup sync fetch pause pause-toggle pause-mod store plot plot-full stats stats-full'
    echo 'suspend end e! shutdown End E! refresh r reset R'
    exit 0
  fi
  ret_val=
  ret_val+=' --today --first --full --percentage --tmux --passed --store --store-force --clear --stats --stats-full'
  ret_val+=' --toggle --show-end --show-left --logins --remaining --clear-screen --loop --show-current-time --shutdown'
  ret_val+=' --plot --plot-full --suspend --shutdown --cmd --force-new-day'
  # noes= i=
  # for i in $ret_val; do
  #   noes+=" --no-${i/--}"
  # done
  extra='% +%'
  echo $ret_val $noes $ret_$extra
  exit 0
fi # }}}
is_to_be_done() { # {{{
  [[ "$to_do $to_do_extra" == *\ $1\ * ]]
} # }}}
save_info() { # {{{
  local mem_file=$TMP_MEM_PATH/.work_time.nfo
  (
    echo "user_margin=\"$user_margin\""
    echo "user_comment=\"${user_comment#, }\""
    echo "paused=\"$paused\""
    echo "paused_time=\"$paused_time\""
    echo "paused_last_time=\"$paused_last_time\""
    echo "pause_margin=\"$pause_margin\""
    echo "extra_added=\"$extra_added\""
    echo "end_at=\"$end_at\""
  ) >$mem_file
  rsync $mem_file $FILE_DATA
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
      return 0
      ;; # }}}
  suspend) # {{{
    $ALIASES tm --b-dump
    $ALIASES tm --l-dump --all --file "susp-$(command date +"$DATE_FMT").layout";; # }}}
  reset) # {{{
    local resetFile="$TMP_MEM_PATH/log-last-reset.tmp"
    if [[ ! -e $resetFile || "$(stat -c %y "$resetFile" | awk '{print $1}')" != "$(command date +"%Y-%m-%d")" ]]; then
      $BASH_PATH/runtime --force --clean-tmp-silent
      touch -d '' "$resetFile"
    fi
    if [[ -n $TMUX ]]; then
      $HOME/.tmux.bash status_right_refresh
    fi;; # }}}
  new-day) # {{{
    $BASH_PATH/runtime --force --clean-tmp-silent
    __util_loglast_extra 'reset'
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
  local FILE=$LOGLAST_FILE
  [[ -z $FILE ]] && FILE=$APPS_CFG_PATH/log-last/work_time.default
  local FILE_DATA=${FILE}.nfo CMD_FILE=$TMP_MEM_PATH/.loglast.cmd
  [[ ! -e "$(dirname $FILE)" ]] && mkdir -p "$(dirname $FILE)"
  local LOOP_TIME=$(( 10 * 60 ))
  local PARAMS_DEFAULT='--logins --first --remaining --passed --show-left --show-end --show-current-time'
  local CMsg='[38;5;8m'
  local to_do=''
  local to_do_extra=''
  local paused=false paused_time= pause_msg_show=false pause_msg_last_time= pause_msg_delta="$((10*60))" paused_last_time= paused_suspend_delta="$((30*60))"
  local colors=true force_new_day=false
  local pause_char="$($ALIASES getUnicodeChar 'log_last_pause')" normal_char="$($BASH_PATH/aliases getUnicodeChar 'log_last_play')"
  set -- $PARAMS_DEFAULT $@
  [[ ! -t 1 ]] && colors=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --full|\
    --logins|--remaining|\
    --toggle|--show-end|--show-left|--percentage|--passed|\
    --store|--store-force|\
    --stats|--stats-full|\
    --loop|--show-current-time|\
    --first|--today|\
    --suspend|--shutdown|\
    --plot|\
    --clear-screen)     to_do+=" ${1/--}";;&
    --loop)             echo $2 | command grep -q '[0-9]\+' && LOOP_TIME=$(( $2 * 60 )) && shift;;
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
    --nested)           to_do='nested logins first';;
    --no-colors)        colors=false;;
    --force-new-day)    force_new_day=true;;
    --no-*)             to_do=${to_do//${1/'--no-'}};;
    --clear)            to_do=''; cmd='';;
    --cmd)              shift; echo "$@" >$CMD_FILE; return 0;;
    esac
    shift
  done # }}}
  to_do=" $to_do "
  local margin_s= startup_margin= end_margin= user_margin= pause_margin= user_comment= TODAY= TODAY_YMD= end_delay= pause_buffer=15 i=
  local extra_comment= extra_margin= extra_added=false end_at=
  source $ALIASES
  source $BASH_PATH/colors
  source $RUNTIME_FILE
  if ! $colors; then
    unset $($BASH_PATH/colors --list)
    CMsg=""
  fi
  [[ -e $TMP_PATH/.log-last.today ]] && source $TMP_PATH/.log-last.today
  [[ -e $TMP_MEM_PATH/log-last.new-day ]] && force_new_day=true && rm $TMP_MEM_PATH/log-last.new-day
  ! is_to_be_done 'nested' && ! is_to_be_done 'tmux' && set_title 'Working Time'
  ! is_to_be_done 'nested' && mutex_init "work-time" --auto-clean-after 60 --no-trap
  while true; do # {{{
    if [[ $((10#$(command date +%H%M))) -gt 2330 ]]; then # {{{
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
    local new_today="$(LC_TIME=en_US.UTF-8 command date +'%b %_d' | tr -s ' ')"
    $force_new_day && TODAY= && force_new_day=false
    local dow=$(command date +'%w')
    if [[ "$new_today" != "$TODAY" ]]; then # {{{
      if ! is_to_be_done 'nested' && [[ -z $($0 --nested | cut -c8-12) ]]; then # {{{
        progress \
          --dots --no-err \
          --msg "Waiting for login time..." --color "${CGold}" \
          --cmd "! test -z \$($0 --nested | head -n1 | cut -c8-12)"
      fi # }}}
      TODAY=$new_today
      TODAY_YMD="$(command date +"%Y%m%d")"
      (
        echo "export TODAY='$TODAY'"
        echo "export TODAY_YMD='$TODAY_YMD'"
      ) >$TMP_PATH/.log-last.today
      startup_margin=0
      end_margin=0
      pause_margin=0
      user_margin=0
      user_comment=
      paused=false
      paused_time=
      paused_last_time=
      pause_msg_show=false
      pause_buffer=15
      extra_comment=
      extra_margin=
      extra_added=false
      end_at=
      if [[ -n $LOGLAST_MARGIN ]]; then
        [[ ${#LOGLAST_MARGIN[*]} == 1 ]] && startup_margin=$LOGLAST_MARGIN || startup_margin=${LOGLAST_MARGIN[$dow]}
        sm="${startup_margin/*:}"
        extra_comment+=", $sm"
        startup_margin=${startup_margin/:*}
      fi
      if [[ -z $startup_margin ]]; then
        case $dow in
        1) startup_margin=${LOGLAST_SMARGIN_MON:-5};;
        *) startup_margin=${LOGLAST_SMARGIN:-3};;
        esac
      fi
      case $dow in
      6) extra_comment+=", sat";;&
      0) extra_comment+=", sun";;&
      0 | 6) paused=true ;;
      esac
      if is_to_be_done 'loop'; then # {{{
        fix_caps
        __util_loglast_extra 'new-day'
        ec="$(__util_loglast_extra 'set-comment')"
        if [[ ! -z $ec ]]; then
          extra_margin="${ec%%:*}"
          extra_comment+=", ${ec#*:}"
          extra_comment="${extra_comment#, }" && extra_comment="${extra_comment%, }"
        fi
        to_do_extra+=" store-force stats-main send "
        if [[ ! -e $FILE_DATA || $(command date -ud "@$(stat -c %Y $FILE_DATA)" +"%Y%m%d") != $TODAY_YMD ]]; then
          save_info
        fi
      fi # }}}
    fi # }}}
    [[ -e $FILE_DATA ]] && source $FILE_DATA
    extra_comment="${extra_comment#, }" && extra_comment="${extra_comment%, }"
    if ! $extra_added; then
      [[ ! -z $extra_margin ]] && user_margin=$((user_margin+extra_margin))
      [[ ! -z $extra_comment && $user_comment != *"$extra_comment"* ]] && user_comment="$(echo "$user_comment, $extra_comment")"
      user_comment="${user_comment#, }" && user_comment="${user_comment%, }"
      extra_added=true extra_margin= extra_comment=
      save_info
    fi
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
          case $(command date +'%w') in
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
        cmd+=" | command grep '^$TODAY'"
      else
        cmd+=" | command grep -e '$TODAY'"
      fi
      to_do=${to_do//'highlight'}
      ! is_to_be_done 'nested' && cmd+=" | cut -c8-"
      if is_to_be_done 'first'; then
        cmd+=" | head -n1"
      fi
    fi # }}}
    if is_to_be_done 'logins'; then # {{{
      if ! $IS_MAC; then
        local gr_cmd= resOk=true
        if ! is_to_be_done 'full'; then # {{{
          gr_cmd="command zgrep -a -h \"gkr-pam: unlocked login keyring\" $(ls -rt /var/log/auth.log*)"
          if is_to_be_done 'first' || is_to_be_done 'today'; then
            local _cmd="$gr_cmd | tr -s ' ' $cmd"
            local res="$(eval $_cmd)"
            [[ -z $res ]] && resOk=false
          fi
        fi # }}}
        if is_to_be_done 'full' || ! $resOk; then # {{{
          gr_cmd="command zgrep -a -h \"gkr-pam: unlocked login keyring\|New session .\+ of user $USER\" $(ls -rt /var/log/auth.log*)"
        fi # }}}
        is_to_be_done 'full' || gr_cmd+=" | cut -c-12"
        cmd="$gr_cmd | tr -s ' ' $cmd"
      else
        cmd="last $USER $cmd"
      fi
      is_to_be_done 'highlight' && cmd+=" | $ALIASES hl +cY '$TODAY.*'"
    fi # }}}
    is_to_be_done 'clear-screen' && clear
    echorm "[$to_do] [$to_do_extra]" >/dev/stderr # DBG
    local d_cur=$(command date +"%H:%M")
    if $paused; then
      [[ -z $paused_time ]] && paused_time=$d_cur
      d_cur=$paused_time
    fi
    local d_cur_s=$(command date -d "$d_cur" '+%s')
    if is_to_be_done 'show-current-time'; then # {{{
      printf 'Time: %6s ' $d_cur
      if $paused; then
        printf "${CRed}%s${COff}" "$pause_char"
        if [[ ! -z $paused_last_time && $paused_last_time != -1 ]]; then
          printf " ${CYellow}@ $(command date +"%H:%M" -d @"$(($paused_last_time+$paused_suspend_delta))")${COff}"
        fi
      else
        printf "${CGreen}%s${COff}" "$normal_char"
      fi
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
      local d_log=$($0 --nested | cut -c8-12)
      local d_log_s=$(command date -d "$d_log" '+%s')
      local d_end_s=$((d_log_s - $margin_s + 8 * 60 * 60))
      if is_to_be_done 'remaining'; then # {{{
        local percentage=$(( ( ($d_cur_s - $d_log_s + $margin_s) * 100) / (8 * 60 * 60) ))
        local color_tmux='white'
        local color_term=${CWhite}
        if   [[ $percentage -lt 25 ]]; then
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
        fi
        ! $colors && color_term=
        if is_to_be_done 'tmux'; then # {{{
          $paused && echo -n "#[fg=red]$pause_char"
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
              command date -d "0 $(($d_end_s - $d_cur_s)) seconds" '+%H:%M'
            else
              if is_to_be_done 'passed'; then
                ! is_to_be_done 'tmux' && echo -en "\b"
                echo "-$(command date -d "0 $(($d_cur_s - $d_end_s)) seconds" '+%H:%M')"
              else
                printf "%5s\n" 'END'
              fi
            fi
            ! is_to_be_done 'tmux' && echo -n "${COff}"
          fi # }}}
          if is_to_be_done 'show-end'; then # {{{
            local d_print="$(command date -u -d "$(echo $(command date +'%z') | cut -c2-) $d_end_s seconds" '+%H:%M')"
            if ! is_to_be_done 'tmux'; then
              echo -en "End:   ${CGreen}$d_print${COff}"
              if [[ ! -z $end_at ]]; then
                echo -n " ${CMsg}"
                local diff=$(($(command date +%s -d $end_at) - $(command date +%s -d $d_print))) sign="+"
                if [[ $diff -ge -120 && $diff -le 120 ]]; then
                  echo -n "@"
                else
                  [[ $diff -lt 0 ]] && sign="-" && diff=$((-diff))
                  echo -n " $sign$(command date +%H:%M -d @$diff --utc)"
                fi
                echo "${COff}"
              fi
              echo
            else
              echo "$d_print"
            fi
          fi # }}}
        fi # }}}
        ! is_to_be_done 'tmux' && echo -e "${CMsg}------------${COff}" && echo
      fi # }}}
      if is_to_be_done 'store'; then # {{{
        local d_mod_s=0
        [[ -e $FILE ]] && d_mod_s="$(stat -c %Y $FILE)"
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
          if mutex_lock 3; then
            update_file=true
            if [[ ! -z $LOGLAST_BACKUP_FILE && ( ! -e $LOGLAST_BACKUP_FILE || $d_cur_s -ge $(( $(stat -c %Y $LOGLAST_BACKUP_FILE) + 3 * 60 * 60 )) ) ]] || is_to_be_done 'store-force'; then
              to_do_extra+=" send "
            fi
            local over=
            if [[ $d_end_s -gt $d_cur_s ]]; then
              over="-$(command date -d "0 $(($d_end_s - $d_cur_s)) seconds" '+%H:%M')"
            else
              over=" $(command date -d "0 $(($d_cur_s - $d_end_s)) seconds" '+%H:%M')"
            fi
            local entry="$TODAY_YMD: $(command date -d "0 $(($d_cur_s - $d_log_s + $margin_s)) seconds" '+%H:%M') | $over | $d_log -> $d_cur"
            local comment=
            [[ ! -z $user_comment ]] && comment+="${user_comment#, } "
            [[ $user_margin != 0 ]] && comment+="M($user_margin) "
            [[ $pause_margin != 0 ]] && comment+="P($pause_margin) "
            comment=$(echo "$comment" | xargs)
            [[ ! -z $comment ]] && entry+=" # $comment"
            if [[ -e $FILE ]] && command grep -q "^$TODAY_YMD:" $FILE; then
              sed -i "s/^$TODAY_YMD:.*/$entry/" $FILE
            else
              echo "$entry" >>$FILE
            fi
            mutex_unlock
          fi
        fi # }}}
      fi # }}}
    fi # }}}
    if is_to_be_done 'stats-main' && [[ -e $FILE ]]; then # {{{
      local pos=
      local sum=0
      local cnt=0
      local lines="$(wc -l $FILE | cut -d ' ' -f1)"
      # Find last sum of time in file # {{{
      local file_cmd="cat $FILE"
      local last_sum_line="$(command grep -n '@' $FILE | tail -n2 | head -n1 | cut -d ':' -f1)"
      if [[ ! -z $last_sum_line && $last_sum_line -lt $lines ]]; then
        file_cmd="tail -n +$last_sum_line $FILE"
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
        sed -i -e "s/^\($TODAY_YMD: [^#@]*\)\( | @..[0-9][0-9]:[0-9][0-9]\)\?\( # .*\)\?/\1 | @ $sum_time2\3/" $FILE
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
        tail -n $max_lines $FILE | head -n $lines | eval sed -e \"s/^/\ \ /\" # $sed_params_extra
        tail -n 2 $FILE                           | eval sed -e \"s/^/\ \ /\" # ${sed_params_extra/@/\#}
        echo  '------------------------------------------------------'
        echo -n "${CCyan}                     "
        [[ $pos == -1 ]] && echo -en '\b-'
        echo -n "${sum_time}${CMsg} | ${COff}"
        if [[ $pos == -1 ]]; then # {{{
          local d_cur_stats=$(tail -n1 $FILE | tr -s ' ' | cut -d' ' -f8)
          local d_cur_s_stats=$(command date -d "$d_cur_stats" '+%s')
          echo -n "         ${CCyan}$(command date -u -d "$(echo $(command date +'%z' | cut -c2-)) $(( $d_cur_s_stats + $sum )) seconds" +'%H:%M')"
        fi # }}}
        echo
        echo  "${CMsg}------------------------------------------------------${COff}"
      fi
      # }}}
    fi # }}}
    if is_to_be_done 'send'; then # {{{
      [[ ! -z $LOGLAST_BACKUP_FILE ]] && rsync $RSYNC_DEFAULT_PARAMS $FILE $LOGLAST_BACKUP_FILE >/dev/null 2>&1 &
      __util_loglast_extra 'send' >/dev/null 2>&1
    fi # }}}
    if is_to_be_done 'plot' || is_to_be_done 'plot-full'; then # {{{
      ! type gnuplot 1>/dev/null 2>&1 && echo "\"gnuplot\" not installed" >/dev/stderr && return 1
      local FILE_PLOT=$TMP_MEM_PATH/work-plot.data line= i= res= full_plot='cat -'
      is_to_be_done 'plot' && full_plot='tail -n100'
      printf "%6s %2s %6s %6s\n" 'No' '8h' 'W' 'A' >$FILE_PLOT
      cat $FILE | $full_plot | sed '$,$ d' | tr -s ' ' | cut -d' ' -f 2,11 | sed -e 's/^0//g' -e 's/ 0/ /g' -e 's/:0/:/g' -e 's/-0/-/g' | while read line; do
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
      [[ -z $end_delay ]] && end_delay=10
      paused_last_time=
      if [[ ! -z $(pgrep -x ssh) ]]; then # {{{
        echo "The following ssh sessions are going to be termianted:"
        echo  "${CMsg}------------------------------------------------------${COff}"
        pgrep -x ssh | xargs -n1 -- bash -c "pstree -la -s \$1 | tail -n2 | sed -e '1s/^ *\`-\(.*\)/$CGold* $CMsg\1$COff/' -e 's/bash [^ ]*\///' -e '2s/^ *\`-\(.*\)/  $CMsg└ $CCyan\1$COff/'" --
        echo  "${CMsg}------------------------------------------------------${COff}"
        echo
      fi # }}}
      local was_break=false
      trap "was_break=true;" INT
      eval "(                                                                                                                                                       \
        progress --pv --cnt $end_delay                                                                                                                              \
          --color \"$(is_to_be_done "suspend" && echo "${CGold}" || echo "${CRed}")\"                                                                               \
          --msg \"${CBlue}Going into $(is_to_be_done "suspend" && echo "${CGold}sleep${CBlue}" || echo "${CRed}shutdown${CBlue}") in $end_delay seconds...${COff}\" \
      )"
      trap - INT
      echo -en "${COff}"
      end_delay=
      if ! $was_break; then # {{{
        __util_loglast_extra 'suspend'
        pkill -x -u $USER 'ssh'
        paused_last_time=-1
        if [[ ! -z $end_at ]]; then
          local diff=$(($EPOCHSECONDS - $(command date +%s -d $end_at)))
          if [[ $diff -ge -300 ]]; then
            end_at=""
            save_info
          fi
        fi
        if is_to_be_done 'suspend'; then
          if [[ ! -z $RUN_AS_ROOT ]]; then
            $RUN_AS_ROOT suspend
          else
            sudo systemctl suspend
          fi
          sleep 10
          __util_loglast_extra 'suspend-post'
          to_do_extra=" store store-force send"
          local key=
          end_margin=0
          while true; do
            echo -n "Press any key to continue..."
            while [[ $(command date +"%Y%m%d") == $TODAY_YMD ]]; do
              read -t 10 -s key && break
            done
            echo
            break
          done
          continue
        else
          if [[ ! -z $RUN_AS_ROOT ]]; then
            $RUN_AS_ROOT shutdown -y
          else
            sudo shutdown now
          fi
        fi
      else
        to_do_extra=
        echo "unpause" >$CMD_FILE
      fi # }}}
    fi # }}}
    if $paused; then # {{{
      local now=$EPOCHSECONDS
      if $pause_msg_show; then # {{{
        if [[ $(($pause_msg_last_time + $pause_msg_delta)) -lt $now ]]; then
          notify-send 'Time Tracker: PAUSED' -u 'critical'
          pause_msg_last_time=$now
          pause_msg_show=false
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
    # Handle loop # {{{
    ! is_to_be_done 'loop' && break
    to_do_extra=
    local key= wasEnterPressed=false
    local LOOP_KEY=10 delayed=0
    export cmdsCompl="p pm m c C s e e! E E! q st bck sync fetch r R help plot $(__util_loglast_extra @@ | sed -e 's/^/ /' -e 's/\s\+$//' -e 's/\s\s\+/ /' -e 's/ / extra-/g')"
    tput sc
    while true; do # Wait for a key or input file {{{
      tput rc
      if type rlwrap >/dev/null 2>&1; then
        key=$($ALIASES run_for_some_time --no-fallback --wait $LOOP_KEY:10 \
          --cmd 'eval rlwrap $RLWRAP_OPTS -o -S \"\ \>\ \" -w 0 -C log-last -H /dev/null --histsize -1 \
                  -f <(echo "$cmdsCompl") \
                  cat')
      else
        read -t $LOOP_KEY key
      fi && \
        if [[ -z $key ]] && ! $wasEnterPressed; then
          wasEnterPressed=true
        else
          break
        fi
      if [[ -e $CMD_FILE ]]; then
        key=$(head -n1 $CMD_FILE)
        sed -i -e '1,1 d' $CMD_FILE
        [[ ! -s $CMD_FILE ]] && rm -rf $CMD_FILE
        [[ ! -z $key ]] && break
      fi
      delayed=$(($delayed + $LOOP_KEY))
      [[ $delayed -ge $LOOP_TIME ]] && continue 2
    done
    # }}}
    [[ -z $key ]] && __util_loglast_extra "new-loop"
    # Handle input # {{{
    set -- ${key}
    while [[ ! -z $1 ]]; do
      local cmd="$1" cmdOrig="$1" cmds= already_paused=false value=
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
      P)            cmd='Pause';;
      p-msg)        cmd='pause-message';;
      c|C)          cmd='comment';;
      s)            cmd='store';;
      e|e!|end)     cmd='suspend';;
      E|E!|End)     cmd='shutdown';;
      chk|st)       cmd='check';;
      bck|b)        cmd='backup';;
      r)            cmd='refresh';;
      R)            cmd='reset';;
      h)            cmd='help';;
      *)            cmd="$cmd";;
      esac # }}}
      # Handle additional actions # {{{
      case $cmd in
      pause-toggle)
        $paused && cmd='unpause' || cmd='pause';;&
      pause-toggle | pause | unpause | pause-mod | margin | comment)
        cmds="$cmd store"
        case $cmd in
        pause-toggle | pause | unpause)
          cmds+=' refresh';;
        esac;;
      suspend | shutdown)
        [[ $cmdOrig != *! ]] && cmds+=" check"
        cmds+=" unpause $cmd pause store"
        ;;
      reset)
        cmds="$cmd refresh";;
      *)
        cmds="$cmd";;
      esac # }}}
      for cmd in $cmds; do # {{{
        case $cmd in # {{{
        help) # {{{
          echo "Pause-Mod V C | pmV C | pm V C     - Adjust pause time (Value, Comment)"
          echo "Margin V C    | mV  C | m  V C     - Adjust margin (Value, Comment)"
          echo "Quit          | q                  - Quit"
          echo "Pause-Toggle  | p                  - Toggle pause"
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
          echo 'System check:'
          echo '  Repositories:'
          $BIN_PATH/git-cmds.sh gitst | grep -v 'UP-TO-DATE' | sed 's/^/    /'
          local cnt=10
          [[ $cmd != check ]] && cnt=3
          progress --dots --msg 'Ack' --cnt $cnt; [[ $? == 11 ]] && sleep 1 || sleep 0.3
          case $? in
          255) break;;
          11)  sleep 1;;
          *)   sleep 0.3;;
          esac;; # }}}
        backup) # {{{
          git backup --all;; # }}}
        sync) # {{{
          git sync   --all --reset;; # }}}
        fetch) # {{{
          git sync   --all --skip-backup;; # }}}
        unpause) # {{{
          if $paused; then
            already_paused=true
            d_cur=$(command date +"%H:%M")
            d_cur_s=$(command date -d "$d_cur" '+%s')
            local pt_s=$(command date -d "$paused_time" '+%s')
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
            paused_last_time=
          fi;; # }}}
        pause-mod) # {{{
          [[ -z $value ]] && value="$1" && shift
          pause_margin=$(($pause_margin + $value))
          [[ $pause_margin -lt 0 ]] && pause_margin=0
          [[ ! -z $1 ]] && user_comment+=", $@" && shift $#
          ;; # }}}
        suspend|shutdown) # {{{
          end_margin=${LOGLAST_EMARGIN:-3}
          case $cmdOrig in # {{{
          e!|E!) # {{{
            end_delay=3;; # }}}
          *) # {{{
            echo $1 | command grep -q '[0-9]\+' && end_delay=$1 && shift
            if ! $already_paused; then
              local left=$((59 - $(command date +"%S" | sed 's/^0\+//')))
              [[ $left -lt 5 ]] && left=5
              trap "echo -e '\n${CGold}Waiting has been skipped${COff}' && sleep 2" INT
              eval "(                                                          \
                progress --pv --cnt $left                                      \
                  --color \"${CGreen}\"                                        \
                  --msg \"${CBlue}Waiting ${left}s for full minute...${COff}\" \
              )"
              trap - INT
            fi;; # }}}
          esac # }}}
          to_do_extra+=" $cmd";; # }}}
        Pause) # {{{
          paused_last_time=-1;;& # }}}
        pause | Pause) # {{{
          if ! $paused; then
            paused_time=$(command date +"%H:%M")
            paused=true
            pause_msg_show=true
            pause_msg_last_time=$EPOCHSECONDS
            [[ $paused_last_time != -1 ]] && paused_last_time=$pause_msg_last_time
            if [[ $cmd == 'pause' ]]; then
              [[ ! -z $1 ]] && user_comment+=", $@" && shift $#
            fi
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
        +*) # {{{
          local onTime="${cmd#+}"
          ;;& # }}}
        +) # {{{
          local onTime="$1"; shift
          ;;& # }}}
        + | +*) # {{{
          local endTime="$($0 | grep "^End:" | awk '{print $2}')"
          local delta=$((5*60)) curTime_s="$EPOCHSECONDS" onTime_before=
          case $onTime in
          '' | -) # {{{
            onTime="$(command date -d "$endTime" +"%s")"
            if [[ $onTime -le $((curTime_s+60)) ]]; then
              onTime="$(command date -d @$((curTime_s+60)) +"%H:%M")"
            else
              onTime="$endTime"
            fi ;; # }}}
          -* | +*) # {{{
            local d="${onTime:1}"
            if $ALIASES time2s --is-hms $d; then
              d=$($ALIASES time2s $d -o s)
              [[ $onTime == +* ]] && d="-$d"
            fi
            onTime_before="$(($(command date -d "$endTime" +"%s") - d))"
            if [[ $onTime_before -gt $((curTime_s+60)) ]]; then
              onTime="$(command date -d @$onTime_before +"%H:%M")"
            else
              echo "Reminder is in the past [${CRed}$(command date -d @$onTime_before +"%H:%M")${COff}]" >/dev/stderr
              shift $#; sleep 3; continue
            fi
            ;; # }}}
          esac
          arg="$1" && shift
          case $arg in
          '') # {{{
            onTime_before="$(command date -d "$onTime" +"%s")"
            onTime_before="$((onTime_before - delta))"
            if [[ $onTime_before -gt $((curTime_s+60)) ]]; then
              onTime_before="$(command date -d @$onTime_before +"%H:%M")"
              $ALIASES reminder "Going home in 5m..." $onTime_before
            fi
            arg='go-home.sh';; # }}}
          'gh') arg='go-home.sh';;
          'p' ) arg='pause.sh';;
          esac
          if [[ "$arg" == 'go-home.sh' ]]; then
            end_at="$onTime"
          fi
          $ALIASES reminder $arg $@ $onTime
          shift $#; sleep 3
          ;; # }}}
        *) # {{{
          to_do_extra+=" $key";; # }}}
        esac # }}}
      done # }}}
    done # }}}
    to_do_extra=" $to_do_extra "
    save_info
    # }}}
  done # }}}
  mutex_deinit
  unset is_to_be_done
} # }}}

loglast "$@"

