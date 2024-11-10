#!/usr/bin/env bash
# vim: fdl=0

putOnList() { # {{{
  [[ -z $1 ]] && return 0
  local ticket_list="$TMP_MEM_PATH/kb-data--${TICKET_PATH##*/}-list.txt" i= silent=false
  [[ ! -e "$ticket_list" ]] && touch "$ticket_list"
  [[ $1 == '-s' ]] && silent=true && shift
  if [[ $# == 1 ]]; then
    if ! command grep -q "^${1}$" "$ticket_list"; then
      echo "$1" >>"$ticket_list"
      sort -u "$ticket_list" >"${ticket_list}.tmp"
      mv "${ticket_list}.tmp" "$ticket_list"
    fi
  else
    local l="$@"
    echo -e "${l// /\\n}" >> "$ticket_list"
    sort -u "$ticket_list" > "${ticket_list}.tmp"
    mv "${ticket_list}.tmp" "$ticket_list"
  fi
  ! $silent && echo "$@"
} # }}}
getIssue() { # {{{
  local p= ext= i= ii= quick_check="${2:-false}" ticket_list="$TMP_MEM_PATH/kb-data--${TICKET_PATH##*/}-list.txt"
  [[ ! -e "$ticket_list" ]] && touch "$ticket_list"
  i="$(echo ${1,,})"
  [[ $i == *\ * ]] && return 0
  [[ $i == *--* ]] && i="${i%%--*}"
  local list="$i"
  if [[ $i == *-* || $i == 'tmp' ]]; then
    ii="$(echo "$i" | cut -d'-' -f1,2)"
    [[ $i != $ii ]] && list+=" $ii"
  fi
  for ii in $list; do # {{{
    command grep -q "^${ii}$" "$ticket_list" && echo "$ii" && return 0
    [[ $i != 'tmp' ]] && command grep -q "^-${ii}$" "$ticket_list" && return 0
  done # }}}
  for ii in $list; do # {{{
    [[ -e "$TICKET_PATH/$ii/${ii}-data.txt" || -e "$TICKET_PATH/$ii/.${ii}-data.txt" ]] && putOnList "$ii" && return 0
    local r="$(findDataFile "$ii")"
    [[ ! -z $r ]] && putOnList "$ii" && return 0
  done # }}}
  if $quick_check; then
    putOnList "-${list// / -}"
    return 0
  fi
  for ii in $list; do # {{{
    for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
      p="$($ext --ticket-path $ii)"
      [[ ! -z $p && ( -e "$p/${ii}-data.txt" || -e "$p/.${ii}-data.txt" ) ]] && putOnList "$ii" && return 0
    done # }}}
  done # }}}
  putOnList "-${list// / -}"
  return 0
} # }}}
findDataFiles() { # {{{
  eval find $TICKET_PATH \
    -mindepth 2 -maxdepth 5 \
      $(find $TICKET_PATH \
          -mindepth 2 -maxdepth 5 -name '.ticket-data.sh' \
        | sed -e 's|\(.*\)/[^/]*|-path \1/\\*|' -e 's/$/ -prune -o/' \
        | tr '\n' ' ') \
    "$@" \
    -type f -name '\*-data.txt' -print 2>/dev/null \
  | command grep ".*/\([^/]*\)/\.\{0,1\}\1-data.txt" \
  | sort
  return 0
} # }}}
findDataFile() { # {{{
  local f="$1"
  [[ ! -z $f ]] || return 0
  [[ $f == *-data.txt ]] || f+='-data.txt'
  findDataFiles -name $f -print -quit -o -name .$f -print -quit
  return 0
} # }}}
getIssuesRaw() { # {{{
  local l="$(findDataFiles $@)"
  putOnList -s $(echo "$l" | sed -e 's|.*/||' -e 's|-data\.txt||' -e 's|^\.||')
  echo "$l"
} # }}}
getIssues() { # {{{
  getIssuesRaw $@ | sed -e 's|.*/||' -e 's|-data\.txt||' -e 's|^\.||' | sort
} # }}}
getIssueID() { # {{{
  local wNr="$1" wnd_name= p="$PWD" f=
  if [[ ! -z $wNr ]]; then # {{{
    issue="$(getIssue "$(tmux display-message -p -F '#W' -t :$wNr 2>/dev/null)" true)"
    # }}}
  else # {{{
    # Get issue from window name # {{{
    if [[ -z $issue ]]; then
      wnd_name="$(tmux display-message -p -t $TMUX_PANE -F '#W')"
      if [[ $wnd_name == *-* || ${wnd_name,,} == 'tmp' ]]; then
        issue="$(getIssue "$wnd_name")"
      else
        issue="$(getIssue "$wnd_name" true)"
      fi
    fi
    # }}}
    # Get issue from current dir # {{{
    if [[ -z $issue ]]; then
      local p="$PWD" f=
      while [[ $p == $TICKET_PATH* ]]; do
        f="${p##*/}"
        [[ -e "$p/${f}-data.txt" ]] && issue="$f" && break
        p="$(command cd "$p/.."; pwd)"
      done
    fi # }}}
    # Get issue from fallback issue # {{{
    if [[ -z $issue ]]; then
      [[ ! -z $ISSUE_FALLBACK ]] && issue="$(getIssue "$ISSUE_FALLBACK" true)"
    fi
    # }}}
    # Get issue from first matching window name # {{{
    if [[ -z $issue ]]; then
      for wnd_name in $(tmux list-windows -F '#W'); do
        if [[ $wnd_name == *-* ]]; then
          issue="$(getIssue "$wnd_name")"
        else
          issue="$(getIssue "$wnd_name" true)"
        fi
        [[ ! -z $issue ]] && break
      done
    fi # }}}
  fi # }}}
  echo "$issue"
} # }}}
filterIssues() { # {{{
  ! $FZF_INSTALLED && echo "" && return 0
  findDataFiles \
  | xargs ls -t \
  | sed -e 's|.*/||' -e 's|-data\.txt||' -e 's/^\.//' \
  | fzf \
      -0 --reverse --no-sort --multi +e -x \
      --preview="$TICKET_TOOL_PATH/ticket-tool.sh --issue '{}' info" \
      --bind "f1:execute($TICKET_TOOL_PATH/ticket-tool.sh --issue '{}' ff -1)" \
      --bind "f3:execute($TICKET_TOOL_PATH/ticket-tool.sh --issue '{}' edit </dev/tty >/dev/tty)" \
  | tr '\n' ' '
  return 0
} # }}}
fzf_wrapper() { # {{{
  local t="$(echo "$1" | sed 's/\([^:]*:[^:]*\):.*/\1/')"
  local s="${t#*:}"
  local i="${1#*$s:}"
  t="${t%:*}"
  local f="$(findDataFile "${t}")"
  f="$f:$(command grep -n "^# $s -\{0,1\}\# {{[{]" $f)"
  shift
  if [[ $@ == *-c\ prev* ]]; then
    local q="$1" qi=
    shift
    for qi in $q; do
      [[ $qi != !* ]] && break
    done
    i="${i%% *}"
    i="${i%%)*}"
    i="${i//\$/\\\\\\$}"
    [[ $i == -* ]] && i="-e '$i'"
    [[ ! -z $i ]] && i+=".*"
    if [[ ! -z $qi && $qi != !* ]]; then
      echo -e "\t---  $t : ${i} $qi ---" && echo
      fzf_exe -f "$f" "$@" | hl +cGold "# $s -\{0,1\}\# {{[{].*" $([[ ! -z $i ]] && echo "+cC \"$i\"") +cG "$qi" # For vim # }} }
    else
      echo -e "\t---  $t : ${i} ---" && echo
      fzf_exe -f "$f" "$@" | hl +cGold "# $s -\{0,1\}\# {{[{].*" +cC "$i" # For vim # }} }
    fi
  else
    fzf_exe -f "$f" "$@"
  fi
}
export -f fzf_wrapper findDataFile findDataFiles
# }}}
readConfiguration() { # {{{
  local confFile="$TMP_MEM_PATH/kb-data-j.conf" tp="${TICKET_PATH_ORIG:-$TICKET_PATH}"
  [[ -e $confFile ]] || return 0
  source <(sed  -n "/^# ${tp//\//\\\/} #/,/^# ${tp//\//\\\/} #/ p" $confFile)
  [[ -z $TICKET_PATH_ORIG ]] && TICKET_PATH_ORIG="$TICKET_PATH"
  [[ -z $TICKET_PATH_SAVE ]] && TICKET_PATH_SAVE="$TICKET_PATH"
  TICKET_PATH="$TICKET_PATH_SAVE"
} # }}}
saveConfiguration() { # {{{
  local confFile="$TMP_MEM_PATH/kb-data-j.conf" tp="${TICKET_PATH_ORIG:-$TICKET_PATH}" current=
  [[ -e $confFile ]] && current="$(sed -n "/^# ${tp//\//\\\/} #/,/^# ${tp//\//\\\/} #/ p" $confFile)"
  local new="$(
    echo "# $tp #"
    echo "export ISSUE_FALLBACK=\"$ISSUE_FALLBACK\""
    echo "export TICKET_PATH_SAVE=\"${TICKET_PATH_SAVE:-$TICKET_PATH}\""
    echo "export TICKET_PATH_ORIG=\"$tp\""
    echo "# $tp #"
  )"
  if [[ "$new" != "$current" ]]; then
    [[ -e $confFile ]] && sed -i "/^# ${tp//\//\\\/} #/,/^# ${tp//\//\\\/} #/ d" $confFile
    echo "$new" >>$confFile
  fi
} # }}}
saveInHistory() { # {{{
  [[ -z "$TICKET_CONF_HISTFILE" ]] && return 0
  ! $addToHistory && return 0
  local l="$1" err="${2:-0}"
  [[ -z $l ]] && return 1
  l="$(echo "$l" | sed -e 's/\s\s\+/ /g')"
  if [[ -s "$TICKET_CONF_HISTFILE" ]]; then
    tail -n30 "$TICKET_CONF_HISTFILE" | sed -e 's/\s\s\+/ /g' | command grep -qF "$l" && return 0
  fi
  [[ $err != 0 ]] && l+=" # $err"
  echo "$l" >>"$TICKET_CONF_HISTFILE"
} # }}}
echorm --name tt:j
verbose=$(echorm -f??) issue= wNr= i= do_grep=false do_history=false reset_only=false do_wait=
loop=false loopTimeout= loopBreakOnTimeout=false loopBreakOnErr=false loopMax=
TICKET_PATH_ORIG= TICKET_PATH_SAVE= updateTP=false addToHistory=true
if [[ $1 == --test ]]; then # {{{
  shift && ( set -xv; "$@"; )
  exit $?
elif [[ $1 == --helper ]]; then
  shift
  "$@"
  exit $?
fi # }}}
readConfiguration
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  @@) # {{{
    params=($@) i=3 first=true
    [[ -z ${params[$i]} ]] && i=$(($i-1))
    while [[ ! -z ${params[$i]} ]]; do
      [[ ${params[$i]} == [0-9]* && $first == 'true' ]] && wNr="${params[$i]}" && break
      [[ ${params[$i],,} == '-j' || ${params[$i],,} == '-jj'  || ${params[$i],,} == '--issue' ]] && issue="${params[$(($i+1))]}" && break
      [[ ${params[$i]} == '-l' ]] && issue="$(tmux list-windows -F '#{window_flags} #W' | command grep "^-" | cut -d\  -f2)" && break
      i=$(($i+1))
      first=false
    done
    break;; # }}}
  @ | @*) # {{{
    [[ $1 == @ ]] && do_wait="$1" || do_wait="${1#@}"
    shift; break ;; # }}}
  --help) # {{{
    echo "Extra switches:"
    echo "  -r         - reset configuration"
    echo "  [0-9]+     - get issue from window number"
    echo "  -L         - get issue from last selected window"
    echo "  -j, -jj    - specify the issue (--issue)"
    echo "  -J, -Jj    - specify the issue, set it as default for next calls"
    echo "  ??         - browse through all issues"
    echo "  --hist     - browse history (one of: --hist | --hist-issue | --hist-full)"
    echo "               and acronyms: -h | h | -hf | hf"
    echo "  --kb       - set knowledge base"
    echo "  --KB       - set knowledge base, set it as default for next calls"
    echo "  --setup    - setup an issue"
    echo "  --init     - more-less like '--setup' but for a list of issues"
    echo "  --pred     - use one of predefined shortcuts"
    echo "  --loop, -l - loop mode"
    echo "  -v         - verbosity, level 1"
    echo "  -vv        - verbosity, level 2"
    echo "  -vvv       - verbosity, level 3"
    echo "  -n         - dry run (if supported in a command)"
    echo
    exit 0;; # }}}
  \?\?) # {{{
    do_grep=true; shift; [[ ! -z $1 ]] && issue="$@" && shift $#;; # }}}
  [0-9]*)   wNr=$1;;
  -v)       verbose=1; echorm + 1;;
  -vv)      verbose=2; echorm + 2;;
  -vvv)     verbose=3; echorm + 3 -xv;;
  -n)       export TICKET_CONF_DRY=true;;
  -j | -jj | -J | -JJ | -Jj | --issue)  # {{{
    cmd="$1"; shift; fallback=false
    [[ $cmd == -J* ]] && fallback=true
    if [[ ! -z $1 && $1 != '-' ]]; then # {{{
      i="$(getIssue "$1" true)"
      [[ -z $i ]] && echore "Ticket for [$1] not found" && exit 1 # }}}
    else # {{{
      i="$(filterIssues)"
      [[ -z $i ]] && exit 0
      fallback=true
    fi # }}}
    if [[ ! -z $i ]]; then # {{{
      if [[ -z $issue ]]; then
        issue="$i"
        $fallback && ISSUE_FALLBACK="$issue"
      else
        issue+=" $i"
      fi
    fi # }}}
    if $fallback; then # {{{
      saveConfiguration
      [[ -z $2 ]] && exit 0
    fi # }}}
    ;; # }}}
  -L)  # {{{
    i="$(tmux list-windows -F '#{window_flags} #W' | command grep "^-" | cut -d\  -f2)"
    issue="$(getIssue "$i" true)"
    [[ -z $issue ]] && echore "Ticket for [$i] not found" && exit 1
    ISSUE_FALLBACK="$issue"
    saveConfiguration
    [[ -z $2 ]] && exit 0 ;; # }}}
  --loop=-) loopBreakOnErr=true; loop=true;; # by purpose NOT ;;&
  --loop=*) # {{{
    loopTimeout=${1#--loop=}
    [[ $loopTimeout == '-'* ]] && loopBreakOnTimeout=true && loopTimeout=${loopTimeout#-};;& # }}}
  --loop-max=*)            loopMax=${1#--loop-max=};;&
  -l | --loop | --loop*=*) loop=true;;
  -r) # {{{
    reset_only=true; ISSUE_FALLBACK=""; TICKET_PATH_SAVE="$TICKET_PATH_ORIG"
    saveConfiguration
    exit 0;; # }}}
  --KB) # {{{
    updateTP=true;;& # }}}
  --kb | --KB) # {{{
    shift; [[ ! -z $1 ]] || exit 1
    kb="$(echo " $KB_PATHS " | sed -ne "s/.* $1:\([^ ]*\) .*/\1/p")"
    [[ ! -z $kb ]] || exit 1
    export TICKET_PATH="$kb"
    $updateTP && TICKET_PATH_SAVE="$kb"
    saveConfiguration
    [[ -z $2 ]] && exit 0 ;; # }}}
  --setup) # {{{
    shift; issue=""; list="$@"
    case $list in
    -) # {{{
      list="$(echo $(filterIssues))";;& # }}}
    '') # {{{
      [[ -z $TICKET_LIST ]] && export TICKET_LIST="$TICKET_TOOL_PATH/list-basic.sh"
      list="$($TICKET_LIST)";;& # }}}
    - | '') # {{{
      [[ -z $list ]] && exit 0
      issue="${list%% *}";; # }}}
    *) # {{{
      issue="$1"
      [[ $# -gt 1 ]] && issue="${@: -1}"
      issue="${issue%/}";; # }}}
    esac
    for i in $list; do
      $TICKET_TOOL_PATH/ticket-setup.sh --open ${i//\/}
    done
    [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue" && saveConfiguration
    exit 0;; # }}}
  --init) # {{{
    shift; issue="${1%/}"
    $TICKET_TOOL_PATH/setup.sh --open "${@//\/}"
    [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue" && saveConfiguration
    exit 0;; # }}}
  --pred | -p) # {{{
    key="$2"; shift 2
    [[ -z $key ]] && key="$(while read v; do [[ ! -z $v ]] && echo "${v%%:*}"; done < <(echo -e "$TICKET_J_PREDEFINED") | fzf -0)"
    [[ -z $key ]] && exit 0
    found=false v=
    while read v; do
      [[ $key == ${v%%:*} ]] && found=true && break
    done < <(echo -e "$TICKET_J_PREDEFINED")
    if $found; then
      body=${v#*:}
      if [[ $1 == '-' ]]; then
        body="$(echo "$body" | sed 's/\(.*\s\+-[jJ]\{1,2\}\s\+[^ ]\+\).*/\1/')"
        shift
      fi
      $0 $body "$@"
    fi
    exit 0;; # }}}
  --hist | --hist-issue | --hist-full | -h | h | -hf | hf) # {{{
    do_history=true
    break ;; # }}}
  --no-hist) # {{{
    addToHistory=false;; # }}}
  --get-current-issue) # {{{
    getIssueID
    exit 0;; # }}}
  *) break;;
  esac
  shift
done # }}}
eval $(echorm -f?var dbg_j)
if [[ "$TICKET_PATH_SAVE" != "$TICKET_PATH_ORIG" && "$1" != '@@' ]]; then # {{{
  echore "Using KB from $TICKET_PATH"
  echore
fi # }}}
if $do_grep; then # {{{
  files= res= file= list=
  [[ -z $issue && ! -z $wNr ]] && issue="$(getIssue "$(tmux display-message -p -F '#W' -t :$wNr 2>/dev/null)" true)"
  if [[ ! -z $issue ]]; then
    for i in $issue; do
      files+=" $($TICKET_TOOL_PATH/ticket-setup.sh --get-path "$i" true)"
      list="${issue// /\\|}"
    done
  else
    files="$(getIssuesRaw)"
    files="$(ls -t $files)"
  fi
  [[ -z $files ]] && echore "No files were found" && exit 0
  [[ -t 1 ]] && tmux delete-buffer -b 'ticket-data' 2>/dev/null
  kb_file="$APPS_CFG_PATH/kb-data--${TICKET_PATH##*/}-info.db" kb_mod="0"
  [[ ! -e "$kb_file" ]] && touch -d '2000-01-01' "$kb_file"
  kb_mod="$(stat -c %Y "$kb_file")"
  tmpFile="$TMP_MEM_PATH/t-info.tmp"
  export colorsOn=false
  issues_newer=
  for file in $files; do # {{{
    [[ $(stat -c %Y "$file") -le $kb_mod ]] && break
    issue=${file##*/} && issue=${issue#.} && issue=${issue%-data.txt}
    sed -i "/^$issue:/ d" "$kb_file"
    issues_newer+="$issue\n"
  done # }}}
  if [[ ! -z $issues_newer ]]; then
    f_dot=$TMP_MEM_PATH/j-grep.$$
    exec 3<> $f_dot
    progress-dot --init
    ( tail --pid=$$ -q -F $f_dot | while read l; do progress-dot; done; rm -f $f_dot ) &
    s="$TICKET_TOOL_PATH/ticket-tool.sh --issue \$issue"
    echo -e "$issues_newer" | work-parallel.sh --lines-max 6 \
      "cat - | while read issue; do [[ -z \$issue ]] && continue; echo '.' >&3; $s ? \$($s ? | tr ' ' '\n' | sort -u | tr '\n' ' ') | sed -e '/^[^:]*:#/d' -e '/# IGN$/d' -e '/:echorm/d' | eval sed -e 's/^/\$issue:/'; done" \
    >"$tmpFile"
    [[ -e $kb_file ]] && cat "$kb_file" >> "$tmpFile"
    mv "$tmpFile" "$kb_file"
    progress-dot --end
    exec 3>&-
  fi
  if [[ -t 1 ]]; then # {{{
    tmpFile="$TMP_MEM_PATH/kb-grep.txt"
    { [[ -z "$list" ]] && cat "$kb_file" || command grep "^\($list\):" "$kb_file"; } | \
      fzf -i --exit-0 --no-sort --multi --ansi --height 100% --prompt='Tickets> ' \
        --preview "fzf_wrapper {} {q} -c prev --prev 20" \
        --preview-window 'hidden' \
        --bind "f1:execute(fzf_wrapper {1} -c less >/dev/tty)" \
        --bind "f2:execute(fzf_wrapper {1} -c vim </dev/tty >/dev/tty)" \
        --bind "f3:execute(fzf_wrapper {1} -c pane >/dev/tty)" \
      | sed \
          -e 's/[^:]*:[^:]*://' \
          -e 's/^\([^()]*)\)\?\s*\$/j /' \
          -e 's/\s*;;.*//' >"$tmpFile"
      tmux load-buffer -b 'ticket-data' "$tmpFile"
      if [[ $(wc -l "$tmpFile" 2>/dev/null | cut -d' ' -f1) -gt 1 ]]; then
        vim --fast "$tmpFile"
      fi
  else
    [[ -z "$list" ]] && cat "$kb_file" || command grep "^\($list\):" "$kb_file"
  fi # }}}
  exit 0
fi # }}}
if [[ -z $issue ]]; then # {{{
  if [[ ! -z $wNr ]]; then # {{{
    issue="$(getIssue "$(tmux display-message -p -F '#W' -t :$wNr 2>/dev/null)" true)"
    [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue"
    [[ -z $1 ]] && saveConfiguration && exit 0
    # }}}
  else # {{{
    issue="$(getIssueID)"
  fi # }}}
  # }}}
else # {{{
  [[ ! -f $issue ]] && issue="$(getIssue "$issue")"
fi # }}}
export verbose
source $TICKET_TOOL_PATH/common
if [[ -z $TICKET_CONF_HISTFILE ]]; then
  [[ ! -z $TICKET_TMUX_SESSION ]] && export TICKET_CONF_HISTFILE="$APPS_CFG_PATH/kb-${TICKET_TMUX_SESSION,,}.hist"
elif [[ $TICKET_CONF_HISTFILE == '-' ]]; then
  TICKET_CONF_HISTFILE=
fi
[[ -z $path_issue ]] && path_issue="$($TICKET_TOOL_PATH/ticket-setup.sh --get-path "$issue" true)"
[[ -z $issue_file ]] && issue_file=$(getIssueFile 2>/dev/null)
export path_issue issue_file
if [[ $1 == '@@' ]]; then # {{{
  ret= param="$3"
  if [[ -z $4 || "$(echo "${@:4}" | sed -e 's/ = /=/g' | tr ' ' '\n' | grep -v '^-' | wc -l)" == 0 ]]; then # {{{
    ret="--help ?? -j -jj -J -Jj --issue -L -r --kb --KB --setup --init --pred -p -l --loop --loop= --loop=- --loop-max= -n"
    [[ ! -z "$TICKET_CONF_HISTFILE" ]] && ret+=" --no-hist $(echo --hist{,-full,-issue}  {-,}{h,hl,hf})"
    if [[ -z "$(getIssue "$(tmux display-message -p -t $TMUX_PANE -F '#W')" true)" ]]; then
      i=1 is= issue_list=":"
      for is in $(tmux list-windows -F '#W'); do
        is="$(getIssue "$is" true)"
        if [[ ! -z "$is" ]] && ! echo "$issue_list" | command grep -q ":$is:"; then
          ret+=" $i"
          issue_list+="$is:"
        fi
        i=$(($i+1))
      done
    fi
  fi # }}}
  kb="$(echo " $@ " | sed -n -e 's/.* --kb \+\([^ ]\+\).*/\1/Ip')"
  kb="$(echo " $KB_PATHS " | sed -ne "s/.* $kb:\([^ ]*\) .*/\1/p")"
  [[ ! -z $kb ]] && export TICKET_PATH="$kb"
  issue="${issue,,}"
  case $4 in # {{{
  --setup | --init | \?\?) param="$4";;
  esac # }}}
  case $param in # {{{
  --pred | -p) # {{{
    ret=
    while read v; do
      ret+="${v%%:*} "
    done < <(echo -e "$TICKET_J_PREDEFINED") ;; # }}}
  --kb | --KB) # {{{
    ret="$( echo " $KB_PATHS " | sed 's/:[^ ]* / /g')" ;; # }}}
  -jj | -JJ | -Jj | --setup | --init | \?\? | --issue) # {{{
    ret=
    case $param in
    --setup) # {{{
      ret=" - --title --recreate"
      ${TICKET_SETUP_ALWAYS:-false}  && ret+=" --no-always" || ret+=" --always"
      ${TICKET_SETUP_DONE:-false}    && ret+=" --no-done"   || ret+=" --done"
      ${TICKET_SETUP_HIDDEN:-false}  && ret+=" --no-hide"   || ret+=" --hide"
      ${TICKET_SETUP_MINIMAL:-false} && ret+=" --no-min"    || ret+=" --min"
      ;;& # }}}
    esac
    files="$(getIssues)"
    ret+=" $files" ;; # }}}
  -j | -J) # {{{
    marker="$TMP_MEM_PATH/j-cmd-marker.$$"
    touch -t $(command date +"%Y%m%d%H%M.%S" -d "1 month ago") $marker
    files="$(getIssues -newer $marker)"
    rm $marker
    files+=" $(command grep -l '^# j-info:.* ALWAYS-INCLUDE' $(getIssuesRaw) | sed -e 's|.*/\.\{0,1\}||' -e 's|-data\.txt||')"
    ret=" $files";; # }}}
  --hist | --hist-full | --hist-issue | -h ) # {{{
    ret=" -l --loop";;& # }}}
  --hist | --hist-full | --hist-issue | -h | h | -hf | hf ) # {{{
    ret=" --clean - 10 20 50 100 500 1000";; # }}}
  -l) shift;&
  *) # {{{
    if [[ ${1,,} == '--kb' ]]; then
      shift 2
      issue="$(getIssue $2 true)"
    fi
    [[ -z $issue ]] && issue="$(getIssue $3 true)"
    end=$3
    $dbg_j && echorm 1 "\nargs-j-in=[$@], e=[$end]"
    shift 3
    [[ $end == [0-9]* ]] && end=
    while [[ ! -z $1 ]]; do
      case $1 in
      -*) [[ $2 == '=' ]] && shift 2;;
      [0-9]*) ;;
      *) break;;
      esac
      shift
    done
    [[ $1 == $issue ]] && shift
    [[ $1 == '@@' ]] && shift
    $dbg_j && echorm 1 "\nargs-j-out=[$@]"
    $dbg_j && echorm -l2 -xv
    if [[ ! -z $issue ]]; then
      isInstalled -t completionCacheInvocation || source $TICKET_TOOL_PATH/completion-cache
      eval $(completionCacheInvocation)
      completionCacheLoad
      key="$@"; [[ -z $key ]] && key="@@"; key="${key// /-}"
      ret1="${complMap[$key]}"
      if [[ -z $ret1 ]]; then
        ret1="$($TICKET_TOOL_PATH/ticket-tool.sh --issue $issue '@@' $@)"
        completionCacheUpdate "$key" "$ret1"
      fi
      [[ -z $@ ]] && ret+=" $ret1" || ret="$ret1"
    fi
    $dbg_j && echorm -l2 +xv
    ;; # }}}
  esac # }}}
  echo "$ret"
  exit
  # }}}
elif $do_history; then # {{{
  [[ -z "$TICKET_CONF_HISTFILE" || ! -s "$TICKET_CONF_HISTFILE" ]] && echore "Empty history" && exit 0
  count=100
  cmd="$1" && shift
  loop=true
  case $cmd in
  --hist | -h | h)         cmd='hist';;&
  --hist-full | -hf | hf)  cmd='hist-full';;&
  --hist-issue)            cmd='hist-issue';;
  -h | h | --hist | -hf | hf) loop=true;;
  esac
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -l | --loop) loop=false;;
    --clean)     cat -n "$TICKET_CONF_HISTFILE" | sed -e '/# [0-9]\+$/d' | sort -k2 -u | sort -k1,1n | cut -c8-;;
    -)           count=;;
    *) # {{{
      if [[ $1 =~ ^[0-9]+$ ]]; then
        count="$1"
      fi;; # }}}
    esac
    shift
  done # }}}
  fzf_params="-0 --cycle --prompt 'Ticket history> ' -m --no-sort --expect 'ctrl-r' --expect 'ctrl-d'"
  check_file="$TMP_MEM_PATH/.j-cmd-sh.$$.tmp"
  [[ ! -z "$issue" && "$cmd" != 'hist-issue' ]] && fzf_params+=" --query='$issue '"
  while true; do
    rm -f "$check_file"
    items=$( \
      cat "$TICKET_CONF_HISTFILE" \
      | sed -e '/^\s*$/d' -e '/^#/d' -e 's/\s\s\+/ /' \
      | if [[ $cmd == 'hist' ]]; then
          tail -n${count:-100}
        elif [[ $cmd == 'hist-issue' && ! -z $issue ]]; then
          grep "$issue" | tail -n$count
        else
          if [[ ! -z $count && $count != 100 ]]; then
            tail -n$count
          else
            cat -
          fi
        fi \
      | tac - \
      | eval fzf $fzf_params)
    [[ $? != 0 || -z "$items" ]] && break
    key="$(echo "$items" | head -n1)"
    case $key in
    ctrl-r) continue;;
    ctrl-d) break;;
    esac
    items="$(echo "$items" | tail -n +2)"
    [[ -z "$items" ]] && break
    echo "$items" \
    | while read -r l; do
        [[ ! -e "$check_file" ]] && touch "$check_file"
        l="${l%% #*}"
        $dbg_j && echorm 1 "Executing '$l'"
        l_eval="$l"
        case $l in
        j\ *) l_eval="${l_eval/j /$TICKET_TOOL_PATH/j-cmd.sh }";;
        esac
        $dbg_j && echorv -M 2 l_eval
        $dbg_j && echorm -xv
        eval "$l_eval"
        err=$?
        $dbg_j && echorm +xv
        saveInHistory "$l" "$err"
      done
      if ! $loop || [[ ! -e "$check_file" ]]; then
        break
      fi
  done
  rm -f "$check_file"
  exit 0
  # }}}
elif [[ ! -z $do_wait ]]; then
  eval $TICKET_TOOL_PATH/ticket-tool.sh --issue $issue wait-on "$do_wait" \"$@\"
  exit
fi # }}}
[[ -z $issue ]] && echore "Ticket not found" && exit 1
saveConfiguration
$dbg_j && echorm 1 "i=[$issue] params=[$@]"
$dbg_j && echorm -l2 -xv
args=
for i; do # {{{
  i="$(echo -e "$i" | sed -e 's/"/\\"/g' -e 's/'"'"'/\\'"'"'/g')"
  [[ $i == *\ * ]] && args+=" \"$i\"" || args+=" $i"
done # }}}
args="${args# }"
historySaved=false
loopI=1
export TICKET_CONF_IN_LOOP=$loop
while true; do # {{{
  $TICKET_TOOL_PATH/ticket-tool.sh --issue $issue "$@"
  err=$?
  l="j -j $issue $args"
  if ! $historySaved; then # {{{
    saveInHistory "$l" "$err"
    historySaved=true
  fi # }}}
  $loop || break
  c=$CGreen; [[ $err != 0 ]] && c=$CRed
  if false \
     || ( [[ ! -z $loopMax && $loopI == $loopMax ]] ) \
     || ( $loopBreakOnErr && [[ $err != 0 ]] ); then
    echo "$c$(printf "%02d" $loopI)$([[ ! -z $loopMax ]] && printf "/%02d" $loopMax)$COff End" && break
  fi
  key=$(progress --msg "$c$(printf "%02d" $loopI)$([[ ! -z $loopMax ]] && printf "/%02d" $loopMax)$COff Run again ?" --keys yY $([[ ! -z $loopTimeout ]] && echo "--wait $loopTimeout"))
  case $? in # {{{
  0)   true;;
  11)  ! $loopBreakOnTimeout;;
  12)  [[ -z $key || ${key,,} == 'y' ]];;
  *)   false;;
  esac || break # }}}
  loopI=$((loopI+1))
done # }}}
$dbg_j && echorm -l2 +xv
exit $err

