#!/usr/bin/env bash
# vim: fdl=0

# Initial checks & set up # {{{
mapCommand() { # {{{
  local cmd="$1" ret= ext=
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
        done;; # }}}
  esac # }}}
  [[ -z $ret && -z $cmd ]] && ret='info'
  echo "${ret:-$cmd}"
} # }}}
echorm --name tt
[[ ! -z $verbose && $verbose -gt $(echorm -f??) ]] && echorm + $verbose
case $1 in
-v)   echorm + 1; shift;;
-vv)  echorm + 2; shift;;
-vvv) echorm + 3; shift;;
esac
echorm -xv
# }}}
# Pre-Setup # {{{
[[ -z $TICKET_PATH ]] && "Env[TICKET_PATH] not defined (tt-t)" >/dev/stderr && exit 1
[[ $1 == --issue ]] && issue="$2" && shift 2
[[ -z $issue ]] && echo "Issue not defined" >/dev/stderr && exit 1
getIssueFile() { # {{{
  [[ -e "$path_issue/${issue}-data.txt" ]] && echo "$path_issue/${issue}-data.txt" && return 0
  [[ -e "$path_issue/.${issue}-data.txt" ]] && echo "$path_issue/.${issue}-data.txt" && return 0
  echo "Cannot find issue file for issue '$issue'/'$path_issue'" >/dev/stderr
  return 1
} # }}}
# Path to issue # {{{
path_issue="$($TICKET_TOOL_PATH/ticket-setup.sh --get-path "$issue" true)"
if ! getIssueFile >/dev/null 2>&1; then
  if [[ $1 == '@@' ]]; then
    exit 0
  fi
  echo "Issue [$issue] not present" >/dev/stderr && exit 1
fi
path_issue="${path_issue/$PWD/.}"
# }}}
if [[ -z $orig_cmd ]]; then
  case $1 in
  @@ | \? ) # {{{
    orig_cmd="$2";; # }}}
  *) orig_cmd="$1";;
  esac
  export orig_cmd
fi
cmd="$(mapCommand "$1")" && shift
params="$@"
if [[ $cmd != '@@' && $cmd =~ .*([\ @]).* ]]; then
  v=${BASH_REMATCH[1]}
  params="$v${cmd#*$v} $params"
  set -- $v${cmd#*$v} "$@"
  cmd="${cmd%%$v*}"
fi
cmd_TT="${0/$PWD\/} --issue"
cmd_tt="$cmd_TT $issue"
setup="$cmd_tt setup"
fzf_params="--no-multi --cycle --ansi --tac --layout=default --height=100%"
export issue path_issue cmd params cmd_tt cmd_TT setup fzf_params
for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
  eval "$($ext --env)"
done # }}}
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
  sed -n "/^# $1 -\{0,1\}\# {{[{]/,/^# }}[}]/p" "$(getIssueFile)"
} # }}}
getFunctionBody() { # {{{
  local fb="$(getFunctionBodyRaw $1 | sed -e '/^# /d')"
  [[ -z $fb ]] && return 0
  echo "$fb"
  return 0
} # }}}
getFunctions() { # {{{
  sed -n '/^# [a-z][^ :]* # {{{/s/^# \(.*\) # {{{.*/\1/p' $(getIssueFile) | tr '\n' ' ' # for vim: }}},}}}
  echo
} # }}}
getCompletionList() { # {{{
  [[ -z $1 ]] && return 0
  local func="$1" excl="[@#?]"
  shift
  while [[ ! -z $1 ]]; do
    case $1 in
    --excl) excl+="\|$2"; shift;;
    *) break;;
    esac
    shift
  done
  local ret=
  local hasOldCompl=false
  echo "$func" | command grep -q "^@@ *\(|.*\)\?)" && hasOldCompl=true
  local compl="$(echo "$func" | sed -n '/^case $1/,/^esac/p' | sed -n '/^[^ ]\+)/s/).*//p' | grep -v "^\($excl\)" | tr '\n' ' ')" fullCompl=
  $hasOldCompl && fullCompl="$(bash -c "$func" - @@)"
  if [[ -z $1 ]]; then
    ret="$compl"
    $hasOldCompl && ret+=" $fullCompl"
  else
    cmd="$1"
    ret="$(echo "$func" | sed -n '/^'"$cmd"').*#.*@@:/s/.*@@: *\([^#{]*\) *#\? *\({{{\)\?/\1/p')" # }}}
    [[ ! -z $ret ]] && ret="${ret//,/ }"
    local commandPart="$(echo "$func" | sed -n '/^'"$cmd"')/,/^[^ ]/p')"
    ret+=" $(echo "$commandPart" | sed '/# IGN/d' | sed -n '/  \+case $[0-9]/,/  \+esac/p' | sed -n -e '/^  \+[^ ]\+ *[)|]/s/ *[)|].*//p' | sed 's/\*//g' | tr '\n' ' ')"
    ret+=" $(echo "$commandPart" | sed '/# IGN/d' | sed -n '/\[\[ $[0-9] == /s/.* \[\[ \$[0-9] == ["'"'"']\([a-zA-Z0-9=.-]*\)["'"'"'] \]\].*/\1/p')"
    ret+=" $(echo "$commandPart" | sed '/# IGN/d' | sed -n '/\[\[ $[0-9] != /s/.* \[\[ \$[0-9] != ["'"'"']\([a-zA-Z0-9=.-]*\)["'"'"'] \]\].*/\1/p')"
    ret="${ret//\'\'/}"; ret="${ret//\"\"/}"
    if echo "$func" | sed -n '/^'"$cmd"')/,/^[^ ]/p' | command grep -q "#.*@@[^:]\|@@)\|== ['\"]\?@@['\"]\?"; then
      shift
      ret+=" $(bash -c "$func" - $cmd @@ "$@")"
    elif $hasOldCompl; then
      local additionalCompl="$(bash -c "$func" - @@ "$@")"
      [[ "$additionalCompl" != "$fullCompl" ]] && ret+=" $additionalCompl"
    fi
  fi
  ret="$(echo $ret)"
  echo "${ret:----}"
} # }}}
export -f getIssueFile getFunctionBodyRaw getFunctionBody getFunctions getCompletionList
# }}}
handled=false
case "$cmd" in
@@)  # {{{
  echorm -l2 -xv
  if [[ -z $1 || $1 == 1 ]]; then # {{{
    ret="? cd edit env info clean $(ls $(dirname $0)/ticket-tool.d/ 2>/dev/null)"
    if [[ $PWD == $TICKET_PATH* ]]; then
      ret+=" tmux"
      git -C $TICKET_PATH rev-parse 2>/dev/null && ret+=" commit"
    fi
    for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
      ret+=" $($ext @@)"
    done # }}}
    ret+=" $(getFunctions)"
    echo "$ret"
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
          ret=$(getCompletionList "$func" "$@");; # }}}
        esac
      fi
      echo $ret;; # }}}
    esac
  fi # }}}
  echorm -l2 +xv
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
  f="$(getIssueFile)"
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
  done < <(sed -n '/^# j-info: ENV: \?.\+/s/^# j-info: ENV: *//p' $(getIssueFile))
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
      export DO_SOURCE=true
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

