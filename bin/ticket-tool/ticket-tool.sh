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
case $1 in
-v)   verbose=1; shift;;
-vv)  verbose=2; shift;;
-vvv) verbose=3; shift;;
esac
[[ $verbose -ge 3 ]] && set -xv
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
  sed -n '/^# [a-z][^ :]* # {{[{]/s/^# \(.*\) # {{[{].*/\1/p' $(getIssueFile) | tr '\n' ' ' # for vim: }} },}} }
  echo
} # }}}
export -f getIssueFile getFunctionBodyRaw getFunctionBody getFunctions
# }}}
handled=false
case "$cmd" in
@@)  # {{{
  [[ $verbose -ge 2 ]] && set -xv
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
    \?) # {{{
      getFunctions;; # }}}
    *) # {{{
      ret=
      if [[ ! -z $cmd && -e $(dirname $0)/ticket-tool.d/$cmd ]]; then # {{{
        ret="$($(dirname $0)/ticket-tool.d/$cmd @@ "$@")"
        echo "${ret:----}"
        exit 0
      fi # }}}
      for ext in $(command find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        $ext @@ $cmd $@ && exit 0
      done # }}}
      func="$(getFunctionBodyRaw $cmd)"
      if [[ ! -z $func ]]; then
        case $cmd in
        info*) # {{{
          ret=" $(echo "$func" | sed -n '/^##\+ @ [A-Za-z0-9].*/ { /}\{3\}/!s/.*@ \([A-Za-z0-9][^ ]*\).*/\L\1/p }')";; # }}}
        *) # {{{
          echo "$func" | head -n1 | command grep -qa '@@' && ret=$(bash -c "$(echo "$func" | sed -e '/^# /d')" - @@ "$@") ;; # }}}
        esac
      fi
      echo $ret;; # }}}
    esac
  fi # }}}
  [[ $verbose -ge 2 ]] && set +xv
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
      info*) $add_prefix && $0 --issue $issue "$cmd" | sed "s/^/$cmd:/" || $0 --issue $issue "$cmd";;
      *)     $add_prefix && getFunctionBody $cmd --plain | sed "s/^/$cmd:/" || getFunctionBody $cmd --plain;;
      esac
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
  silent=false
  [[ $1 == '--silent' ]] && shift && silent=true
  for b in $(tmux list-buffers -F '#{buffer_name}' | command grep -a "^${issue}-" | sort); do
    $silent || echo "# $b: $(tmux show-buffer -b $b)"
    tmux delete-buffer -b $b
  done
  unset silent
  func="$(getFunctionBody $cmd)"
  [[ ! -z $func ]] && bash -c "$func" - "$@"
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

