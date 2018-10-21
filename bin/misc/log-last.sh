#!/bin/bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  ret_val='--today --first --full --percentage --tmux --passed --store --store-force --clear --stats --stats-full --toggle --show-end --show-left --logins --remaining --clear-screen --loop --show-current-time --shutdown --plot --suspend --shutdown --cmd'
  if [[ $3 == '--cmd' ]]; then
    echo 'quit margin comment check st backup sync fetch pause-toggle pause-mod suspend end e! shutdown End E! store plot'
    exit 0
  fi
  noes= i=
  for i in $ret_val; do
    noes+=" --no-${i/--}"
  done
  extra='% +%'
  echo $ret_val $noes $ret_$extra
  exit 0
fi # }}}
is_to_be_done() { # {{{
  [[ "$to_do $to_do_extra" == *\ $1\ * ]]
} # }}}
__util_loglast_extra() { # {{{
  case $1 in
  suspend) $BASH_PATH/aliases tm --b-dump;;
  reset) # {{{
    if [[ -n $TMUX ]]; then
      tmux show-environment | command grep "^TMUX_SB.*update_time" | while read i; do
        tmux set-environment  ${i%%=*} "$(echo "${i#*=}" | sed -e 's/update_time=[0-9]*;/update_time=0;/')"
      done
      tmux show-environment -g | command grep "^TMUX_SB.*update_time" | while read i; do
        tmux set-environment  -g ${i%%=*} "$(echo "${i#*=}" | sed -e 's/update_time=[0-9]*;/update_time=0;/')"
      done
    fi;; # }}}
  esac
  for i in $BASH_PROFILES; do
    [[ -e "$BASH_PATH/profiles/$i/aliases" ]] && $BASH_PATH/profiles/$i/aliases __util_loglast_extra "$1"
  done
} # }}}
loglast() { # {{{
  source $BASH_PATH/aliases
  local FILE=$LOGLAST_FILE
  [[ -z $FILE ]] && FILE=$TMP_PATH/.work_time.default
  local FILE_DATA=${FILE}.nfo CMD_FILE=$TMP_MEM_PATH/.loglast.cmd
  local LOOP_TIME=$(( 10 * 60 ))
  local PARAMS_DEFAULT='--logins --first --remaining --passed --show-left --show-end --show-current-time'
  local CMsg='[38;5;8m'
  local to_do=''
  local to_do_extra=''
  local paused=false paused_time= pause_char='P' normal_char='' pause_msg_show=false pause_msg_last_time= pause_msg_delta=$((10*60))
  $TERMINAL_HAS_EXTRA_CHARS && pause_char='⏸ ' && normal_char='⏺ '
  set -- $PARAMS_DEFAULT $@
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
    --no-*)             to_do=${to_do//${1/'--no-'}};;
    --clear)            to_do=''; cmd='';;
    --cmd)              shift; echo "$@" >$CMD_FILE; return 0;;
    esac
    shift
  done # }}}
  to_do=" $to_do "
  local margin_s= startup_margin= end_margin= user_margin= pause_margin= user_comment= TODAY= TODAY_YMD= end_delay= pause_buffer=15 i=
  source $BASH_PATH/colors
  source $RUNTIME_FILE
  ! is_to_be_done 'nested' && ! is_to_be_done 'tmux' && set_title --set-pane 'Working Time'
  ! is_to_be_done 'nested' && mutex_init "work-time" --auto-clean-after 60 --no-trap
  while true; do # {{{
    local new_today="$(LC_TIME=en_US.UTF-8 command date +'%b %_d' | tr -s ' ')"
    if [[ $new_today != $TODAY ]]; then # {{{
      if ! is_to_be_done 'nested' && [[ -z $($0 --nested | cut -c8-12) ]]; then # {{{
        progress \
          --no-err \
          --msg "Waiting for login time..." --color "${CGold}" \
          --cmd "test -n $($0 --nested | cut -c8-12)"
      fi # }}}
      TODAY=$new_today
      TODAY_YMD="$(command date +"%Y%m%d")"
      startup_margin=0
      end_margin=0
      pause_margin=0
      user_margin=0
      user_comment=
      paused=false
      paused_time=
      pause_msg_show=false
      pause_buffer=15
      local dow=$(command date +'%w')
      if [[ -n $LOGLAST_MARGIN ]]; then
        [[ ${#LOGLAST_MARGIN[*]} == 1 ]] && startup_margin=$LOGLAST_MARGIN || startup_margin=${LOGLAST_MARGIN[$dow]}
        user_comment=${startup_margin/*:}
        startup_margin=${startup_margin/:*}
      fi
      if [[ -z $startup_margin ]]; then
        case $dow in
        1) startup_margin=5;;
        *) startup_margin=2;;
        esac
      fi
      if is_to_be_done 'loop'; then # {{{
        fix_caps
        __util_loglast_extra 'refresh'
        to_do_extra+=" store-force stats-main send "
        if [[ ! -e $FILE_DATA || $(command date -ud "@$(stat -c %Y $FILE_DATA)" +"%Y%m%d") != $TODAY_YMD ]]; then
          (
            echo "user_margin=\"$user_margin\""
            echo "user_comment=\"$user_comment\""
            echo "paused=\"$paused\""
            echo "paused_time=\"$paused_time\""
            echo "pause_margin=\"$pause_margin\""
          ) >$FILE_DATA
        fi
        __util_loglast_extra 'reset'
      fi # }}}
    fi # }}}
    [[ -e $FILE_DATA ]] && source $FILE_DATA
    margin_s=$(( ( $startup_margin + $end_margin + $user_margin - $pause_margin ) * 60))
    # echo "today=[$TODAY]" >/dev/stderr # DBG
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
        local gr_cmd=
        if is_to_be_done 'full'; then
          gr_cmd="command zgrep -a -h \"gkr-pam: unlocked login keyring\|New session .\+ of user $USER\" $(ls -rt /var/log/auth.log*)"
        else
          gr_cmd="command zgrep -a -h \"gkr-pam: unlocked login keyring\|New session c[0-9]\+ of user $USER\" $(ls -rt /var/log/auth.log*) | cut -c-12"
        fi
        cmd="$gr_cmd | tr -s ' ' $cmd"
      else
        cmd="last $USER $cmd"
      fi
      is_to_be_done 'highlight' && cmd+=" | $BASH_PATH/aliases hl +cY '$TODAY.*'"
    fi # }}}
    is_to_be_done 'clear-screen' && clear
    # echo "[$to_do] [$to_do_extra]" >/dev/stderr # DBG
    local d_cur=$(command date +"%H:%M")
    $paused && d_cur=$paused_time
    local d_cur_s=$(command date -d "$d_cur" '+%s')
    if is_to_be_done 'show-current-time'; then # {{{
      printf 'Time: %6s ' $d_cur
      $paused && printf "${CRed}%s${COff}" "${pause_char}" || printf "${CGreen}%s${COff}" "${normal_char}"
      printf "\n"
      printf -- "${CMsg}------------${COff}\n"
    fi # }}}
    if is_to_be_done 'logins'; then # {{{
      # echo "cmd=[$(echo $cmd | tr '\n' ' ')]" >/dev/stderr # DBG
      ! is_to_be_done 'nested' && is_to_be_done 'first' && printf "Start: ${CGold}"
      local str="$(eval $cmd | sed -e 's/\([A-Z][a-z][a-z]\)\s\+\([0-9]\) /\1  \2 /')"
      while [[ ${#str} -lt 5 ]]; do str="0$str"; done
      printf "%s" "$str"
      is_to_be_done 'nested' && printf "\n" && return 0
      printf "${COff}\n"
    fi # }}}
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
            ! is_to_be_done 'tmux' && echo -e "End:   ${CGreen}$d_print${COff}" || echo "$d_print"
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
            [[ ! -z $user_comment ]] && comment+="$user_comment "
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
      [[ ! -z $LOGLAST_BACKUP_FILE ]] && rsync $RSYNC_DEFAULT_PARAMS $FILE $LOGLAST_BACKUP_FILE >/dev/null 2>&1
      __util_loglast_extra 'send'
    fi # }}}
    if is_to_be_done 'plot'; then # {{{
      ! type gnuplot 1>/dev/null 2>&1 && echo "\"gnuplot\" not installed" >/dev/stderr && return 1
      local FILE_PLOT=$TMP_MEM_PATH/work-plot.data line= i= res=
      printf "%6s %2s %6s %6s\n" 'No' '8h' 'W' 'A' >$FILE_PLOT
      cat $FILE | tr -s ' ' | cut -d' ' -f 2,11 | sed -e 's/^0//g' -e 's/ 0/ /g' -e 's/:0/:/g' -e 's/-0/-/g' | while read line; do
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
      if [[ ! -z $(pgrep -x ssh) ]]; then # {{{
        echo "The following ssh sessions are going to be termianted:"
        echo  "${CMsg}------------------------------------------------------${COff}"
        pgrep -x ssh | xargs -n1 -- bash -c "pstree -la -s \$1 | tail -n2 | sed -e '1s/^ *\`-\(.*\)/$CGold* $CMsg\1$COff/' -e 's/bash [^ ]*\///' -e '2s/^ *\`-\(.*\)/  $CMsg└ $CCyan\1$COff/'" --
        echo  "${CMsg}------------------------------------------------------${COff}"
        echo
      fi # }}}
      local was_break=false
      trap "was_break=true;" INT
      eval "(                                                                                                                                                         \
        progress --pv --cnt $end_delay                                                                                                                                \
          --color \"$(is_to_be_done "suspend" && echo "${CGold}" || echo "${CRed}")\"                                                                               \
          --msg \"${CBlue}Going into $(is_to_be_done "suspend" && echo "${CGold}sleep${CBlue}" || echo "${CRed}shutdown${CBlue}") in $end_delay seconds...${COff}\" \
      )"
      trap - INT
      echo -en "${COff}"
      end_delay=
      if ! $was_break; then # {{{
        [[ ! -z $LOGLAST_BEFORE_SUSPEND ]] && eval $LOGLAST_BEFORE_SUSPEND
        pkill -x -u $USER 'ssh'
        if is_to_be_done 'suspend'; then
          sudo systemctl suspend
          sleep 10
          $BASH_PATH/aliases fix_caps
          to_do_extra=" store store-force send"
          local key=
          end_margin=0
          read -p "Press any key to continue..." key
          continue
        else
          sudo shutdown now
        fi
      else
        to_do_extra=
        continue
      fi # }}}
    fi # }}}
    if is_to_be_done 'pause-show-message'; then # {{{
      local now=$(command date +"%s")
      if [[ $(($pause_msg_last_time + $pause_msg_delta)) -lt $now ]]; then
        notify-send 'Time Tracker: PAUSED' -u 'critical'
        pause_msg_last_time=$now
      fi
    fi # }}}
    # Handle loop # {{{
    ! is_to_be_done 'loop' && break
    to_do_extra=
    local key=
    local LOOP_KEY=10 delayed=0
    while true; do # Wait for a key or input file {{{
      read -t $LOOP_KEY key && break
      if [[ -e $CMD_FILE ]]; then
        key=$(cat $CMD_FILE)
        rm -rf $CMD_FILE
        break
      fi
      delayed=$(($delayed + $LOOP_KEY))
      [[ $delayed -ge $LOOP_TIME ]] && continue 2
    done
    # }}}
    # Handle input # {{{
    set -- ${key}
    while [[ ! -z $1 ]]; do
      local cmd="$1" cmds= cmdFull= already_paused=false value=
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
      p-msg)        cmd='pause-message';;
      c)            cmd='comment';;
      s)            cmd='store';;
      e|e!|end)     cmd='suspend';  cmdFull="$cmd";;
      E|E!|End)     cmd='shutdown'; cmdFull="$cmd";;
      chk|st)       cmd='check';;
      bck|b)        cmd='backup';;
      r)            cmd='refresh';;
      R)            cmd='reset';;
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
          cmds+=' reset refresh';;
        esac;;
      suspend | shutdown)
        [[ $cmdFull != *! ]] && cmds+=" check"
        cmds+=" unpause $cmd pause store"
        ;;
      reset)
        cmds="$cmd refresh";;
      *)
        cmds="$cmd";;
      esac # }}}
      for cmd in $cmds; do # {{{
        case $cmd in # {{{
        quit) # {{{
          break 3;; # }}}
        margin) # {{{
          [[ -z $value ]] && value="$1" && shift
          user_margin="$value"
          case $user_margin in # {{{
          r|R)
            user_margin=-15; user_comment='Rower';;
          '')
            user_margin=0;;
          esac # }}}
          [[ ! -z $1 ]] && user_comment="$@" && shift $#
          ;; # }}}
        comment) # {{{
          user_comment="$@"; shift $#;; # }}}
        check) # {{{
          echo 'System check:'
          echo '  Repositories:'
          $BIN_PATH/git-cmds.sh gitst | grep -v 'UP-TO-DATE' | sed 's/^/    /'
          local cnt=10
          [[ $cmd != check ]] && cnt=3
          progress --msg 'Ack' --cnt $cnt --key; [[ $? == 11 ]] && sleep 1 || sleep 0.3
          case $? in
          255) break;;
          11)  sleep 1;;
          *)   sleep 0.3;;
          esac;; # }}}
        backup) # {{{
          git backup --all;; # }}}
        sync) # {{{
          git sync   --all;; # }}}
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
          fi;; # }}}
        pause-mod) # {{{
          [[ -z $value ]] && value="$1" && shift
          pause_margin=$(($pause_margin + $value))
          [[ $pause_margin -lt 0 ]] && pause_margin=0
          [[ ! -z $1 ]] && user_comment="$@" && shift $#
          ;; # }}}
        suspend|shutdown) # {{{
          end_margin=1
          case $cmdFull in # {{{
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
        pause) # {{{
          if ! $paused; then
            paused_time=$(command date +"%H:%M")
            paused=true
            pause_msg_show=true
            pause_msg_last_time=$(command date +"%s")
            if [[ $cmd == 'pause' ]]; then
              [[ ! -z $1 ]] && user_comment="$@" && shift $#
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
          __util_loglast_extra "$1"
          shift
          ;; # }}}
        *) # {{{
          to_do_extra+=" $key";; # }}}
        esac # }}}
      done # }}}
    done # }}}
    $pause_msg_show && to_do_extra+=" pause-show-message"
    to_do_extra=" $to_do_extra "
    local mem_file=$TMP_MEM_PATH/.work_time.nfo
    (
      echo "user_margin=\"$user_margin\""
      echo "user_comment=\"$user_comment\""
      echo "paused=\"$paused\""
      echo "paused_time=\"$paused_time\""
      echo "pause_margin=\"$pause_margin\""
    ) >$mem_file
    rsync $mem_file $FILE_DATA
    # }}}
  done # }}}
  mutex_deinit
  unset is_to_be_done
} # }}}

loglast "$@"

