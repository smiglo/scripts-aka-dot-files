#!/bin/bash
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
  if [[ $i == *-* ]]; then
    ii="$(echo "$i" | cut -d'-' -f1,2)"
    [[ $i != $ii ]] && list+=" $ii"
  fi
  for ii in $list; do # {{{
    command grep -q "^${ii}$" "$ticket_list" && echo "$ii" && return 0
    command grep -q "^-${ii}$" "$ticket_list" && return 0
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
      $BASH_PATH/aliases fzf_exe -f "$f" "$@" | $BASH_PATH/aliases hl +cGold "# $s -\{0,1\}\# {{[{].*" $([[ ! -z $i ]] && echo "+cC \"$i\"") +cG "$qi" # For vim # }} }
    else
      echo -e "\t---  $t : ${i} ---" && echo
      $BASH_PATH/aliases fzf_exe -f "$f" "$@" | $BASH_PATH/aliases hl +cGold "# $s -\{0,1\}\# {{[{].*" +cC "$i" # For vim # }} }
    fi
  else
    $BASH_PATH/aliases fzf_exe -f "$f" "$@"
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
  local confFile="$TMP_MEM_PATH/kb-data-j.conf" tp="${TICKET_PATH_ORIG:-$TICKET_PATH}"
  [[ -e $confFile ]] && sed -i "/^# ${tp//\//\\\/} #/,/^# ${tp//\//\\\/} #/ d" $confFile
  (
    echo "# $tp #"
    echo "export ISSUE_FALLBACK=\"$ISSUE_FALLBACK\""
    echo "export TICKET_PATH_SAVE=\"${TICKET_PATH_SAVE:-$TICKET_PATH}\""
    echo "export TICKET_PATH_ORIG=\"$tp\""
    echo "# $tp #"
  ) >> $confFile
} # }}}
verbose=${TICKET_J_VERBOSE:-0} issue= wNr= i= do_grep=false reset_only=false
TICKET_PATH_ORIG= TICKET_PATH_SAVE= updateTP=false subcmd=
# subcmd="$TICKET_J_DEFAULT_SUBCMD"
if [[ $1 == --test ]]; then # {{{
  shift && ( set -xv; "$@"; )
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
      [[ ${params[$i],,} == '-j' || ${params[$i],,} == '-jj' ]] && issue="${params[$(($i+1))]}" && break
      [[ ${params[$i]} == '-l' ]] && issue="$(tmux list-windows -F '#{window_flags} #W' | command grep "^-" | cut -d\  -f2)" && break
      i=$(($i+1))
      first=false
    done
    break;; # }}}
  -h) # {{{
    echo "Extra switches:"
    echo "  -r         - reset configuration"
    echo "  [0-9]+     - get issue from window number"
    echo "  -l         - get issue from last selected window"
    echo "  -j, -jj    - specify the issue"
    echo "  -J, -Jj    - specify the issue, set it as default for next calls"
    echo "  ??         - browse through all issues"
    echo "  --kb       - set knowledge base"
    echo "  --KB       - set knowledge base, set it as default for next calls"
    echo "  --setup    - setup an issue"
    echo "  --init     - more-less like '--setup' but for a list of issues"
    echo "  --pred     - use one of predefined shortcuts"
    echo "  -v         - verbosity, level 1"
    echo "  -vv        - verbosity, level 2"
    echo "  -vvv       - verbosity, level 3"
    echo
    exit 0;; # }}}
  \?\?) # {{{
    do_grep=true; shift; [[ ! -z $1 ]] && issue="$@" && shift $#;; # }}}
  [0-9]*)   wNr=$1;;
  -v)       verbose=1;;
  -vv)      verbose=2;;
  -vvv)     verbose=3; set -xv;;
  -j | -jj | -J | -JJ | -Jj)  # {{{
    cmd="$1"; shift; fallback=false
    [[ $cmd == -J* ]] && fallback=true
    if [[ ! -z $1 && $1 != '-' ]]; then # {{{
      i="$(getIssue "$1" true)"
      [[ -z $i ]] && echo "Ticket for [$1] not found" >/dev/stderr && exit 1 # }}}
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
  -l)  # {{{
    i="$(tmux list-windows -F '#{window_flags} #W' | command grep "^-" | cut -d\  -f2)"
    issue="$(getIssue "$i" true)"
    [[ -z $issue ]] && echo "Ticket for [$i] not found" >/dev/stderr && exit 1
    ISSUE_FALLBACK="$issue"
    saveConfiguration
    [[ -z $2 ]] && exit 0 ;; # }}}
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
    if [[ $list == '-' ]]; then
      list="$(echo $(filterIssues))"
      [[ -z $list ]] && exit 0
      issue="${list%% *}"
    else
      issue="$1"
      [[ $# -gt 1 ]] && issue="${@: -1}"
      issue="${issue%/}"
    fi
    $TICKET_TOOL_PATH/ticket-setup.sh --open ${list//\/}
    [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue" && saveConfiguration
    exit 0;; # }}}
  --init) # {{{
    shift; issue="${1%/}"
    $TICKET_TOOL_PATH/setup.sh --open "${@//\/}"
    [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue" && saveConfiguration
    exit 0;; # }}}
  --pred | -p | @* ) # {{{
    [[ $1 == @* ]] && { key="${1#@}"; shift 1; } || { key="$2"; shift 2; }
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
  -) subcmd='';;
  *) break;;
  esac
  shift
done # }}}
[[ $verbose -ge 3 ]] && set -xv
if [[ "$TICKET_PATH_SAVE" != "$TICKET_PATH_ORIG" && "$1" != '@@' ]]; then # {{{
  echo "Using KB from $TICKET_PATH" >/dev/stderr
  echo
fi # }}}
if $do_grep; then # {{{
  files= res= file= list=
  [[ -z $issue && ! -z $wNr ]] && issue="$(getIssue "$(tmux display-message -p -F '#W' -t :$wNr 2>/dev/null)" true)"
  if [[ ! -z $issue ]]; then
    for i in $issue; do
      files+=" $($TICKET_TOOL_PATH/ticket-setup.sh --get-path "$i" true)"
    done
  else
    files="$(getIssuesRaw)"
  fi
  [[ -z $files ]] && echo "No files were found" >/dev/stderr && exit 0
  [[ -t 1 ]] && tmux delete-buffer -b 'ticket-data' 2>/dev/null
  kb_file="$APPS_CFG_PATH/kb-data--${TICKET_PATH##*/}-info.db" updated=false kb_mod="0"
  [[ ! -e "$kb_file" ]] && touch -d '2000-01-01' "$kb_file"
  kb_mod="$(stat -c %Y "$kb_file")"
  $BASH_PATH/aliases progress --mark --dots --out /dev/stderr --msg "Updating DB"
  for file in $files; do # {{{
    issue="$(echo "$file"| sed -e 's|.*/\.\{0,1\}||' -e 's|-data\.txt||')"
    list+="$issue\|"
    [[ $(stat -c %Y "$file") -le $kb_mod ]] && continue
    sed -i "/^$issue:/ d" "$kb_file"
    $TICKET_TOOL_PATH/ticket-tool.sh --issue $issue \
      ? $($TICKET_TOOL_PATH/ticket-tool.sh --issue $issue ? | tr ' ' '\n' | sort -u | tr '\n' ' ') \
      | sed -e "s/^/$issue:/" >>"$kb_file"
    updated=true
  done # }}}
  $updated && sort -t':' -k1,1 -s "$kb_file" >"${kb_file}.tmp" && mv "${kb_file}.tmp" "$kb_file"
  $BASH_PATH/aliases progress --unmark
  if [[ -t 1 ]]; then # {{{
    command grep "^\(${list:0:-2}\):" "$kb_file" | \
      fzf -i --exit-0 --no-sort --multi --height 100% --prompt='Tickets> ' \
        --preview "fzf_wrapper {} {q} -c prev --prev 20" \
        --preview-window 'hidden' \
        --bind "f1:execute(fzf_wrapper {1} -c less >/dev/tty)" \
        --bind "f2:execute(fzf_wrapper {1} -c vim </dev/tty >/dev/tty)" \
        --bind "f3:execute(fzf_wrapper {1} -c pane >/dev/tty)" | \
        ( while read res; do tmux set-buffer -ab 'ticket-data' "$(echo "$res" | sed -e 's/[^:]*:[^:]*:\(.*\)/\1/' -e 's/^-/\\-/' -e 's/$//')"; done )
  else
    command grep "^\(${list:0:-2}\):" "$kb_file"
  fi # }}}
  exit 0
fi # }}}
if [[ -z $issue ]]; then # {{{
  if [[ ! -z $wNr ]]; then # {{{
    issue="$(getIssue "$(tmux display-message -p -F '#W' -t :$wNr 2>/dev/null)" true)"
    [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue"
    # }}}
  else # {{{
    # Get issue from current dir # {{{
    if [[ -z $issue ]]; then
      p="$PWD" f=
      while [[ $p == $TICKET_PATH* ]]; do
        f="${p##*/}"
        [[ -e "$p/${f}-data.txt" ]] && issue="$f" && break
        p="$(command cd "$p/.."; pwd)"
      done
    fi # }}}
    # Get issue from window name # {{{
    if [[ -z $issue ]]; then
      wnd_name="$(tmux display-message -p -t $TMUX_PANE -F '#W')"
      if [[ $wnd_name == *-* ]]; then
        issue="$(getIssue "$wnd_name")"
      else
        issue="$(getIssue "$wnd_name" true)"
      fi
    fi
    # }}}
    # Get issue from fallback issue # {{{
    if [[ -z $issue ]]; then
      [[ ! -z $ISSUE_FALLBACK ]] && issue="$(getIssue "$ISSUE_FALLBACK" true)"
    fi
    # }}}
    # Get issue from first matching window name # {{{
    if [[ -z $issue ]]; then
      wnd_name=
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
  # }}}
else # {{{
  [[ ! -f $issue ]] && issue="$(getIssue "$issue")"
fi # }}}
export verbose
if [[ $1 == '@@' ]]; then # {{{
  ret= param="$3"
  if [[ $2 == 1 || ${@: -2:1} == '--kb' || ${@: -2:1} == '--KB' ]]; then # {{{
    ret="-h ?? -j -jj -J -Jj -l -r --kb --KB --setup --init --pred -p"
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
    while read v; do
      [[ -z $v ]] && continue
      ret+=" @${v%%:*}"
    done < <(echo -e "$TICKET_J_PREDEFINED")
  fi # }}}
  kb="$(echo " $@ " | sed -n -e 's/.* --kb \+\([^ ]\+\).*/\1/Ip')"
  kb="$(echo " $KB_PATHS " | sed -ne "s/.* $kb:\([^ ]*\) .*/\1/p")"
  [[ ! -z $kb ]] && export TICKET_PATH="$kb"
  issue="${issue,,}"
  case $4 in # {{{
  --setup | --init) param="$4";;
  esac # }}}
  case $param in
  --pred) # {{{
    ret=
    while read v; do
      ret+="${v%%:*} "
    done < <(echo -e "$TICKET_J_PREDEFINED") ;; # }}}
  --kb | --KB) # {{{
    ret="$( echo " $KB_PATHS " | sed 's/:[^ ]* / /g')" ;; # }}}
  --setup) # {{{
    ret+=" - --title --recreate"
    ${TICKET_SETUP_ALWAYS:-false}  && ret+=" --no-always" || ret+=" --always"
    ${TICKET_SETUP_DONE:-false}    && ret+=" --no-done"   || ret+=" --done"
    ${TICKET_SETUP_HIDDEN:-false}  && ret+=" --no-hide"   || ret+=" --hide"
    ${TICKET_SETUP_MINIMAL:-false} && ret+=" --no-min"    || ret+=" --min"
    ;;& # }}}
  -j | -J) # {{{
    marker="$TMP_MEM_PATH/j-cmd-marker.$$"
    touch -t $(command date +"%Y%m%d%H%M.%S" -d "1 month ago") $marker
    files="$(getIssues -newer $marker)"
    rm $marker
    files+=" $(command grep -l '^# j-info:.* ALWAYS-INCLUDE' $(getIssuesRaw) | sed -e 's|.*/\.\{0,1\}||' -e 's|-data\.txt||')"
    ret+=" $files" ;; # }}}
  -jj | -JJ | -Jj | --setup | --init | \?\?) # {{{
    files="$(getIssues)"
    ret+=" $files" ;; # }}}
  -l) shift;&
  *) # {{{
    [[ -z $issue ]] && issue="$(getIssue $3 true)"
    end=$3
    [[ $verbose -ge 1 ]] && echo -e "\nargs-j-in=[$@], e=[$end]" >/dev/stderr
    shift 3
    if [[ ${1,,} == '--kb' ]]; then
      shift 2
      issue="$(getIssue $2 true)"
    fi
    [[ $end == [0-9]* ]] && end=
    while [[ ! -z $1 && $1 != $end ]] && [[ $1 == -* || $1 == [0-9]* ]]; do
      shift
    done
    [[ $1 == $issue ]] && shift
    [[ $1 == '@@' ]] && shift
    [[ $verbose -ge 1 ]] && echo -e "\nargs-j-out=[$@]" >/dev/stderr
    [[ $verbose -ge 2 ]] && set -xv
    if [[ ! -z $issue ]]; then
      ret1=" $($TICKET_TOOL_PATH/ticket-tool.sh --issue $issue '@@' $subcmd $@)"
      if [[ ! -z "$ret1" ]]; then
        ret+=" $ret1"
      elif [[ ! -z "$subcmd" ]]; then
        ret+=" $($TICKET_TOOL_PATH/ticket-tool.sh --issue $issue '@@' $@)"
      fi
    fi
    [[ $verbose -ge 2 ]] && set +xv
    ;; # }}}
  esac
  echo $ret
  exit
fi # }}}
[[ -z $issue ]] && echo "Ticket not found" >/dev/stderr && exit 1
saveConfiguration
[[ $verbose -ge 1 ]] && echo "i=[$issue] params=[$@]" >/dev/stderr
[[ $verbose -ge 2 ]] && set -xv
$TICKET_TOOL_PATH/ticket-tool.sh --issue $issue $subcmd "$@"
err=$?
if [[ $err != 0 && ! -z $subcmd ]] && $BASH_PATH/aliases progress --msg "Fallback command ($fallback) did not success, trying without it" --wait 2s --key; then
  $TICKET_TOOL_PATH/ticket-tool.sh --issue $issue "$@"
  err=$?
fi
[[ $verbose -ge 2 ]] && set +xv
exit $err

