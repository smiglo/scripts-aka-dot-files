#!/bin/bash
# vim: fdl=0

# Initial checks & set up # {{{
mapCommand() { # {{{
  local cmd="$1" ret= ext=
  case $cmd in # {{{
  i)    ret='info';;
  e)    ret='edit';;
  ci)   ret='commit';;
  s)    ret='setup';;
  tm)   ret='tmux';;
  *)    # {{{
        for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do
          ret="$($ext --map-cmd "$cmd")"
          [[ ! -z $ret ]] && break
        done;; # }}}
  esac # }}}
  [[ -z $ret && -z $cmd ]] && ret='info'
  echo "${ret:-$cmd}"
} # }}}
if ! ${skip_sourcing:-false}; then
  source $HOME/.bashrc --do-min ''
  export skip_sourcing=true
fi
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
  echo "Cannot find issue file for issue '$issue'/'$path_issne'" >/dev/stderr
  return 1
} # }}}
# Path to issue # {{{
path_issue="$($TICKET_TOOL_PATH/ticket-setup.sh --get-path "$issue" true)"
! getIssueFile >/dev/null 2>&1 && echo "Issue [$issue] not present" >/dev/stderr && exit 1
path_issue="${path_issue/$PWD/.}"
# }}}
cmd="$(mapCommand "$1")" && shift
[[ ! -z $ret ]] && cmd="$ret"
params="$@"
cmd_TT="${0/$PWD\/} --issue"
cmd_tt="$cmd_TT $issue"
setup="$cmd_tt setup"
fzf_params="--no-multi --cycle --ansi --tac --layout=default --height=100%"
export issue path_issue cmd params cmd_tt cmd_TT setup fzf_params
for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
  eval "$($ext --env)"
done # }}}
getFunctionBodyRaw() { # {{{
  sed -n "/^# $1 -\{0,1\}\# {{[{]/,/^# }}[}]/p" "$(getIssueFile)"
} # }}}
getFunctionBody() { # {{{
  local fb="$(getFunctionBodyRaw $1 | sed -e '/^# /d')"
  [[ -z $fb ]] && return 0
  [[ $2 != '--plain' ]] && fb="source $HOME/.bashrc --do-basic ''; $fb"
  echo "$fb"
  return 0
} # }}}
getFunctions() { # {{{
  sed -n '/^# [a-z][^ :]* # {{[{]/s/^# \(.*\) # {{[{].*/\1/p' $(getIssueFile) | tr '\n' ' ' # for vim: }} },}} }
  echo
} # }}}
export -f getIssueFile getFunctionBodyRaw getFunctionBody getFunctions
# }}}
case "$cmd" in
@@)  # {{{
  [[ $verbose -ge 2 ]] && set -xv
  if [[ -z $1 || $1 == 1 ]]; then # {{{
    ret="? cd edit env archive clean setup browser"
    if [[ $PWD == $TICKET_PATH* ]]; then
      ret+=" tmux"
      git -C $TICKET_PATH rev-parse 2>/dev/null && ret+=" commit"
    fi
    for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
      ret+=" $($ext @@)"
    done # }}}
    ret+=" $(getFunctions)"
    echo $ret
    # }}}
  else # {{{
    cmd="$(mapCommand "$1")" && shift
    case $cmd in
    archive) # {{{
      echo "--all --all-all --clean --pkg --test";; # }}}
    browser) # {{{
      echo "@ff @chrome @chromium -1";; # }}}
    cd | edit) # {{{
      echo "-v";; # }}}
    commit) # {{{
      echo "-p -b";; # }}}
    setup) # {{{
      $cmd_tt setup @@ "$@";; # }}}
    \?) # {{{
      getFunctions;; # }}}
    *) # {{{
      for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        $ext @@ $cmd $@ && exit 0
      done # }}}
      ret=
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
    for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
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
archive) # {{{
  is_git=false
  git -C $TICKET_PATH rev-parse 2>/dev/null && is_git=true
  cd "$path_issue"
  dst_tar="$issue-archive.tar" dst_gz="$dst_tar.gz" list= params= do_clean=false do_test=false
  [[ -e $dst_tar ]] && echo "Intermediate file [$dst_tar] exists, remove them and proceed again" >/dev/stderr && exit 1
  [[ -e $dst_gz ]] && { gunzip "$dst_gz"; params+=" -r"; } || params+=" -c"
  [[ $1 == --pkg ]] && set -- --all-all --test
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --all) # {{{
      if $is_git; then
        list="$(git clean -dxfn . | cut -d' ' -f3)"
      else
        list="$(command find . -name ${issue}-'*' -prune -o -name .${issue}-'*' -prune -o -name .done -prune -o -print | sed '/^\.$/ d')"
      fi
      [[ -z $list ]] && echo "No files were chosen" >/dev/stderr && exit 1
      do_clean=true
      ;; # }}}
    --all-all) # {{{
      list="$(command find . -print | sed '/^\.$/ d')"
      list="$(echo "$list" | sort | fzf --height 100% --prompt "Choose files> ")"
      [[ -z $list ]] && echo "No files were chosen" >/dev/stderr && exit 1
      ;; # }}}
    --clean) do_clean=true;;
    --test)  do_test=true;;
    *)       list="$@"; shift $#; break;;
    esac
    shift
  done # }}}
  if [[ -z $list ]]; then # {{{
    if $is_git; then
      list="$(eval command find . \\\( $(git clean -n -dxf | cut -d\  -f3 | xargs -i echo "-path ./{} -o" | sed 's|/ -o|/\\* -o|') -path '../..' \\\) -print;)"
    else
      list="$(command find . -name ${issue}-'*' -prune -o -name .${issue}-'*' -prune -o -name .done -prune -o -print)"
    fi
    list="$(echo "$list" | sed '/^\.$/ d' | sort | fzf --height 100% --prompt "Choose files> ")"
  fi # }}}
  [[ -z $list ]] && echo "No files were chosen" >/dev/stderr && exit 1
  list="$(echo "$list" | tr '\n' ' ')"
  tar $params -f "$dst_tar" $list
  $do_test && tar -tf "$dst_tar"
  gzip $dst_tar
  if $is_git; then # {{{
    git add "$dst_gz"
    $cmd_tt commit
  fi # }}}
  if $do_clean; then # {{{
    command mkdir -p $TMP_MEM_PATH/issue/$issue
    echo "$list" | tr ' ' '\n' | rsync -a --files-from=- . $TMP_MEM_PATH/issue/$issue/
    rm -rf $list
  fi # }}}
  ;; # }}}
browser) # {{{
  browser="${TICKET_CONF_BROWSER#@}" params=
  if [[ -z $browser ]]; then
    $IS_MAC && browser="open" || browser="chromium"
  fi
  all=true
  while [[ ! -z $1 ]]; do
    case $1 in
    @ff | @chrome | @chromium | @brave) browser="${1#@}";;
    @*) cmd="${1#@}"; shift; params="$@"; shift $#; break;;
    -1) all=false;;
    *)  break;;
    esac
    shift
  done
  urls="$@"
  if [[ -z $urls ]]; then
    func="$(getFunctionBodyRaw "$cmd")"
    [[ -z $func ]] && echo "Cannot get any URLs from [$cmd]" >/dev/stderr && exit 1
    if [[ $cmd == 'browser' ]]; then
      urls="$(echo "$func")"
    else
      urls="$($cmd_tt $cmd $params)"
    fi
    urls="$(echo "$urls" | sed -n -e '/^#/d' -e 's/URL:/\n\0/gp' | sed -n -e 's/URL:\s*\([^ ,]*\).*/\L\1/p')"
    [[ -z $urls ]] && echo -e "No ULRs were provided by [$cmd ${params:-\b}]" >/dev/stderr && exit 1
    ! $all && urls="$(echo "$urls" | head -n1)"
  fi
  for i in $urls; do
    case $browser in
    ff)       firefox -new-tab -url $i;;
    chrome)   /opt/google/chrome $i;;
    chromium) chromium-browser $i;;
    brave)    browser="${TICKET_CONF_BROWSER_BRAVE_PATH:-/opt/brave.com/brave/brave}"
              [[ ! -f $browser ]] && echo "Brave not found at [$browser]" >/dev/stderr && exit 1
              $browser $i;;
    open)     open $i;;
    esac
  done;; # }}}
cd) # {{{
  [[ $1 == "-v" ]] && ( cd $path_issue; pwd; ) || { cd "$path_issue"; exec bash; }
  ;; # }}}
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
commit) # {{{
  ! git -C $TICKET_PATH rev-parse 2>/dev/null && exit 1
  do_push=false do_push_all=false
  while [[ ! -z $1 ]]; do
    case $1 in
    -p) do_push=true;;
    -b) do_push_all=true;;
    esac
    shift
  done
  cd "$path_issue"
  [[ -z $(git status --short .) ]] && exit 0
  if git diff --cached --quiet; then
    git diff --quiet && git ls-files -o --directory --exclude-standard | sed q1 >/dev/null 2>&1 && exit 0
    git add .
  fi
  if [[ $(git log -1 --format="%s") == *\[i\]\ $issue* ]]; then
    git commit --amend --no-verify --reuse-message=HEAD
  else
    git commit -m"[i] $issue: Update" --no-verify
  fi
  if $do_push_all; then
    git backup
  elif $do_push; then
    git push
  fi
  exit 0;; # }}}
edit) # {{{
  f="$(getIssueFile)"
  [[ $1 == "-v" ]] && echo $f && exit 0
  [[ -e "$(dirname "$f")/Session.vim" ]] && (command cd "$(dirname "$f")"; vim-session;) && exit 0
  vim $f
  ;; # }}}
tmux) # {{{
  [[ $PWD != $TICKET_PATH* ]] && exit 1
  title="${issue}"
  declare -f __ticket_title >/dev/null 2>&1 && title="$(__ticket_title "$title")"
  isInit=false
  if [[ $1 == 'INIT' ]]; then
    shift && isInit=true
  else
    title="${title}-ext"
  fi
  tmux list-windows -F '#W' | command grep -q "$title" && exit 0
  export w=$(($(tmux display-message -p -F '#I') + 1))
  export pl_abs="$(command cd $path_issue; pwd)"
  export title
  if $isInit; then # {{{
    tmux \
      new-window   -a -n $title -d -c $pl_abs  \; \
      set-option   -t $w -w @locked_title 1    \; \
      split-window -t $w.1 -d -c $pl_abs -v -p30
    $BASH_PATH/aliases set_title --from-tmux $w --lock-force "$title"
    func="$(getFunctionBody "tmux-init")"
    [[ ! -z $func ]] && bash -c "$func" - "$@"
    sleep 1
    cmd="${@:-vim-session}"
    tmux \
      select-pane -t.1 \; \
      send-keys -l -t $w.1 "$cmd"
    # }}}
  else # {{{
    func="$(getFunctionBody "tmux-splits")"
    if [[ ! -z $func ]]; then
      bash -c "$func" - "$@"
      tmux select-pane -t $w.1
      $BASH_PATH/aliases set_title --from-tmux $w --lock-force "$title"
      sleep 1
      func="$(getFunctionBody "tmux-cmds")"
      [[ ! -z $func ]] && bash -c "$func" - "$@"
    fi
  fi # }}}
  exit 0;; # }}}
setup) # {{{
  func="$(getFunctionBody 'setup')"
  while [[ $1 == -* ]]; do # {{{
    case $1 in
    --loop) break;;
    -*) # {{{
      case $1 in
      *) # {{{
        handled=false
        for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
          v="$($ext $cmd $1)"
          [[ ! -z $v ]] && { eval "$v"; handled=true; break; }
        done # }}}
        ! $handled && [[ ! -z "$func" ]] && eval $(bash -c "$func" - "$1") ;; # }}}
      esac;; # }}}
    esac
    shift
  done # }}}
  case $1 in
  @@) # {{{
    shift
    while [[ $1 == -* ]]; do # {{{
      case $1 in
      --full) break;;
      esac
      shift
    done # }}}
    if [[ -z $1 || $1 == --full ]]; then # {{{
      ret="--loop ?"
      for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        ret+=" $($ext $cmd "get-ext-commands" $1)"
        ret+=" $($ext $cmd "get-ext-switches")"
      done # }}}
      [[ ! -z "$func"  ]] && ret+=" $(bash -c "$func" - @@ "$@")"
      # }}}
    else # {{{
      ret=
      for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        ret="$($ext $cmd @@ "$@")"
        [[ -z $ret ]] || break
      done # }}}
      [[ -z $ret && ! -z "$func" ]] && ret+=" $(bash -c "$func" - @@ "$@")"
    fi # }}}
    echo "$ret"
    ;; # }}}
  \?) # {{{
    case $2 in
    '' | @@)  # {{{
      echo "$($setup @@ --full)";; # }}}
    \#show-all) # {{{
      echo "Show all commands";; # }}}
    \#travelsal) # {{{
      echo "Toggle travelsal mode";; # }}}
    \#reload) # {{{
      echo "Reload configuration";; # }}}
    @Quit) # {{{
      echo  "Quit";; # }}}
    *) # {{{
      source $BASH_PATH/colors
      for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        ret="$($ext $cmd "$@")"
        [[ -z $ret ]] || break
      done # }}}
      if [[ -z "$ret" && ! -z "$func" ]]; then
        ret="$(bash -c "${func#source*; }" - '?' "$2")"
        [[ -z "$ret" ]] && ret="$(echo "$func" | sed -n "/^\s*$2)/,// p" | sed -e "s/^\(\s*$2\)\().*\)/${CGold}\1${COff}\2/")"
      fi
      echo "$ret";; # }}}
    esac
    ;; # }}}
  --loop | '') # {{{
    $BASH_PATH/aliases set_title --set-pane "$issue: setup"
    source $BASH_PATH/colors
    utils_cmd="#reload\n#show-all\n#travelsal\n"
    reload_cmds=true use_travelsal=
    while $reload_cmds; do # {{{
      l= op= use_travelsal=${use_travelsal:-true} reload_cmds=false hidden="!^@"
      if [[ ! -z "$func" ]]; then # {{{
        l="$(bash -c "${func#source*; }" - '@@')"
        l="$(echo "${l//  / }" | tr ' ' '\n' | sed '/^\s*$/ d' | sort)"
        [[ ! -z "$l" ]] && l+="\n"
      fi # }}}
      ext_cmds=
      for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
        ext_cmds+=" $($ext $cmd "get-ext-commands")"
      done # }}}
      ext_cmds="$(echo "$ext_cmds" | tr ' ' '\n')\n"
      l="$(echo -e "${utils_cmd}${ext_cmds}${l}${CGold}@Quit${COff}" | sed -e '/^\s*$/d')"
      $use_travelsal && op="$($setup '@travelsal' '-INIT-')"
      [[ $op == @* ]] && hidden=''
      while true; do # {{{
        op="$(echo -e "$l" | fzf $fzf_params --query="$([[ ! -z $hidden ]] && echo "$hidden ")$([[ ! -z $op ]] && echo "$op ")" --preview="$0 setup ? {1}")"
        [[ $? != 0 || $op == '@Quit' ]] && break
        [[ -z $op ]] && continue
        case $op in
        '#show-all') hidden=''; use_travelsal=false; op=''; continue;;
        '#travelsal') # {{{
          if $use_travelsal; then
            use_travelsal=false
            op=''
          else
            use_travelsal=false
            op="$($setup '@travelsal' '-INIT-')"
          fi
          continue;; # }}}
        '#reload')   reload_cmds=true; func="$(getFunctionBody 'setup')"; break;;
        *) # {{{
          params="$($setup @@ "$op")" arg=
          [[ "$params" != "$($setup @@ @@)" ]] && arg="$(echo "$params" | sed 's/ /\n/g' | fzf $fzf_params)"
          $setup "$op" $arg;; # }}}
        esac
        err="$?"
        [[ $err != 0 ]] && break 2
        $use_travelsal && { op="$($setup '@travelsal' "$op")"; } || { op=''; }
        [[ $op == @* ]] && hidden=''
      done # }}}
    done;; # }}} # }}}
  *) # {{{
    for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
      $ext $cmd $@ && exit 0
    done # }}}
    [[ ! -z "$func" ]] && bash -c "$func" - "$@" ;; # }}}
  esac
  ;; # }}}
*) # {{{
  case $cmd in
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
    if [[ ! -z $func ]]; then
      func="${func#source*; }"
      len="$(tput cols)"
      [[ $len -gt 60 ]] && len=60
      l1="$(eval printf "─%.0s"  {1..$len})"
      l2="$(eval printf "═%.0s"  {1..$len})"
      multi=$((${#l1} / 4))
      multi="$(printf "\\\\0%.s" $(eval echo {1..$multi}))"
      [[ -t 1 ]] || unset $(command grep "^C" $BASH_PATH/colors | sed -e 's/=.*//' | tr '\n' ' ')
      if [[ -z $1 ]]; then
        echo -ne "$func\n" | sed -e "s/^\(##\+ @\) .*}}[}]/\1/"
      else
        while [[ ! -z $1 ]]; do
          s="${1,,}"
          s="$(echo -ne "$func\n" | command grep -ai "^##\+ @ $s\( .*\)\{0,1\}" | head -n1 | sed -e 's/^##\+ @ //' -e 's/ #.*//')"
          [[ -z $s ]] && echo "Section [$1] not found" >/dev/stderr && shift && continue
          if echo -ne "$func\n" | grep -aq  "^##\+ @ $s .*}}[}]"; then
            echo -ne "$func\n" | sed -n -e "/^##\+ @ $s .*{{[{]/,/^##\+ @ $s .*}}[}]/p" | sed -e "s/^\(##\+ @\).*}}[}]/\1/"
          else
            indent="$(echo -ne "$func\n" | command grep -a "^##\+ @ $s" | head -n1 | sed -e 's/^\(##\+\) .*/\1/')"
            max="$((${#indent}-1))"
            [[ $max -lt 2 ]] && max=2
            echo -ne "$func\n" | sed -n -e "/^##\+ @ $s/,/^#\{2,$max\}$\|^$indent @\|^$indent @ }}[}]/p" \
            | sed -e "s/##\+ @ $s/--@@\0/" -e "s/^#\{2,$max\}$\|^#\{2,${#indent}\} @.*/$indent @/" -e 's/^--@@//'
          fi
          shift
        done
      fi | sed \
        -e '/^"\+$/ d' \
        -e "/^'''$/ d" \
        -e "s/^---$/$l1/" -e "s/^===$/$l2/" -e "s/^\(.\)\1\{3\}$/$multi/" \
        -e 's/^## \([^@]*$\)/# \1/' \
        -e "s/^\(##\+\) @ \([a-zA-Z0-9][^ ]*\).*/\1 ${CGold}\2${COff}/g" \
        -e '/^##\+ [@#].*/ d' \
        -e '/^##\+$/ d'
    fi;; # }}}
  [a-z]*) # {{{
    export DO_SOURCE=true
    for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
      $ext $cmd "$@"
      err=$?
      [[ $err != 255 ]] && exit $err
    done # }}}
    func="$(getFunctionBody $cmd)"
    if [[ ! -z $func ]]; then
      bash -c "$func" - "$@"
    else
      echo "No definition for [$cmd]" >/dev/stderr
    fi;; # }}}
  esac;; # }}}
esac

