#!/usr/bin/env bash
# vim: fdl=0

bell_cnt=
bell_sleep=
margin='A'
loop=
log_file="$BASHRC_RUNTIME_PATH/at.log"
data_file="$BASHRC_RUNTIME_PATH/at.dat"
dbg_level="D"
bell_cmd=
days=
declare -a days_active=( # {{{
  [0]=false
  [1]=true
  [2]=true
  [3]=true
  [4]=true
  [5]=true
  [6]=false
) # }}}
declare -a days_name=( # {{{
  [0]="sun"
  [1]="mon"
  [2]="tue"
  [3]="wed"
  [4]="thu"
  [5]="fri"
  [6]="sat"
) # }}}

if [[ $1 == '@@' ]]; then # {{{
  case $3 in
  -c) echo "1 3 5";;
  -d) echo "1 10 15";;
  -m) echo "10 15 30 A";;
  --cmd) echo "CMD";;
  --days) # {{{
    echo "mon tue wed thu fri sat sun mon-fri wed,fri"
    echo "1 2 3 4 5 6 7 1-5 3,5"
    echo "every work"
    ;; # }}}
  *)
    echo "-c -d -m --cmd --popup --days --list -k --kill --load --log-tail --log-cat --loop -l --no-loop --list"
    echo "12:00 15m";;
  esac
  exit 0
fi # }}}

getNow() { # {{{{
  echo ${EPOCHSECONDS:-$(epochSeconds)}
} # }}}
timeToWakeUp() { # {{{
  local at=$1
  local day=$(date +%w)
  local at_s=$(date +%s -d "$at") now_s=$(getNow)
  if [[ $at_s -le $now_s ]] || ! ${days_active[day]}; then
    day=$(((day + 1) % 7))
    while ! ${days_active[day]}; do day=$(( (day + 1) % 7)); done
    at_s=$(date +%s -d "$at ${days_name[day]}")
    [[ $at_s -gt $now_s ]] || at_s=$(date +%s -d "$at next week")
  fi
  local m=$margin
  [[ $m == 'A' ]] && m=$((bell_cnt * bell_sleep))
  echo "$((at_s - now_s - m)) $((at_s - m))"
} # }}}
wakeUpThread() { # {{{
  local at=$1 wake_in= wake_at= now_s= delta=30 sleep_time_1=$((60 * 60)) sleep_time_2=$((5 * 60))
  dbg --init -v=$dbg_level --ts-abs --out=$log_file --name="at[$at/$BASHPID]" --id=show
  dbg I "cfg: ($bell_cnt,$bell_sleep,$margin,$loop,$days)"
  while true; do
    read wake_in wake_at <<<$(timeToWakeUp $at)
    dbg I "next bell in ${wake_in}s (${wake_at}s), sleep at $(getNow)s"
    for sleep_time in $sleep_time_1 $sleep_time_2; do
      while true; do
        [[ $(getNow) -lt $((wake_at - sleep_time - 60)) ]] || break
        sleep $sleep_time
        dbg D "hearbeat (every ${sleep_time}s)..."
      done
    done
    if [[ $(getNow) -lt $((wake_at - 5)) ]]; then
      read wake_in wake_at <<<$(timeToWakeUp $at)
      dbg D "reaching to bell: ${wake_in}s (${wake_at}s)"
      sleep $wake_in
    fi
    now_s=$(getNow)
    dbg I "woken up at ${now_s}s : ${wake_at}s"
    if [[ $now_s -lt $((wake_at + delta)) ]]; then
      [[ $now_s -lt $((wake_at + 10)) ]] || dbg W "a little to late"
      for ((i=0; i<bell_cnt; i++)); do
        sleep-precise -s
        dbg I "bell"
        $bell_cmd >/dev/null 2>&1
        sleep-precise $bell_sleep
      done
    else
      dbg E "far too late by $((now_s - wake_at - delta))s, skipping"
    fi
    $loop || { dbg I "not in loop"; break; }
  done
  dbg I "bye"
  dbg --deinit
  sed -i -e '/'"^$BASHPID"' /d' $data_file
} # }}}

[[ -z $1 ]] && set -- --list
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -c) bell_cnt=$2; shift;;
  -d) bell_sleep=$2; shift;;
  -m) margin=$2; shift;;
  -l | --loop) loop=true;;
  --no-loop) loop=false;;
  --popup) # {{{
    bell_cmd="tmux-popup --title notifier eval echo \"\$(date +$TIME_FMT): $2\" # @C @-W"; shift
    [[ -z $bell_cnt ]] && bell_cnt=1
    [[ -z $bell_sleep ]] && bell_sleep=0;; # }}}
  --cmd) # {{{
    bell_cmd="$2"; shift
    [[ -z $bell_cnt ]] && bell_cnt=1
    [[ -z $bell_sleep ]] && bell_sleep=0;; # }}}
  --days) # {{{
    days="${2,,}"; shift
    days="$(echo "$days" | sed \
      -e 's/mon/1/g' \
      -e 's/tue/2/g' \
      -e 's/wed/3/g' \
      -e 's/thu/4/g' \
      -e 's/fri/5/g' \
      -e 's/sat/6/g'\
      -e 's/sun/0/g')"
    case $days in
    work)  days=$(seq 1 5);;
    every) days=$(seq 0 6);;
    *-*)   days=$(seq ${days%-*} ${days#*-}) ;;
    *,*)   days=${days//,/ };;
    [0-7]) days=$((days%7));;
    esac
    for d in ${!days_active[*]}; do days_active[$d]=false; done
    for d in $days; do days_active[$((d % 7))]=true; done
    [[ -z $loop ]] && loop=true;; # }}}
  --load) # {{{
    [[ -e $APPS_CFG_PATH/notifier/schedule.txt ]] || return 0
    list=$($0 --list)
    cat $APPS_CFG_PATH/notifier/schedule.txt | sed -e '/^#/d' -e '/^\s*$/d' | while read at tmp params; do
      echo "$list" | grep -q "^$at " && continue
      eval $0 $params $at
    done
    exit 0;; # }}}
  --log-cat) # {{{
    [[ -e $log_file ]] || die "no log file"
    cat $log_file
    exit 0;; # }}}
  --log-tail) # {{{
    tail -F $log_file
    exit 0;; # }}}
  -k | --list | --kill) # {{{
    [[ -s $data_file ]] || exit 0
    pids="$(ps -axo pid=)"
    list="$( \
      map_days() { # {{{
        for d in ${!days_active[*]}; do days_active[$d]=false; done
        case $days in
        *Mo*) days_active[1]=true;;&
        *Tu*) days_active[2]=true;;&
        *We*) days_active[3]=true;;&
        *Th*) days_active[4]=true;;&
        *Fr*) days_active[5]=true;;&
        *Sa*) days_active[6]=true;;&
        *Su*) days_active[0]=true;;&
        esac
      } # }}}
      cat $data_file \
      | while read -r pid at loop bell_cnt bell_sleep margin days; do
        map_days
        read wake_in wake_at <<<$(timeToWakeUp $at)
        line="$at / $wake_in $wake_at / $pid : ($bell_cnt,$bell_sleep,$([[ $margin != 'A' ]] && echo "$margin,")$($loop && echo "L,")$days)"
        if ! echo "$pids" | grep -q "^\s*$pid\s*$"; then
          echor "GONE: $line"
          sed -i -e '/'"^$pid"' /d' $data_file
          continue
        fi
        echo "$line"
      done | sort -k3,3n)"
    [[ ! -z $list ]] || exit 0
    case $1 in
    --list) # {{{
      echo "$list";; # }}}
    -k | --kill) # {{{
      echo "$list" \
      | fzf --prompt 'to stop> ' \
      | while read -r p; do
        pid=$(echo $p | awk '{print $6}')
        echor "killing: $(echo $p | awk '{print $1}') pid:$pid"
        kill-rec -9 $pid
        sed -i -e '/'"^$pid"' /d' $data_file
      done;; # }}}
    esac
    exit 0;; # }}}
  *) at="$1"; break;;
  esac; shift
done # }}}
case $at in # {{{
*:* | *:*:*);;
'') die "missing time";;
*)
  time2s --is-hms $at || die "invalid time format '$at'"
  at=$(time2s $at);;
esac # }}}
[[ -z $loop ]] && loop=false
if [[ -z $bell_cmd ]]; then # {{{
  if $IS_MAC; then
    bell_cmd="${NOTIFICATOR_CMD:-afplay /System/Library/Sounds/Funk.aiff}"
    [[ -z $bell_cnt ]] && bell_cnt=${NOTIFICATOR_CNT:-3}
    [[ -z $bell_sleep ]] && bell_sleep=${NOTIFICATOR_SLEEP:-2}
  else
    bell_cmd="${NOTIFICATOR_CMD:-echo 'bell'}"
    [[ -z $bell_cnt ]] && bell_cnt=${NOTIFICATOR_CNT:-2}
    [[ -z $bell_sleep ]] && bell_sleep=${NOTIFICATOR_SLEEP:-5}
  fi
fi # }}}
[[ $bell_cnt != 0 ]] || die "bell count is 0"
days= # {{{
for ((i=1;i<=7;i++)); do
  ${days_active[$((i%7))]} || continue
  n=${days_name[$((i%7))]:0:2}
  days+=${n^}
done # }}}
wakeUpThread $at &
pid=$!
disown $pid
echo "$pid $at $loop $bell_cnt $bell_sleep $margin $days" >>$data_file

