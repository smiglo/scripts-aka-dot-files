#!/usr/bin/env bash
# vim: fdl=0

# Defaults  # {{{
verbose=false
log_level=I

info_file=$BASHRC_RUNTIME_PATH/tmux-sb.info
err_dev="/dev/stderr"

default_interval=120
default_sleep=10

markLU="_last_update"
markIgn='--IGNORED--'

battery_interval=${TMUX_SB_BATTERY_DELTA:-$((60))}
cpu_interval=${TMUX_SB_CPU_DELTA:-$((30))}
hdd_used_interval=${TMUX_SB_HDD_OVERLAY_DELTA:-$((1 * 60 * 60))}
lockstatus_interval=${TMUX_SB_LOCKSTATUS_DELTA:-$((30))}
mic_interval=${TMUX_SB_MIC_DELTA:-$((60))}
net_interval=${TMUX_SB_NET_DELTA:-$((30))}
notifications_interval=${TMUX_SB_NOTIFICATIONS_DELTA:-$((30))}
reminder_interval=${TMUX_SB_REMINDER_DELTA:-$((30))}
ssh_interval=${TMUX_SB_MIC_DELTA:-$((15))}
temp_interval=${TMUX_SB_TEMP_DELTA:-$((30))}
usb_interval=${TMUX_SB_USB_DELTA:-$((15))}
weather_interval=${TMUX_SB_WEATHER_DELTA:-$((1 * 60 * 60))}

[[ -e $APPS_CFG_PATH/tmux-sb-workers.sh ]] && source $APPS_CFG_PATH/tmux-sb-workers.sh

# }}}
battery_tmux_sb_worker() { # @@ # {{{
  is_ac() { # {{{
    if $IS_MAC; then
      pmset -g batt  | grep 'InternalBattery' | grep -q 'discharging' && echo 'false' || echo 'true'
    else
      upower -i /org/freedesktop/UPower/devices/line_power_AC | grep -q "online: *yes" && echo 'true' || echo 'false'
    fi
  } # }}}
  get_percentage() { # {{{
    local perc=
    if $IS_MAC; then
      perc="$(pmset -g batt  | grep 'InternalBattery' | awk '{print $3}')"
      perc="${perc%\%;}"
    else
      perc="$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -F "percentage:" | awk '{print $2}')"
      perc="${perc%\%}"
    fi
    echo "${perc%\%}"
  } # }}}
  local thresholds="${TMUX_SB_BATTERY_THRESHOLDS:-30:true 60:true 80:true 95}" colors="1 3 2 14"
  local value=
  local ac_on="$(is_ac)" perc="$(get_percentage)" max=${thresholds##* }
  if ! $ac_on || [[ $perc -lt ${max%%:*} ]]; then
    battery_interval=30
    local c= i= showPerc=
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
      $IS_MAC && value+="#[fg=colour10]${UNICODE_EXTRA_CHARS[extra-bar]}"
    fi
    $showPerc && { value+="#[fg=colour$c]${perc}%"; $ac_on && value+=" "; }
    $ac_on && value+="#[fg=colour2]${UNICODE_EXTRA_CHARS[power]}"
  else
    value=
    battery_interval="${TMUX_SB_BATTERY_DELTA:-$((2 * 60))}"
  fi
  unset is_ac get_percentage
  printf "%b" "$value"
} # }}}
cpu_tmux_sb_worker() { # @@ # {{{
  local thresholds="${TMUX_SB_CPU_THRESHOLDS:-9 7 5 3}"  colors="196 202 208 226"
  local value= cpu_1m= cpu_5m= c= i=
  if ! $IS_MAC; then # {{{
    read cpu_1m cpu_5m < <(cat /proc/loadavg | awk '{print int($1), int($2)}')
  else
    read cpu_1m cpu_5m < <(uptime | awk '{print int($11), int($12)}')
  fi # }}}
  if [[ $cpu_1m -ge ${thresholds##* } ]]; then # {{{
    local first=true showPerc="${TMUX_SB_CPU_SHOW_PERC:-false}"
    cpu_interval=15
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
    value+="${UNICODE_EXTRA_CHARS[high-cpu]}"
    if $showPerc; then
      value+="${cpu_1m}/${cpu_5m}%"
    elif $IS_MAC; then
      value+="#[fg=colour10]${UNICODE_EXTRA_CHARS[extra-bar]}"
    fi
    value+="#[fg=default,none]"
  else
    cpu_interval=${TMUX_SB_CPU_DELTA:-$((30))} value=
  fi # }}}
  printf "%b" "$value"
} # }}}
hdd_used_tmux_sb_worker() { # {{{
  local used= color=
  used=$(command df / | awk '/^'"${TMUX_SB_HDD_USED_DISK:-overlay}"' / {print $5}')
  used=${used/%\%}
  if (( used < 50 )); then
    color="colour040"
    ${TMUX_SB_HDD_OVERLAY_REPORT_ALWAYS:-false} || return 0
  elif (( used < 75 )); then
    color="colour220"
  elif (( used < 90 )); then
    color="colour208"
  else
    color="colour196"
  fi
  local value="$(printf "#[fg=%s]%s%%#[fg=default,none]" "$color" "$used")"
  printf "%b" "$value"
} # }}}
lockstatus_tmux_sb_worker() { # @@ # {{{
  local value= lockCmd="$(tmux show-options -vg 'lock-command')"
  if [[ 'false' == 'true' \
        || ( "$lockCmd" != *sshh-add* || "$lockCmd" == *'--tmux -1'* ) \
        || ( "$(tmux show-options -vg 'lock-after-time')" == 0 ) \
        || ( "$(tmux show-option  -qv @lock_allowed)" == 'false' || "$(tmux show-option -gqv @lock_allowed)" == 'false' ) \
     ]]; then
     value="$(printf "#[fg=colour10]%b#[fg=default,none]" "${UNICODE_EXTRA_CHARS[padlock]}")"
  fi
  printf "%b" "$value"
} # }}}
mic_tmux_sb_worker() { # {{{
  local level=${TMUX_SB_WORKER_MIC_LEVEL:-80} isInternal=false amixerP="-D pulse"
  local dev=${TMUX_SB_WORKER_MIC_DEV:-Capture}
  case ${TMUX_SB_WORKER_MIC_INTERNAL_MIC_BOOST:-skip} in
  skip) ;;
  true)
    local v="$(amixer $amixerP sget 'Internal Mic Boost' | sed -n 's/.*Front Left:.*\[\([0-9]\+\)%\].*/\1/p')"
    [[ $v -gt 0 ]] && isInternal=true;;
  false)
    if ! amixer $amixerP sget 'Headset Mic' 1>/dev/null 2>&1 || amixer $amixerP sget 'Headset Mic' | grep -q "Mono:.*\[off\]"; then
      return
    fi
  esac
  local mic="$(get-unicode-char 'mic')" mute="$(get-unicode-char 'mute')"
  local value=
  if amixer $amixerP sget "$dev" | grep -q "Front Left:.*\[off\]"; then
    value="#[fg=colour9]$mic$mute"
  else
    $isInternal && return
    local v="$(amixer $amixerP sget "$dev" | sed -n 's/.*Front Left:.*\[\([0-9]\+\)%\].*/\1/p')"
    if [[ $v -le $level ]]; then
      value="#[fg=colour11]$mic$mute"
    elif ! $isInternal; then
      value="#[fg=colour14]$mic"
    fi
  fi
  printf "%b" "$value"
} # }}}
net_tmux_sb_worker() { # {{{
  local value= char=$(get-unicode-char 'link') con="#[bg=colour124]#[fg=colour226,bold]" coff="#[bg=default,none]" isNet=false
  ping -c1 8.8.8.8 -w1 >/dev/null 2>&1 && value=0 || value=$(net -s; echo $?)
  case $value in
  0)  value=""; isNet=true;;
  1)  value="$char$con 8 $coff";;
  2)  value="$char$con DNS $coff";;
  10) value="$char$con GW $coff";;
  11) value="$char$con $(get-unicode-char 'icon-err') GW $coff";;
  *)  value="$char$con ? $value$coff";;
  esac
  if $isNet; then
    echo "connectivity=true"  >$BASHRC_RUNTIME_PATH/net.status
  else
    echo "connectivity=false" >$BASHRC_RUNTIME_PATH/net.status
  fi
  printf "%b" "$value"
} # }}}
notifications_tmux_sb_worker() { # @@ # {{{
  local delta=$((5*60)) ntf_file="${NOTIFICATION_FILE_TMUX:-$TMP_MEM_PATH/notifications-tmux.txt}" icon= value=
  if [[ ! -e "$ntf_file" ]]; then
    icon='##'
  elif [[ "$(stat -c "%Y" "$ntf_file")" -ge "$(($now - $delta))" ]]; then
    icon=" ${UNICODE_EXTRA_CHARS[envelope]} "
  fi
  [[ ! -z $icon ]] && value="$(printf "#[bg=colour124]#[fg=colour226,bold]%b#[bg=default,none]" "$icon")"
  printf "%b" "$value"
} # }}}
reminder_tmux_sb_worker() { # {{{
  local ts= value=
  local icon="${UNICODE_EXTRA_CHARS[bell]} "
  case $1 in
  -ts) ts=$2; shift 2;;
  esac
  case ${TMUX_SB_REMINDER_METHOD:-tmux} in
  tmux) # {{{
    local now=$EPOCHSECONDS diffClose=$((2 * 60 + 30)) closeEnough=false
    [[ -z $ts ]] && read ts _ < <($SCRIPT_PATH/bin/reminder.sh next)
    [[ -z $ts ]] && return 0
    (( now > ts )) && return 0
    local diff=$((ts - now))
    (( diff < diffClose )) && closeEnough=true
    if $closeEnough; then # {{{
      value="$(printf "#[bg=colour124]#[fg=colour226,bold] ")" # }}}
    else # {{{
      value="$(printf "#[fg=colour03]")"
    fi # }}}
    method="${TMUX_SB_REMINDER_PRINT_METHOD:-auto}"
    case $method in # {{{
    auto)
      method="absolute"
      (( diff < ${TMUX_SB_REMINDER_REMAINING_THRESHOLD:-$((5 * 60))} )) && method="remaining";;
    esac # }}}
    case $method in
    absolute) # {{{
      value+="$(printf "%b %s" "$icon" "$(date +%H:%M -d@$ts)")";; # }}}
    remaining) # {{{
      local diff=$((ts - now)) remaining=
      if (( diff < 60 )); then
        remaining="${diff}s"
      else
        remaining=$(time2s --to-HMS $diff)
        ${TMUX_SB_REMINDER_PRINT_ROUND:-true} && remaining="${remaining%:*}"
      fi
      value+="$(printf "%b %s" "$icon" "$remaining")";; # }}}
    esac
    if $closeEnough; then # {{{
      value+=" "
    fi # }}}
    value+="$(printf "#[bg=default,none]#[fg=default,none]")";; # }}}
  loglast) # {{{
    local what=
    read ts what _ < <($SCRIPT_PATH/bin/oth/reminder-loglast.sh -l)
    ts=${ts%:*}
    [[ -z $ts ]] && return
    case $what in
    P)  icon="${UNICODE_EXTRA_CHARS[pause]}";;
    GH) icon="${UNICODE_EXTRA_CHARS[home]}";;
    esac
    value="$(printf "#[fg=colour12]%b%s#[fg=default,none]" "$icon" "$ts")";; # }}}
  esac
  printf "%b" "$value"
} # }}}
ssh_tmux_sb_worker() { # {{{
  local w="$(w -h -i)" isRoot=false isSsh=false sshCnt=0 moreThanOne=false d="${TMUX_SB_WORKER_SSH_FROM_NO:-:0}"
  $IS_DOCKER && w="$(w -h -i | grep -v tmux)"
  local lines="$(echo "$w" | wc -l)"
  echo "$w" | grep -q "^root" && isRoot=true
  local weAreOverSSH=false
  $ALIASES_SCRIPTS/tmux/tm.sh --is-ssh && weAreOverSSH=true
  if ! $IS_MAC && [[ $lines -gt 1 ]] && ! $weAreOverSSH; then
    w="$(echo "$w" | cut -c19- | grep -v "^$d")"
    if [[ ! -z $w ]]; then
      sshCnt=$(who | grep -v "(:\|tmux(.*%\|seat0" | sort -k5,5 -u | wc -l)
      moreThanOne=true
      [[ $sshCnt -gt 1 ]] && isSsh=true
    fi
  fi
  local sign="$(get-unicode-char 'exclamation')" value=
  if $isSsh; then
    if [[ $sshCnt == 1 ]]; then
      $weAreOverSSH && isSsh=false
    fi
    $isSsh && value="#[bg=colour124]#[fg=colour226,bold] $sign$sign$sign #[bg=default,none]"
  elif $isRoot; then
    value="#[bg=colour124]#[fg=colour226,bold] $sign$sign #[bg=default,none]"
  elif $moreThanOne; then
    value="#[bg=colour124]#[fg=colour226,bold] $sign #[bg=default,none]"
  fi
  printf "%b" "$value"
} # }}}
usb_tmux_sb_worker() { # {{{
  local prefix="/media/$USER" value=
  $IS_MAC && prefix="/Volumes"
  if [[ $(echo $prefix/*) != "$prefix/*" ]]; then
    if ! $IS_MAC || [[ $(echo $prefix/*) != "$prefix/Macintosh HD" ]]; then
      value="#[fg=colour148]${UNICODE_EXTRA_CHARS[disk]}"
    fi
  fi
  printf "%b" "$value"
} # }}}
temp_tmux_sb_worker() { # {{{
  which temperature-monitor.sh >/dev/null 2>&1 || { vSet temp ignored true; return 1; }
  local value=$(temperature-monitor.sh -1)
  [[ ! -z $value ]] || return 1
  value=${value%% *}
  [[ $value -ge ${TMUX_SB_TEMP_THRESHOLD:-80} ]] || return 0
  value="#[fg=colour208]${value%% }°C"
  printf "%b" "$value"
} # }}}
weather_tmux_sb_worker() { # @@ # {{{
  local value=
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
  local STORAGE_FILE="$MEM_KEEP/weather-tmux.log"
  if [[ -e $STORAGE_FILE ]]; then # {{{
    WEATHER_INFO=()
    local line=
    while read line; do
      WEATHER_INFO+=("$line")
    done < <(cat $STORAGE_FILE)
    [[ ! -z ${WEATHER_INFO[0]} && $now -ge $(( ${WEATHER_INFO[0]} + $((7 * 24 * 60 * 60)) )) ]] && WEATHER_INFO=()
    [[ -z ${WEATHER_INFO[0]} ]] && WEATHER_INFO[0]="$now"
  fi # }}}
  local err=false
  if [[ -z $WEATHER_API_KEY ]]; then
    ERR "Error: No API key"
    return 1
  fi
  while ! $err; do # {{{
    if [[ -z ${WEATHER_INFO[1]} ]]; then
      local loc=$(curl --silent --connect-timeout 2 http://ip-api.com/csv)
      if [[ $? != 0 || -z $loc ]]; then # {{{
        ERR "Error when acquiring location"
        err=true
        break
      fi # }}}
      WEATHER_INFO[1]=$(echo "$loc" | cut -d , -f 8)
      WEATHER_INFO[2]=$(echo "$loc" | cut -d , -f 9)
      [[ ${WEATHER_INFO[1]} == 51.* && ${WEATHER_INFO[2]} == 16.* ]] && WEATHER_INFO[1]=51.099 && WEATHER_INFO[2]=17.039
    fi
    local weather="$(curl --silent --connect-timeout 2 "http://api.openweathermap.org/data/2.5/weather?lat=${WEATHER_INFO[1]}&lon=${WEATHER_INFO[2]}&APPID=$WEATHER_API_KEY&units=metric")"
    if [[ $? == 0 && ! -z $weather && $(echo $weather | jq .cod) == 200 ]]; then
      WEATHER_INFO[0]="$now"
      WEATHER_INFO[3]="$(echo "$weather" | jq .main.temp  | cut -d . -f 1)"
      WEATHER_INFO[4]="$(echo "$weather" | jq .wind.speed | awk '{print int($1*3.6+0.5)}')"
      WEATHER_INFO[5]="$(echo "$weather" | jq .wind.deg   | cut -d . -f 1)"
      WEATHER_INFO[6]="$(echo "$weather" | jq .weather[0].id)"
    else
      ERR "Error when acquiring forecast"
      err=true
      break
    fi
    { echo  "${WEATHER_INFO[0]}"
      echo  "${WEATHER_INFO[1]}"
      echo  "${WEATHER_INFO[2]}"
      echo  "${WEATHER_INFO[3]}"
      echo  "${WEATHER_INFO[4]}"
      echo  "${WEATHER_INFO[5]}"
      echo  "${WEATHER_INFO[6]}"
    } >$STORAGE_FILE
    break
  done # }}}
  if ! $err; then
    value="$(printf "%s %s #[fg=colour72]%s" "$(weather_icon "${WEATHER_INFO[6]}")" "$(weather_temp_color "${WEATHER_INFO[3]}")" "$(weather_wind_arrow ${WEATHER_INFO[5]} ${WEATHER_INFO[4]})")"
    weather_interval="${TMUX_SB_WEATHER_DELTA:-$((1 * 60 * 60))}"
  else
    value="#[fg=colour124]$(get-unicode-char 'icon-err')☁️ #[fg=default,none]"
    weather_interval=60
  fi
  unset weather_icon weather_wind_arrow weather_temp_color
  printf "%b" "$value"
  $err && return 1
  return 0
} # }}}

saveData() { # {{{
  local fTmp=$info_file.tmp now=$1
  (
    echo "declare -A data"
    echo "data[$markLU]=\"$now\" # $(date +$DATE_FMT -d @$now)"
    for i in $(printf '%s\n' ${!data[*]} | sort); do
      [[ ${data[$i]} == "$markIgn" || $i == "$markLU" ]] && continue
      echo "data[$i]=\"${data[$i]}\""
    done
  ) >$fTmp
  $lock mv $fTmp $info_file 2>/dev/null
} # }}}
isIgnored() { # {{{
  [[ $(vGet $1 ignored false) == 'true' ]]
} # }}}
tryToDo() { # {{{
  local var=$1 isFunction=false
  if declare -f ${var}_tmux_sb_worker &>/dev/null; then
    isFunction=true
  elif [[ -z "$(vGet $var tmux_sb_worker)" ]]; then
    local found=false i=
    for i in $BASH_PROFILES_FULL; do
      if [[ -e $i/aliases ]] && $i/aliases __util_tmux_sb_worker --defined $var; then
        vSet $var tmux_sb_worker "'$i/aliases __util_tmux_sb_worker $var'"
        found=true
        break
      fi
    done
    if ! $found; then
      WRN "${var}_tmux_sb_worker is missing"
      vSet $var ignored true
      return 1
    fi
  fi
  local last=$(vGet $var last 0) interval=$(vGet $var interval)
  if [[ -z $interval ]]; then
    WRN "Interval for $var (\$${var}_interval) not defined, setting to default interval of $default_interval"
    vSet $var interval $default_interval
    interval=$default_interval
  fi
  (( now > last + interval )) || return 1
  if $isFunction; then
    eval ${var}_tmux_sb_worker 2>$err_dev
  else
    eval "$(vGet $var tmux_sb_worker)" 2>$err_dev
  fi
  vSet $var last $now
} # }}}
fromAliases() { # {{{
  local f=$1 justSource=false
  [[ $1 == '--source' ]] && shift && f=$1 && justSource=true
  ! declare -F $f >/dev/null 2>&1 && source <($ALIASES --source $f)
  $justSource && return 0
  "$@"
} # }}}
worker() { # {{{
  source "$UNICODE_EXTRA_CHARS_FILE"
  # fromAliases --source get-unicode-char
  local fTmpSingle=$info_file.single.tmp
  local i= now=
  declare -A data
  for i in $TMUX_STATUS_RIGHT_EXTRA_SORTED; do
    data[$i]=""
  done
  INF - "list: $TMUX_STATUS_RIGHT_EXTRA_SORTED"
  while true; do
    now=${EPOCHSECONDS:-$(epochSeconds)}
    [[ -e $info_file ]] && source <($lock cat $info_file)
    for i in $TMUX_STATUS_RIGHT_EXTRA_SORTED; do
      [[ ${data[$i]} == "$markIgn" ]] && DBG "$i: ignored" && continue
      TRC "$i: checking"
      if tryToDo $i >$fTmpSingle; then
        data[$i]="$(cat $fTmpSingle)"
        INF "$i: updated"
      elif isIgnored $i; then
        DBG "$i: ignored"
        data[$i]="$markIgn"
      else
        DBG "$i: skipped"
      fi
    done
    saveData $now
    if $verbose; then
      echo "---"
      cat $info_file
      echo
    fi
    sleep $default_sleep
  done
} # }}}

import-module dbg
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  ---tmux) err_dev="/dev/null";;
  -v) verbose=true;;
  -s) verbose=false; log_level=W;;
  -f) info_file=$2; shift;;
  *)  break;;
  esac; shift
done # }}}
lock= fLockFile=${info_file}.lock
type flock >/dev/null 2>&1 && lock="flock $fLockFile"
case $1 in # {{{
--test) # {{{
  shift
  xv=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -xv) xv=true;;
    *)   break;;
    esac; shift
  done # }}}
  [[ -z $1 ]] && echoe -w "Worker is missing" && exit 1
  i=$1
  f="${i}_tmux_sb_worker" && shift
  ! declare -f $f &>/dev/null && echoe -w "Function [$f] not defined" && exit 1
  now=${EPOCHSECONDS:-$(epochSeconds)}
  DBG --init --ts-add --prefix D
  source "$UNICODE_EXTRA_CHARS_FILE"
  fromAliases --source get-unicode-char
  $xv && set -xv
  w="$($f $@)"; err=$?
  $xv && set +xv
  [[ $err == 0 ]] || echoe -w "Error when invoking $f"
  echo "data[$i]=\"$w\""
  DBG --deinit;; # }}}
--get-all-values) # {{{
  [[ -e $info_file ]] || { echo "declare -A data"; exit 1; }
  $lock cat $info_file;; # }}}
--get-value) # {{{
  [[ -e $info_file ]] || exit 1
  source <($lock cat $info_file)
  shift
  for i; do
    echo "${data[$i]}"
  done;; # }}}
--list) # {{{
  declare -F | awk '/_tmux_sb_worker/{sub(/_tmux_sb_worker/,"",$3); print $3}';; # }}}
--tmux | --kill) # {{{
  ps a | awk '/tmux-sb-worker\.sh ---tmux/ {print $1}' | xargs -r kill -9 2>/dev/null
  if [[ $1 == '--tmux' ]]; then
    $0 ---tmux -s --out "${info_file}.log" --prefix &
    disown
  fi;; # }}}
--update) # {{{
  [[ -e $info_file ]] || exit 0
  i=$2; shift 2
  [[ ! -z $i ]] || exit 1
  source "$UNICODE_EXTRA_CHARS_FILE"
  now=${EPOCHSECONDS:-$(epochSeconds)}
  f="${i}_tmux_sb_worker"
  ! declare -f $f &>/dev/null && echoe -w "Function [$f] not defined" && exit 1
  w="$($f $@)" || echoe -w "Error when invoking $f"
  source <($lock cat $info_file)
  data[$i]="$w"
  saveData $now;; # }}}
*) # {{{
  DBG --init --ts=show --ts-abs $log_level $@
  INF - "Start: $(date +"$DATE_FMT")"
  worker
  DBG --deinit;; # }}}
esac # }}}

