#!/usr/bin/env bash
# vim: fdl=0

_set-title() { # {{{
  if [[ $1 == @@ ]]; then # {{{
    local ret="--set-all --set-none --set-terminal --set-pane --set-window --lock --lock-force --unlock --unlock-force --tmux-session -wl -wlf -l -lf --from-tmux --batch --pwd= --pwd-pane="
    [[ $2 == 1 ]] && ret+=" --dbg"
    echo $ret
    return 0
  fi # }}}
  [[ $- == *x* ]] && return 0
  set-title_getter_default() { # {{{
    local ret=
    case $PWD in # {{{
    $SHARABLE_PATH/* | $HOME/*/Dropbox*) ret='sharable';;
    $RUNTIME_PATH/*)     ret='runtime';;
    $HOME/Desktop*)      ret='desktop';;
    $HOME/Documents*)    ret='docs';;
    $HOME/Downloads*)    ret='downloads';;
    $TMP_MEM_PATH/*)     ret='tmp-mem';;
    $TMP_PATH/*)         ret='tmp';;
    /etc*)               ret='/etc';;
    $HOME)               ret='~';;
    esac # }}}
    echo "$ret"
    return 0
  } # }}}
  convertPwd() { # {{{
    local pwdGetters="$1" pwdGetter= lengthOfLast=${SET_TITLE_LENGTH_OF_LAST:-15} i= ret= path=$PWD env=
    if $isTMUX; then # {{{
      local prefix="$(tmux show-options -v @tmux_path 2>/dev/null)"
      prefix="${prefix%/}"
      if [[ ! -z $prefix && $prefix != $HOME ]]; then
        case $path in
        $prefix/*) path="./${path#$prefix/}";;
        $prefix)   path=".";;
        esac
      fi
    fi # }}}
    for pwdGetter in $pwdGetters; do # {{{
      case $pwdGetter in # {{{
      full) # {{{
        ret="$path";; # }}}
      last|last2) # {{{
        [[ -z $ret ]] && ret="$path"
        ret="${ret/*\/}";;& # }}}
      shorten|shorten2) # {{{
        local beginning="${path%\/*}"
        local last="${path/*\/}"
        [[ $beginning == $last ]] && last=
        ret="$(echo $beginning | sed -e "s;\(/.\)[^/]*;\1;g")"
        [[ ! -z $last ]] && ret="$ret/$last"
        [[ $ret = ./* ]] && ret=${ret:2}
        if echo $ret | grep -q ".*/./././.*"; then
          ret="$(echo "$ret" | sed -e 's|\([^/]*\)/.*/\([^/]*\)|\1/.../\2|')"
        fi;;& # }}}
      last2|shorten2) # {{{
        local last="${path/*\/}"
        ret="${path/$last}"
        if [[ ${#last} -ge $(($lengthOfLast + 3)) ]]; then
          last="${last:0:$lengthOfLast}..."
        fi
        ret+="$last";; # }}}
      set-title_getter_PROFILES) # {{{
        ${SET_TITLE_USE_GETTER_PROFILES:-false} || continue
        if [[ -z $ret ]]; then
          local retInternal=
          for i in $BASH_PROFILES_FULL; do
            [[ -e "$i/aliases" ]] && retInternal="$($i/aliases __util_set-title)"
            [[ ! -z $retInternal ]] && break
          done
          if [[ ! -z $retInternal ]]; then
            env="$(echo "$retInternal" | sed -n '/^# *env:/s/^# *env: *//p')"
            ret="$(echo "$retInternal" | sed '/^# *env:/d')"
            break
          fi
        fi;; # }}}
      set-title_getter_*) # {{{
        if [[ -z $ret ]]; then
          local retInternal=
          declare -F $pwdGetter >/dev/null 2>&1 && retInternal="$($pwdGetter)"
          [[ ! -z $retInternal ]] && ret="$retInternal"
        fi;; # }}}
      esac # }}}
    done # }}}
    ret=${ret/$HOME/\~}
    echo "$ret"
    if [[ ! -z "$env" ]]; then
      echo "$env"
    fi
  } # }}}
  local title= convertPwd_out=
  local pwdGetter=${SET_TITLE_PWD_GETTER:-"shorten2"}
  local pwdPaneGetter="set-title_getter_PROFILES set-title_getter_default last"
  local setTerminalTitle= setPaneTitle= setWindowTitle=
  local isTMUX=false
  local title_pane= lock_title=
  local batch=false from_tmux=
  local dbg=false
  [[ $1 == '--dbg' ]] && shift && dbg=true && set -xv
  [[ -n $TMUX ]] && type tmux >/dev/null 2>&1 && isTMUX=true
  ${TMUX_POPUP:-false} && return 0
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --pwd=*)           pwdGetter=${1/--pwd=};;
    --pwd-pane=*)      pwdPaneGetter=${1/--pwd-pane=};;
    --set-all)         setTerminalTitle=true;  setWindowTitle=true; setPaneTitle=true;;
    --set-none)        setTerminalTitle=false; setWindowTitle=false; setPaneTitle=false;;
    --set-terminal)    setTerminalTitle=true; [[ -z $setWindowTitle ]] && setWindowTitle=false; [[ -z $setPaneTitle ]]     && setPaneTitle=false;;
    --set-pane)        setPaneTitle=true;     [[ -z $setWindowTitle ]] && setWindowTitle=false; [[ -z $setTerminalTitle ]] && setTerminalTitle=false;;
    --set-window)      setWindowTitle=true;   [[ -z $setPaneTitle ]]   && setPaneTitle=false;   [[ -z $setTerminalTitle ]] && setTerminalTitle=false;;
    -wl|-wlf| \
      --batch| \
      --from-tmux)     setTerminalTitle=false; setWindowTitle=true; setPaneTitle=false;;&
    --lock| \
      -l|-wl)          lock_title=true;;
    --lock-force| \
      -lf|-wlf)        lock_title='true-force';;
    --unlock)          lock_title=false;;
    --unlock-force)    lock_title='false-force';;
    --tmux-session)    $isTMUX && title="$TMUX_SESSION";;
    --from-tmux)       shift; from_tmux="-t ${1/.*}"; lock_title='true-force'; isTMUX=true;;&
    --batch| \
      --from-tmux)     setWindowTitle=false; batch=true; [[ -z $lock_title ]] && lock_title='true-force'; sleep 0.1;;
    *)                 title="$1"; title_pane="$1"; break;;
    esac
    shift
  done # }}}
  local current_pane= current_pane_title=
  if $isTMUX; then
    [[ -z $setTerminalTitle ]] && setTerminalTitle=false
    [[ -z $setWindowTitle ]] && setWindowTitle=false
    [[ -z $setPaneTitle ]] && setPaneTitle=true
  else
    [[ -z $setTerminalTitle ]] && setTerminalTitle=true
    [[ -z $setWindowTitle ]] && setWindowTitle=false
    [[ -z $setPaneTitle ]] && setPaneTitle=false
  fi
  if $isTMUX; then # {{{
    [[ -z $title ]] && title="$(tmux show-environment "SET_TITLE_NEW_WINDOW_TITLE" 2>/dev/null | cut -d'=' -f2)"
    read current_pane current_pane_title < <(tmux display-message -p -t $TMUX_PANE -F '#P #T')
  fi # }}}
  if $setPaneTitle; then # {{{
    if [[ -z $lock_title && $current_pane_title == @* ]]; then
      setPaneTitle=false
    else
      if [[ ! -z $title_pane ]]; then
        [[ $lock_title == true* && $title_pane != @* ]] && title_pane="@$title_pane"
      else
        convertPwd_out="$(convertPwd "$pwdPaneGetter")"
        title_pane="$(echo "$convertPwd_out" | sed -n '1p')"
        eval "$(echo "$convertPwd_out" | sed -n '2,$p')"
      fi
    fi
  fi # }}}
  [[ -z $title ]] && title="$SET_TITLE_FORCED_TITLE"
  if [[ -z $title ]]; then
    convertPwd_out="$(convertPwd "$pwdGetter")"
    title="$(echo "$convertPwd_out" | sed -n '1p')"
    eval "$(echo "$convertPwd_out" | sed -n '2,$p')"
  fi
  title="$(echo "$title" | sed -e 's/  \+/ /g' -e 's/\(\w\) \(\w\)/\1-\2/g' -e 's/ //g')"
  if $setTerminalTitle; then
    if ${SET_TITLE_TERMINAL_VIA_TMUX:-true} && [[ -n $TMUX ]]; then
      tmux set -qg set-titles-string "$title"
    else
      printf ']0;%s' "$title" >/dev/stderr
    fi
  fi
  local suffix=$SET_TITLE_SUFFIX
  if [[ ! -z $title_pane ]]; then
    suffix="${suffix/$title_pane\/}"
    suffix="${suffix/$title_pane}"
  fi
  $setPaneTitle && printf ']2;%s%s\\' "${title_pane//\\/}" "${suffix}" >/dev/stderr
  if $isTMUX || $batch; then # {{{
    local TMUX_LOCKED_TITLE='@locked_title' locked_pane=
    if $isTMUX; then # {{{
      $dbg && echo "current pane=($(tmux display-message -p -t $TMUX_PANE -F "#S:#I.#P")) ft=($from_tmux)"
      locked_pane=$(tmux show-option $from_tmux -qvw $TMUX_LOCKED_TITLE)
    fi # }}}
    if [[ -z $locked_pane || $lock_title == 'true-force' ]]; then # {{{
      if $setWindowTitle; then
        printf 'k%s\\'   "$title" >/dev/stderr
      elif $batch; then
        $isTMUX && tmux rename-window $from_tmux "$title"
      fi
    fi # }}}
    if $isTMUX && [[ ! -z $lock_title ]]; then # {{{
      case $lock_title in
        true  | true-force ) [[ -z $locked_pane               || $lock_title == 'true-force'  ]] && tmux set-option $from_tmux -w   $TMUX_LOCKED_TITLE $current_pane;;
        false | false-force) [[ $current_pane == $locked_pane || $lock_title == 'false-force' ]] && tmux set-option $from_tmux -qwu $TMUX_LOCKED_TITLE;;
      esac
    fi # }}}
  fi # }}}
  $dbg && set +xv
  return 0
} # }}}
_set-title "$@"

