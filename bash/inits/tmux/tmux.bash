#!/usr/bin/env bash
# vim: fdl=0

defaults() { # {{{
  # Windows numbering {{{
  if [[ $TMUX_VERSION -gt 20 ]]; then
    tmux set -qg renumber-windows on
  fi # }}}
  # Use UTF8 {{{
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
  ${IS_MAC:-false} && tmux set -qg default-command "reattach-to-user-namespace -l bash"
  # }}}
  # Lock & CMatrix # {{{
  [[ $(id -u) != 0 ]] && type cmatrix >/dev/null 2>&1 && tmux set -qg lock-command "$ALIASES sshh-add --lock --tmux ${TMUX_LOCK_PRE_TIMEOUT:-60}"
  tmux set -g lock-after-time ${TMUX_LOCK_TIMEOUT:-0} 
  # }}}
  if [[ $TMUX_VERSION -lt 24 ]]; then
    tmux bind-key '?' list-keys
  else
    tmux bind-key -T prefix '?'     display-message "2nd key(h)..." \\\; switch-client -T ext1
    tmux bind-key -n        'M-/'   switch-client -T ext1
    tmux bind-key -T ext1   '?'     list-keys -T prefix
    tmux bind-key -T ext1   'r'     list-keys -T root
    tmux bind-key -T ext1   'c'     list-keys -T copy-mode-vi
    tmux bind-key -T ext1   'p'     display-panes
    tmux bind-key -T ext1   'h'     list-keys -T ext1
    tmux bind-key -T ext1   'R'     display-message "Reloading..." \\\; source-file ~/.tmux.conf
    tmux bind-key -T ext1 -r 'C-h'  run-shell '~/.tmux.bash smarter_nest -z#{window_zoomed_flag} "C-h" "select-pane -L"'
    tmux bind-key -T ext1 -r 'C-j'  run-shell '~/.tmux.bash smarter_nest -z#{window_zoomed_flag} "C-j" "select-pane -D"'
    tmux bind-key -T ext1 -r 'C-k'  run-shell '~/.tmux.bash smarter_nest -z#{window_zoomed_flag} "C-k" "select-pane -U"'
    tmux bind-key -T ext1 -r 'C-l'  run-shell '~/.tmux.bash smarter_nest -z#{window_zoomed_flag} "C-l" "select-pane -R"'
    tmux unbind -T prefix   'R'
    local params=
    [[ $TMUX_VERSION -gt 16 ]] && params="-c \"#{pane_current_path}\""
    tmux bind-key -T ext1 \| run-shell "~/.tmux.bash smarter_nest '|'  'split-window -h -p 25 $params'"
    tmux bind-key -T ext1 -  run-shell "~/.tmux.bash smarter_nest '-'  'split-window -v -p 20 $params'"
    tmux bind-key -T ext1 \\ run-shell "~/.tmux.bash smarter_nest '\\' 'split-window -h       $params'"
    tmux bind-key -T ext1 _  run-shell "~/.tmux.bash smarter_nest '_'  'split-window -v       $params'"
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
    local interval= params= now="$(command date +'%s')" lastChange= delta=30 mod_delta=$((15*60)) progress=
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
        tmux set -qg status-interval "${interval:-30}"
        [[ -z $doNext ]] && echo "doNext=\"remove\"" >>"$f"
        exit 0
      ;; # }}}
    *end) # {{{
      params="stop"
      if [[ -z $lastChange || "$lastChange" == "0" ]]; then
        lastChange="$now"
        echo "lastChange=\"$lastChange\"" >>"$f"
      elif [[ "$now" -gt "$((lastChange + delta))" ]]; then
        progress_drawer "$entry" $extraParams end
        tmux set -qg status-interval "${interval:-30}"
        [[ -z $doNext ]] && echo "doNext=\"remove\"" >>"$f"
        exit 0
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
      [[ $interval == "1" ]] && interval="30"
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
    local cur_time=$(command date +%s) delta=$((15*60))
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
battery() { # @@ {{{
  is_ac() { # {{{
    if $IS_MAC; then
      pmset -g batt  | command grep 'InternalBattery' | grep -q 'discharging' && echo 'false' || echo 'true'
    else
      upower -i /org/freedesktop/UPower/devices/line_power_AC | command grep -q "online: *yes" && echo 'true' || echo 'false'
    fi
  } # }}}
  get_percentage() { # {{{
    local perc=
    if $IS_MAC; then
      perc="$(pmset -g batt  | command grep 'InternalBattery' | awk '{print $3}')"
      perc="${perc%\%;}"
    else
      perc="$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | command grep -F "percentage:" | awk '{print $2}')"
      perc="${perc%\%}"
    fi
    echo "${perc%\%}"
  } # }}}
  local delta="${TMUX_SB_BATTERY_DELTA:-$((2 * 60))}" # 2 minues
  local thresholds="${TMUX_SB_BATTERY_THRESHOLDS:-30:true 60:true 80:true 95}" colors="1 3 2 14"
  local update_time= value= battery_info="$(tmux show-environment -g "TMUX_SB_BATTERY_INFO" 2>/dev/null)"
  battery_info="${battery_info#*=}"
  if ! $testing && [[ ! -z $battery_info ]]; then # {{{
    eval "$battery_info"
    if [[ $cur_time -lt $(( $update_time + $delta )) ]]; then
      printf "%s" "$value"
      unset is_ac get_percentage
      return 0
    fi
  fi # }}}
  local ac_on="$(is_ac)" perc="$(get_percentage)" max=${thresholds##* }
  if ! $ac_on || [[ $perc -lt ${max%%:*} ]]; then
    local delta=30 c= i= showPerc=
    # Colors  # {{{
    for i in $thresholds; do
      showPerc=${TMUX_SB_BATTERY_SHOW_PERC:=false}
      if [[ $i == *:* ]]; then # {{{
        showPerc="${i#*:}"
        i="${i%%:*}"
      fi # }}}
      [[ $perc -lt $i ]] && c="${colors%% *}" && break
      colors="${colors#* }"
    done # }}}
    value="#[fg=colour$c]${UNICODE_EXTRA_CHARS[battery]}"
    if ! $ac_on; then
      $IS_MAC && value+="#[fg=colour10]${UNICODE_EXTRA_CHARS[extra_bar]}"
    fi
    $showPerc && { value+="#[fg=colour$c]${perc}%"; $ac_on && value+=" "; }
    $ac_on && value+="#[fg=colour2]${UNICODE_EXTRA_CHARS[power]}"
  else # {{{
    value=
    delta="${TMUX_SB_BATTERY_DELTA:-$((2 * 60))}"
  fi # }}}
  tmux set-environment -g "TMUX_SB_BATTERY_INFO" "update_time=$cur_time;value=\"$value\";delta=\"$delta\""
  unset is_ac get_percentage
  printf "%b" "$value"
} # }}}
cpu() { # @@ {{{
  local delta="${TMUX_SB_CPU_DELTA:-$((1*60))}" # 1 minute
  local thresholds="${TMUX_SB_CPU_THRESHOLDS:-9 7 5 3}"  colors="196 202 208 226"
  local update_time= value= cpu_info="$(tmux show-environment -g "TMUX_SB_CPU_INFO" 2>/dev/null)" cpu_1m= cpu_5m= c= i=
  cpu_info="${cpu_info#*=}"
  if ! $testing && [[ ! -z $cpu_info ]]; then # {{{
    eval "$cpu_info"
    if [[ $cur_time -lt $(( $update_time + $delta )) ]]; then # {{{
      printf "%s" "$value"
      return 0
    fi # }}}
  fi # }}}
  if ! $IS_MAC; then # {{{
    read cpu_1m cpu_5m <<<$(cat /proc/loadavg | awk '{print int($1), int($2)}')
  else
    read cpu_1m cpu_5m <<<$(uptime | awk '{print int($11), int($12)}')
  fi # }}}
  if [[ $cpu_1m -ge ${thresholds##* } ]]; then # {{{
    local first=true showPerc="${TMUX_SB_CPU_SHOW_PERC:-false}"
    delta=15
    # Colors # {{{
    for i in $thresholds; do
      if [[ $cpu_1m -ge $i ]]; then
        $first && showPerc=true;
        c="${colors%% *}"
        break
      fi
      first=false
      colors="${colors#* }"
    done # }}}
    value="#[fg=colour$c,bold]"
    value+="${UNICODE_EXTRA_CHARS[high_cpu]}"
    if $showPerc; then
      value+="${cpu_1m}/${cpu_5m}%"
    elif $IS_MAC; then
      value+="#[fg=colour10]${UNICODE_EXTRA_CHARS[extra_bar]}"
    fi
    value+="#[fg=default,none]"
  else
    delta="${TMUX_SB_CPU_DELTA:-$((1*60))}" value=
  fi # }}}
  tmux set-environment -g "TMUX_SB_CPU_INFO" "update_time=$cur_time;value=\"$value\";delta=\"$delta\""
  printf "%b" "$value"
} # }}}
weather_tmux() { # @@ {{{
  local delta="${TMUX_SB_WEATHER_DELTA:-$((1 * 60 * 60))}" # One hour
  local update_time= value= weather_info="$(tmux show-environment -g "TMUX_SB_WEATHER_INFO" 2>/dev/null)"
  weather_info="${weather_info#*=}"
  if ! $testing && [[ ! -z $weather_info ]]; then # {{{
    eval "$weather_info"
    if [[ $cur_time -lt $(( $update_time + $delta )) ]]; then
      printf "%b" "$value"
      return 0
    fi
  fi # }}}
  weather_icon() { # {{{
    # Icons: [ 🌣  (  🌞  )  🌤  🌥  ☁️  🌦  🌧  🌨  ⛈  🌩  🌪  🌫  🌬  ]
    local icon=
    [[ -z $TMUX_DEFAULT_WEATHER_ICONS ]] &&
      local TMUX_DEFAULT_WEATHER_ICONS=" \
        800::🌞 \
        801:802::🌤 \
        803::🌥 \
        804::☁️  \
        500:501:520:521:531::🌦 \
        600:601:602:611:612:615:616:620:621:622::🌨 \
        300:301:302:310:311:312:313:314:321:502:503:504:511:522::🌧 \
        200:201:202:210:211:212:221:230:231:232::⛈  \
        701:711:721:731:741:751:761:762:771::🌫 \
      "
    [[ ! -z "$TMUX_WEATHER_ICONS" ]] && [[ " $TMUX_WEATHER_ICONS " =~ ^.*[\ :]$1([0-9:])*::([^\ ]+)\ .* ]] \
      && icon="${BASH_REMATCH[2]}"
    [[ -z "$icon" ]] && [[ " $TMUX_DEFAULT_WEATHER_ICONS " =~ ^.*[\ :]$1([0-9:])*::([^\ ]+)\ .* ]] \
      && icon="${BASH_REMATCH[2]}"
    [[ -z $icon ]] \
      && icon="$1"
    local colors=" \
      800::#[fg=colour226] \
      801:802::#[fg=colour228] \
      803::#[fg=colour254] \
      804::#[fg=colour251] \
      500:501:520:521:531::#[fg=colour228] \
      600:601:602:611:612:615:616:620:621:622::#[fg=colour74] \
      300:301:302:310:311:312:313:314:321:502:503:504:511:522::#[fg=colour74] \
      200:201:202:210:211:212:221:230:231:232)::#[fg=colour250] \
      701:711:721:731:741:751:761:762:771::#[fg=colour250] \
    "
    local c=
    [[ " $colors " =~ ^.*[\ :]$1([0-9:])*::([^\ ]+)\ .* ]] && c="${BASH_REMATCH[2]}"
    printf "%b%b" "$c" "$icon"
  } # }}}
  weather_wind_arrow() { # {{{
    local out=()
    if   [[ $2 -lt 3 ]];                         then out=(↺ ↻)
    elif [[ $2 -lt ${WEATHER_WIND_SPEED:-15} ]]; then out=(↓ ↙ ← ↖ ↑ ↗ → ↘)
    elif [[ $2 -lt ${WEATHER_WIND_SPEED:-30} ]]; then out=(⇓ ⇙ ⇐ ⇖ ⇑ ⇗ ⇒ ⇘)
    else                                              out=(⇊ ⇇ ⇈ ⇉)
    fi
    local len="${#out[*]}"
    local radius="$(echo "$len" | awk '{print 360/$1}')"
    printf "%b %skm/h" "${out[$(echo "$1" | awk "{print int(\$1/$radius+0.5)%$len}")]}" "$2"
  } # }}}
  weather_temp_color() { # {{{
    if   [[ $1 -lt -5 ]]; then printf "#[fg=colour33]%d°C"  "$1"
    elif [[ $1 -lt  5 ]]; then printf "#[fg=colour45]%d°C"  "$1"
    elif [[ $1 -lt 15 ]]; then printf "#[fg=colour172]%d°C" "$1"
    elif [[ $1 -lt 22 ]]; then printf "#[fg=colour178]%d°C" "$1"
    else                       printf "#[fg=colour226]%d°C" "$1"
    fi
  } # }}}
  local STORAGE_FILE="$TMP_MEM_PATH/.weather-tmux.log"
  if [[ -e $STORAGE_FILE ]]; then # {{{
    WEATHER_INFO=()
    local line=
    while read line; do
      WEATHER_INFO+=("$line")
    done < <(cat $STORAGE_FILE)
    [[ ! -z ${WEATHER_INFO[7]} && $cur_time -ge $(( ${WEATHER_INFO[7]} + $((7 * 24 * 60 * 60)) )) ]] && WEATHER_INFO=()
    [[ -z ${WEATHER_INFO[7]} ]] && WEATHER_INFO[7]="$cur_time"
  fi # }}}
  local err=false
  if [[ -z $WEATHER_API_KEY ]]; then
    $testing && echo "Error: No API key" >/dev/stderr || tmux display-message "Weather: No API key"
  fi
  while [[ -z ${WEATHER_INFO[0]} || -z ${WEATHER_INFO[3]} || $cur_time -ge $(( ${WEATHER_INFO[0]} + $delta )) ]] || $testing; do # {{{
    if [[ -z ${WEATHER_INFO[1]} ]]; then
      local loc=$(curl --silent --connect-timeout 2 http://ip-api.com/csv)
      if [[ -z $loc || $? != 0 ]]; then # {{{
        $testing && echo "Error when acquiring location" >/dev/stderr || tmux display-message "Weather: Error when acquiring location"
        err=true
        break
      fi # }}}
      WEATHER_INFO[1]=$(echo "$loc" | cut -d , -f 8)
      WEATHER_INFO[2]=$(echo "$loc" | cut -d , -f 9)
      [[ ${WEATHER_INFO[1]} == 51.* && ${WEATHER_INFO[2]} == 16.* ]] && WEATHER_INFO[1]=51.099 && WEATHER_INFO[2]=17.039
    fi
    local weather="$(curl --silent --connect-timeout 2 "http://api.openweathermap.org/data/2.5/weather?lat=${WEATHER_INFO[1]}&lon=${WEATHER_INFO[2]}&APPID=$WEATHER_API_KEY&units=metric")"
    if [[ ! -z $weather && $? == 0 && $(echo $weather | jq .cod) == 200 ]]; then
      WEATHER_INFO[0]="$cur_time"
      WEATHER_INFO[3]="$(echo "$weather" | jq .main.temp  | cut -d . -f 1)"
      WEATHER_INFO[4]="$(echo "$weather" | jq .wind.speed | awk '{print int($1*3.6+0.5)}')"
      WEATHER_INFO[5]="$(echo "$weather" | jq .wind.deg   | cut -d . -f 1)"
      WEATHER_INFO[6]="$(echo "$weather" | jq .weather[0].id)"
    else
      $testing && echo "Error when acquiring forecast" >/dev/stderr || tmux display-message "Weather: Error when acquiring forecas"
      err=true
      break
    fi
    if $testing; then # {{{
      while [[ ! -z $1 ]]; do
        case $1 in
        --reset)               WEATHER_INFO[0]=0;;
        --temp)                shift; WEATHER_INFO[3]=$1;;
        --wind-speed)          shift; WEATHER_INFO[4]=$1;;
        --wind-dir|--wind-deg) shift; WEATHER_INFO[5]=$1;;
        --clouds)              shift; WEATHER_INFO[6]=$1;;
        --dbg)                 echo "Weather=[$(echo $weather | jq .)]";;
        esac
        shift
      done
    fi # }}}
    { echo  "${WEATHER_INFO[0]}"
      echo  "${WEATHER_INFO[1]}"
      echo  "${WEATHER_INFO[2]}"
      echo  "${WEATHER_INFO[3]}"
      echo  "${WEATHER_INFO[4]}"
      echo  "${WEATHER_INFO[5]}"
      echo  "${WEATHER_INFO[6]}"
      echo  "${WEATHER_INFO[7]}"
    } >$STORAGE_FILE
    break
  done # }}}
  export WEATHER_INFO
  local ret=
  if ! $err; then
    ret="$(printf "%s %s #[fg=colour72]%s" "$(weather_icon "${WEATHER_INFO[6]}")" "$(weather_temp_color "${WEATHER_INFO[3]}")" "$(weather_wind_arrow ${WEATHER_INFO[5]} ${WEATHER_INFO[4]})")"
  else
    ret="#[fg=colour124]✗☁️ #[fg=default,none]"
  fi
  tmux set-environment -g "TMUX_SB_WEATHER_INFO" "update_time=$cur_time;value=\"$ret\"$($err && echo ";delta=60")"
  printf "%b" "$ret"
  $testing && echo
  unset weather_icon weather_wind_arrow weather_temp_color
  $err && return 1
  return 0
} # }}}
system_notifications() { # @@ {{{
  local ntf_file="${NOTIFICATION_FILE_TMUX:-$TMP_MEM_PATH/notifications-tmux.txt}" icon= delta=$((5*60))
  if [[ ! -e "$ntf_file" ]]; then
    icon='#'
  elif [[ "$(stat -c "%Y" "$ntf_file")" -ge "$(($cur_time - $delta))" ]]; then
    icon="${UNICODE_EXTRA_CHARS[envelope]}"
  fi
  printf "%b" "$icon"
} # }}}
status_right_extra() { # @@ {{{
  [[ -z "$TMUX_STATUS_RIGHT_EXTRA_SORTED" ]] && printf " " && return 0
  source "$UNICODE_EXTRA_CHARS_FILE"
  local tm_info="$1" tm_time="$2"
  [[ -z $tm_info ]] && tm_info="$(tmux display-message -pF '#S:#I.#P')"
  [[ -z $tm_time ]] && tm_time="$(command date +'%H:%M')"
  local session="${tm_info%%:*}" l= ret=
  local cur_time=$(command date +%s) update_time= value= do_update= weather_info=
  local logtime_params="$(tmux show-environment -t $session "TMUX_SB_LOGTIME_PARAMS" 2>/dev/null)"
  logtime_params="${logtime_params#*=}"
  for l in $TMUX_STATUS_RIGHT_EXTRA_SORTED; do
    case $l in
    tmux_info)  ret+=" #[fg=colour244]$($HOME/.tmux.bash get_marked_pane)";;
    time)       [[ $logtime_params != 'hidden' ]] && ret+=" #[fg=colour12]$tm_time";;
    weather)    weather_info="$(weather_tmux)" && ret+=" $weather_info";;
    logtime) # {{{
      [[ $logtime_params == 'false' ]] && continue
      [[ ! -e $BIN_PATH/misc/log-last.sh ]] && continue
      if [[ $logtime_params == 'hidden' ]]; then # {{{
        local delta="$((10 * 60))" time_params="$(tmux show-environment -g "TMUX_SB_TIME_PARAMS" 2>/dev/null)"
        time_params="${time_params#*=}"
        [[ ! -z $time_params ]] && eval "$time_params"
        if [[ $cur_time -ge $(( $update_time + $delta )) || -z "$value" ]] || $testing; then
          value=$($BIN_PATH/misc/log-last.sh --tmux %)
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
          [[ $params = *%* ]] && delta=$((5*60))
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
    usb) # {{{
      local prefix="/media/$USER"
      $IS_MAC && prefix="/Volumes"
      if [[ $(echo $prefix/*) != "$prefix/*" ]]; then
        ret+=" #[fg=colour148]${UNICODE_EXTRA_CHARS[disk]}"
      fi
      ;; # }}}
    cpu) # {{{
      local out="$(cpu)"
      [[ ! -z "$out" ]] && ret+=" $out"
      ;; # }}}
    progress_bar) # {{{
      local out="$(progress_bar_worker)"
      [[ ! -z "$out" ]] && ret+=" $out"
      ;; # }}}
    notifs) # {{{
      local notifs="$(system_notifications)"
      [[ ! -z "$notifs" ]] && ret+=" #[bg=colour124] #[fg=colour226,bold]$notifs #[bg=colour235,none]"
      ;; # }}}
    battery) # {{{
      local out="$(battery)"
      [[ ! -z "$out" ]] && ret+=" $out"
      ;; # }}}
    *) # {{{
      local out= i=
      for i in $BASH_PROFILES_FULL; do
        [[ -e $i/aliases ]] && out="$($i/aliases __util_tmux_extra $l)"
        [[ ! -z $out ]] && break
      done
      if ! ${dbg:-false}; then
        [[ ! -z "$out" ]] && ret+=" $out"
      else
        ret+=" $l:[$out]"
      fi
      ;; # }}}
    esac
  done
  printf "%b" "$ret "
} # }}}
status_right_refresh() { # @@ {{{
  tmux show-environment | command grep "^TMUX_SB.*update_time" | while read i; do
    tmux set-environment  ${i%%=*} "$(echo "${i#*=}" | sed -e 's/update_time=[0-9]*;/update_time=0;/')"
  done
  tmux show-environment -g | command grep "^TMUX_SB.*update_time" | while read i; do
    tmux set-environment  -g ${i%%=*} "$(echo "${i#*=}" | sed -e 's/update_time=[0-9]*;/update_time=0;/')"
  done
} # }}}
status_right() { # {{{
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
    info="$($ALIASES getUnicodeChar "${icon:-localhost}")"
    if ${TMUX_SB_SHOW_HOSTNAME:-false}; then
      [[ -z $icon ]] && info="$(hostname | tr '[a-z]' '[A-Z]' | sed 's/\..*//')"
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
    tmux set -g @fingers-pattern-$cnt "$i"
    cnt="$(($cnt+1))"
  done
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
  local params=
  [[ $TMUX_VERSION -gt 16 ]] && params="-c \"#{pane_current_path}\""
  tmux bind-key \| run-shell "~/.tmux.bash smarter_nest -z#{window_zoomed_flag} '|'  'split-window -h -p 25 $params'"
  tmux bind-key -  run-shell "~/.tmux.bash smarter_nest -z#{window_zoomed_flag} '-'  'split-window -v -p 20 $params'"
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
smarter_nest() { # @@ {{{
  local send_prefix= key= version= do_eval=true dbg=false log_f= err= zoom= keep_zoom=false
  [[ $1 == --dbg ]] && dbg=true && shift
  [[ $1 == --dbg=* ]] && dbg=true && log_f="${1#--dbg=}" && shift
  $dbg && [[ ! -z $log_f ]] && exec 2>>$log_f
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --no-prefix) send_prefix='NONE';;
    --ver)       shift; version=$1;;
    --no-eval)   do_eval=false;;
    -z0 | -z1)   zoom=${1#-z};;
    -Z0 | -Z1)   zoom=${1#-Z}; keep_zoom=true;;
    --keep-zoom) keep_zoom=true;;
    *)           key=$1; shift; break;;
    esac
    shift
  done # }}}
  [[ ! -z $version && $TMUX_VERSION -le $version ]] && return 0
  [[ -z $send_prefix ]] && send_prefix=${TMUX_PREFIX_2:-$(tmux show-options -gv prefix2)} || send_prefix=
  local pane_info= auto_check_nest=$(tmux show-options -wqv @mark_auto) auto_check_nest_g=$(tmux show-options -gqv @mark_auto)
  if ! $auto_check_nest && ( [[ $zoom == 1 ]] || smarter_nest_allowed "$@" ); then
    [[ $auto_check_nest_g == 'false' || $auto_check_nest_g == 'toggling' ]] && auto_check_nest=false || auto_check_nest=true
  fi
  [[ -z $auto_check_nest ]] && auto_check_nest=$auto_check_nest_g
  if [[ $auto_check_nest == 'true' ]] && ! ${TMUX_SMART_IGNORE:-false}; then # {{{
    pane_info=$(tmux display-message -p -t $TMUX_PANE -F '#P:#{pane_pid}')
    if ! $IS_MAC; then
      local ps_out="$(command ps -o args -g ${pane_info/*:})"
    else
      local ps_out="$(command pstree ${pane_info/*:} | sed "s/.*= [0-9]\+ $USER //")"
    fi
    if echo "$ps_out" | command grep -q -P "^tmux|^docker-compose|^docker attach|^ssh( .+)? (\S+@)?(\w{3,}|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$"; then
      if echo "$ps_out" | command grep -q "^\(sh -c \)\{0,1\}vlock\|^git\|^scp\|^rsync"; then
        pane_info=
      else
        ps_out="$(echo "$ps_out" | command grep "ssh")"
        if [[ ! -z $TMUX_SMART_BLACKLIST ]] && echo "$ps_out" | command grep -q "$TMUX_SMART_BLACKLIST"; then
          pane_info=
        fi
      fi
    else
      pane_info=
    fi
  fi # }}}
  [[ $auto_check_nest_g == 'toggling' ]] && tmux set-option -g @mark_auto true
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
  return 0
} # }}}
lock_toggle() { # {{{
  local w_status="$(tmux show-option  -qv @lock_allowed)"
  local g_status="$(tmux show-option -gqv @lock_allowed)"
  local new_status=
  case $w_status in
  false) tmux set-option -uq @lock_allowed; tmux display-message "Locking changed to global value ($( ${g_status:-true} && echo 'enabled' || echo 'disabled'))";;
  *)     case $g_status in
         false) new_status='true';;
         *)     new_status='false';;
         esac
         tmux set-option $( [[ $1 == -g ]] && echo '-g' ) @lock_allowed $new_status
         tmux display-message "Locking $( $new_status && echo 'enabled' || echo 'disabled') $( [[ $1 == -g ]] && echo 'globally' || echo 'locally')"
         ;;
  esac
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
scratch_pane() { # {{{
  local cwd="$1" params="$2" pane_id=
  [[ -z $params ]] && params="-h -p 50"
  [[ -e "$cwd" ]] && params+=" -c \"$cwd\""
  pane_id="$(eval tmux split-window $params -P -F "'#{pane_id}'")"
  sleep 0.5
  tmux send-keys -t $pane_id "pt hn; clear"
} # }}}
pasteKey_worker() { # @@ {{{
  local auto=$1 buff="$2" query="$3"
  local v="$( \
    keep-pass.sh --list-all-keys \
    | eval fzf \
      --preview="\"keep-pass.sh --key '{1}' --no-intr\"" \
      +m --prompt="\"Key> \"" $([[ ! -z $query ]] && echo "--query=\"$query\"") -0 \
  )"
  [[ $? == 0 && ! -z "$v" ]] || return 1
  v="$(keep-pass.sh --key "$v")"
  [[ ! -z $v ]] || return 1
  if $auto; then
    [[ $v == *'..' ]] && v="${v%..}" || v+=""
  fi
  tmux set-buffer -b $buff "$v"
} # }}}
pasteKey() { # @@ {{{
  local buff="key.$$" pane_id= auto=true f="$TMP_MEM_PATH/keep-pass-key" delta=30 key=
  [[ $1 == '--set-key' ]] && echo "$2" >"$f" && return 0
  [[ $1 == '-m' ]] && auto=false && shift
  [[ -e "$f" && $(stat -c "%Y" "$f") -gt $(($(command date +%s)-$delta)) ]] && key="$(cat "$f")"
  rm -f "$f"
  tmux delete-buffer -b "$buff" >/dev/null 2>&1
  pane_id="$(tmux split-window -h -p 50 -P -F '#{pane_id}' "$HOME/.tmux.bash pasteKey_worker $auto '$buff' '$key'")"
  while tmux display-message -p -t "$pane_id" -F '#{pane_id}' >/dev/null 2>&1; do
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
  case $3 in
  --dbg | --dbg2 | --test | --time) # {{{
    sed -n 's/^\([a-z].*\)() { # @@ .*/\1/p' tmux.bash
    ;;& # }}}
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
    cur_time=$(command date +%s)
    $sTime && { time "$@"; } || { $@; }
    echo
  ) 2>&1
  ;; # }}}
*) "$@";;
esac

