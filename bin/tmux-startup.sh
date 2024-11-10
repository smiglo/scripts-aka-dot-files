#!/usr/bin/env bash
# vim: fdl=0

export BASHRC_TRACE=false
unset BASH_XTRACEFD
# Completion # {{{
if [[ $1 == '@@' ]]; then
  if [[ $3 != '--todo' ]]; then
    echo "--no-lock --lock --no-attach --attach --dbg --do-post --do-env --todo --env --preconfigure $(echo $(tmux list-sessions -F '#S')) --no-progress"
  else
    echo "pre init env post"
  fi
  exit 0
fi
# }}}
# INIT # {{{
${TMUX_DISABLED:-false} && exit 0
TMUX_INIT_LOCK=$TMP_MEM_PATH/.tmux_startup.lock
LOCK="$([[ "${BASH_SOURCE[0]}" == "$0" ]] && echo 'false' || echo 'true')"
case $1 in
  --lock)
    LOCK=true; shift;;
  --no-lock)
    LOCK=false; shift;;
esac
if $LOCK; then # {{{
  ! command mkdir $TMUX_INIT_LOCK &>/dev/null && exit 0
  trap "rm -rf $TMUX_INIT_LOCK" EXIT
fi # }}}
# Source extensions # {{{
for i in $BASH_PROFILES_FULL; do
  [[ -e $i/tmux-startup.sh ]] && source $i/tmux-startup.sh
done
[[ -e $RUNTIME_PATH/tmux-startup.sh ]] && source $RUNTIME_PATH/tmux-startup.sh # }}}
# }}}
# Functions # {{{
isTmux_16() { # {{{
  [[ $(tmux -V | sed 's/.* //') == '1.6' ]]
} # }}}
getTmuxInitSessions() { # {{{
  echo "MAIN"
} # }}}
getRemoteSessionName() { # {{{
  [[ ! -z $TMUX_REMOTE_NAME ]] && echo "$TMUX_REMOTE_NAME" && return 0
  local name=$HOSTNAME p=
  for p in $TMUX_REMOTE_PREFIXES; do
    name="${name/$p}"
  done
  echo "${name^^}" | tr '.' '_'
} # }}}
isSession() { # {{{
  local s="$1"
  [[ -z $s ]] && return 1
  [[ $s == 'REMOTE' ]] && s=$(getRemoteSessionName)
  tmux has-session -t $s >/dev/null 2>&1
} # }}}
run() { # {{{
  local s= cmd= hide=false clear_after=false
  local current=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --hide)     hide=true;;
    --no-hide)  hide=false;;
    --clear)    clear_after=true;;
    --no-clear) clear_after=false;;
    --select)   current=$(tmux display-message -p -t $TMUX_PANE -F '#S:#I.#P');;
    *)          [[ -z $s ]] && s="$1" || break;;
    esac; shift
  done # }}}
  cmd=$1; shift
  case $cmd in
  set_title) # {{{
    set_title --from-tmux ${s%.*} "$1"
    sleep 0.1
    return 0;; # }}}
  layout | layout-default | layout-restore) # {{{
    hide=true; clear_after=true
    [[ -z $current ]] && current=$(tmux display-message -p -t $TMUX_PANE -F '#S:#I.#P')
    case $cmd in
    layout-restore) # {{{
      cmd="tm --session --restore -w";; # }}}
    layout | layout-default) # {{{
      local params="-w"
      [[ "$cmd" == 'layout-default' ]] && params="-wd"
      cmd="tm --l-restore $@ $params --set-pane-1 || true";; # }}}
    esac
    shift $#;; # }}}
  command | exec | \
  cd | mc | pt |   \
  vim | vim-session) # {{{
    hide=true; clear_after=true;; # }}}
  esac
  [[ ! -z $@ ]] && cmd+=" $@"
  $hide && cmd=" $cmd"
  $clear_after && cmd="$cmd; clear"
  [[ ! -z $current ]] && tm --switch $s
  tmux send-key -t $s -l "$cmd"
  sleep 0.1
  [[ ! -z $current ]] && tm --switch $current
  return 0
} # }}}
layoutRestore() { # {{{
  run $1 layout-restore
  sleep 0.5
  run $1 layout --set-pane-1
  sleep 0.5
} # }}}
run_mc() { # {{{
  local le=$2
  local ri=$3
  [[ -z $le || ! -e $le ]] && le=$HOME
  [[ -z $ri || ! -e $ri ]] && ri=$HOME
  run $1 "mc $le $ri"
} # }}}
makeNiceSplits() { # {{{
  # Init # {{{
  local max_c=4 rows= p_no=2 i= no= splits= row= dbg=false
  [[ $# == 0 ]] && return 0
  while [[ ! -z $1 ]]; do
    case $1 in
    -1) p_no=1;;
    -2) p_no=2;;
    --p-no) p_no=$2; shift;;
    *) break;;
    esac; shift
  done
  [[ -z $1 ]] && return 0
  local cnt="$#" p_no_orig=$p_no
  splits="RUN:p=$p_no cd \"$1\"\n"
  shift
  [[ $# == 0 ]] && echo "$splits" && return 0
  # {{{
  if [[ $cnt -le 3 ]]; then
    max_c="$cnt"
  elif [[ $cnt == 4 ]]; then
    max_c="2"
  elif [[ $cnt -le 6 ]]; then
    max_c="3"
  fi # }}}
  # }}}
  # Verticals # {{{
  rows="$(($cnt / $max_c))"
  [[ $(($cnt % $max_c)) != 0 ]] && rows="$(($rows + 1))"
  $dbg && echo "cnt=$cnt, max_c=$max_c, rows=$rows" >/dev/stderr
  for i in $(seq 1 $rows); do
    [[ $i -lt $rows ]] && splits+="SPLIT:p=$p_no -v -p $((($rows - $i) * 100 / ($rows - $i + 1))) -c "$1"\n"
    p_no="$(($p_no + 1))"
  done # }}}
  # Horizontals # {{{
  p_no=$p_no_orig row=1 co=1
  for i in $(seq 1 $cnt); do
    $dbg && echo "HORZ: co=$co, ro=$row, i=$i, pno=$p_no, arg=[$1]" >/dev/stderr
    if [[ $row == $rows ]]; then # {{{
      [[ $(($cnt % $max_c)) != 0 ]] && max_c="$(($cnt % $max_c))"
      row=-1
      $dbg && echo "HORZ: last row, max_c=$max_c" >/dev/stderr
    fi # }}}
    if [[ $co -lt $max_c ]]; then # {{{
      no="$(($max_c - $co))"
      splits+="SPLIT:p=$p_no -h -p $(($no * 100 / ($no + 1))) -c "$1"\n"
    fi # }}}
    p_no="$(($p_no + 1))"
    co="$(($co+1))"
    if [[ $co -gt $max_c ]]; then # {{{
      $dbg && echo "HORZ: next-row" >/dev/stderr
      [[ ! -z $1 ]] && splits+="RUN:p=$p_no cd \"$1\"\n"
      co=1
      [[ $row -gt 0 ]] && row="$(($row+1))"
    fi # }}}
    shift
  done # }}}
  echo "$splits"
} # }}}
initFromEnv() { # {{{
  local sessionName="$sessionName" setup= silent=true change_window=true
  [[ ! -z $1 ]] && sessionName="$1" && shift
  [[ ! -z $sessionName ]] || return 1
  [[ $sessionName == 'REMOTE' ]] && sessionName=$(getRemoteSessionName)
  tmux has-session -t "$sessionName" >/dev/null 2>&1 || return 1
  case $1 in
  @*) setup=${1#@};;
  '' | --)
    [[ $1 == '--' ]] && shift
    setup="TMUX_${sessionName//-/_}_ENV_SETUP"
    if type $setup >/dev/null 2>&1; then
      if [[ $1 == '.' ]]; then
        $setup "$(tmux display-message -p -t $TMUX_PANE -F '#W')"
        change_window=false
      else
        $setup "$@"
      fi
    else
      setup="${!setup}"
      [[ ${setup:0:1} == '@' ]] && ${setup#@}
    fi ;;
  *) setup="$@";;
  esac
  [[ ! -z $setup ]] || return 0
  ${TMUX_INIT_PROGRESS:-true} && progress --mark --dots --msg "Setting up windows in [$sessionName]..."
  [[ ! $(declare -p setup) =~ "declare -a" ]] && setup=($setup)
  local i= p= t= c= w=$(($(tmux display -t "$sessionName" -p -F '#{session_windows}') + 1)) msgs=
  for i in ${!setup[*]}; do # {{{
    t=$(echo "${setup[$i]}" | cut -d':' -f1)
    p=$(echo "${setup[$i]}" | cut -d':' -f2)
    c=$(echo "${setup[$i]}" | cut -d':' -f3-)
    [[ -z $p ]] && p="$t" && t=
    [[ ! -e $p ]] && msgs+="Window[$t]: Path ($p) does not exists\n" && continue
    p=$(command cd $p; pwd -P)
    local create=true pane_cnt=1
    if [[ ! -z $t ]] && tmux list-window -t $sessionName -F '#W' | command grep -q "^$t\$"; then
      $change_window && msgs+="Window [$t]: Already created\n" && continue
      create=false
      w="$(tmux list-window -t $sessionName -F '#I. #W' | command grep " $t\$" | sed 's/\..*//')"
      pane_cnt="$(tmux display-message -t $sessionName:$w -p -F '#{window_panes}')"
    fi
    if $create; then
      tmux \
        new-window -t $sessionName:$w $([[ ! -z $t ]] && echo "-n $t") -d -c "$p" \; \
        set-option -t $sessionName:$w -w @locked_title 1
    fi
    # Title # {{{
    if [[ ! -z $t ]]; then
      set_title --from-tmux $sessionName:$w --lock "$t"
      sleep 0.1
    fi # }}}
    if tm --l-restore --check "$p" "$t"; then
      run $sessionName:$w.1 "layout"
    else
      # Preconfigured Splits # {{{
      if [[ -z $c && ! -z $t ]]; then
        c="${t^^}" && c="TMUX_${sessionName//-/_}_PRE_${c//-/_}"
        c="${!c}"
      fi
      if [[ ! -z $c ]]; then
        makePreconfiguredSplits --wnd $w --cnt-panes $pane_cnt --pwd "$p" "$c" # }}}
      else
        tmux split-window -t $sessionName:$w -v -p 20 -d -c "$p"
      fi
    fi
    # Vim # {{{
    if [[ ! -z $t ]]; then
      local session_file= tt="${t,,}" d="Session-" i=
      [[ -e "$p/.vim" ]] && d=".vim/"
      for i in $tt ${tt%%--*}; do
        if [[ -e "$p/$d$i.as.vim" ]]; then
          session_file="$d$i.as.vim"
        elif [[ -e "$p/$d$i.vim" ]]; then
          session_file="$d$i.vim"
        fi
        [[ ! -z $session_file ]] && break
        [[ $tt == ${tt%%--*} ]] && break
      done
      if [[ -z $session_file ]]; then
        if [[ -e "$p/${d%-}.as.vim" && ! -h "$p/${d%-}.as.vim" ]]; then
          session_file="${d%-}.as.vim"
        elif [[ -e "$p/${d%-}.vim" && ! -h "$p/${d%-}.vim" ]]; then
          session_file="${d%-}.vim"
        fi
      fi
      [[ ! -z "$session_file" ]] && run $sessionName:$w.1 "vim-session $session_file"
    fi # }}}
    tmux select-pane -t $sessionName:$w.1
    # Wait for a window to be fully created # {{{
    if [[ ! -z $t ]]; then
      local cnt=10
      while ! tmux list-windows -t $sessionName -F '#W' | command grep -q "^$t$" && [[ $cnt -gt 0 ]]; do
        sleep 0.3
        cnt=$(($cnt-1))
      done
      sleep 1
    fi # }}}
    msgs+="Window [$t]: Created (${p/$HOME/~})\n"
    w=$(($w+1))
  done # }}}
  ${TMUX_INIT_PROGRESS:-true} && progress --unmark
  ! $silent && echo -e "$msgs" | sed 's/^/  /'
  $change_window && tmux select-window -t $sessionName:1
} # }}}
setBuffer() { # {{{
  local force=false
  [[ $1 == '-f' ]] && force=true && shift
  local name=$1
  local content=$2
  ! $force && tmux show-buffer -b "$name" >/dev/null 2>&1 && return 0
  tmux set-buffer -b "$name" "$content"
  return 0
} # }}}
# initSession() # {{{
if isTmux_16; then
  initSession() { # {{{
    local s=$1
    local p=$2
    isSession "$s" && return 1
    cd $p
    tmux new-session -d -s "$s" || return 1
    cd - >/dev/null 2>&1
  } # }}}
else
  initSession() { # {{{
    local s=$1
    local p=$2
    isSession "$s" && return 1
    tmux -u new-session -d -s "$s" -c "$p" $tmux_size_params || return 1
    tmux set -q -t $s @tmux_path "$p"   || return 1
    tmux set-environment -gur RCSTUFF_FUNCTION_EXPORTED
  } # }}}
fi
# }}}
init() { # {{{
  if [[ $# == 1 || $1 == '-' ]]; then
    [[ $1 == '-' ]] && shift
    sessionName="${FUNCNAME[1]#initTmux_}"
    sessionPath="$1"
  else
    sessionName="$1"
    sessionPath="$2"
    shift 2
  fi
  [[ -z $sessionName || -z $sessionPath || ! -e $sessionPath ]] && echo "return 1;" && return 1
  echo "export sessionName=\"$sessionName\";"
  echo "export sessionPath=\"$sessionPath\";"
  unset RCSTUFF_FUNCTION_EXPORTED
  initSession $sessionName $sessionPath || echo "return 0;"
  return 0
} # }}}
getSizeParam() { # {{{
  if [[ $TMUX_VERSION -ge 34 ]]; then
    echo "-l $1%"
  else
    echo "-p $1"
  fi
} # }}}
runExtensions() { # {{{
  local i= sessionName="${1:-$sessionName}"
  [[ -z $sessionName ]] && return 0
  for i in $(eval echo \$TMUX_INIT_EXT_${sessionName//-/_}); do
    if ! declare -F $i >/dev/null 2>&1; then
      echo "Extention [$1: $i] not defined" >/dev/stderr
      continue
    fi
    $i
  done
} # }}}
makePreconfiguredSplits() { # {{{
  local sessionName="$sessionName"
  [[ -z $sessionName ]] && sessionName="${TMUX_SESSION:-$(tmux display-message -p -t $TMUX_PANE -F '#S')}"
  [[ -z $sessionPath ]] && sessionPath="$(tmux show -qvt "$sessionName" '@tmux_path')"
  local path="$sessionPath" wnd= cfg= cnt_panes=1 dbg=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
      -s)          sessionName="$2"; shift
                   [[ $sessionName == 'REMOTE' ]] && sessionName=$(getRemoteSessionName);;
      --pwd)       path=$2; shift;;
      --wnd)       wnd=$2; shift;;
      --wnd-name)  wnd="$(tmux list-windows -t "$sessionName" -F '#I |#W|' | command grep -F "|$2|" | cut -d' ' -f1)"; shift;;
      --cnt-panes) cnt_panes=$2; shift;;
      *)           cfg=$1;  break;
    esac
    shift
  done # }}}
  [[ $sessionName == 'REMOTE' ]] && sessionName=$(getRemoteSessionName)
  # Errors # {{{
  isSession $sessionName || return 1
  [[ ! -z $wnd ]] || return 1
  [[ $(tmux display-message -t $sessionName:$wnd -pF '#{window_panes}') == $cnt_panes ]] || return 1
  [[ -z $cfg ]] && cfg="$(eval echo "\$TMUX_INIT_SPLITS_${sessionName//-/_}_${wnd}")"
  [[ ! -z $cfg ]] || return 0
  # }}}
  echo -e "$cfg" | while read i; do
    p=1 pwd= cmd= params= i="$(echo $i)"
    [[ -z $i ]] && continue
    $dbg && echo "Entry: [$i]" >/dev/stderr
    case $i in
    DBG) # {{{
      dbg=true
      ;; # }}}
    SPLIT:* | RUN:* | SELECT:* | TMUX:*) # {{{
      cmd="${i#*:}"
      cmd="$(echo "$cmd" | sed 's/\(^p=[0-9]\+\) \([^#]\)/\1 # \2/')"
      params="$cmd"
      [[ $cmd == *\#* ]] && params=$(echo ${cmd#*\#}) && eval $cmd
      $dbg && echo "  Params=[$params], Cmd=[$cmd], p=[$p], pwd=[$pwd]" >/dev/stderr
      ;;& # }}}
    SPLIT:*) # {{{
      [[ $params != *-c\ * ]] && params+=" -c \"${pwd:-$path}\""
      eval tmux split-window -d -t $sessionName:$wnd.$p $params;; # }}}
    RUN:*) # {{{
      if [[ $params != *\#* ]] || eval ${params%%\#*}; then
        run $sessionName:$wnd.$p "$(echo ${params#*\#})"
      else
        run --hide $sessionName:$wnd.$p "clear; echo 'Condition \"$(echo ${params%%\#*})\" not met to run \"$(echo ${params#*\#})\".'"
      fi;; # }}}
    SELECT:*) # {{{
      tmux select-pane -t $sessionName:$wnd.$p;; # }}}
    TMUX:*) # {{{
      cmd=${cmd//-t ./-t $sessionName:$wnd.}
      cmd=${cmd//;/\\;}
      eval tmux $cmd;; # }}}
    esac
  done
} # }}}
restoreSaved() { # {{{
  local i=
  declare -A openVimIn
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --vims)
      shift
      for i in $1; do
        [[ $i == *:* ]] && openVimIn[${i%%:*}]="${i#*:}" || openVimIn[$i]=
      done;;
    *) break;
    esac; shift
  done # }}}
  local sessionName="${1:-$sessionName}"
  local src="$APPS_CFG_PATH/tmux/sessions/$sessionName/windows.save"
  [[ -e $src ]] || touch $src
  local windows="$(tmux list-windows -t $sessionName -F '#I #W')"
  local i="$(echo "$windows" | wc -l | xargs)" title= tmp=
  echor "Restoring layout"
  while read title tmp; do
    title=${title#*:}
    local no="$(echo "$windows" | awk '/ '"$title"'$/ {print $1}')"
    if [[ -z $no ]]; then
      tmux new-window -t $sessionName:$i -a -d
      i=$((i+1)); no=$i
      sleep 0.3
      run $sessionName:$no set_title "$title"
      sleep 0.3
    fi
    echor "- $sessionName:$no: $title"
    layoutRestore $sessionName:$no.1
    [[ -v openVimIn[$title] ]] || openVimIn[$title]=
  done <$src
  sleep 2
  while read no title; do
    [[ -v openVimIn[$title] ]] || continue
    echor "- $sessionName:$no: launching vim (${openVimIn[$title]})"
    run $sessionName:$no.1 vim-session ${openVimIn[$title]}
    sleep 0.5
  done <<<"$(tmux list-windows -t $sessionName -F '#I #W')"
} # }}}
# initTmux_MAIN ... # {{{
if ! declare -f initTmux_MAIN >/dev/null 2>&1; then
  if ! $IS_DOCKER; then
    initTmux_MAIN() { # {{{
      eval $(init "$HOME")
      tmux \
        new-window    -t $sessionName:1 -a -d -c "$SCRIPT_PATH" \; \
        split-window  -t $sessionName:2.1 -v $(getSizeParam 20) -d -c "$SCRIPT_PATH" \; \
        select-window -t $sessionName:1 \; \
        select-pane   -t $sessionName:1.1
      local isNet=false vims=
      net --wait=10s && isNet=true
      run $sessionName:1 set_title "Widgets"
      makePreconfiguredSplits --wnd 1
      run $sessionName:2 set_title "Tools"
      if [[ " $TMUX_INIT_SESSIONS " != *" ENV "* || " $TMUX_INIT_SESSIONS_SKIP " == *" ENV "* ]]; then
        vims+=" Tools"
      fi
      restoreSaved --vims "$vims"
    } # }}}
  else
    initTmux_MAIN() { # {{{
      eval $(init "$HOME")
      tmux \
        split-window  -t $sessionName:1.1 -v $(getSizeParam 20) -d -c "$SCRIPT_PATH"\; \
        new-window    -t $sessionName:1 -a -d \; \
        split-window  -t $sessionName:2.1 -v $(getSizeParam 20) -d \; \
        select-window -t $sessionName:1 \; \
        select-pane   -t $sessionName:1.1
      run $sessionName:1.1 cd "$SCRIPT_PATH"
      run $sessionName:1 set_title "Tools"
      run $sessionName:2 set_title "Main"
      restoreSaved --vims "Main:docker"
    } # }}}
  fi
fi # }}}
initTmux_REMOTE() { # {{{
  eval $(init "$(getRemoteSessionName)" "${TMUX_STARTUP_DIR:-$HOME}")
  if isTmux_16; then
    tmux \
      split-window -t $sessionName:0 -v $(getSizeParam 20) -d " cd $sessionPath; exec bash" \; \
      new-window   -t $sessionName:1 -d " cd $sessionPath; exec bash"
  else
    tmux \
      split-window -t $sessionName:1 -v $(getSizeParam 20) -d -c "$sessionPath" \; \
      new-window   -t $sessionName:2 -d -c "$sessionPath"
  fi
  sessionName='REMOTE'
  restoreSaved
} # }}}
initTmux_ROOT() { # {{{
  eval $(init "${TMUX_STARTUP_DIR:-$HOME}")
  tmux \
    split-window -t $sessionName:1 -v $(getSizeParam 20) -d -c "$sessionPath"
  if type vlock 1>/dev/null 2>&1; then
    tmux set -qg lock-command vlock
  fi
  tmux set -qg lock-server on
  tmux set -qg lock-after-time ${TMUX_LOCK_TIMEOUT_ROOT:-300}
  $HOME/.tmux.bash status_left "$(getUnicodeChar 'root')" '#[fg=colour226]'
} # }}}
# }}}
# MAIN # {{{
# Create sessions # {{{
sessions=
sessionName=
sessionEnvParams=
do_attach="$([[ "${BASH_SOURCE[0]}" == "$0" ]] && echo 'false' || echo 'true')"
todo="pre init env post"
dbg=false
[[ -z $1 ]] && set -- --do-env ${TMUX_SESSION:-$(tmux display-message -p -t $TMUX_PANE -F '#S')}
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --no-progress) TMUX_INIT_PROGRESS=false;;
  --no-attach) do_attach=false;;
  --attach)    do_attach=true;;
  --dbg)       dbg=true;;
  --do-post)   todo="pre env post";;
  --todo)      todo="$2"; shift;;
  --do-env) # {{{
    todo="pre env"
    if [[ $2 == '--' ]]; then
      shift 2
      sessionName="$1"
      [[ -z $sessionName || $sessionName == '.' ]] && sessionName="${TMUX_SESSION:-$(tmux display-message -p -t $TMUX_PANE -F '#S')}"
      sessions="$sessionName"
      shift
      sessionEnvParams="$sessionName"
      [[ ! -z $1 ]] && sessionEnvParams+=" -- $@"
      shift $#
    fi ;; # }}}
  --env) # {{{
    shift
    sn="${TMUX_SESSION:-$(tmux display-message -p -t $TMUX_PANE -F '#S')}"
    initFromEnv "${@:-$sn}"
    exit;; # }}}
  --preconfigure) # {{{
    shift
    $dbg && set -xv
    makePreconfiguredSplits "$@"
    $dbg && set +xv
    exit;; # }}}
  *) sessions=$@ # {{{
     sessionName=${1^^}
     break;; # }}}
  esac
  shift
done # }}}
todo=" $todo "
if [[ -z $sessions ]]; then # {{{
  if [[ ! -z $TMUX_INIT_SESSIONS ]]; then
    sessions=$TMUX_INIT_SESSIONS
  else
    sessions=$(getTmuxInitSessions)
  fi
fi # }}}
# Load pre/runtime configuration # {{{
if [[ "$todo" =~ " pre " ]]; then
  runExtensions 'PRE_INIT' || true
  [[ -e $RUNTIME_PATH/tmux-startup-pre.sh ]] && source $RUNTIME_PATH/tmux-startup-pre.sh || true
  for i in $BASH_PROFILES; do
    [[ -e $RUNTIME_PATH/tmux-startup-pre.$i.sh ]] && source $RUNTIME_PATH/tmux-startup-pre.$i.sh || true
  done
fi # }}}
tmux_size_params=
[[ ! -n $TMUX ]] && tmux_size_params="-x $(tput cols) -y $(tput lines)"
for s in $sessions; do # {{{
  [[ " $TMUX_INIT_SESSIONS_SKIP " == *" $s " ]] && continue
  (
    $dbg && set -xv
    s=${s^^}
    unset TMUX
    if declare -f initTmux_${s//-/_} >/dev/null 2>&1; then
      initTmux_${s//-/_}
    else
      [[ -z sessionName ]] && sessionName="$s"
    fi
    if isSession "$sessionName"; then
      [[ "$todo" =~ " init " ]] && runExtensions
      [[ "$todo" =~ " env "  ]] && initFromEnv $sessionEnvParams
    fi
  )
done # }}}
# Load post/runtime configuration # {{{
if [[ "$todo" =~ " post " ]]; then
  runExtensions 'POST_INIT' || true
  [[ -e $RUNTIME_PATH/tmux-startup-post.sh ]] && source $RUNTIME_PATH/tmux-startup-post.sh || true
  for i in $BASH_PROFILES; do
    [[ -e $RUNTIME_PATH/tmux-startup-post.$i.sh ]] && source $RUNTIME_PATH/tmux-startup-post.$i.sh || true
  done
fi # }}}
# Load stored buffers # {{{
buffers_path=$RUNTIME_PATH/tmux-buffers
for i in $(cd $buffers_path && ls *.buffer 2>/dev/null); do
  tmux load-buffer -b "${i/.buffer}" $buffers_path/$i
done # }}}
[[ ! -z $TMUX_USE_NICE_PRIO ]] && sudo renice -n ${TMUX_USE_NICE_PRIO} -p $(command ps -A -o pid,comm | command grep 'tmux: server' | awk '{print $1}') >/dev/null 2>&1
rm -rf $TMUX_INIT_LOCK
if $do_attach; then # {{{
  trap "kill -SIGHUP $PPID" SIGHUP
  # Choose current session # {{{
  if [[ -z $sessionName ]] || ! tmux has-session -t $sessionName 1>/dev/null 2>&1; then
    [[ -e $TMP_PATH/.tmux_last_session.$USER ]] && sessionName="$(cat $TMP_PATH/.tmux_last_session.$USER)"
  fi
  if [[ $TMUX_INIT_SESSIONS == 'REMOTE' ]]; then
    sessionName="$(getRemoteSessionName)"
  fi
  if [[ -z $sessionName ]] || ! tmux has-session -t $sessionName 1>/dev/null 2>&1; then
    sessionName=${TMUX_SESSION_DEFAULT:-'MAIN'}
  fi # }}}
  # Attach to current session # {{{
  if [[ ! -n $TMUX ]]; then
    tmux attach-session -t $sessionName
  else
    tmux switch-client -t $sessionName
  fi # }}}
fi # }}}
# }}}
# }}}

