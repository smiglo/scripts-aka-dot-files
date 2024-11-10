#!/usr/bin/env bash
# vim: fdl=0

# Initial checks & set up # {{{
mapCommand() { # {{{
  local cmd="$1" ret= ext=
  [[ $cmd == '@@' ]] && echo "@@" && return 0
  case $cmd in # {{{
  i)    ret='info';;
  e)    ret='edit';;
  ci)   ret='commit';;
  s)    ret='setup';;
  sh)   ret='shell';;
  tm)   ret='tmux';;
  *)    # {{{
        for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do
          ret="$($ext --map-cmd "$cmd")"
          [[ ! -z $ret ]] && break
        done
        if [[ -z $ret ]]; then
          local allCmds="$($cmd_tt @@ | tr ' ' '\n' | command grep "^[a-z]")"
          local shortcut= err=
          shortcut=$(mapShortCutToFull --all "$cmd" "$allCmds"); err=$?
          if [[ ! -z $shortcut ]]; then
            [[ $err == 0 ]] && ret="$shortcut" || echor -C "Multi-match for '%imp:{$cmd}': $shortcut"
          fi
        fi;; # }}}
  esac # }}}
  [[ -z $ret && -z $cmd ]] && ret='info'
  echo "${ret:-$cmd}"
} # }}}
getPathFast() { # {{{
  local path_issue="$TICKET_PATH/$issue"
  [[ -e "$path_issue/${issue}-data.txt" || -e "$path_issue/.${issue}-data.txt" ]] && echo "$path_issue" && return 0
  return 1
}
export -f getPathFast # }}}
echorm --name tt
[[ ! -z $verbose && $verbose -gt $(echorm -f??) ]] && echorm + $verbose
case $1 in
-v)   echorm + 1; shift;;
-vv)  echorm + 2; shift;;
-vvv) echorm + 3; shift;;
esac
eval $(echorm -f?var dbg_tt)
$dbg_tt && echorm -xv
# }}}
# Pre-Setup # {{{
source $TICKET_TOOL_PATH/common
[[ -z $TICKET_PATH ]] && "Env[TICKET_PATH] not defined (tt-t)" >/dev/stderr && exit 1
if [[ $1 == --issue ]]; then
  issue="$2"
  shift 2
  path_issue="$(getPathFast || $TICKET_TOOL_PATH/ticket-setup.sh --get-path "$issue" true)"
  issue_file=$(getIssueFile 2>/dev/null)
fi
[[ -z $issue ]] && echo "Issue not defined" >/dev/stderr && exit 1
# Path to issue # {{{
[[ -z $path_issue ]] && path_issue="$($TICKET_TOOL_PATH/ticket-setup.sh --get-path "$issue" true)"
[[ -z $issue_file ]] && issue_file=$(getIssueFile 2>/dev/null)
if [[ -z $issue_file ]]; then
  if [[ $1 == '@@' ]]; then
    exit 0
  fi
  echo "Issue [$issue] not present" >/dev/stderr && exit 1
fi
path_issue="${path_issue/$PWD/.}"
declare -A conf=([use-new-args]=false)
eval "$(sed -n '/^# j-info: CONF:/s/# j-info: CONF: *//p' $issue_file)"
export TICKET_CONF_USE_NEW_ARGS=${conf[use-new-args]:-default}
# }}}
if [[ -z $orig_cmd ]]; then
  case $1 in
  @@ | \? ) # {{{
    orig_cmd="$2";; # }}}
  *) orig_cmd="$1";;
  esac
  export orig_cmd
fi
cmd_TT="${0/$PWD\/} --issue"
cmd_tt="$cmd_TT $issue"
case $1 in
  @@ | env) cmd=$1;;
  *) cmd="$(mapCommand "$1")";;
esac; shift
params="$@"
if [[ $cmd != '@@' && $cmd =~ .*([\ @]).* ]]; then
  v=${BASH_REMATCH[1]}
  params="$v${cmd#*$v} $params"
  set -- $v${cmd#*$v} "$@"
  cmd="${cmd%%$v*}"
fi
setup="$cmd_tt setup"
fzf_params="--no-multi --cycle --ansi --tac --layout=default --height=100%"
export issue issue_file path_issue cmd params cmd_tt cmd_TT setup fzf_params
if true || ( [[ $cmd != '@@' ]] && ! ${TICKET_CONF_SKIP_ENV:-false}); then
  for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
    eval "$($ext --env)"
  done # }}}
fi
export TICKET_CONF_WAIT_ON_PHRASES_COMPL="$(echo -e "$TICKET_CONF_WAIT_ON_PHRASES_SHORT" | sed -e '/^#/d' -e '/^\s*$/d' -e 's/^/@/' -e 's/:.*//')"
values="$(echo -e "$TICKET_CONF_WAIT_ON_PHRASES_SHORT" | sed -e '/^#/d' -e '/^\s*$/d' -e 's/[^:]*://')"
while read -r i; do
  i="${i//\@\@/\ }"
  ! echo -e "$values" | command grep -q -F "$i" && TICKET_CONF_WAIT_ON_PHRASES_COMPL+=" '$i'"
done <<<"$(echo -e "$TICKET_CONF_WAIT_ON_PHRASES" | sed 's/\ /\@\@/g' | tr ' ' '\n')"
[[ ! -z $TICKET_CONF_WAIT_ON_PHRASE_DEF ]] && TICKET_CONF_WAIT_ON_PHRASES_COMPL+=" @"
unset values i
[[ -z $TICKET_KB_NAME ]] && TICKET_KB_NAME="$(basename "${TICKET_PATH,,}")"
export KB_DATA_FILE="$APPS_CFG_PATH/kb-${TICKET_KB_NAME}-data.sh"
[[ -e "$KB_DATA_FILE" ]] && source "$KB_DATA_FILE"
[[ -z "$TICKET_CONF_FILE" ]] && export TICKET_CONF_FILE="$path_issue/ticket.conf"
[[ -e "$TICKET_CONF_FILE" ]] && source "$TICKET_CONF_FILE"
[[ -z $TICKET_CONF_IN_LOOP ]] && export TICKET_CONF_IN_LOOP=false
[[ -z $TICKET_CONF_DRY ]] && export TICKET_CONF_DRY=false
getFunctionBodyRaw() { # {{{
  sed -n "/^# $1 -\{0,1\}\# {{[{]/,/^# }}[}]/p" "$issue_file"
} # }}}
getFunctionBody() { # {{{
  local fb="$(getFunctionBodyRaw $1 | sed -e '/^# /d')"
  [[ -z $fb ]] && return 0
  echo "$fb"
  return 0
} # }}}
getFunctions() { # {{{
  sed -n '/^# [a-z][^ :]* # {\{3\}/s/^# \(.*\) # {\{3\}.*/\1/p' $issue_file | tr '\n' ' ' # for vim: },}
  echo
} # }}}
getCompletionList() { # {{{
  [[ -z $1 ]] && return 0
  local func="$1" excl="[@#?]"
  shift
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --excl) excl+="\|$2"; shift;;
    *) break;;
    esac
    shift
  done # }}}
  local ret= subCmd=
  isInstalled -t completionCacheInvocation || source $TICKET_TOOL_PATH/completion-cache
  eval $(completionCacheInvocation)
  completionCacheLoad
  if [[ $func != - ]]; then # {{{
    local hasOldCompl=false
    if [[ -z $1 ]]; then # {{{
      ret="${complMap["$cmd"]}"
      if [[ -z $ret ]]; then
        echo "$func" | command grep -q "^@@ *\(|.*\)\?)" && hasOldCompl=true
        ret="$(echo "$func" | sed -n '/^case $\(1\|scmd\)/,/^esac/p' | sed -n '/^[^ ]\+)/s/).*//p' | grep -v "^\($excl\)" | tr '\n' ' ')"
        $hasOldCompl && ret+=" $(bash -c "$func" - @@)"
        ret=" $ret " && ret="${ret// \* }"
        completionCacheUpdate "$cmd" "$ret"
      fi # }}}
    else # {{{
      subCmd="$1"
      ret="${complMap["$cmd-$subCmd"]}"
      if [[ -z $ret ]]; then
        echo "$func" | command grep -q "^@@ *\(|.*\)\?)" && hasOldCompl=true
        useDefaultCompletion=true
        if echo "$func" | sed -n '/^'"$subCmd"')/,/^[^ ]/p'  | sed '$d' | command grep -q "#.*@@[^:-]\|@@)\|== ['\"]\?@@['\"]\?"; then
          shift
          ret+=" $(bash -c "$func" - $subCmd @@ "$@")"
          useDefaultCompletion=false
        elif $hasOldCompl; then
          local additionalCompl="$(bash -c "$func" - @@ "$@")"
          ret+=" $additionalCompl" && useDefaultCompletion=false
        fi
        if $useDefaultCompletion; then
          ret+=" $(echo "$func" | sed -n '/^'"$subCmd"').*#.*@@:/s/.*@@: *\([^#{]*\) *#\? *\({\{3\}\)\?/\1/p')" # } }
          [[ ! -z $ret ]] && ret="${ret//,/ }"
          local commandPart="$(echo "$func" | sed -n '/^'"$subCmd"')/,/^[^ ]/p' | sed '/# IGN/d' )"
          commandPart="$(echo "$commandPart" | sed -n '/^  while \[\[ ! -z $1 \]\]; do/,/  done/p')"
          local spaces="$(echo "$commandPart" | command grep "^  \+case \$[0-9]" | sed 's/case.*$//')"
          if [[ ! -z "$spaces" ]]; then
            ret+=" $(echo "$commandPart" | sed -n '/^'"$spaces"'case $[0-9]/,/^'"$spaces"'esac/p' | sed -n -e '/^'"$spaces"'[^ ]\+ *[)|]/s/ *[)].*//p' | sed -e 's/|/ /g' -e 's/\*//g' | tr '\n' ' ')"
          fi
          ret+=" $(echo "$commandPart" | sed -n '/\[\[ $[0-9] == /s/.* \[\[ \$[0-9] == ["'"'"']\([a-zA-Z0-9=.-]*\)["'"'"'] \]\].*/\1/p')"
          ret+=" $(echo "$commandPart" | sed -n '/\[\[ $[0-9] != /s/.* \[\[ \$[0-9] != ["'"'"']\([a-zA-Z0-9=.-]*\)["'"'"'] \]\].*/\1/p')"
          ret="${ret//\'\'/}"; ret="${ret//\"\"/}"
        fi
        completionCacheUpdate "$cmd-$subCmd" "$ret"
      fi
    fi # }}}
    # }}}
  else # {{{
    ret="${complMap["ALL"]}"
    if [[ -z $ret ]]; then
      ret="? cd edit env info clean $(ls $(dirname $0)/ticket-tool.d/ 2>/dev/null)"
      if [[ $PWD == $TICKET_PATH* ]]; then
        ret+=" tmux"
        git -C $TICKET_PATH rev-parse 2>/dev/null && ret+=" commit"
      fi
      for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        ret+=" $($ext @@)"
      done # }}}
      ret+=" $(getFunctions)"
      completionCacheUpdate "ALL" "$ret"
    fi
  fi # }}}
  ret="$(echo "$ret" | tr -s ' ')"
  echo "${ret:----}"
} # }}}
export -f getIssueFile getFunctionBodyRaw getFunctionBody getFunctions getCompletionList
# }}}
handled=false
case "$cmd" in
@@)  # {{{
  $dbg_tt && echorm -l2 -xv
  if [[ -z $1 || $1 == 1 ]]; then # {{{
    getCompletionList -
    # }}}
  else # {{{
    cmd="$(mapCommand "$1")" && shift
    case $cmd in
    cd) # {{{
      echo "-v --get"
      [[ -e $path_issue ]] && echo "$(command cd $path_issue && find . -maxdepth 2 -type d | sed -e '/^\.$/d' -e 's|^\./||' -e '/^\./d')"
      ;; # }}}
    edit) # {{{
      echo "-v";; # }}}
    help) # {{{
      $0 --issue $issue @@ $@;;# }}}
    \?) # {{{
      getFunctions;; # }}}
    *) # {{{
      ret=
      func="$(getFunctionBodyRaw $cmd)"
      export func
      if [[ ! -z $cmd && -e $(dirname $0)/ticket-tool.d/$cmd ]]; then # {{{
        ret="$($(dirname $0)/ticket-tool.d/$cmd @@ "$@")"
        ret="$(echo "$ret" | xargs)"
        echo "${ret:----}"
        exit 0
      fi # }}}
      for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        $ext @@ $cmd $@ && exit 0
      done # }}}
      if [[ ! -z $func ]]; then
        case $cmd in
        info*) # {{{
          ret=" $(echo "$func" | sed -n '/^##\+ @ [A-Za-z0-9].*/ { /}\{3\}/!s/.*@ \([A-Za-z0-9][^ ]*\).*/\L\1/p }')";; # }}}
        *) # {{{
          ret="$(getCompletionList "$func" "$@")";; # }}}
        esac
      fi
      ret="$(echo "$ret" | xargs)"
      echo "${ret:----}";; # }}}
    esac
  fi # }}}
  $dbg_tt && echorm -l2 +xv
  ;; # }}}
\?) # {{{
  if [[ -z $1 ]]; then
    ret=
    ret+=" env info setup"
    ret+=" $(getFunctions)"
    for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
      ret+=" $($ext ?)"
    done # }}}
    echo "$ret" | tr ' ' '\n' | sort -u | tr '\n' ' '
  else
    add_prefix=false
    [[ $# -gt 1 ]] && add_prefix=true
    while [[ ! -z $1 ]]; do
      cmd="$(mapCommand "$1")" && shift
      case $cmd in
      info*) $0 --issue $issue "$cmd";;
      *)     getFunctionBody $cmd --plain;;
    esac \
      | sed \
          -e 's/\s*#\s*\({{{\|}}}\)\s*//' \
          -e '/^\s*$/d' \
          -e 's/\s\+\(;;\)$/\1/' \
      | { $add_prefix && sed -e "s/^/$cmd:/" || cat -; }
    done
  fi
  ;; # }}}
cd) # {{{
  cmd='exec bash' p="$path_issue"
  while [[ ! -z $1 ]]; do
    case $1 in
    -v)    cmd='pwd';;
    --get) shift; eval tar -cf - "$1" | $cmd_tt cd "$2"; exit $?;;
    --tar) cmd="tar xf -";;
    *)     p+="/$1";;
    esac
    shift
  done
  [[ ! -e $p ]] && echo command mkdir -p $p
  [[ ! -t 1 ]] && cmd="pwd"
  ( command cd $p; eval $cmd; );; # }}}
clean) # {{{
  is_git=false
  git -C $TICKET_PATH rev-parse 2>/dev/null && is_git=true
  if $is_git; then
    list="$(eval command find . \\\( $(git clean -n -dxf | cut -d\  -f3 | xargs -i echo "-path ./{} -o" | sed 's|/ -o|/\\* -o|') -path '../..' \\\) -print;)"
  else
    list="$(command find . -name ${issue}-'*' -prune -o -name .${issue}-'*' -prune -o -name .done -prune -o -print)"
  fi
  list="$(echo "$list" | sed '/^\.$/ d' | sort | fzf --height 100% --prompt "Choose files> ")"
  [[ $? != 0 || -z $list ]] && return 0
  command mkdir -p $TMP_MEM_PATH/issue/$issue
  echo "$list" | tr ' ' '\n' | rsync -a --files-from=- . $TMP_MEM_PATH/issue/$issue/
  rm -rf $list
  ;; # }}}
edit) # {{{
  [[ $1 == '@@' ]] && exit 0
  f="$issue_file"
  [[ $1 == "-v" ]] && echo $f && exit 0
  [[ -e "$(dirname "$f")/Session.vim" ]] && (command cd "$(dirname "$f")"; vim-session;) && exit 0
  vim $f
  ;; # }}}
env) # {{{
  silent=false minimal=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --silent) silent=true;;
    --min)    minimal=true;;
    *)        break;;
    esac; shift
  done # }}}
  while read l; do
    echo "export ${l#export }"
  done < <(sed -n '/^# j-info: ENV: \?.\+/s/^# j-info: ENV: *//p' "$issue_file")
  if ! $minimal; then
    for b in $(tmux list-buffers -F '#{buffer_name}' | command grep -a "^${issue}-" | sort); do
      $silent || echo "# $b: $(tmux show-buffer -b $b)"
      tmux delete-buffer -b $b
    done
    func="$(getFunctionBody $cmd)"
    [[ ! -z $func ]] && bash -c "$func" - "$@"
  fi
  unset silent minimal;; # }}}
help) # {{{
  $0 --issue $issue @@ $@
  ;; # }}}
info*) # {{{
  func="$(getFunctionBody $cmd)"
  export func
  if [[ ! -z $func ]]; then
    handled=true
    $(dirname $0)/ticket-tool.d/info "$@"
  fi;;& # }}}
[a-z]*) # {{{
  if ! $handled; then
    if [[ -e $(dirname $0)/ticket-tool.d/$cmd ]]; then
      $(dirname $0)/ticket-tool.d/$cmd "$@"
    else
      for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        $ext $cmd "$@"
        err=$?
        [[ $err != 255 ]] && exit $err
      done # }}}
      func="$(getFunctionBody $cmd)"
      if [[ ! -z $func ]]; then
        bash -c "$func" - "$@"
      else
        echo "No definition for [$cmd]" >/dev/stderr
      fi
    fi
  fi;; # }}}
esac

