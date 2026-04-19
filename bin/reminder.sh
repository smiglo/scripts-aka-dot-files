#!/usr/bin/env bash
# vim: fdl=0

getMode() { # {{{
  local mode=
  case $1 in
  a  | add       | -a | --add)    mode="add";;
  c  | clean     | -c | --clean)  mode="clean";;
  cd | countdown | -cd)           mode="countdown";;
  CD | CountDown | -CD)           mode="CountDown";;
  e  | edit      | -e | --edit)   mode="edit";;
  l  | list      | -l | --list)   mode="list";;
  load)                           mode="load";;
  monitor)                        mode="monitor";;
  n  | next      | -n | --next)   mode="next";;
  esac
  echo "$mode"
} # }}}

reminderFile="${REMINDER_FILE:-$REMINDER_PATH/reminders.no-git.dat}"

if [[ $1 == '@@' ]]; then # @@:new # {{{
  args=( ${@: 3} ) num=${#args[*]} mode=
  for ((i = 0; i < num; ++i )); do # {{{
    mode="$(getMode ${args[i]})"
    [[ ! -z $mode ]] && break
  done # }}}
  if [[ ! -z $mode ]]; then # {{{
    case $mode in
    add) # {{{
      case $((num - i)) in
      1) echo "TIME DATE.TIME DATE_FMT 10:00 MMDD.HHMM DD.HHMM";;
      2) echo "INFO DESCRIPTION";;
      esac;; # }}}
    clean) # {{{
      echo "--all -n --next"
      while read _ _ entry; do
        echo "$entry"
      done <$reminderFile
      echo "TS";; # }}}
    countdown) # {{{
      case $2 in
      -l | --loop) echo "0 120 60 300 inf -";;
      *) echo "-l --loop i - --err-on-key";;
      esac;; # }}}
    CountDown) # {{{
      echo "---";; # }}}
    list) # {{{
      echo "--add-ts"
      echo "--pretty --no-pretty"
      echo "-e --expired -t --today -f --full";; # }}}
    load) # {{{
      case $2 in
      -f | --file) echo "@@-f";;
      --n-days) echo "7 14 30";;
      *) echo "-f --file --n-days -v -vv -vvv --v-add --json";;
      esac;; # }}}
    next) # {{{
      echo "---";; # }}}
    monitor) # {{{
      echo "--tmux --kill -";; # }}}
    esac # }}}
  else # {{{
    echo "add clean edit list load next"
    echo "countdown CountDown"
    echo "monitor"
    echo "-s -v"
  fi # }}}
  exit 0
fi # }}}

import-module time-tools echor dbg

getDefaultParams() { # {{{
  local mode="$1"
  [[ ! -z $mode ]] || return 0
  local -n params="REMINDER_DEFAULT_PARAMS_${mode^^}"
  [[ ! -z $params ]] && echo "$params" && return 0
  case $mode in
  countdown) echo "--loop 120";;
  esac
} # }}}
buildEntry() { # {{{
  local ts=$1 info=${2:--}
  echo -e "$ts\t$(date +$DATE_FMT -d@$ts)\t\t$info"
} # }}}
convertTime() { # {{{
  local ts="$1"
  time2s --is-hms "$ts" && ts="$(time2s $ts)"
  ts="$(time2s "${ts/./ }" -o abs-s 2>/dev/null)"
  $narrowToMinutes && ts=$((ts / 60 * 60))
  echo "$ts"
} # }}}
dummy-launcher() { # {{{
  local ts="$1" info="$2"
  echoe -c "launching for '$info' at $ts"
} # }}}
getNext() { # {{{
  [[ -e $reminderFile ]] || return 1
  local tomorrow="$(time2s "tomorrow 0:0" -o abs-s)" ts= info=
  sed -e '/^#/d' -e '/^\s*$/d' $reminderFile \
  | sort -k1,1n \
  | ( while IFS=$'\t' read -r ts _ info; do
      (( ts > now )) || continue
      (( ts < tomorrow )) || break
      echo -e "$ts\t$info"
      exit 0
    done; exit 1; )
  return $?
} # }}}
schedule() { # {{{
  local tsOrig="$1" info="$2"
  ts=$(convertTime "$tsOrig")
  [[ ! -z $ts && $ts != 0 ]] || eval $(die "cannot create entry from $tsOrig, $info")
  (( ts > now )) || { echoe $verbose -c "skipping - expired: '$tsOrig, $info'"; return 1; }
  if [[ " $tsList " == *" $ts "* ]]; then
    echoe $verbose -c "overriding: '$tsOrig, $info' on '$(awk '/^'"$ts"'/ {print}' $reminderFile | tr -s '\t' | cut -f3- | xargs)'"
    sed -i '/^'"$ts"'/d' $reminderFile
  fi
  entry="$(buildEntry "$ts" "$info")"
  echoe $verbose -c "adding: '$entry'"
  echo -e "$entry"
} # }}}

scheduleFile="$REMINDER_SCHEDULE_FILE"
verbose=${REMINDER_DEFAULT_VERBOSE:-false}
defaultMode="${REMINDER_DEFAULT_MODE:-countdown}"
monitorLogLevel=${REMINDER_MONITOR_LOG_LEVEL:-I}
monitorLogFile="${REMINDER_MONITOR_LOG_FILE:-$BASHRC_RUNTIME_PATH/reminder-monitor.log}"
reminderLauncher="$REMINDER_LAUNCHER"
narrowToMinutes=${REMINDER_NARROW_TO_MINUTES:-true}
mode=
now=$EPOCHSECONDS
tzOrig=$TZ
[[ -e $RUNTIME_PATH/date.tz ]] && export TZ=$(cat $RUNTIME_PATH/date.tz)

case $1 in # {{{
lfe) shift; set -- list -fe "$@";;
lf)  shift; set -- list -f  "$@";;
esac # }}}

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -s) verbose=false;;
  -v) verbose=true;;
  *)  mode="$(getMode $1)"; [[ ! -z $mode ]] && shift; break
  esac; shift
done # }}}

tmpFile="$TMP_MEM_PATH/${reminderFile##*/}.tmp"
[[ -e "${reminderFile%/*}" ]] || mkdir -p "${reminderFile%/*}"

if [[ -z $mode ]]; then # {{{
  if [[ ! -t 0 || ! -z $@ ]]; then
    mode="add"
  else
    mode=$defaultMode
    set -- $(getDefaultParams "$mode")
  fi
fi # }}}

export REMINDER_DEFAULT_VERBOSE=$verbose

case $mode in
add) # {{{
  touch $reminderFile
  tsList=" $(awk '!/^#|^\s*$/ { print $1 }' $reminderFile | tr '\n' ' ') "
  rm -f $tmpFile
  if [[ -t 0 || ! -z $1 ]]; then
    tsOrig="$1" info="$2"
    [[ ! -z $tsOrig ]] || die -s=!$verbose "missing entry: [date.]time [info]"
    schedule "$tsOrig" "$info" >$tmpFile
  elif [[ ! -t 0 ]]; then
    cat - \
    | while read -r tsOrig info; do
        [[ ! -z $tsOrig ]] || eval $(die -c -s=!$verbose  "missing entry: [date.]time [info]")
        schedule "$tsOrig" "$info"
    done >$tmpFile
  fi
  if [[ -e $tmpFile ]]; then
    [[ -e $reminderFile ]] && cat $reminderFile >>$tmpFile
    sort -k1,1n $tmpFile >$reminderFile
  fi;; # }}}
clean) # {{{
  [[ -e $reminderFile ]] || exit 0
  tsToClean=
  rm -f $tmpFile
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --all) # {{{
      echo >$reminderFile
      exit 0;; # }}}
    -n | --next) # {{{
      IFS=$'\t' read tsToClean _ < <(getNext)
      [[ ! -z $tsToClean ]] || exit 0;; # }}}
    *) # {{{
      tsToClean="$(awk '/'"$1"'/ {print $1}' $reminderFile | head -n1)";; # }}}
    esac; shift
  done # }}}
  cp $reminderFile $tmpFile
  while IFS=$'\t' read -r ts tsNice info; do
    if [[ -z $tsToClean ]]; then
      (( ts > now ))
    else
      (( ts != tsToClean ))
    fi || { echoe $verbose -c "removing: '$tsNice, $info'"; continue; }
    buildEntry "$ts" "$info"
  done <$tmpFile \
  | sort -k1,1n >$reminderFile;; # }}}
countdown) # {{{
  [[ -e $reminderFile ]] || exit 0
  loopMethod=inf errOnKey=false showPrevious=false
  eval set -- $(compl-canonicalize -l "loop:" -s "l:" -- "$@")
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --err-on-key) errOnKey=true;;
    -l | --loop) loopMethod=$2; shift;;
    -) loopMethod=;;
    i) loopMethod="inf";;
    [0-9]*) loopMethod=$1;;
    esac; shift
  done # }}}
  case $loopMethod in # {{{
  '') loopMethod=0;;
  inf | - | infinity) loopMethod="infinity";;
  [0-9]*);;
  *) loopMethod=120;;
  esac # }}}
  nextUpdateTS=$now nextUpdateInterval=15
  keyPressed=false
  IFS=$'\t' read -r ts info < <(getNext)
  (( $? == 0 )) || exit 0
  trap "tput rc; tput cnorm; echo; exit 0;" INT
  tput sc; tput civis
  declare -Ax colorMap=( ["step1"]="ok" ["step2"]="info" ["step3"]="imp" ["step4"]="red" ["at"]="gray" ["cancelled"]="gray")
  for ((now = EPOCHSECONDS, diff = ts - now; diff >= 0; now = EPOCHSECONDS, diff = ts - now)); do # {{{
    sleep-precise -s
    c="step1"
    time="$(time2s --to-HMS $diff)"
    if false; then :
    elif (( diff <   2 )); then c="at"; time=$(date +%H:%M:%S -d@$ts)
    elif (( diff <  30 )); then c="step4"
    elif (( diff <  60 )); then c="step3"
    elif (( diff < 120 )); then c="step2"
    fi
    tput rc; printfc --no-nl "%$c:$time : %info:%s at %ts:$(date +%H:%M -d@$ts)   " "$info"
    case $loopMethod in # {{{
    0) break;;
    infinity);;
    *) (( diff <= $loopMethod )) || break;;
    esac # }}}
    read -s -n1 -t $(sleep-precise -i 1) key && case ${key,,} in q) keyPressed=true; break;; esac
    (( diff > 15 )) || nextUpdateTS=0
    if (( now - nextUpdateTS >= nextUpdateInterval )); then # {{{
      IFS=$'\t' read -r tsNew infoNew < <(getNext)
      if (( $? != 0 )); then # {{{
        tput rc; printfc --no-nl "%cancelled:$time : %info:%s at %ts:$(date +%H:%M -d@$ts)   " "$info"
        break
      fi # }}}
      if (( tsNew != ts )); then # {{{
        (( diff > 1 )) || break
        tput rc; tput el
        if $showPrevious; then # {{{
          printfc --no-nl "%cancelled:$time : %info:%s at %ts:$(date +%H:%M -d@$ts)   " "$info"; echo
          tput sc
        fi # }}}
        ts=$tsNew
      fi # }}}
      info="$infoNew"
      nextUpdateTS=$now
    fi # }}}
  done # }}}
  tput rc; tput cnorm; echo
  $errOnKey && $keyPressed && exit 1
  exit 0;; # }}}
CountDown) # {{{
  waitTime="10x3"
  source $UNICODE_EXTRA_CHARS_FILE
  dots=${UNICODE_EXTRA_CHARS[progress-dots]} dotI=$(( RANDOM % ${#dots} ))
  tput sc; tput civis
  while true; do # {{{
    if read ts info < <(getNext); then # {{{
      tput rc; tput cnorm; tput el
      $0 countdown --loop infinity --err-on-key || break
      tput sc; tput civis
      continue
    fi # }}}
    for (( i=0; i <= ${waitTime%x*}; ++i )); do # {{{
      tput rc; cl --no-nl gray "[${dots:$dotI:1}]"; dotI=$(( RANDOM % ${#dots} ))
      read -s -n1 -t${waitTime#*x} key && case ${key,,} in q) break 2;; '') continue 2;; esac
    done # }}}
  done # }}}
  tput rc; tput cnorm; echo
  $0 clean;; # }}}
edit) # {{{
  rm -f $tmpFile
  while IFS=$'\t' read -r ts_s ts info; do
    (( ts_s > now )) || echo -n "# "
    echo -e "$(date +"%Y.%m.%d %H:%M" -d @$(time2s $ts -o abs-s))\t\t$info"
  done <$reminderFile >$tmpFile
  vim $tmpFile || exit 0
  sed -e '/^#/d' -e '/^\s*$/d' $tmpFile \
  | while IFS=$'\t' read -r ts info; do
    ts="${ts//[.:]}00"
    ts="${ts/ /-}"
    entry="$(buildEntry "$(convertTime "$ts")" "$info")"
    echoe $verbose -c "updating: '$entry'"
    echo "$entry"
  done \
  | sort -k1,1n >$reminderFile;; # }}}
list) # {{{
  [[ -e $reminderFile ]] || exit 0
  today="$(time2s "today 0:0" -o abs-s)" tomorrow="$(time2s "tomorrow 0:0" -o abs-s)"
  expired=false printAll=false addTS=false prettyPrint=
  eval set -- "$(compl-canonicalize -l "add-ts,expired,pretty,no-pretty,full,today" -s "eft" -- "$@")"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --add-ts) addTS=true;;
    -e | --expired) expired=true;;
    --pretty) prettyPrint=true;;
    --no-pretty) prettyPrint=false;;
    -f | --full) printAll=true;;
    -t | --today) printAll=false;;
    esac; shift
  done # }}}
  weekDay=
  declare Days=("sun" "mon" "tue" "wed" "thu" "fri" "sat")
  [[ -t 1 ]] || [[ ! -z $prettyPrint ]] || prettyPrint=false
  [[ -z $prettyPrint ]] && prettyPrint=true
  icon_ok="$(get-unicode-char icon-ok)" icon_ex="$(get-unicode-char icon-err)"
  $prettyPrint || { colorsOn=false; icon_ok="+"; icon_ex="-"; }
  while IFS=$'\t' read -r ts tsNice info; do
    $expired || (( ts > now )) || continue
    $printAll || (( ts > today )) || continue
    $printAll || (( ts < tomorrow )) || break
    if [[ $tsNice =~ ^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})$ ]]; then # {{{
      tsNice="${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
      date="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
      if $printAll && $prettyPrint; then # {{{
        wd=$(date +%w -d "$date")
        [[ $weekDay == $wd ]] || { echo "$(cl gray "# ${Days[$wd]} / $date")"; weekDay=$wd; }
      fi # }}}
      tsNice="${tsNice%:00}"
    fi # }}}
    if $expired; then # {{{
      (( ts <= now )) && cl --no-nl err "$icon_ex " || cl --no-nl ok "$icon_ok "
    fi # }}}
    echo "$(cl ts "$tsNice")$($addTS && cl gray " $ts") $(cl info "$info")"
  done <$reminderFile;; # }}}
load) # {{{
  declare -A Days=([sun]=0 [mon]=1 [tue]=2 [wed]=3 [thu]=4 [fri]=5 [sat]=6)
  daysInAdvance=7 verbose=false verboseAddParam="-s" dbgCond=false useJson= vLevel=0
  eval set -- "$(compl-canonicalize -l "v-add,json,file:,n-days:" -s "vf:" -- "$@")"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -v) (( ++vLevel ));;
    --v-add) verboseAddParam="-v";;
    --json) useJson=true;;
    -f | --file) scheduleFile="$2"; shift;;
    --n-days) daysInAdvance="$2"; shift;;
    esac; shift
  done # }}}
  (( vLevel >= 1 )) && { verbose=true; }
  (( vLevel >= 2 )) && { verboseAddParam="-v"; }
  (( vLevel >= 3 )) && { dbgCond=true; }
  if [[ -z $scheduleFile ]]; then
    if [[ -t 0 ]]; then
      scheduleFile="$REMINDER_PATH/schedule.json"; useJson=true
      [[ -e $scheduleFile ]] || { scheduleFile="$REMINDER_PATH/schedule.txt"; useJson=false; }
    else
     scheduleFile="/dev/stdin"
     [[ -z $useJson ]] && useJson=false
    fi
  elif [[ -z $useJson ]]; then
    useJson=true
    [[ $scheduleFile == *.json ]] || useJson=false
  fi
  [[ -e $scheduleFile ]] || die "schedule file '$scheduleFile' does not exits"
  [[ -s $scheduleFile ]] || die "nothing to schedule"
  declare -a dates=()
  for ((i = 0; i <= daysInAdvance; ++i)); do dates+=( "$(date +"%Y-%m-%d %w" -d "+$i day")" ); done
  if $useJson; then
      jq -r '
        .[] | [
          .time,
          (.days | if type == "array" then join(",") else . end),
          .description // "-",
          .condition // "-",
          .disabled // false
        ] | @tsv' $scheduleFile
    else
      sed -e '/^#/d' -e '/^\s*$/d' $scheduleFile
    fi \
  | while IFS=$'\t' read -r time days info cond disabled; do
    $disabled && continue
    echoe $verbose -c "parsing entry: '$time' on '$days' with '$info', '$cond', $disabled"
    info="${info:--}"
    cond="${cond:--}"
    daysFor=
    days=${days,,}
    case $days in # {{{
    all  | week)  daysFor="$(seq 0 6)";;
    work | wweek) daysFor="$(seq 1 5)";;
    weekend)      daysFor="6 0";;
    *-*)          daysFor="$(seq ${Days[${days%-*}]} ${Days[${days#*-}]})";;
    *,*)          for dd in ${days//,/ }; do daysFor+="${Days[$dd]} "; done;;
    *)            daysFor=${Days[$days]};;
    esac # }}}
    echoe $verbose -c "* applies for -> '$(echo $daysFor)'"
    for d in $daysFor; do # {{{
      for ((i = 0; i <= daysInAdvance; ++i)); do
        read aDate weekDay <<<${dates[$i]}
        (( $d == $weekDay )) || continue
        if [[ $cond != '-' ]]; then # {{{
          if [[ $cond =~ script(:(.*))? ]]; then
            scriptFile=${BASH_REMATCH[2]}
            [[ -z $scriptFile || $scriptFile == "-" ]] && scriptFile="reminder-checker.sh"
            is-installed $scriptFile || eval $(die -b2 "* script file not found: $scriptFile")
            (
              $dbgCond && set -xv
              $scriptFile -t $time -d-for "$daysFor" -i "$info" --date $aDate
            )
          else
            eval "($dbgCond && set -xv; "$cond")"
          fi || { echoe $verbose -c "* condition '$cond' not meet for $d, ($aDate, $weekDay), skipping"; continue; }
        fi # }}}
        echo -e "$aDate.$time\t$info"
      done
    done # }}}
  done \
  | $0 $verboseAddParam add
  $0 $verboseAddParam clean;; # }}}
monitor) # {{{
  handleKeys=true
  [[ -z $1 ]] && set -- --tmux
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -) # {{{
      monitorLogFile="/dev/stderr"
      monitorLogLevel="D";; # }}}
    --tmux | --kill) # {{{
      ps a | awk '/reminder.sh monitor ---tmux/ {print $1}' | xargs -r kill -9 2>/dev/null
      if [[ $1 == '--tmux' ]]; then # {{{
        $0 monitor ---tmux &
        disown
      fi # }}}
      exit 0;; # }}}
    ---tmux) # {{{
      handleKeys=false;; # }}}
    esac; shift
  done # }}}
  [[ -f $monitorLogFile ]] && rm -f $monitorLogFile
  DBG --init $monitorLogLevel --ts=show --ts-abs --out "$monitorLogFile" --prefix
  declare -A Sleeps=( [no-file]=60 [no-next]=30 [too-far]=15 [close-enough]=2 )
  tmuxStatusInterval=$(tmux show-options -gv status-interval 2>/dev/null)
  [[ -z $tmuxStatusInterval ]] && tmuxStatusInterval=15
  trap "tmux set-option -g status-interval $tmuxStatusInterval >/dev/null 2>&1;" INT
  heartbeatTS=$EPOCHSECONDS heartbeatInterval=$((5 * 60))
  tooFarTS=0 tooFarInterval=$((5 * 60))
  minuteBefore=60
  updateWorker=true
  [[ -z $TMUX_SB_WORKER || ! -x $TMUX_SB_WORKER ]] && updateWorker=false
  INF - "monitor thread, pid: $$"
  INF "sleeps: $(declare -p Sleeps), heartbeat: ${heartbeatInterval}s"
  declare -A infoMsg=()
  while true; do # {{{
    sleep-precise -s
    now=$EPOCHSECONDS timeout=1
    (( now - heartbeatTS < heartbeatInterval )) || { DBG - "heartbeat after $((now - heartbeatTS))s"; heartbeatTS=$now; }
    TZ=$tzOrig
    [[ -e $RUNTIME_PATH/date.tz ]] && export TZ=$(cat $RUNTIME_PATH/date.tz)
    while true; do # {{{
      [[ -e $reminderFile ]] || { DBG "no-file"; timeout=${Sleeps[no-file]}; break; }
      IFS=$'\t' read ts info < <(getNext)
      (( $? == 0 )) || { DBG "no-next"; timeout=${Sleeps[no-next]}; break; }
      key="$ts:$info"
      [[ ! -z ${infoMsg[$key]} ]] || { INF - "[$ts] got that one: $(date +"$DATE_FMT" -d@$ts), $info"; infoMsg[$key]=true; }
      diff=$((ts - now))
      if (( diff > minuteBefore )); then # {{{
        (( now - tooFarTS < tooFarInterval )) || { tooFarTS=$now; DBG "[$ts] too-far: ${diff}s"; }
        if (( diff <= 3 * minuteBefore )) && $updateWorker; then
          $TMUX_SB_WORKER --update reminder -ts $ts
        fi
        (( diff > minuteBefore + ${Sleeps[too-far]} )) && timeout=${Sleeps[too-far]} || timeout=$(( diff - minuteBefore ))
        break # }}}
      elif $updateWorker; then # {{{
        [[ ! -z ${infoMsg[$key:interval]} ]] || { tmux set-option -g status-interval 1 >/dev/null 2>&1; infoMsg[$key:interval]=true; }
        $TMUX_SB_WORKER --update reminder -ts $ts
      fi # }}}
      if [[ -z ${infoMsg[$key:close]} ]]; then # {{{
        INF "[$ts] close-enough: ${diff}s"
        infoMsg[$key:close]=true
      fi # }}}
      DBG "[$ts] close-enough: ${diff}s"
      (( diff < 30 )) || { timeout=${Sleeps[close-enough]}; break; }
      (( diff < 2 )) || { break; }
      DBG "[$ts] firing up in ${diff}s"
      while (( ts - EPOCHSECONDS > 0 )); do sleep 0.2; done
      INF - "[$ts] fired at $EPOCHSECONDS, $info"
      if [[ ! -z $reminderLauncher ]] && is-installed $reminderLauncher; then # {{{
        $reminderLauncher "$ts" "$info"
      fi # }}}
      if $updateWorker; then # {{{
        $TMUX_SB_WORKER --update reminder
        [[ ! -z ${infoMsg[$key:interval]} ]] && ( sleep 1; tmux set-option -g status-interval $tmuxStatusInterval >/dev/null 2>&1 ) &
      fi # }}}
      unset infoMsg[$key] infoMsg[$key:close] infoMsg[$key:interval]
      break
    done # }}}
    if $handleKeys; then # {{{
      read -s -n1 -t $(sleep-precise -i $timeout) key && case ${key,,} in q) break;; esac # }}}
    else # {{{
      sleep-precise $timeout
    fi # }}}
  done # }}}
  tmux set-option -g status-interval $tmuxStatusInterval >/dev/null 2>&1
  INF "bye"
  DBG --deinit;; # }}}
next) # {{{
  getNext
  exit $?;; # }}}
esac

