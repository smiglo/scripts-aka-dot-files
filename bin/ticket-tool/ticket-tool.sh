#!/bin/bash
# vim: fdl=0

# Initial checks & set up # {{{
mapCommand() { # {{{
  local cmd="$1" ret= ext=
  case $cmd in # {{{
  i)    ret='info';;
  e)    ret='edit';;
  ci)   ret='commit';;
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
fzf_params="--no-multi --cycle --ansi --tac --height=100%"
export issue path_issue cmd params cmd_tt cmd_TT fzf_params
for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
  eval "$($ext --env)"
done # }}}
info_pretty1() { # {{{
  local title="$(printf "   %s" "${issue^^}: Additional Information")" len=60
  [[ $(( ${#title} + $len)) -ge $(tput cols) ]] && len=$(($(tput cols)-${#title}-3))
  [[ $len -lt 3 ]] && len=3
  title+="$(printf " %.0s" $(eval echo {1..$len}))"
  l1="$(eval printf "─%.0s"  {1..${#title}})"
  l2="$(eval printf "═%.0s"  {1..${#title}})"
  echo "┌$l1┐"
  echo "│$title│"
  echo "└$l1┘"
} # }}}
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
  sed -n '/^# [a-z].* # {{[{]/s/^# \(.*\) # {{[{].*/\1/p' $(getIssueFile) | tr '\n' ' ' # for vim: }} },}} }
  echo
} # }}}
export -f getIssueFile getFunctionBodyRaw getFunctionBody getFunctions
# }}}
case "$cmd" in
@@)  # {{{
  [[ $verbose -ge 2 ]] && set -xv
  if [[ -z $1 || $1 == 1 ]]; then # {{{
    ret="? cd edit env archive"
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
      echo "--all --clean --test";; # }}}
    cd | edit) # {{{
      echo "-v";; # }}}
    commit) # {{{
      echo "-p -b";; # }}}
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
          ret=
          ${TICKET_CONF_INFO_HEADER:-false} && ret+=" --no-header" || ret+="--header"
          ret+=" $(echo "$func" | command grep -ai '^##\+ @ [a-z0-9].*' | sed -e '/}\{3\}/d' -e 's/^##\+ @ //' -e 's/ #.*//' | tr [A-Z] [a-z])";; # }}}
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
    getFunctions
  else
    add_prefix=false
    [[ $# -gt 1 ]] && add_prefix=true
    while [[ ! -z $1 ]]; do
      cmd="$(mapCommand "$1")" && shift
      case $cmd in
      info*) $add_prefix && $0 --issue $issue "$cmd" --no-header | sed "s/^/$cmd:/" || $0 --issue $issue "$cmd" --no-header;;
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
  [[ -e $dst_gz ]] && { gunzip "$dst_gz"; params+=" -r"; } || params+=" -c"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --all) # {{{
      if $is_git; then
        list="$(git clean -dxfn . | cut -d' ' -f3)"
      else
        list="$(command find . -name ${issue}-'*' -prune -o .${issue}-'*' -prune -o -name .done -prune -o -print | sed '/^\.$/ d')"
      fi
      do_clean=true
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
    list="$(echo "$list" | sed '/^\.$/ d' | sort | fzf --tac --height 100% --prompt "Choose files> ")"
  fi # }}}
  [[ -z $list ]] && echo "No file was chosen" >/dev/stderr && exit 1
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
cd) # {{{
  [[ $1 == "-v" ]] && ( cd $path_issue; pwd; ) || { cd "$path_issue"; exec bash; }
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
  title="${issue^^}-ext"
  isInit=false
  [[ $1 == 'INIT' ]] && shift && isInit=true && title="${issue^^}"
  tmux list-windows -F '#W' | command grep -q "$title" && exit 0
  export w=$(($(tmux display-message -p -F '#I') + 1))
  if $isInit; then # {{{
    pl_abs="$(command cd $path_issue; pwd)"
    tmux \
      new-window   -a    -c $pl_abs          \; \
      split-window -t .1 -c $pl_abs -v -p30  \; \
      select-pane  -t $w.1
    $BASH_PATH/aliases set_title --from-tmux $w --lock-force "$title"
    sleep 1
    cmd="${@:-vim-session}"
    tmux send-keys -l -t $w.1 "$cmd"
    # }}}
  else # {{{
    func="$(getFunctionBody "tmux-splits")"
    if [[ ! -z $func ]]; then
      bash -c "$func" - "$@"
      $BASH_PATH/aliases set_title --from-tmux $w --lock-force "$title"
      sleep 1
      func="$(getFunctionBody "tmux-cmds")"
      [[ ! -z $func ]] && bash -c "$func" - "$@"
    fi
  fi # }}}
  exit 0;; # }}}
*) # {{{
  case $cmd in
  env) # {{{
    silent=false
    [[ $1 == '--silent' ]] && shift && silent=true
    for b in $(tmux list-buffers -F '#{buffer_name}' | command grep -a "^${issue}-" | sort); do
      $silent || echo -n "$b: $(tmux show-buffer -b $b)" && echo
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
      # Print header ? # {{{
      printHeader="${TICKET_CONF_INFO_HEADER:-false}"
      case $1 in
      --no-header) printHeader=false; shift;;
      --header)    printHeader=true;  shift;;
      esac
      $printHeader && info_pretty1
      # }}}
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
            if [[ $indent == \#\#\#* ]]; then
              echo -ne "$func\n" | sed -n -e "/^##\+ @ $s/,/^#\{2,${#indent}\} @/p"
            else
              echo -ne "$func\n" | sed -n -e "/^##\+ @ $s/,/^##\+ @ \|^#\+ }}[}]/p"
            fi | sed -e "s/##\+ @ $s/--@@\0/" -e "s/^#\{2,${#indent}\} @.*/$indent @/" -e 's/^--@@//'
          fi
          shift
        done
      fi | sed \
        -e '/^"$/ d' \
        -e "s/^---$/$l1/" -e "s/^===$/$l2/" -e "s/^\(.\)\1\{3\}$/$multi/" \
        -e 's/^## \([^@]*$\)/# \1/' \
        -e "s/^\(##\+\) @ \([a-zA-Z0-9][^ ]*\).*/\1 ${CGold}\2${COff}/g" \
        -e '/^##\+ [@#].*/ d'
    fi;; # }}}
  [a-z]*) # {{{
    export DO_SOURCE=true
    for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-tool-ext.sh); do # {{{
      $ext $cmd "$@" && exit 0
    done # }}}
    func="$(getFunctionBody $cmd)"
    if [[ ! -z $func ]]; then
      bash -c "$func" - "$@"
    else
      echo "No definition for [$cmd]" >/dev/stderr
    fi;; # }}}
  esac;; # }}}
esac

