#!/usr/bin/env bash
# vim: fdl=0

_progress() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    [[ $2 == --shorts ]] && return 0
    local retVal=""
    case $3 in
    --cnt)     retVal="CNT";;
    --color | --end-color) retVal="COLOR";;
    --delay)   retVal="DELAY";;
    --end-msg) retVal="ON-SUCC:ON-FAIL";;
    --keys)    retVal="KEYS";;
    --mark-do) retVal="CMD";;
    --out)     retVal="/dev/stdout /dev/stderr";;
    --steps)   retVal="STEPS";;
    --msg | --end-msg) retVal="MSG";;
    --unmark)  retVal="--err=0 --err=1 --err=true --err=false -c";;
    *) # {{{
      retVal+=" --msg --end-msg --out --color --end-color --clean"
      retVal+=" --cmd --every-step --file-mod"
      retVal+=" --delay --cnt --steps --wait --wait-pv"
      retVal+=" --key --no-key --get-key --keys"
      retVal+=" --err --no-err --err-on-timeout"
      retVal+=" --mark --unmark --mark-do"
      retVal+=" --tmux --tmux-only"
      retVal+=" --dbg --dbg2"
      retVal+=" --tput --no-tput"
      retVal+=" --pv --dots --spin --random-text"
      retVal+=" MSG"
      ;; # }}}
    esac
    echo "$retVal"
    return 0
  fi # }}}
  # Init # {{{
  [[ -z $COff ]] && source $BASH_PATH/colors
  local cmd= delay= msg= cnt=0 every= steps= dbg= endTime=
  local method= rndTxt=
  local out="/dev/stderr" color="${CHLSearch}" end_message= end_color=
  local key= get_key=false pressed_key= extra_keys=
  local mark_file="$TMP_MEM_PATH/progress-$PROGRESS_PID.tmp" do_mark=false
  local tmux_progress=false tmux_entry="PR#$PROGRESS_PID" tmux_text="P[%s]" tmux_progress_only=false
  local report_error=true report_error_timeout=false retVal=0 useTput=
  local fileModFile= fileModSha=0
  if [[ -z $PROGRESS_DOTS_SUPPORTED ]]; then # {{{
    PROGRESS_DOTS_SUPPORTED=true
    if [[ ! -z $LC_CTYPE ]] && ! echo "$LC_CTYPE" | grep -q "UTF-8"; then
      PROGRESS_DOTS_SUPPORTED=false
    elif which locale >/dev/null 2>&1 && ! locale | grep -q "LC_CTYPE=.*UTF-8"; then
      PROGRESS_DOTS_SUPPORTED=false
    fi
  fi # }}}
  set -- $PROGRESS_PARAMS "$@"
  local argCnt=$#
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --cmd)        shift; cmd=$1;;
    --clean)      rm -f $TMP_MEM_PATH/progress-*; return 0;;
    --delay)      shift; delay=$1;;
    --msg)        shift; msg=$1;;
    --cnt)        shift; cnt=$1;;
    --out)        shift; out=$1;;
    --color)      shift; color=$1;;
    --end-color)  shift; end_color=$1;;
    --end-msg)    shift; end_message=$1;;
    --steps)      shift; steps=$1;;
    --file-mod) # {{{
                  shift
                  fileModFile=$1
                  fileModSha=0
                  [[ -e $fileModFile ]] && fileModSha="$(sha1sum $fileModFile | cut -d" " -f1)"
                  cmd='[[ -e '"$fileModFile"' && '"$fileModSha"' != $(sha1sum '"$fileModFile"' | cut -d" " -f1) ]]';; # }}}
    --no-err)     report_error=false;;
    --err)        report_error=true;;
    --err-on-timeout) report_error=false; report_error_timeout=true;;
    --key)        key=true; report_error=false;;
    --no-key)     key=false;;
    --keys | --get-key) # {{{
                  key=true
                  [[ $1 == '--keys' ]] && shift && extra_keys=$1
                  get_key=true;; # }}}
    --every-step) every=true;;
    --pv)         method='pv';;
    --dots)       ${PROGRESS_DOTS_SUPPORTED:-true} && method='dots';;
    --spin)       method='spin';;
    --random-text)      shift; rndTxt="$1";     [[ -z $rndTxt ]] && rndTxt="work" && end_message="done:fail"; method='random-text';;
    --tmux | --tmux-only) # {{{
                  case $1 in
                  --tmux-only) # {{{
                    if ! $do_mark; then
                      _progress --mark-raw "$@"
                      return 0
                    fi
                    tmux_progress_only=true;; # }}}
                  esac
                  tmux_progress=true
                  [[ ! -z "$2" && "$2" != '--'* ]] && tmux_text="$2" && shift
                  [[ $tmux_text == '-' ]] && tmux_text=""
                  ;; # }}}
    --mark-do) # {{{
      local toDo="$2"; shift 2
      _progress --mark "$@"
      eval "$toDo" >/dev/null 2>&1
      sleep 0.2
      _progress --unmark
      return 0;; # }}}
    --mark)       shift; ( _progress --mark-raw "$@" & : ); return 0;;
    --mark-f | --mark-raw) # {{{
                  case $1 in
                  --mark-f)     shift; mark_file="$TMP_MEM_PATH/progress-$1.tmp"; tmux_entry="PR#$1";;
                  esac
                  touch $mark_file; echo "$@" >$mark_file; cmd="[[ ! -e $mark_file ]]"; do_mark=true; every=true;; # }}}
    --unmark)     shift; local delay= err=0 # {{{
                  rm -f "${mark_file%.tmp}.err.tmp"
                  while [[ ! -z $1 ]]; do # {{{
                    case $1 in
                    --err=*) err=${1#--err=}; if [[ $err == 'true' ]]; then err=0; elif [[ $err == 'false' ]]; then err=1; fi;;
                    -c)      shift; end_color="$1";;
                    *)       mark_file="$TMP_MEM_PATH/progress-$1.tmp" && tmux_entry="PR#$1";;
                    esac
                    shift
                  done # }}}
                  (
                    echo "retVal=$err"
                    [[ ! -z $end_color ]] && echo "end_color=\"$end_color\""
                  ) >"${mark_file%.tmp}.err.tmp"
                  [[ -e $mark_file ]] && set -- $(cat $mark_file)
                  while [[ ! -z $1 ]]; do # {{{
                    case $1 in
                    --delay) delay=$2; shift;;
                    --pv | --dots | --spin) method="$1";;
                    --random-text) method="$1"; shift;;
                    --tmux | --tmux-only)   tmux_progress=true;;
                    esac
                    shift
                  done # }}}
                  if [[ -z $delay ]]; then # {{{
                    case $method in
                    dots) delay=0.15;;
                    pv)   delay=1;;
                    spin) delay=1;;
                    random-text) delay=0.25;;
                    *)    delay=1;;
                  esac
                  fi # }}}
                  if [[ $method == 'spin' && $(echo $delay | awk '{print $1 * 100}') -lt 50 ]]; then # {{{
                    delay=0.5
                  fi # }}}
                  rm -f $mark_file
                  $tmux_progress && tmux_progress $tmux_entry end 0
                  sleep $delay; return ${err:-20};; # }}}
    --wait-pv | --wait) # {{{
                  [[ $1 == '--wait-pv' ]] && method='pv' && report_error=false
                  shift
                  endTime="$(time2s -o abs-s $1)";; # }}}
    --dbg)        dbg="l1"; useTput=false;;
    --dbg2)       dbg="l2"; useTput=false;;
    --tput)       useTput=true;;
    --no-tput)    useTput=false;;
    *)            if [[ $argCnt == 1 ]]; then # {{{
                    endTime="$(time2s -o abs-s $1)"; every=true
                    key=true; report_error=false
                  else
                    msg="$1"
                  fi;; # }}}
    esac
    shift
  done # }}}
  if [[ -z $useTput ]]; then
    [[ -t 1 ]] && useTput=${USE_TPUT:-true} || useTput=false
  fi
  if [[ -z $method ]]; then # {{{
    ${PROGRESS_DOTS_SUPPORTED:-true} && method='dots' || method='spin'
  fi # }}}
  if [[ -z $delay ]]; then # {{{
    case $method in
    dots) delay=0.15;;
    pv)   delay=1;;
    spin) delay=1;;
    random-text) delay=0.10;;
    *)    delay=1;;
    esac
  fi # }}}
  if [[ -z $steps ]]; then # {{{
    [[ $method == 'dots' ]] && steps=10 || steps=4
  fi # }}}
  if [[ $method == 'spin' && $(echo $delay | awk '{print $1 * 100}') -lt 50 ]]; then # {{{
    delay=0.5
  fi # }}}
  # }}}
  if $tmux_progress; then # {{{
    eval tmux-progress $tmux_entry $([[ ! -z $tmux_text ]] && echo "--text \"$tmux_text\"")
    $tmux_progress_only && return 0
  fi # }}}
  if [[ -z $every ]]; then
    [[ -z $cmd ]] && every=true || every=false
  fi
  if [[ -z $cmd ]]; then
    key=${key:-true}
    cmd=false
  else
    key=${key:-false}
  fi
  local chars=() local charIdx=0
  unset -f setCursor
  case $method in
  pv) # {{{
    local fName="$TMP_MEM_PATH/progress-pv-$$.tmp" writes="$cnt" do_break=false pkey=
    rm -f "$fName" && touch "$fName"
    [[ ! -z $msg ]] && echo "$msg " >>$out
    echo -n "${color}" >>$out
    if [[ ! -z $endTime ]]; then
      cnt="$(echo "$((endTime-${EPOCHSECONDS:-$(epochSeconds)})) $delay" | awk '{printf "%.0f", $1/$2}')"
      writes="$cnt"
    fi
    for ((; cnt>=0; --cnt)); do
      [[ -e "$fName" && $writes -gt 0 ]] && echo -n "." >>"$fName" && : $((--writes))
      if ! $do_break && [[ ! -z $cmd ]]; then # {{{
        eval $cmd >/dev/null 2>&1 && do_break=true
      fi # }}}
      if ! $do_break; then # {{{
        if $key; then
          if read -s -t $delay -n 1 pkey </dev/tty >/dev/null; then
            retVal=$((10+2))
            case $pkey in
            n|N|q|Q) retVal=255; do_break=true;;
            '')      do_break=true;;
            *)       echo "$extra_keys" | grep -sq "$pkey" && do_break=true
            esac
            $do_break && pressed_key=$pkey
          fi
        else
          sleep $delay
        fi
      fi # }}}
      if $do_break || [[ $cnt == 1 ]]; then # {{{
        if [[ -e "$fName" ]]; then
          [[ $writes -gt 0 ]] && echo -n "." >>"$fName" && : $((--writes))
          rm -f "$fName"
        else
          echo "$retVal $pressed_key" >"$fName"
          break
        fi
      fi # }}}
    done | tail -s 0.1 --follow=name "$fName" 2>/dev/null | pv -s $cnt -i $(echo "$delay" | awk '{printf "%d", $1/2}') -t -e --progress | cat - >/dev/null
    echo -n "${COff}" >>$out
    stty echo 2>/dev/null
    retVal=0 pressed_key=
    [[ -e "$fName" ]] && { read retVal pressed_key <<< $(cat "$fName"); rm -f "$fName"; }
    if ! $report_error; then # {{{
      case $retVal in
      11) $report_error_timeout || retVal=0;;
      0|10|12) retVal=0;;
      esac
    fi # }}}
    $get_key && echo "$pressed_key"
    $tmux_progress && tmux-progress $tmux_entry end $retVal
    return $retVal
    ;; # }}}
  dots) # {{{
    genChars() {
      chars=()
      local i=
      if [[ -e $BASHRC_RUNTIME_PATH/progress-dots ]]; then
        source $BASHRC_RUNTIME_PATH/progress-dots
      else
        for ((i=1; i<0xFF; i++)); do chars+=("$(printf "%x" $((0x2800+$i)))"); done
        echo "chars=(${chars[*]})" >$BASHRC_RUNTIME_PATH/progress-dots
      fi
    }
    nextChar()    { local l=${#chars[*]}; charIdx=$((($charIdx+1+$RANDOM%($l-1))%$l)); }
    getChar()     { echo -en "\u${chars[$charIdx]}"; }
    getLastChar() { echo -en "\u28ff"; }
    ;; # }}}
  spin) # {{{
    [[ -z $end_message ]] && end_message="DONE:BREAK"
    genChars() { chars=('-' '\' '|' '/'); }
    nextChar() { charIdx=$((($charIdx + 1) % ${#chars[*]})); }
    getChar()  { echo -en "${chars[$charIdx]}"; }
    getLastChar() {
      local msg='   '
      case $1 in
      0|10|11|12) [[ ! -z "${end_message/:*}" ]] && msg="${end_message/:*}";;
      *)          [[ ! -z "${end_message/*:}" ]] && msg="${end_message/*:}";;
      esac
      echo -ne "$msg"
    }
    ;; # }}}
  random-text) # {{{
    genChars() {
      unset chars
      local j="--infinity"
      if [[ ! -z $endTime ]]; then # {{{
        local cnt=$(echo "$((endTime-${EPOCHSECONDS:-$(epochSeconds)})) $delay" | awk '{printf "%d", $1/$2}')
        j="--once --cnt $cnt"
      fi # }}}
      chars="$(random-text-drawer --no-tput $j "$rndTxt")"
    }
    nextChar() {
      chars="$(random-text-drawer --state "$chars")"
    }
    getChar()  {
      random-text-drawer --print "$chars"
    }
    getLastChar() {
      local t=
      if [[ ! -z $end_message ]]; then # {{{
        case $1 in
        0|10|11|12) t="${end_message/:*}";;
        *)          t="${end_message/*:}";;
        esac
      fi # }}}
      if [[ ! -z $t ]]; then # {{{
        chars="$(echo -e "$chars;\nexport s=\"$t\"")"
        if $useTput; then
          tput el
        else
          printf "%$((${#rndTxt}+2))s" " "
          setCursor
        fi
      fi # }}}
      random-text-drawer --final "$chars"
    }
    setCursor() {
      $useTput && tput rc || printf "\b%.0s" $(seq $((${#rndTxt}+2)))
    }
    ;; # }}}
  esac
  if ! declare -f setCursor >/dev/null 2>&1; then # {{{
    setCursor() {
      $useTput && tput rc || printf "\b\b\b"
    }
  fi # }}}
  cleanChars() { unset charIdx chars; unset -f genChars getChar getLastChar nextChar setCursor; }
  genChars
  local i=0 chpid=
  [[ ! -z $msg ]] && echo -n "$msg " >>$out
  trap "if $useTput; then  ${TPUT_USE_CVVIS:-true} && tput cvvis || reset; fi; echo >$out; return 0;" INT
  $useTput && tput sc && tput civis
  echo -en "${color}[$(getChar)]${COff}" >>$out
  if [[ ! -z $dbg ]]; then # {{{
    echo >/dev/stderr
    echo "cmd=($cmd)" >/dev/stderr
    echo >/dev/stderr
  fi # }}}
  if [[ $out != '/dev/stderr' && "$cmd" != 'false' ]] && ! $do_mark; then # {{{
    exec 3>&2
    exec 2> /dev/null
  fi # }}}
  stty -echo 2>/dev/null
  while true; do # {{{
    if [[ ! -z $chpid ]] && ! ps -o pid | grep -q "$chpid"; then # {{{
      wait $chpid && { chpid=; break; } || chpid=
    fi # }}}
    if $every || [[ $i == 0 ]]; then # {{{
      if [[ ! -z $dbg ]]; then
        local lerr=
        case $dbg in
        l1) eval $cmd; lerr=$?; echorv lerr; [[ $lerr == 0 ]] && break;;
        l2) ( set -xv; eval $cmd ); lerr=$?; echorv lerr; [[ $lerr == 0 ]] && break;;
        esac
      else
        if [[ $out != '/dev/stderr' && "$cmd" != 'false' ]] && ! $do_mark; then
          if [[ -z $chpid ]]; then
            ( eval $cmd >/dev/null 2>&1 ) &
            chpid=$!
          fi
        else
          ( eval $cmd >/dev/null 2>&1 ) && break
        fi
      fi
      if [[ ! -z $endTime && ${EPOCHSECONDS:-$(epochSeconds)} -gt $endTime ]]; then
        [[ $cmd == 'false' ]] && retVal=$((10+1)) || retVal=1
        break
      fi
    fi # }}}
    if $key; then # {{{
      if read -s -t $delay -n 1 pressed_key; then
        retVal=$((10+2))
        local do_break=false
        case $pressed_key in
        n|N|q|Q) retVal=255; do_break=true;;
        '')      do_break=true;;
        *)       echo "$extra_keys" | grep -sq "$pressed_key" && do_break=true
        esac
        if $do_break; then
          [[ ! -z $pressed_key ]] && echo "$extra_keys" | grep -sq "$pressed_key" && retVal=$((10+3))
          break
        fi
      fi
      # }}}
    else # {{{
      sleep $delay
    fi # }}}
    i=$(( ($i + 1) % $steps))
    nextChar
    echo -ne "$(setCursor)${color}[$(getChar)]${COff}" >>$out
    if [[ $cnt != 0 ]]; then # {{{
      cnt=$(( $cnt - 1 ))
      if [[ $cnt == 0 ]]; then
        [[ $cmd == 'false' ]] && retVal=$((10+1)) || retVal=1
        break
      fi
    fi # }}}
  done # }}}
  stty echo 2>/dev/null
  if [[ ! -z $chpid ]] && ! ps -o pid | grep -q "$chpid"; then # {{{
    wait $chpid
  fi # }}}
  if [[ $out != '/dev/stderr' && "$cmd" != 'false' ]] && ! $do_mark; then # {{{
    exec 2>&3
    exec 3>&-
  fi # }}}
  if $do_mark && [[ -e "${mark_file%.tmp}.err.tmp" ]]; then
    retVal=20
    [[ -s "${mark_file%.tmp}.err.tmp" ]] && source "${mark_file%.tmp}.err.tmp"
    rm "${mark_file%.tmp}.err.tmp"
  fi
  case $retVal in # {{{
  0|10|11|12) [[ $color != ${COff} ]] && color=${end_color:-$CIGreen};;
  13)         [[ $color != ${COff} ]] && color=${end_color:-$CIPurple};;
  *)          [[ $color != ${COff} ]] && color=${CIRed};;
  esac
  echo -ne "$(setCursor)${color}[$(getLastChar $retVal)]${COff}" >>$out
  echo >>$out # }}}
  cleanChars
  $get_key && echo "$pressed_key"
  if ! $report_error; then # {{{
    case $retVal in
    11) $report_error_timeout || retVal=0;;
    0|10|12) retVal=0;;
    esac
  fi # }}}
  if $useTput; then
    ${TPUT_USE_CVVIS:-true} && tput cvvis || reset
  fi
  trap - INT
  $tmux_progress && tmux-progress $tmux_entry end $retVal
  return $retVal
}
alias PC='progress --clean' # }}}
_progress "$@"

