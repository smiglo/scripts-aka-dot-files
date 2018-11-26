#!/bin/bash
# vim: fdl=0

putOnList() { # {{{
  [[ -z $1 ]] && return 0
  local ticket_list="$TMP_MEM_PATH/${TICKET_PATH##*/}-list.txt" i= silent=false
  [[ ! -e "$ticket_list" ]] && touch "$ticket_list"
  [[ $1 == '-s' ]] && silent=true && shift
  if [[ $# == 1 ]]; then
    if ! command grep -q "^${1}$" "$ticket_list"; then
      { cat "$ticket_list"; echo "$1"; } | sort -u >"${ticket_list}"
    fi
  else
    local l="$@"
    { cat "$ticket_list"; echo -e "${l// /\\n}"; } | sort -u >"${ticket_list}"
  fi
  ! $silent && echo "$@"
} # }}}
getIssue() { # {{{
  local p= ext= i= ii= quick_check="${2:-false}" ticket_list="$TMP_MEM_PATH/${TICKET_PATH##*/}-list.txt"
  [[ ! -e "$ticket_list" ]] && touch "$ticket_list"
  i="$(echo ${1,,})"
  [[ $i == *\ * ]] && return 0
  [[ $i == *--* ]] && i="${i%%--*}"
  local list="$i"
  if [[ $i == *-* ]]; then
    ii="$(echo "$i" | cut -d'-' -f1,2)"
    [[ $i != $ii ]] && list+=" $ii"
  fi
  for ii in $list; do # {{{{
    command grep -q "^${ii}$" "$ticket_list" && echo "$ii" && return 0
  done # }}}
  for ii in $list; do # {{{
    [[ -e "$TICKET_PATH/$ii/${ii}-data.txt" || -e "$TICKET_PATH/$ii/.${ii}-data.txt" ]] && putOnList "$ii" && return 0
    local r="$(command find $TICKET_PATH -maxdepth 4 -path "*/${ii}/${ii}-data.txt" | head -n1)"
    [[ ! -z $r ]] && putOnList "$ii" && return 0
  done # }}}
  $quick_check && return 0
  for ii in $list; do # {{{
    for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
      p="$($ext --ticket-path $ii)"
      [[ ! -z $p && ( -e "$p/${ii}-data.txt" || -e "$p/.${ii}-data.txt" ) ]] && putOnList "$ii" && return 0
    done # }}}
  done # }}}
  return 0
} # }}}
findDataFiles() { # {{{
  find $TICKET_PATH \
    -maxdepth 4 \
    $(find $TICKET_PATH \
        -mindepth 2 -maxdepth 4 -name '.ticket-data.sh' \
      | sed -e 's|\(.*\)/[^/]*|-path \1|' -e 's/$/ -prune -o/' \
      | tr '\n' ' ') \
    -name \*data.txt -print
} # }}}
getIssuesRaw() { # {{{
  local i= params="$@" n= l=
  for i in $(findDataFiles); do
    n="$(basename "$(dirname "$i")")"
    [[ "${n}-data.txt" == "${i/*\/}" || ".${n}-data.txt" == "${i/*\/}" ]] || continue
    echo "$i"
    l+=" $n"
  done
  putOnList -s $l
  return 0
} # }}}
getIssues() { # {{{
  getIssuesRaw $@ | sed -e 's|.*/||' -e 's|-data\.txt||' -e 's|^\.||' | sort
  return 0
} # }}}
fzf_wrapper() { # {{{
  local t="$(echo "$1" | sed 's/\([^:]*:[^:]*\):.*/\1/')"
  local s="${t#*:}"
  local i="${1#*$s:}"
  t="${t%:*}"
  local f="$(find $TICKET_PATH -maxdepth 4 -name "${t}-data.txt" | head -n1)"
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
    if [[ ! -z $qi && $qi != !* ]]; then
      echo -e "\t---  $t : ${i}.* $qi ---" && echo
      $BASH_PATH/aliases fzf_exe -f "$f" "$@" | $BASH_PATH/aliases hl +cGold "# $s -\{0,1\}\# {{[{].*" $([[ ! -z $i ]] && echo "+cC \"$i.*\"") +cG "$qi" # For vim # }} }
    else
      echo -e "\t---  $t : ${i}.* ---" && echo
      $BASH_PATH/aliases fzf_exe -f "$f" "$@" | $BASH_PATH/aliases hl +cGold "# $s -\{0,1\}\# {{[{].*" +cC "$i.*" # For vim # }} }
    fi
  else
    $BASH_PATH/aliases fzf_exe -f "$f" "$@"
  fi
}
export -f fzf_wrapper
# }}}
readConfiguration() { # {{{
  local confFile="$TMP_MEM_PATH/ticket-tool-j.conf"
  [[ -e $confFile ]] || return 0
  source <(sed  -n "/^# ${TICKET_PATH//\//\\\/} #/,/^# ${TICKET_PATH//\//\\\/} #/ p" $confFile)
} # }}}
saveConfiguration() { # {{{
  local confFile="$TMP_MEM_PATH/ticket-tool-j.conf"
  [[ -e $confFile ]] && sed -i "/^# ${TICKET_PATH//\//\\\/} #/,/^# ${TICKET_PATH//\//\\\/} #/ d" $confFile
  (
    echo "# $TICKET_PATH #"
    echo "export ISSUE_FALLBACK=\"$ISSUE_FALLBACK\""
    echo "# $TICKET_PATH #"
  ) >> $confFile
} # }}}
verbose=${TICKET_J_VERBOSE:-0} issue= wNr= i= do_grep=false reset_only=false
readConfiguration
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  [0-9]*)   wNr=$1;;
  -v)       verbose=1;;
  -vv)      verbose=2;;
  -vvv)     verbose=3; set -xv;;
  -j | -jj | \
  -J | -JJ) cmd="$1"; i="$(getIssue $2 true)"; shift
            if [[ ! -z $i ]]; then
              if [[ -z $issue ]]; then
                issue="$i"
                [[ $cmd == '-J' || $cmd == '-JJ' ]] && ISSUE_FALLBACK="$issue"
              else
                issue+=" $i"
              fi
            fi;;
  -l)       issue="$(tmux list-windows -F '#{window_flags} #W' | command grep "^-" | cut -d\  -f2)"
            [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue";;
  -r)       reset_only=true; ISSUE_FALLBACK=""
            saveConfiguration
            exit 0;;
  --setup)  shift; issue="$1"
            [[ $# -gt 1 ]] && issue="${@: -1}"
            $TICKET_TOOL_PATH/ticket-setup.sh --open "$@"
            [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue" && saveConfiguration
            exit 0;;
  --init)   shift; issue="$1"
            $TICKET_TOOL_PATH/setup.sh --open "$@"
            [[ ! -z $issue ]] && ISSUE_FALLBACK="$issue" && saveConfiguration
            exit 0;;
  \?\?)     do_grep=true; shift; [[ ! -z $1 ]] && issue="$@" && shift $#;;
  -h) # {{{
    echo "Extra switches:"
    echo "  [0-9]+     - get issue from window number"
    echo "  -v         - verbosity, level 1"
    echo "  -vv        - verbosity, level 2"
    echo "  -vvv       - verbosity, level 3"
    echo "  -j, -jj    - specify the issue"
    echo "  -J, -JJ    - specify the issue, set it as default for next calls"
    echo "  -l         - get issue from last selected window"
    echo "  -r         - reset configuration"
    echo "  --setup    - setup an issue"
    echo "  ??         - grep through all issues"
    echo
    exit 0;; # }}}
  @@) # {{{
    if [[ $3 == [0-9]* ]]; then
      wNr="$3"
    elif [[ $5 == [0-9]* ]]; then
      wNr="$5"
    else
      params=($@)
      i=3
      while [[ ! -z ${params[$i]} ]]; do
        [[ ${params[$i]} == [0-9]* ]] && wNr=${params[$i]} && break
        [[ ${params[$i],,} == '-j' || ${params[$i],,} == '-jj' ]] && issue="${params[$(($i+1))]}" && break
        [[ ${params[$i]} == '-l' ]] && issue="$(tmux list-windows -F '#{window_flags} #W' | command grep "^-" | cut -d\  -f2)" && break
        i=$(($i+1))
      done
    fi
    break;; # }}}
  *)        break;;
  esac
  shift
done # }}}
[[ $verbose -ge 3 ]] && set -xv
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
  kb_file="$TMP_PATH/kb-${TICKET_PATH##*/}-info.db" updated=false kb_mod="0"
  [[ ! -e "$kb_file" ]] && touch -d '2000-01-01' "$kb_file"
  kb_mod="$(stat -c %Y "$kb_file")"
  $BASH_PATH/aliases progress --mark --dots --out /dev/stderr --msg "Updating DB"
  for file in $files; do # {{{
    issue="$(echo "$file"| sed -e 's|.*/||' -e 's|-data\.txt||' -e 's|^\.||')"
    list+="$issue\|"
    [[ $(stat -c %Y "$file") -le $kb_mod ]] && continue
    sed -i "/^$issue:/ d" "$kb_file"
    $TICKET_TOOL_PATH/ticket-tool.sh --issue $issue \
      ? $(echo "env r-edit $($TICKET_TOOL_PATH/ticket-tool.sh --issue $issue ?)" | tr ' ' '\n' | sort | tr '\n' ' ') \
      | sed -e "s/^/$issue:/" >>"$kb_file"
    updated=true
  done # }}}
  $updated && sort -t':' -k1,1 -s "$kb_file" >"${kb_file}.tmp" && mv "${kb_file}.tmp" "$kb_file"
  $BASH_PATH/aliases progress --unmark
  sleep 0.3
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
  if [[ $2 == 1 ]]; then # {{{
    ret="-h ?? -j -jj -J -JJ -l -r --setup --init"
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
  issue="${issue,,}"
  case $4 in # {{{
  --setup | --init) param="$4";;
  esac # }}}
  case $param in
  --setup) # {{{
    ret+=" --title --recreate"
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
    files+=" $(command grep -lF '^# j-info: .*[^-]ALWAYS-INCLUDE' $(getIssuesRaw) | sed -e 's|.*/||' -e 's|-data\.txt||')"
    ret+=" $files" ;; # }}}
  -jj | -JJ | --setup | --init | \?\?) # {{{
    files="$(getIssues)"
    ret+=" $files" ;; # }}}
  -l) shift;&
  *) # {{{
    [[ -z $issue ]] && issue="$(getIssue $3 true)"
    end=$3
    [[ $verbose -ge 1 ]] && echo -e "\nargs-j-in=[$@], e=[$end]" >/dev/stderr
    shift 3
    [[ $end == [0-9]* ]] && end=
    while [[ ! -z $1 && $1 != $end ]] && [[ $1 == -* || $1 == [0-9]* ]]; do
      shift
    done
    [[ $1 == $issue ]] && shift
    [[ $1 == '@@' ]] && shift
    [[ $verbose -ge 1 ]] && echo -e "\nargs-j-out=[$@]" >/dev/stderr
    [[ $verbose -ge 2 ]] && set -xv
    [[ ! -z $issue ]] && ret+=" $($TICKET_TOOL_PATH/ticket-tool.sh --issue $issue '@@' $@)"
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
$TICKET_TOOL_PATH/ticket-tool.sh --issue $issue "$@"
err=$?
[[ $verbose -ge 2 ]] && set +xv
exit $err

