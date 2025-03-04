#!/usr/bin/env bash
# vim: fdl=0

_reminder() { # @@ # {{{
  if [[ $1 == @@ ]]; then # {{{
    local ret="-v -i -rm -l --list -l-full --list-full -e --edit --no-at"
    case $3 in
    -i | -rm) # {{{
      ret="$(at -l | awk '{print $1}')" ;; # }}}
    *) # {{{
      case $2 in
      1) # {{{
        ret+=" $(find . -maxdepth 1 -type f -executable)"
        if [[ ! -z $REMINDER_DIR && -e $REMINDER_DIR ]]; then
          for i in $(cd "$REMINDER_DIR"; ls -d *); do
            [[ -f $REMINDER_DIR/$i && -x $REMINDER_DIR/$i ]] && ret+=" $i"
          done
        fi;; # }}}
      *) # {{{
        ret="30m 1h 16:30";; # }}}
      esac;; # }}}
    esac
    echo "$ret"
    return 0
  fi # }}}
  $IS_MAC && tool="$BASH_PATH/messages.sh"
  type $tool >/dev/null 2>&1 || $silent || { echor "Notifier tool [$tool] not found"; return 1; }
  local i= j= no= tool='/usr/bin/notify-send' verbose=">/dev/null 2>&1" be_verbose=false silent=false addAtP=true pd= pt=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -v) verbose=; be_verbose=true;;
    -s) silent=true;;
    *)  break;;
    esac; shift
  done # }}}
  if [[ -z $1 ]]; then
    [[ -t 1 ]] && set -- -e || set -- -l
  fi
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -i) # {{{
      shift
      for i in ${@:-$(at -l | sort -k1,1n | awk '{print $1}')}; do
        at -l | grep -q "^$i\s" || continue
        at -l | grep "^$i\s"
        at -c "$i" | sed -e '1,/exit 1/ d' -e '/^[{}]/d' -e '/^\s*$/d' | sed 's/^/\t/'
      done
      return 0;; # }}}
    -e      | --edit | \
    -rm     | \
    -l      | --list | \
    -l-full | --list-full) # {{{
      local oIFS="$IFS" list= d= msg=
      IFS=
      while read i; do # {{{
        no="$(echo "$i" | awk '{print $1}')"
        d="$(date -d "$(echo "$i" | awk '{print $3,$4,$6,$5}')" +"%y%m%d%H%M")"
        msg="$(at -c "$no" | sed -e '1,/exit 1/ d' -e '/^[{}]/d' -e '/^\s*$/d' | sed 's/^/\t/' | xargs)"
        list+="$no $d : $msg\n"
      done < <(at -l) # }}}
      IFS="$oIFS"
      list="$(echo -en "$list" \
        | sort -k2,2n \
        | sed 's/^\([0-9]\+\) \([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\) : /\1 \4.\3.\2-\5:\6 : /' \
        | sed -e 's| --at=[0-9]\+||')"
      case $1 in
      -e      | --edit) # {{{
        list="$(echo -en "$list" \
          | sed -e 's|/[^ ]*/||' -e 's|ll-||' -e 's|\.sh||' \
          | sed -e 's|pni|@|' -e 's|go-home|GH|' -e 's|pause|P|' -e 's|notify-send .* Reminder:|!|' \
          | sed -e 's|^\([0-9]\+\) \([0-9.]\+\)-\([0-9:]\+\) : |\1 \2 \3 |' \
        )"
        declare -a listC listIds listN toAdd toRemove
        readarray -t listC <<<$(echo "$list" | sed 's/^[0-9]* \+//')
        readarray -t listIds <<<$(echo "$list" | sed 's/ .*//')
        local tmpFile=$TMP_MEM_PATH/reminder.$$.tmp # {{{
        (
          for i in ${!listC[*]}; do echo "${listC[i]}"; done
          echo
          echo "# Usage: time-stamp P|@|!|GH msg"
          echo "#"
          echo "# P  :: pause   :: P msg"
          echo "# @  :: pni     :: @ msg(@time)"
          echo "# !  :: notif   :: ! msg"
          echo "# GH :: go-home :: GH msg"
        ) >$tmpFile # }}}
        vim --fast-save -1l $tmpFile || { rm $tmpFile; return 0; }
        readarray -t listN <<<$(cat $tmpFile | sed -e '/^#/d' -e '/^\s*$/d')
        rm $tmpFile
        for i in ${!listN[*]}; do # {{{
          for j in ${!listC[*]}; do
            [[ ${listN[i]} == ${listC[j]} ]] || continue
            listC[j]=""
            continue 2
          done
          toAdd+=("${listN[i]}")
        done # }}}
        for i in ${!listC[*]}; do # {{{
          [[ -z ${listC[i]} ]] && continue
          toRemove+=("${listIds[i]}")
        done # }}}
        [[ ! -z ${toAdd[*]} || ! -z ${toRemove[*]} ]] || return 0
        for i in ${!toAdd[*]}; do # {{{
          [[ ! -z ${toAdd[i]} ]] || continue
          line=${toAdd[i]}
          local newTs= newWhat= newMsg=
          if [[ $line =~ ^([0-9.: -]+)\ +(P|@|!|GH|p|gh)?(\ *(.*))? ]]; then # {{{
            newTs="$(echo ${BASH_REMATCH[1]})"
            newWhat="$(echo ${BASH_REMATCH[2]})"
            newMsg="$(echo ${BASH_REMATCH[4]})"
            [[ $newTs == *' :' ]] && newTs=${newTs% :}
            newTs="$(echo $newTs)"
          else
            { $silent || echor "Ignored line: [$line]"; } && continue
          fi # }}}
          case ${newWhat^^} in # {{{
          P)  newWhat="pause.sh";;
          GH) newWhat="go-home.sh";;
          @)  newWhat="ll-pni.sh";;
          \!) newWhat="";;
          '') newWhat="";;
          esac # }}}
          if [[ " $newTs " =~ [0-9.-]+[\ -]([0-9][0-9]?:[0-9][0-9]?) ]]; then
            pt=${BASH_REMATCH[1]} && pd="$(echo ${newTs/$pt})" && pd=${pd%-}
          elif [[ " $newTs " =~ ([0-9][0-9]?:[0-9][0-9]?) ]]; then
            pt=$newTs
          else
            { $silent || echor "cannot parse TS: [$newTs]"; } && continue
          fi
          if [[ ! -z $pd ]]; then
            pd=${pd%.}
            [[ $pd =~ ^([0-9][0-9]?)$ ]] && pd+=".$(date +%m)"
            [[ $pd =~ ^([0-9][0-9]?)\.([0-9][0-9]?)$ ]] && pd+=".$(date +%y)"
            [[ $pd =~ ^([0-9][0-9]?)\.([0-9][0-9]?)\.([0-9][0-9])$ ]] && pd=${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}
          fi
          reminder -s $newWhat $([[ ! -z $newMsg ]] && echo "'$newMsg'") "$pt $pd" || $silent || echor "Failed to add [$newWhat] at [$pt $pd]"
        done # }}}
        for i in ${!toRemove[*]}; do # {{{
          [[ ! -z ${toRemove[i]} ]] || continue
          at -r ${toRemove[i]}
        done # }}}
        $silent || reminder -l;; # }}}
      -rm     | \
      -l      | --list | \
      -l-full | --list-full) # {{{
        [[ -z $list ]] && return 0
        local id= ts= tmp= rest= isFull=false
        local today="$(date +%d.%m.%y)"
        [[ $1 == '-l-full' || $1 == '--list-full' ]] && isFull=true
        echo "$list" | while read id ts tmp rest; do # {{{
          case $rest in
          */pause.sh*)        rest="P ${rest#*/pause.sh}";;
          */go-home.sh*)      rest="GH ${rest#*/go-home.sh}";;
          */reminders/*.sh*)  rest="${rest#*/reminders/}";;
          *\ Reminder:\ -*)   rest="- ${rest#* Reminder: -}";;
          *\ Reminder:\ *)    rest="! ${rest#* Reminder: }";;
          */ll-pni.sh*)       rest="@ ${rest#*/ll-pni.sh}";;
          */ll-*)             rest="LL-${rest#*/ll-}";;
          /*)                 rest="C ${rest##*/}";;
          esac
          rest="$(echo $rest | sed -e 's|/[^ ]*/||' -e 's|\.sh||')"
          if $isFull; then
            echo "${ts/-/ }: $rest"
          else
            [[ $ts == $today* ]] || continue
            echo "${ts#*-}: $rest"
          fi
        done # }}}
        case $1 in
        -rm) # {{{
          shift
          local no="$@"
          if [[ -z $no ]]; then # {{{
            no="$(echo "$list" | fzf -0 -m -s --prompt 'To remove> ' | cut -d' ' -f1)"
            [[ -z $no ]] && return
          fi # }}}
          at -r $no;; # }}}
        esac;; # }}}
      esac
      return 0;; # }}}
    -v) verbose=; be_verbose=true;;
    -s) silent=true;;
    --no-at) addAtP=false;;
    *)  break;;
    esac
    shift
  done # }}}
  local msg="$1" ts="${2#+}" h= m= s= file=false err=0 params=
  if [[ $# -gt 2 ]]; then
    ts="${@:$#:$#}"
    params="${@:2:$#-2}"
  fi
  [[ ! -z $msg && ! -z $ts ]] || $silent || { echor "Argument missing [$@]"; return 1; }
  time2s --is-hms "$ts" && ts="$(time2s $ts)"
  [[ " $ts " =~ .*\ ([0-9][0-9]?:[0-9][0-9]?(:[0-9][0-9]?)?)\ .* ]] && pt=${BASH_REMATCH[1]} && pd="$(echo ${ts/$pt})"
  if [[ ! -z $pd ]]; then
    pd=${pd%.}
    [[ $pd =~ ^([0-9][0-9]?)$ ]] && pd+=".$(date +%m)"
    [[ $pd =~ ^([0-9][0-9]?)\.([0-9][0-9]?)$ ]] && pd+=".$(date +%y)"
    [[ $pd =~ ^([0-9][0-9]?)\.([0-9][0-9]?)\.([0-9][0-9])$ ]] && pd=${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}
  fi
  [[ "$pt" == *:*:* ]] && pt="${pt%:*}"
  local tsAbs="$(time2s "$pd $pt" -o abs-s)"
  if [[ "$tsAbs" -le $((EPOCHSECONDS + 30)) ]]; then
    $silent || echor "Scheduled time is before near-now, rejecting"
    return 1
  fi
  if [[ ! -z "$REMINDER_DIR" && -e "$REMINDER_DIR/$msg" ]]; then
    msg="$REMINDER_DIR/$msg"
    $addAtP && params="--at=$tsAbs $params"
  fi
  [[ "$msg" == ./* ]] && msg="$PWD/$msg"
  [[ "$msg" == /* && -e "$msg" ]] && file=true
  if $file; then # {{{
    $be_verbose && set -xv
    echo "$msg $params" | ( cd $HOME; eval at "'$pt $pd'" $verbose )
    err="$?"
    $be_verbose && set +xv
    ! grep -q "${tool##*/}\|no-notify" "$msg" && msg="Script [${msg##*/}] executed" && file=false
  fi # }}}
  if ! $file && [[ $err == '0' ]]; then # {{{
    local msg_wrapper="$REMINDER_DIR/.msg.sh"
    if [[ -e "$msg_wrapper" ]]; then
      echo "$msg_wrapper \"Reminder: $msg\""
    else
      if ! $IS_MAC; then
        echo "$tool -i starred -u critical 'Reminder: $msg'"
      else
        echo "$tool 'Reminder' '$msg'"
      fi
    fi | ( $be_verbose && set -xv; cd $HOME; eval at "'$pt $pd'" $verbose )
    err="$?"
  fi # }}}
  if [[ $err == 0 ]]; then
    ! $silent && at -l | sort -k1,1n | tail -n1
    if $be_verbose; then
      at -c "$(at -l | sort -k1,1n | tail -n1 | awk '{print $1}')" | sed -n -e '/^\s*$/d' -e '/^\/home/,$ p' | sed 's/^/\t/'
    fi
  else
    $silent || echor "Failed to schedule the reminder"
  fi
  return $err
} # }}}
_reminder "$@"

