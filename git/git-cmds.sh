#!/bin/bash
# vim: fdl=0

# Functions {{{
dbg() { # {{{
  echo -e $@ >/dev/stderr;
} # }}}
gitdir() { # {{{
  local dir=$(git rev-parse --git-dir 2>/dev/null)
  [[ $? != 0 ]] && return 1
  echo "$dir"
  return 0
} # }}}
add_spaces() { # {{{
  local len=$1
  local pos=${2:-"70"}
  local spaces=""
  while [[ $len -lt $pos ]]; do
    spaces+=" "
    len=$(($len + 1))
  done
  echo "$spaces"
  return 0
} # }}}
check_repo() { # {{{
  source $BIN_PATH/bash/colors
  local check_origin=false
  local check_full_owr=$checkFull
  local dir=$1; shift
  local silent=false
  local skipSubmodules=false
  if [[ $dir == @* ]]; then
    ! $do_all && return
    dir=${dir/@}
  fi
  [[ ! -e $dir ]] && return 0
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    origin)           check_origin=true;;
    full)             check_full_owr=true;;
    --silent)         silent=true;;
    --skipSubmodules) skipSubmodules=true;;
    esac
    shift
  done # }}}
  local msg="[${CGreen}${dir/$HOME/\~}${COff}]$(add_spaces $((${#dir}+2)))"
  [[ ! -e $dir/.git ]] && echo -e "$msg[${CRed}.GIT${COff}]" && return
  pushd $dir > /dev/null
  local git=".git"
  [[ -f $git ]] && git=$(cat $git | awk '{print $2}')
  ! $skipSubmodules && git submodule --quiet foreach "git-cmds.sh --test check_repo \$PWD --skipSubmodules $(! $display_status && echo '--silent')"
  local commands=
  local is_change=false
  local c="git status --short"
  local change_label=
  if [[ "$($c)" != "" ]]; then # {{{
    is_change=true
    change_label="COMMIT"
    $display_status && commands+="\n$c"
  fi # }}}
  local r= gitBackupParams=
  $check_full_owr && gitBackupParams+=" --full"
  for r in $(git remote); do # {{{
    if [[ $r == 'origin' && $PWD != ${MY_PROJ_PATH}* ]]; then # {{{
      if ! $check_origin || ! $check_full_owr; then
        continue
      fi
    fi # }}}
    echo "$r" | command grep -qvE "$(getMainRemotes)" && ! $check_full_owr && continue
    [[ $(git config --get remote.$r.url) == http* ]] && continue
    local cur_branch="$(git branch | command grep "^\*" | cut -c3-)"
    local b=
    for b in $(git branch | cut -c3-); do # {{{
      if [[ $b == "$cur_branch" || $b == 'master' ]] && ( ! git branch -a | command grep -q $r/$b || [[ "$(git rev-parse $b)" != "$(git rev-parse $r/$b)" ]] ); then
        is_change=true
        if [[ $change_label != *BACKUP* ]]; then
          [[ ! -z $change_label ]] && change_label+="|"
          change_label+="BACKUP"
        fi
        if ! git branch -a | command grep -q $r/$b; then # {{{
          if $check_new_branches; then
            if [[ $change_label != *NEW* ]]; then
              [[ ! -z $change_label ]] && change_label+="|"
              change_label+="NEW($b)"
            fi
          fi
          # }}}
        elif $display_status; then # {{{
          if $display_full; then
            commands+="\necho Changes: $CGreen$r$COff/${CGold}${b}${COff}..${CGold}${b}${COff}\ngit lgf $r/$b~..$b"
          else
            commands+="\necho Changes: $CGreen$r$COff/${CGold}${b}${COff}: $(($(git lgf $r/$b..$b | wc -l)+1)) commit(s) ahead"
          fi
        fi # }}}
      fi
    done # }}}
  done # }}}
  if $is_change; then # {{{
    ! $silent && echo -e -n "$msg" && echo -e "[${CRed}$change_label${COff}]"
    if $display_status; then # {{{
      while read c; do
        $c
      done < <(echo -e $commands)
    fi # }}}
    local is_ok=true
    if $is_interactive && [[ $change_label == COMMIT* ]]; then
      bash || is_ok=false
    fi
    $is_ok && ${do_backup:-false} && git backup $gitBackupParams
    $display_status && echo -e $sep # }}}
  elif $display_status; then # {{{
    echo -e -n "$msg"
    echo -e "[${CGold}UP-TO-DATE${COff}]"
  fi # }}}
  popd >/dev/null
} # }}}
gitst() { # {{{
  if [[ $1 == @@ ]]; then # {{{
    echo "--backup --new-branches --all --full -v --verbose --verbose-full --interactive"
    return 0
  fi # }}}
  source $BIN_PATH/bash/colors
  local sep="------------------------------------------------------------------------"
  local do_backup=false do_all=false display_status=false display_full=false is_interactive=false check_new_branches=false checkFull=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --backup)          do_backup=true;;
    --all)             do_all=true;;
    --verbose-full)    display_status=true; display_full=true;;
    --verbose|-v)      display_status=true;;
    --interactive)     is_interactive=true;;
    --full)            checkFull=true;;
    --new-branches)    check_new_branches=true;;
    esac
    shift
  done # }}}
  export sep do_backup do_all display_status display_full is_interactive checkFull check_new_branches
  local dir=
  for dir in $GIT_REPOS; do
    check_repo ${dir//:/ }
  done
} # }}}
getMainRemotes() { # {{{
  echo "origin|_backup.*"
  return 0
} # }}}
backup() { # {{{
  source $BIN_PATH/bash/colors
  [[ $1 == @@ ]] && echo "--all --all-br --tags --force --full -ff -v --verbose" && return 0
  local repos=$PWD
  local checkFull=false
  local skipSubmodules=false
  local params_main=
  local verbose=false
  [[ -z $1 ]] && set -- $(git config --get utils.backup-switches || true)
  while [[ ! -z $1 ]]; do
    case $1 in
    --all)    repos=$GIT_REPOS;;
    --full)   checkFull=true;;
    --all-br) params_main+=" --all";;
    -ff)      checkFull=true; params_main+=" --force";;
    --skip-submodules) skipSubmodules=true;;
    -v | --verbose) verbose=true;;
    *)        params_main+=" $1";;
    esac
    shift
  done

  local label_uptodate="[${CGold}UP-TO-DATE${COff}]"
  local label_done="[${CCyan}DONE${COff}]"

  local repo= orig_repo= repo_printed=false
  for orig_repo in $repos; do

    repo=${orig_repo/:*}
    [[ $repo == @* ]] && repo=${repo/@}

    pushd $repo >/dev/null
    local dir=$(gitdir)
    if [[ "$?" != "0" ]]; then
      echo -e -n "[${CGreen}${repo/$HOME/\~}${COff}]"
      echo "$(add_spaces $((${#repo}+2)))[${CRed}.GIT${COff}]"
      popd >/dev/null
      continue
    fi

    dir=$(cd $dir; pwd)
    dir=${dir/\/.git}
    for r in $GIT_REPOS; do
      r=${r/:*/}
      [[ "${dir/*projects\//projects/}" == "${r/@*projects\//projects/}" ]] && params_main+=" --force" && break
    done

    local sub_params="$params_main"
    $checkFull && sub_params+=" --full"
    $verbose   && sub_params+=" --verbose"

    ! $skipSubmodules && git submodule --quiet foreach "git backup --skip-submodules $sub_params"

    $verbose && echo -e "[${CGreen}${repo/$HOME/\~}${COff}]"
    local git_cmd="git push --recurse-submodules=no $params_main" r=

    for r in $(git remote); do
      local remoteUrl=$(git config --get remote.$r.url)
      remoteUrl=${remoteUrl/\~/$HOME}
      local st=
      if [[ $r == 'origin' ]]; then
        if [[ $orig_repo != *:origin* ]] && ! $checkFull && [[ $PWD != ${MY_PROJ_PATH}* ]]; then
          continue
        fi
      fi
      echo "$r" | command grep -qvE "$(getMainRemotes)" && ! $checkFull && continue
      $verbose && echo -e -n "  [$r]$(add_spaces $((${#r}+4)))"
      if [[ $remoteUrl == http* ]]; then
        $verbose && echo "[${CGold}FOREIGN${COff}]"
        continue
      fi
      local update_needed=false
      [[ ! -z $params_main ]] && update_needed=true
      if ! $update_needed; then
        local b= oldIFS=$IFS
        IFS=
        while read b; do
          [[ $b == *HEAD* || $b == *detached* ]] && continue
          [[ "$(git rev-parse $b)" != "$(git rev-parse $r/$b)" ]] && update_needed=true && break
        done < <(git branch | cut -c3-)
        IFS=$oldIFS
        if ! $update_needed; then
          $verbose && echo "$label_uptodate"
          continue
        fi
      fi
      local ex_params=
      [[ "$(git branch | command grep "^\*" | cut -c3-)" != 'master' ]] && ex_params="--force"
      case $r in
      origin|_backup*|tom)
        if ! $verbose; then
          ! $repo_printed && echo -e "[${CGreen}${repo/$HOME/\~}${COff}]" && repo_printed=true
          echo -e -n "  [$r]$(add_spaces $((${#r}+4)))"
        fi
        ;;&
      origin|_backup*)
        local isRemote=false
        if [[ $remoteUrl == *@* || $remoteUrl == *:*  ]]; then
          isRemote=true
        fi
        ! $isRemote && [[ ! -d $remoteUrl ]] && echo "[${CRed}NOT EXIST${COff}]" && continue
        st="$($git_cmd $ex_params $r 2>&1)"
        echo "$label_done"
        ;;
      tom)
        st=$(mnt.sh --silent -D gh -r "$git_cmd $ex_params tom" 2>&1)
        echo "$label_done"
        ;;
      *) $verbose && echo "[${CGold}SKIPPED${COff}]";;
      esac
    done
    popd >/dev/null
  done
  return 0
} # }}}
rbb() { # {{{
  local dir=$(gitdir)
  [[ "$?" != "0" ]] && return 1

  local dst=$1
  local branch=$2

  dbg -n "Rebasing $branch on $dst... "
  [[ $(git rev-list --max-count=1 $dst) == $(git merge-base $branch $dst) ]] && dbg "Up to date" && return 0
  dbg ""

  local simple=true
  local cmd=
  [[ $3 == 'full' ]] && simple=false

  if $simple; then
    cmd="git rebase -q $dst $branch"
  else
    local ahead=$(git log --pretty=oneline _backup/$dst..$branch | wc -l)
    ahead=${ahead// }
    cmd="git rebase -q --onto $dst $branch~$ahead $branch"
  fi
  dbg $cmd
  eval $cmd

  return 0
} # }}}
svn_rb() { # {{{
  local dir=$(gitdir)
  [[ "$?" != "0" ]] && return 1
  local branch_map=".gitbranches"
  [[ ! -e "$branch_map" ]] && dbg "File with branches map ($branch_map) does not exist" && return 1
  local stash=
  local i=
  local branch=
  local line=
  local key=

  stash=$(git status --short)
  [[ -z $stash ]] && stash=false || stash=true
  $stash && git stash -q
  branch=$(git branch | command grep "*" | sed "s/* //")

  while read line; do
    [[ -z $line ]] && continue
    [[ $line == \#* ]] && continue
    rbb ${line/ *} ${line/* }
    if [[ $? != 0 ]]; then
      while true; do
        read -u 1 -p "Rebase has failed. Terminate[t/q], git rebase --skip[s]?" key
        case $key in
          t|T|q|Q) return 1;;
          s|S) git rebase -q --skip; break;;
        esac
      done
    fi
  done < $branch_map

  git checkout $branch
  $stash && git stash pop -q

  return 0
} # }}}
do_sync() { # {{{
  local params=$@
  local parRemote=
  local parBranch=
  local skipBackup=false
  local verbose=false
  local quiet=false
  local resetH=false
  while [[ ! -z $1 ]]; do
    case $1 in
    --skip-backup) skipBackup=true;;
    --remote) shift; parRemote+=" $1";;
    --branch) shift; parBranch=$1;;
    --reset)  resetH=true;;
    --verbose|-v) verbose=true;;
    --quiet) quiet=true; verbose=false;;
    esac
    shift
  done
  if [[ -z $parBranch ]]; then
    parBranch="$(git rev-parse --abbrev-ref HEAD)"
    [[ $parBranch == 'HEAD' ]] && parBranch=
  fi
  [[ -z $parBranch ]] && parBranch='master'
  local remotes="$parRemote origin _backup-gl _backup-gw _backup-hdd _backup-usb tom _backup"
  local done_remotes
  local remote
  local cmd="git-cmds.sh --test do_sync $params --skip-backup $(! $verbose && echo "--quiet")"
  export cmd
  source $BIN_PATH/bash/colors
  local dir=${PWD/$HOME/\~}
  ! $quiet && ! $verbose && echo -en "Repository [${CGreen}${dir}${COff}]$(add_spaces $((${#dir}+20)))"
  git submodule --quiet foreach 'cd $PWD; $cmd'
  $verbose && echo -en "Repository [${CGreen}${dir}${COff}]$(add_spaces $((${#dir}+20)))"
  for remote in $remotes; do
    local remoteUrl=$(git config --get remote.$remote.url)
    remoteUrl=${remoteUrl/\~/$HOME}
    if [[ $remoteUrl == http* ]]; then
      $verbose && echo "[${CGold}FOREIGN${COff}]"
      return 0
    fi
    if [[ $done_remotes == *$remote* && $remote != "_backup" ]]; then
      $verbose && echo "[${CGold}Skipping ($remote)${COff}]"
      continue
    fi
    done_remotes+=" $remote"
    [[ $(git remote) != *$remote* ]] && continue
    if ! $quiet; then
      echo "[${CCyan}Syncing from $remote...${COff}]"
    fi
    git fetch --recurse-submodules=no $remote
    if [[ $? == 0 ]]; then
      local stash=$(git status --short) skip=false
      [[ -z $stash ]] && stash=false || stash=true
      $stash && git stash -q
      git rebase -q $remote/$parBranch $parBranch
      [[ $? != 0 ]] && $resetH && git reset --hard $remote/$parBranch && skip=true
      if ! $skipBackup && ! $skip ; then
        $verbose && echo "Backing up..."
        git backup
      fi
      $stash && git stash pop -q
      break
    fi
  done
} # }}}
sync() { # {{{
  local remote=
  local branch=
  local repos=$PWD
  local saveTime=false
  local params=
  if [[ $1 == '@@' ]]; then
    local ret="--all --all-all --env --remote -r --branch -b --skip-backup --reset"
    local args=("$@")
    case ${args[$((${#args[*]}-1))]} in
    -b|--branch) ret="$(git branch | sed 's/^..//')";;
    -r|--remote) ret="$(git remote)";;
    esac
    echo $ret
    return 0
  fi
  while [[ ! -z $1 ]]; do
    case $1 in
    --all-all) repos=$GIT_REPOS; saveTime=true;;
    --all | --env) repos="$BASH_UPDATE_REPOS"; saveTime=true;;
    -r|--remote) shift; remote+=" --remote $1";;
    -b|--branch) shift; branch="--branch $1";;
    --skip-backup) params+=" --skip-backup";;
    -v|--verbose) params+=" --verbose";;
    --reset) params+=" --reset";;
    esac
    shift
  done
  source $BIN_PATH/bash/colors
  for r in $repos; do
    [[ $r == @* ]] && continue
    r=${r/:*}
    pushd $r >/dev/null
    do_sync $params $remote $branch
    popd >/dev/null
  done
  $saveTime && [[ -e $BIN_PATH/setup_updater.sh ]] && $BIN_PATH/setup_updater.sh --saveTime
} # }}}
commit_fast() { # {{{
  local dir=$(gitdir)
  [[ "$?" != "0" ]] && return 1
  if git diff --cached --quiet; then
    git diff --quiet && git ls-files -o --directory --exclude-standard | sed q1 >/dev/null 2>&1 && return 0
    git add -A
  fi
  local msg=
  case $1 in
  -m)  msg="$2";;
  -m*) msg="${1/-m}";;
  *)   msg="[$($BASH_PATH/aliases date)] ${1:-"Fast commit"}";;
  esac
  local template=$(git config --get utils.commit-fast)
  # e.g. git config --add user.commit-fast 'printf "%s%s" "$(date +"%Y%m%d")" "$( [[ ! -z $1 ]] && echo ": $@" || echo "")"'
  [[ ! -z $template ]] && msg="$(eval $template)"
  git commit --no-verify -q -m "$msg"
} # }}}
bash_switches() { # {{{
  local dir=$(gitdir)
  [[ "$?" != "0" ]] && return 1
  local state=${1:-false}
  git config utils.bash.showDirtyState $state
  git config utils.bash.showUntrackedFiles $state
  git config utils.bash.showStashState $state
  git config utils.bash.completeAdd $state
} # }}}
usage() { # {{{
  dbg "Incorrect command: $(basename $0) [$@]"
  return 1
} # }}}
userset() { # {{{
  if [[ $1 == '@@' ]]; then
    local ret="-d --default -f --full"
    local args=("$@")
    case ${args[$((${#args[*]}-1))]} in
    -d|--default) ret="$(echo ${!GIT_USER_*} | sed 's/GIT_USER_//g')";;
    -f|--full) ret="";;
    esac
    echo $ret
    return 0
  fi
  local user= name= email= value=
  local params=${@:-"-d default"}
  set -- $params
  while [[ ! -z $1 ]]; do
    case $1 in
      -d|--default)
        shift; user=${1:-'default'}
        user="GIT_USER_${user^^}"
        value="${!user}"
        [[ -z $value ]] && echo "GIT user ($user) not found" && return 1
        name="${value/:*}"
        email="${value/*:}"
        ;;
      -f|--full)
        shift; name="$1"
        shift; email="$1"
        ;;
    esac
    shift
  done
  [[ -z "$name" || -z "$email" ]] && echo "GIT user not fully specified ($name <$email>)" && return 1
  git config user.name  "$name"
  git config user.email "$email"
  echo "User set to ($name <$email>)"
} # }}}
range_diff() { # {{{
  local do_full=false
  local list_only=false
  local put_in_file=false
  local range="@~..@"
  local cmd= cmd_diff=
  while [[ ! -z $1 ]]; do
    case $1 in
    --full | -f ) do_full=true;;
    --list | -l ) list_only=true;;
    --file )      put_in_file=true;;
    *)            range=$1;;
    esac
    shift
  done
  if [[ $range == *@* || $range == *HEAD* ]]; then
    local head=$(git describe --all --always | sed 's|^heads/||')
    range=${range//@/$head}
    range=${range//HEAD/$head}
  fi
  cmd_diff="git diff -w $range"
  cmd+="$cmd_diff --name-only"
  ! $do_full   && cmd+=" | grep -v '/test/unit/'"
  $put_in_file && eval $cmd | sed "s/^/$cmd_diff -- /" > "$TMP_PATH/range-diff-files-$range.txt"
  ! $list_only && cmd+=" | LESS=\"-dFiJRSwX -x4 -z-4 -+F -~ -c\" xargs -n1 $cmd_diff -- "
  eval $cmd
} # }}}
# }}}
# MAIN {{{
cmd="${1:-usage}"
shift
if [[ $cmd != "--test" && $cmd != @@* ]]; then
  params=
  while [[ ! -z $1 ]]; do
    params+=" \"$1\""
    shift
  done
fi
case "$cmd" in # {{{
@@*) # {{{
  [[ $cmd == '@@' ]] && { cmd="$2"; shift 2; } || cmd="${cmd#@@}"
  cmd="${cmd//-/_}" params="@@"
  while [[ ! -z $1 ]]; do
    params+=" \"$1\""
    shift
  done;; # }}}
backup)        cmd=backup;;
svn-rb)        cmd=svn_rb;;
sync)          cmd=sync;;
gitst)         cmd=gitst;;
commit-fast)   cmd=commit_fast;;
bash-switches) cmd=bash_switches;;
userset)       cmd=userset;;
range-diff)    cmd=range_diff;;
--test)        cmd=$1; shift; params="$@";;
*)             cmd="usage \"$cmd\"";;
esac # }}}
# dbg "$cmd $params"
eval $cmd $params
exit $?
# }}}

