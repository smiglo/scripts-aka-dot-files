#!/usr/bin/env bash
# vim: fdl=0

getIcon() { # {{{
  local char=
  [[ " $TMUX_ICONS " =~ \ $1:([^ ]*)\  ]] && echo "${BASH_REMATCH[1]}" || $ALIASES get-unicode-char "$1"
} # }}}
defaults() { # {{{
  # Make clipboard works in vim under tmux (OS/X) # {{{
  ${IS_MAC:-false} && ${TMUX_MAC_USE_REATTACH:-true} && tmux set -qg default-command "reattach-to-user-namespace -l bash"
  # }}}
  # Lock & CMatrix # {{{
  [[ $UID != 0 ]] && type cmatrix >/dev/null 2>&1 && tmux set -qg lock-command "sshh-add --lock --tmux ${TMUX_LOCK_PRE_TIMEOUT:-60}"
  tmux set -g lock-after-time ${TMUX_LOCK_TIMEOUT:-0}
  # }}}
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
      v="${UNICODE_EXTRA_CHARS[progress-dots]}"
    else
      v="${UNICODE_EXTRA_CHARS[progress-bar]}"
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
  local dir="$MEM_KEEP" f_prefix="tmux_sb_progress_" f= ret=
  for f in $(ls $dir/${f_prefix}*.sh 2>/dev/null); do # {{{
    local entry=
    local interval= params= now="${EPOCHSECONDS:-$(epochSeconds)}" lastChange= delta=30 mod_delta=$((15*60)) progress=
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
      tmux set -qg status-interval "${interval:-$TMUX_SB_INTERVAL}"
      [[ -z $doNext ]] && echo "doNext=\"remove\"" >>"$f"
      return 0;; # }}}
    *end) # {{{
      params="stop"
      if [[ -z $lastChange || "$lastChange" == "0" ]]; then
        lastChange="$now"
        echo "lastChange=\"$lastChange\"" >>"$f"
      elif [[ "$now" -gt "$((lastChange + delta))" ]]; then
        progress_drawer "$entry" $extraParams end
        tmux set -qg status-interval "${interval:-$TMUX_SB_INTERVAL}"
        [[ -z $doNext ]] && echo "doNext=\"remove\"" >>"$f"
        return 0
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
      [[ $interval == "1" ]] && interval="$TMUX_SB_INTERVAL"
      echo "interval=\"$interval\"" >>"$f"
    fi # }}}
    [[ "$(tmux show-options -vg status-interval)" != "1" ]] && tmux set -qg status-interval 1
    ret+=" ${out}#[fg=default,none]"
  done # }}}
  echo "${ret:1}"
} # }}}
progress_bar() { # @@ # {{{
  local dir="$MEM_KEEP" f_prefix="tmux_sb_progress_" f=
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
    local cur_time=${EPOCHSECONDS:-$(epochSeconds)} delta=$((15*60))
    for f in $(ls $dir/${f_prefix}*.sh 2>/dev/null); do
      grep -q '^state=".*end"$' "$f" && sed -i 's/^state="\(.*end\)\"$/state="\1-now"/' "$f" && continue
      if [[ ( $2 == 'all-all' ) || ( $2 == 'all' && "$(stat -c "%Y" "$f")" -lt "$(($cur_time - $delta))" ) ]]; then
        sed -i 's/^state="\(.*\)\"$/state="end-now"/' "$f" && continue
      fi
    done
    return 0
  fi # }}}
  local entry="${1,,}"
  [[ -z $entry ]] && return 1
  shift
  local makeLink=false c=
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
      import-module time2s time-tools
      expire=$(time2s "$2" -o abs-s)
      shift
      ;; # }}}
    --params)   extraParams="$2"; shift;;
    esac
    shift
  done # }}}
  f="$dir/${f_prefix}${entry}.sh"
  $makeLink && touch "$f" && ln -sf "$f" "$MEM_KEEP/"
  if [[ -z $state || $state == 'start' ]]; then # {{{
    rm -f "$f"
    progress_drawer $entry 'start'
    state="cont"
    [[ "$(tmux show-options -vg status-interval)" != "1" ]] && tmux set -qg status-interval 1
  fi # }}}
  (
    echo "entry=\"$entry\""
    echo "state=\"$state\""
    [[ ! -z $color ]]       && echo "color=\"$color\""
    [[ ! -z $text ]]        && echo "text=\"$text\""
    [[ ! -z $delta ]]       && echo "delta=\"$delta\""
    [[ ! -z $expire ]]      && echo "expire=\"$expire\""
    [[ ! -z $useProgress ]] && echo "useProgress=\"$useProgress\""
    [[ ! -z $extraParams ]] && echo "extraParams=\"$extraParams\""
  ) >>"$f"
} # }}}
add_to_result() { # {{{
  [[ ! -z "$1" ]] && ret+=" $1"
} # }}}
status_git() { # @@ # {{{
  ${TMUX_STATUS_RIGHT_GIT_STATUS:-true} || return
  local tm_info="$1" pPath="$2"
  if [[ -z $pPath ]]; then
    [[ -z $tm_info ]] && tm_info="$(tmux display-message -pF '#S:#I.#P')"
    pPath="$(tmux list-panes -a -F '#S:#I.#P #{pane_current_path}' | awk '/^'"$tm_info"' /{print $2}' )"
  fi
  [[ -e $pPath ]] || return
  if ! declare -Fx __git_ps1 >/dev/null || ! declare -Fx __git_eread; then # {{{
    local promptFile="${GIT_PROMPT_STATUS_FILE:-$BASH_PATH/completion.d/git/git-prompt.sh}"
    if [[ -e $TMUX_STATUS_RIGHT_GIT_INTERNAL_PS1 ]]; then
      source $TMUX_STATUS_RIGHT_GIT_INTERNAL_PS1
    elif [[ -e $promptFile ]]; then
      source $promptFile
    else
      return
    fi
  fi # }}}
  unset GIT_PS1_SHOWCOLORHINTS
  local gitdir="$(cd $pPath; git rev-parse --path-format=absolute --git-dir 2>/dev/null)" b= stat= i=
  [[ ! -z $gitdir ]] || return
  read b stat < <(cd $pPath; ( git symbolic-ref HEAD 2>/dev/null || git describe HEAD || echo "-"; __git_ps1 "%s" ) | tr '\n' ' ' 2>/dev/null)
  b="${b##refs/heads/}"
  if [[ $b == '-' ]]; then
    if [[ $stat =~ ^\((.*)\)(.*)$ ]]; then
      b=${BASH_REMATCH[1]}
      stat=${BASH_REMATCH[2]}
    elif [[ $stat =~ ^(.*)\|(REBASE.*) ]]; then
      b=${BASH_REMATCH[1]}
      stat=${BASH_REMATCH[2]}
    fi
  elif [[ $stat =~ ^\((.*)\)(.*)$ ]]; then
    stat=${BASH_REMATCH[2]:-=}
  fi
  b=${b#tags/} b="${b##remotes/}"
  stat="${stat#$b}" && stat="${stat// }"
  case $stat in
  '#') stat=;;
  'GIT_DIR!') stat="GD";;
  'BARE:'*) stat="B";;
  '|REBASE-'*) stat="${stat/REBASE-/RB:}";;
  '|MERGE-'*) stat="${stat/MERGE-/M:}";;
  '|MERGING-'*) stat="${stat/MERGING-/M:}";;
  '|BISECTING-'*) stat="${stat/BISECTING-/BIS:}";;
  '|AM/REBASE-'*) stat="${stat/AM\/REBASE-/AM\/RB:}";;
  esac
  local nonFF="$(getIcon exclamation)"
  stat="${stat/<>/$nonFF}"
  if ${PS1_CFG_GIT_USE_CACHE:-false}; then # {{{
    local statF=$MEM_KEEP/tmux-git
    declare -A git_stat
    [[ -e $statF ]] && source $statF
    git_stat["$pPath"]="$stat"
    declare -p git_stat | sed 's/\[/\n[/g' >$statF
  fi # }}}
  # brach mapping # {{{
  # TMUX_STATUS_RIGHT_GIT_BRANCH_MAP+=' devel/(.*):D/${BASH_REMATCH[1]}'
  # TMUX_STATUS_RIGHT_GIT_BRANCH_MAP+=' feat/(.*):F/${BASH_REMATCH[1]}'
  # TMUX_STATUS_RIGHT_GIT_BRANCH_MAP+=' feature/(.*):F/${BASH_REMATCH[1]}'
  # TMUX_STATUS_RIGHT_GIT_BRANCH_MAP+=' fix/(.*):F/${BASH_REMATCH[1]}'
  # TMUX_STATUS_RIGHT_GIT_BRANCH_MAP+=' test/(.*):T/${BASH_REMATCH[1]}'
  TMUX_STATUS_RIGHT_GIT_BRANCH_MAP+=" master:m main:m home-work:hw next:n devel:d"
  local changed=false
  for i in $TMUX_STATUS_RIGHT_GIT_BRANCH_MAP; do # {{{
    [[ $b =~ ^${i%%:*}$ ]] || continue
    b="$(echo "$(eval echo "${i#*:}")")"
    changed=true
    break
  done # }}}
  if ! $changed; then # {{{
    if [[ $b == */* ]]; then
      local bShort= i= p=
      declare -a p1 p2
      IFS='/' read -ra p1 <<< "$b"
      for ((i=0; i<${#p1[*]}-1; i++)); do
        if [[ ${p1[i]} =~ ^([a-zA-Z0-9]+)-([0-9]+)$ ]]; then
          bShort+="${BASH_REMATCH[1]:0:1}-${BASH_REMATCH[2]}/"
        else
          IFS='-' read -ra p2 <<< "${p1[i]}"
          for p in ${p2[*]}; do bShort+="${p:0:1}-"; done
          bShort="${bShort%-}/"
        fi
      done
      local last=${p1[-1]}
      if [[ $last =~ ^([a-zA-Z0-9]+)-([0-9]+)$ ]]; then
        bShort="${bShort%/}/${BASH_REMATCH[1]:0:1}-${BASH_REMATCH[2]}"
      else
        bShort="${bShort%/}/$last"
      fi
      b="$bShort"
    fi
  fi # }}}
  local pre=
  [[ $b == */* ]] && pre="${b%/*}/" && b="${b##*/}"
  if [[ $b =~ ^([A-Z]+-[0-9]+)([_/-].*)? ]]; then # {{{
    b="${BASH_REMATCH[1]}"
    for i in $TMUX_STATUS_RIGHT_GIT_ID_MAP; do
      [[ ${i%%:*} == ${b%%-*} ]] && b="${i#*:}-${b#*-}" && break
    done
  fi # }}}
  local len=${TMUX_STATUS_RIGHT_GIT_BRRANCH_LEN:-15}
  [[ ${#b} -lt $len ]] || b="${b:0:$len}.."
  [[ ! -z $stat ]] && stat=" $stat"
  stat="$pre$b$stat"
  # }}}
  # repo mapping  # {{{
  local repoName="$(cd $pPath; git config utils.repo-name)"
  if [[ -z $repoName ]]; then
    case $gitdir in
    */.git/worktrees/*) repoName="${gitdir%/.git/worktrees/*}";;
    */.git/modules/* ) repoName="${gitdir##*/}";;
    */.git) repoName="${gitdir%/.git}";;
    *.git)  repoName="${gitdir%.git}";;
    esac
    repoName="$(basename ${repoName:-$gitdir})"
    TMUX_STATUS_RIGHT_GIT_REPO_MAP+=' scripts:s'
    TMUX_STATUS_RIGHT_GIT_REPO_MAP+=' vim:v'
    TMUX_STATUS_RIGHT_GIT_REPO_MAP+=' \.runtime:rt'
    TMUX_STATUS_RIGHT_GIT_REPO_MAP+=' (.*)\.github\.io:${BASH_REMATCH[1]}'
    for i in $TMUX_STATUS_RIGHT_GIT_REPO_MAP; do
      [[ $repoName =~ ^${i%%:*}$ ]] || continue
      repoName="$(echo "$(eval echo "${i#*:}")")"
      break
    done
  fi # }}}
  printf "#[fg=colour10,bold] |#[fg=colour13,none] %s%s" "$repoName" " $stat"
} # }}}
status_right_extra() { # @@ # {{{
  [[ -z "$TMUX_STATUS_RIGHT_EXTRA_SORTED" ]] && printf " " && return 0
  source "$UNICODE_EXTRA_CHARS_FILE"
  local tm_info="$1" tm_time="$2"
  [[ -e $TMP_MEM_PATH/.tz.changed ]] && tm_time= # force to use current TZ
  [[ -z $tm_info ]] && tm_info="$(tmux display-message -pF '#S:#I.#P#D')"
  [[ -z $tm_time ]] && tm_time="$(date +'%H:%M')"
  local session="${tm_info%%:*}" l= ret= pane_id="%${tm_info##*%}"
  tm_info="${tm_info%\%*}"
  local cur_time=${EPOCHSECONDS:-$(epochSeconds)} update_time= value= do_update= out=
  local logtime_params=
  if [[ $TMUX_STATUS_RIGHT_EXTRA_SORTED =~ logtime ]]; then
    logtime_params="$(tmux show-environment -t $session "TMUX_SB_LOGTIME_PARAMS" 2>/dev/null)"
    logtime_params="${logtime_params#*=}"
  fi
  [[ -z $TMUX_SB_WORKER ]] && return 0
  source <($TMUX_SB_WORKER --get-all-values)
  if [[ -z ${data["_last_update"]} || ${data["_last_update"]} -lt $((${EPOCHSECONDS:-$(epochSeconds)} - 3 * 60)) ]] && ! ${TMUX_SB_WORKER_IGNORE:-false}; then
    ret+="#[bg=colour124]#[fg=colour226,bold] W$(getIcon exclamation) #[bg=default,none]"
  fi
  local list="$($TMUX_SB_WORKER --list)"
  for l in $TMUX_STATUS_RIGHT_EXTRA_SORTED; do # {{{
    if [[ -v "data[$l]" ]]; then # {{{
      out="${data[$l]}"
      if ! ${dbg:-false}; then
        add_to_result "$out"
      else
        ret+=" $l:[$out]"
      fi # }}}
    elif [[ " $list " == *" $l "* ]]; then # {{{
      : # }}}
    else # {{{
      case $l in # {{{
      progress_bar) add_to_result "$(progress_bar_worker)";;
      tmux_info)    ret+=" #[fg=colour244]$(get_marked_pane $pane_id)";;
      # time)         [[ $logtime_params != 'hidden' ]] && ret+=" #[fg=colour12]$tm_time";;
      time)
        if ${TMUX_STATUS_BAR_USE_LOGLAST:-false}; then
          [[ $logtime_params != 'hidden' ]] && ret+=" #[fg=colour12]$tm_time"
        else
          ret+=" #[fg=colour12]$tm_time"
        fi;;
      logtime) # {{{
        ${TMUX_STATUS_BAR_USE_LOGLAST:-false} || continue
        [[ $logtime_params == 'false' ]] && continue
        [[ ! -e $BIN_PATH/misc/log-last.sh ]] && continue
        if [[ $logtime_params == 'hidden' ]]; then # {{{
          local delta="$((10 * 60))" time_params="$(tmux show-environment -g "TMUX_SB_TIME_PARAMS" 2>/dev/null)"
          time_params="${time_params#*=}"
          [[ ! -z $time_params ]] && eval "$time_params"
          if [[ $cur_time -ge $(( $update_time + $delta )) || -z "$value" ]] || $testing; then
            value=$($BIN_PATH/misc/log-last.sh --tmux %)
            value="${value/*\#\[fg=/\#\[fg=}"
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
            [[ $params == *%* ]] && delta=$((5*60))
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
      *) # {{{
        local i=
        for i in $BASH_PROFILES_FULL; do
          [[ -e $i/aliases ]] && out="$($i/aliases __util_tmux_extra $l)"
          [[ ! -z $out ]] && break
        done
        if ! ${dbg:-false}; then
          add_to_result "$out"
        else
          ret+=" $l:[$out]"
        fi
        ;; # }}}
      esac # }}}
    fi # }}}
  done # }}}
  printf "%b" "${ret# } "
  return 0
} # }}}
status_right() { # {{{
  [[ ! -z $TMUX_SB_INTERVAL ]] && tmux set -qg status-interval "$TMUX_SB_INTERVAL"
  tmux set -qg status-right "#($HOME/.tmux.bash status_git '#S:#I.#P' '#{pane_current_path}')#[fg=colour10,bold] | #[fg=colour12,none]#{s/WORKSPACE/W/:#{session_name}}:#I.#P#($HOME/.tmux.bash status_right_extra '#S:#I.#P#D' '%H:%M')"
} # }}}
status_left_extra() { # {{{
  local format='#[fg=colour12]' end='#[fg=colour10,bold]|' overSSH=false default=false info= sName= checkSSH=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --format)    printf "%s" "$format"; return 0;;
    --end)       printf "%s" "$end"; return 0;;
    --default)   default=true;;
    --check-ssh) checkSSH=true;;
    -s)          sName="$2"; shift;;
    *)           break;;
    esac
    shift
  done # }}}
  $ALIASES_SCRIPTS/tmux/tm.sh --is-ssh && overSSH=true
  if $checkSSH; then
    $overSSH && printf "%b" "$(getIcon ssh)"
    return 0
  fi
  TMUX_STATUS_LEFT_EXTRA_MAP= # Temporarily disabled
  [[ ! -z $TMUX_STATUS_LEFT_EXTRA_MAP ]] && info="$(echo -e "$TMUX_STATUS_LEFT_EXTRA_MAP" | sed -n '/^'$sName':/s/^'$sName'://p')"
  if [[ -z $info ]] || $default; then
    if ${TMUX_SB_SHOW_HOSTNAME:-false}; then
      info="$TMUX_HOSTNAME"
      [[ -z $info ]] && info="${HOSTNAME^^}" && info="${info%%.*}"
    else
      info="$(getIcon ${TMUX_ICON_HOST:-localhost})"
    fi
  fi
  [[ $info != '#'* ]] && info="$format$info"
  if ${TMUX_STATUS_LEFT_CHECK_SSH:-true}; then
    info+="#($HOME/.tmux.bash status_left_extra --check-ssh)"
  else
    $overSSH && info+="$(getIcon ssh)"
  fi
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
    info=" $format$info"
    ${TMUX_STATUS_LEFT_CHECK_SSH:-true} && info+="#($HOME/.tmux.bash status_left_extra --check-ssh)"
    info+="$(status_left_extra --end) "
  fi
  tmux set -qg status-left "$(printf "%b" "$info")"
} # }}}
set_title_extra() { # {{{
  local ts= body= isSsh= sshIcon=
  IFS=$'\t' read -r ts body isSsh sshIcon < <(tmux show -gqv @tmux-title)
  [[ ! -z $ts ]] || ts=0
  if [[ -z $body ]]; then
    body="#S: #W"
    if [[ ! -z $TMUX_TITLE ]]; then
      body="$TMUX_TITLE"
    elif [[ ! -z $TMUX_ICON_HOST ]] || ${TMUX_TITLE_ADD_ICON:-true}; then
      body="$(getIcon ${TMUX_ICON_HOST:-localhost})"
    elif $IS_DOCKER; then
      local host="${TMUX_HOSTNAME:-${HOSTNAME%%.*}}"
      body="${host^^} $body"
    fi
  fi
  if (( EPOCHSECONDS - ts >= 120 )) && ${TMUX_STATUS_LEFT_CHECK_SSH:-true}; then
    ts=$EPOCHSECONDS
    if $ALIASES_SCRIPTS/tmux/tm.sh --is-ssh; then
      isSsh=true
      [[ ! -z $sshIcon ]] || sshIcon=$(getIcon ssh)
    fi
  fi
  [[ ! -z $isSsh ]] || isSsh=false
  tmux set -g @tmux-title "$ts	$body	$isSsh	$sshIcon"
  ! $isSsh || body+=" $sshIcon"
  printf '%b' "$body"
} # }}}
set_title() { # {{{
  if ${TMUX_TITLE_CHECK_SSH:-true}; then
    tmux set -qg set-titles-string "#($HOME/.tmux.bash set_title_extra)"
  elif [[ ! -z $TMUX_ICON_HOST ]]; then
    tmux set -qg set-titles-string "$(getIcon "$TMUX_ICON_HOST")"
  elif [[ ! -z $TMUX_TITLE ]]; then
    tmux set -qg set-titles-string "$TMUX_TITLE"
  else
    tmux set -qg set-titles-string "#S: #W"
  fi
} # }}}
window_status_flags() { # {{{
  local flags="$1"
  flags="${flags/\*}"
  flags="${flags/-}"
  if [[ $flags == *M* ]]; then
    flags="${flags/M}"
  fi
  if [[ $flags == *Z* ]]; then
    flags="${flags/Z}"
    flags="$(getIcon zoom)$flags"
  fi
  printf "%b" "$flags"
} # }}}
plugins() { # {{{
  [[ $TMUX_VERSION -le 16 ]] && return 0
  tmux set -qg @tpm_plugins 'tmux-plugins/tpm morantron/tmux-fingers'
  if ${TMUX_PLUGINS_ADD_YANK:-false}; then
    tmux set -qg @tpm_plugins 'tmux-plugins/tpm tmux-plugins/tmux-yank morantron/tmux-fingers'
    tmux set -qg @copy_mode_yank_wo_newline '!'
    tmux set -qg @copy_mode_yank 'Enter'
    tmux set -qg @copy_mode_put 'C-y'
    tmux set -qg @copy_mode_yank_put 'M-y'
  fi
  local i= cnt=0
  for i in $TMUX_FINGERS_REGEX; do
    tmux set -qg @fingers-pattern-$cnt "$i"
    cnt="$(($cnt+1))"
  done
  tmux set -qg @fingers-key "f"
  tmux set -qg @fingers-ctrl-action "cat - | $ALIASES xclip --put"
  tmux run-shell ~/.tmux/plugins/tpm/tpm
} # }}}
select_marked_pane() { # @@ # {{{
  local paneId="$(tmux list-panes -F '#D #S:#W.#D' | awk '/^'"$1 "'/ {print $2}')"
  [[ -z $paneId ]] && return 1
  local markedPaneId="$(tmux list-panes -F '#{pane_marked} #S:#W.#D' | awk '/^1/ {print $2}')"
  if [[ -z $markedPaneId ]]; then
    local firstPaneId="$(tmux list-panes -F '#P #S:#W.#D' | awk '/^1 / {print $2}')"
    tmux select-pane -t $paneId -m
    if [[ $firstPaneId == $paneId ]]; then
      tmux last-pane -Z
    else
      tmux select-pane -t 1
    fi
    return 0
  fi
  if [[ $paneId == $markedPaneId ]]; then
    markedPaneId=
  fi
  if [[ -z $markedPaneId ]]; then
    tmux select-pane -t $paneId -m
    tmux last-pane -Z
  else
    tmux select-pane -t $paneId -m
    tmux switch-client -t $markedPaneId
  fi
} # }}}
get_marked_pane() { # @@ # {{{
  local paneId=$1
  local nestF=$TMUX_NEST/$paneId
  [[ -e $nestF ]] || return
  printf "%b" "$(getIcon smart)"
} # }}}
mark_toggle() { # @@ # {{{
  local delay= paneId=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -p) paneId=$2; shift;;
    -d*) delay=${1/-d}; [[ -z $delay ]] && delay=2;;
    esac
    shift
  done # }}}
  [[ ! -z $paneId ]] || return 1
  local nestF=$TMUX_NEST/$paneId interval=$(tmux show-options -gqv status-interval)
  tmux set -qg status-interval 1
  if [[ -z $delay ]]; then
    [[ -e $nestF ]] && rm -f $nestF || touch $nestF
    tmux run-shell -b -d 2 -C "set -qg status-interval $interval"
  else
    rm -f $nestF
    tmux run-shell -b -d $delay "touch -f $nestF; tmux set -qg status-interval $interval"
  fi
} # }}}
switch_pane_1_last() { # @@ # {{{
  local pAct= pMark= p= a= m= cnt=0
  while read -r p a m; do
    cnt=$((cnt + 1))
    [[ $a == 1 ]] && pAct=$p
    [[ $m == 1 ]] && pMark=$p
  done < <(tmux list-panes -F '#P #{pane_active} #{pane_marked}')
  [[ $cnt -gt 1 ]] || return 0
  if [[ $pAct == 1 || $pAct == $pMark ]]; then
    echo "last-pane"
  else
    echo "select-pane -t .${pMark:-1}"
  fi
} # }}}
lock_toggle() { # @@ # {{{
  local verbose=true mode='toggle' changed=false
  [[ -z $1 ]] && set - ssh
  while [[ ! -z $1 ]]; do
    case $1 in
    -q) verbose=false;;
    --lock)   mode='lock';;
    --unlock) mode='unlock';;
    --lock-allowed) # {{{
      local w_status="$(tmux show-option -qv @lock_allowed)" g_status="$(tmux show-option -gqv @lock_allowed)" new_status=
      case $w_status in
      false) # {{{
        [[ "$mode" == 'lock' ]] && shift && continue
        $verbose && tmux display-message "Locking changed to global value ($( ${g_status:-true} && echo 'ENABLED' || echo 'DISABLED'))"
        tmux set-option -uq @lock_allowed
        changed=true;; # }}}
      *) # {{{
        case $g_status in
        false) # {{{
          [[ "$mode" == 'lock' ]] && shift && continue
          new_status='true';; # }}}
        *) # {{{
          [[ "$mode" == 'unlock' ]] && shift && continue
          new_status='false';; # }}}
        esac
        $verbose && tmux display-message "Locking $( $new_status && echo 'ENABLED' || echo 'DISABLED') $( [[ $1 == -g ]] && echo 'globally' || echo 'locally')"
        tmux set-option $( [[ $1 == -g ]] && echo '-g' ) @lock_allowed $new_status
        changed=true;; # }}}
      esac;; # }}}
    --ssh) # {{{
      local lockCmd="$(tmux show-options -vg 'lock-command')"
      if [[ "$lockCmd" == *'sshh-add'* && $UID != 0 ]]; then
        local timeout="${TMUX_LOCK_PRE_TIMEOUT:-60}"
        case $lockCmd in
        *\ --tmux\ -1) # {{{
          [[ "$mode" == 'unlock' ]] && shift && continue
          $verbose && tmux display-message "SSH Agent lock after ${TMUX_LOCK_PRE_TIMEOUT:-60}s";; # }}}
        *\ --tmux\ *) # {{{
          [[ "$mode" == 'lock' ]] && shift && continue
          $verbose && tmux display-message "SSH Agent lock DISABLED"; timeout=-1;; # }}}
        esac
        tmux set -qg lock-command "sshh-add --lock --tmux $timeout"
        changed=true
      fi;;# }}}
    --screen) # {{{
      local timeout="${TMUX_LOCK_TIMEOUT:-300}"
      case "$(tmux show-options -vg 'lock-after-time')" in
      0) # {{{
        [[ "$mode" == 'unlock' ]] && shift && continue
        $verbose && tmux display-message "Screen saver after ${timeout}s";; # }}}
      *) # {{{
        [[ "$mode" == 'lock' ]] && shift && continue
        $verbose && tmux display-message "Screen saver DISABLED"; timeout=0;; # }}}
      esac
      tmux set -g 'lock-after-time' $timeout
      changed=true;; # }}}
    esac
    shift
  done
  $changed && return 0 || return 1
} # }}}
switch_client() { # {{{
  local current_s= i= dst= src=
  current_s="$1"
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
  current_s="$1"
  current_s="${current_s^^}" && current_s="${current_s//-/_}"
  current_w="$2"
  local -n ref_w="TMUX_SWITCH_WINDOW_${current_s}_MAP"
  for i in $ref_w; do
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
  if [[ $(tmux display-message -p -F '#I') == '1' ]] || $switch_to_last; then
    tmux last-window
  else
    tmux select-window -t :1
  fi
  return 0
} # }}}
scratch_pane() { # @@ # {{{
  local cwd="$1" params="$2" pane_id=
  [[ -z $params ]] && params="-h -l 50%"
  [[ -e "$cwd" ]] && params+=" -c \"$cwd\""
  pane_id="$(eval tmux split-window $params -P -F "'#{pane_id}'")"
  sleep 0.5
  tmux send-keys -t $pane_id "pt hn; clear"
} # }}}
pasteKey_worker() { # @@ # {{{
  source ~/.bashrc --do-basic
  local buff="$1" query="$2" v= keys="$(keep-pass.sh --list-all-keys)"
  if [[ ! -z $query ]]; then
    local m="$(echo "$keys" | grep "$query")"
    [[ $(echo "$m" | wc -l) == 1 ]] && v="$m"
  fi
  if [[ -z $v ]]; then
    v="$( \
      echo "$keys" \
      | eval fzf \
        --preview="\"keep-pass.sh --key '{1}' --no-intr\"" \
        +m --prompt="\"Key> \"" $([[ ! -z $query ]] && echo "--query=\"$query\"") -0 \
    )"
    [[ $? == 0 && ! -z "$v" ]] || return 1
  fi
  v="$(keep-pass.sh --key "$v")"
  [[ ! -z $v ]] || return 1
  [[ $v == *'..' ]] && v="${v%..}" || v+=""
  tmux set-buffer -b $buff "$v"
} # }}}
pasteKey() { # @@ # {{{
  local buff="key.$$" pane_src=$(tmux display-message -p -F '#D') pane_id= key= res=
  pane_src=${pane_src#%}
  local f="$TMP_MEM_PATH/keep-pass.$pane_src.key"
  while [[ ! -z $1 ]]; do
    case $1 in
    --set-key) # {{{
      shift
      local pDelta= pKeep= pCount=
      while [[ ! -z 1 ]]; do
        case $1 in
        --delta)    pDelta=$2; shift;;
        --keep-for) pKeep=$2; pDelta=$2; shift;;
        --keep)     pCount=999; pDelta=0; shift;;
        --count)    pCount=$2; pDelta=0; shift;;
        *)          echo "$1" >"$f"; break;;
        esac
        shift
      done
      [[ ! -z $pDelta ]] && echo "delta=$pDelta" >>"$f"
      [[ ! -z $pKeep  ]] && echo "keep=$pKeep"   >>"$f"
      [[ ! -z $pCount ]] && echo "count=$pCount" >>"$f"
      return 0;; # }}}
    --delete-key) # {{{
      rm -f "$f"
      return 0;; # }}}
    --pane) # {{{
      pane_src=${2#%}; f=${f%.*.key}.$pane_src.key; shift;; # }}}
    esac
    shift
  done
  if [[ -e "$f" ]]; then # {{{
    local delta=30 keep= count= fTime="$(stat -c "%Y" "$f")" cTime="${EPOCHSECONDS:-$(epochSeconds)}"
    source <(cat "$f" | grep "^\(delta\|keep\|count\)=")
    if [[ true == true \
      && ( $delta == 0 || $fTime -gt $((cTime-delta)) ) \
      && ( -z $keep    || $fTime -gt $((cTime-keep)) ) \
      && ( -z $count   || $count -gt 0 ) \
       ]]; then
      key="$(cat "$f" | head -n1)"
      if [[ ! -z $count ]]; then
        count=$((count-1))
        [[ $count -gt 0 ]] && sed -i -e '/^count=/s/=.*/='$count'/' "$f"
      fi
    fi
    if [[ false == true \
      || ( -z $keep   && -z $count ) \
      || ( ! -z $keep && $fTime -lt $((cTime-keep)) ) \
      || ( $count == 0 ) \
       ]]; then
      rm -f "$f"
    fi
  fi # }}}
  tmux delete-buffer -b "$buff" >/dev/null 2>&1
  pane_id="$(tmux split-window -h -l 50% -P -F '#{pane_id}' "$HOME/.tmux.bash pasteKey_worker '$buff' '$key'")"
  while true; do
    res=$(tmux display-message -p -t "$pane_id" -F '#{pane_id}' 2>/dev/null)
    [[ -z $res ]] && break
    sleep 0.5
  done
  tmux list-buffers -F '#{buffer_name}' | grep -q "^$buff$" \
    && tmux paste-buffer -d -b "$buff"
  return 0
} # }}}
preserve_zoom() { # @@ # {{{
  local zoomed=$1; shift
  local zoomCmd=
  [[ $zoomed == 1 ]] && zoomCmd="\\; resize-pane -Z"
  local inline=false
  [[ $1 == '-I' ]] && inline=true && shift
  local param="$@"
  $inline && param="$($param)"
  eval tmux $param $zoomCmd
} # }}}
new_window() { # {{{
  local currPaneId=$1 path="$2" doSplit=${3:-false}
  local env_src="$(tmux display-message -p -t $currPaneId -F '#{s/^\$//:#{session_id}}.#{window_id}')"
  if $doSplit; then
    tmux new-window -a -e ENV_SNAPSHOT_SRC=$ENV_SNAPSHOT_PRE.$env_src -c "$path" \; \
      split-window -v -l 20% -d -c "$path"
  else
    tmux new-window -a -e ENV_SNAPSHOT_SRC=$ENV_SNAPSHOT_PRE.$env_src -c "$path"
  fi
} # }}}

[[ -z $TMUX_VERSION ]] && TMUX_VERSION="$(tmux -V | sed 's/\.//' | cut -c6-7)"
export testing=false
err=0
case $1 in
@@) # {{{
  case ${4:-$3} in
  --dbg | --dbg2 | --test | --time) # {{{
    sed -n 's/^\([a-z].*\)() { # @@ .*/\1/p' tmux.bash
    ;; # }}}
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
    cur_time=${EPOCHSECONDS:-$(epochSeconds)}
    if $sTime; then
      time "$@"
    else
      $@
    fi
    err=$?
    echo
    exit $err
  ) 2>&1
  err=$?
  ;; # }}}
*) "$@";;
esac
exit $err

