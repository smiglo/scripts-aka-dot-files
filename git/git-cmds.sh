#!/usr/bin/env bash
# vim: fdl=0

# Functions {{{
_dbg() { # {{{
  echo -e $@ >/dev/stderr;
} # }}}
_gitdir() { # {{{
  local dir=$(git rev-parse --git-dir 2>/dev/null)
  [[ $? != 0 ]] && return 1
  (command cd $dir/..; pwd)
  return 0
} # }}}
_add_spaces() { # {{{
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
_check_repo() { # {{{
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
  local msg="[${CGreen}${dir/$HOME/~}${COff}]$(_add_spaces $((${#dir}+2)))"
  [[ ! -e $dir/.git ]] && echo -e "$msg[${CRed}.GIT${COff}]" && return
  pushd $dir > /dev/null
  local git=".git"
  [[ -f $git ]] && git=$(cat $git | awk '{print $2}')
  (
    unset -f $(declare -F | awk '{print $3}')
    ! $skipSubmodules && git submodule --quiet foreach "git-cmds.sh --test _check_repo \$PWD --skipSubmodules $(! $display_status && echo '--silent')"
  )
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
    case $r in
    origin | _backup*);;
    *) continue;;
    esac
    if [[ $r == 'origin' && $PWD != ${MY_PROJ_PATH}* ]]; then # {{{
      if ! $check_origin || ! $check_full_owr; then
        continue
      fi
    fi # }}}
    echo "$r" | command grep -qvE "$(_getMainRemotes)" && ! $check_full_owr && continue
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
    _check_repo ${dir//:/ }
  done
} # }}}
_getMainRemotes() { # {{{
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
  while [[ ! -z $1 ]]; do # {{{
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
  done # }}}

  local label_uptodate="[${CGold}UP-TO-DATE${COff}]"
  local label_done="[${CCyan}DONE${COff}]"

  local repo= orig_repo= repo_printed=false
  for repo in $repos; do # {{{
    if [[ " $GIT_REPOS $BASH_UPDATE_REPOS " == *" $repo "* ]]; then
      [[ -e $BIN_PATH/setup_updater.sh ]] && $BIN_PATH/setup_updater.sh --saveTime
      break
    fi
  done # }}}
  for orig_repo in $repos; do # {{{

    repo=${orig_repo/:*}
    [[ $repo == @* ]] && repo=${repo/@}

    [[ ! -e $repo ]] && continue
    pushd $repo >/dev/null
    local dir=$(_gitdir)
    if [[ "$?" != "0" ]]; then # {{{
      echo -e -n "[${CGreen}${repo/$HOME/~}${COff}]"
      echo "$(_add_spaces $((${#repo}+2)))[${CRed}.GIT${COff}]"
      popd >/dev/null
      continue
    fi # }}}

    for r in $GIT_REPOS; do # {{{
      r=${r/:*/}
      [[ "${dir/*projects\//projects/}" == "${r/@*projects\//projects/}" ]] && params_main+=" --force" && break
    done # }}}

    local sub_params="$params_main"
    $checkFull && sub_params+=" --full"
    $verbose   && sub_params+=" --verbose"

    (
      unset -f $(declare -F | awk '{print $3}')
      ! $skipSubmodules && git submodule --quiet foreach "git backup --skip-submodules $sub_params"
    )

    $verbose && echo -e "[${CGreen}${repo/$HOME/~}${COff}]"
    local git_cmd="git push --recurse-submodules=no $params_main" r=

    for r in $(git remote); do # {{{
      local remoteUrl=$(git config --get remote.$r.url)
      remoteUrl=${remoteUrl/\~/$HOME}
      local st=
      if [[ $r == 'origin' ]]; then # {{{
        if [[ $orig_repo != *:origin* ]] && ! $checkFull && [[ $PWD != ${MY_PROJ_PATH}* ]]; then
          continue
        fi
      fi # }}}
      echo "$r" | command grep -qvE "$(_getMainRemotes)" && ! $checkFull && continue
      $verbose && echo -e -n "  [$r]$(_add_spaces $((${#r}+4)))"
      if [[ $remoteUrl == http* ]]; then # {{{
        $verbose && echo "[${CGold}FOREIGN${COff}]"
        continue
      fi # }}}
      local update_needed=false
      [[ ! -z $params_main ]] && update_needed=true
      if ! $update_needed; then # {{{
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
      fi # }}}
      local ex_params=
      [[ "$(git branch | command grep "^\*" | cut -c3-)" != 'master' ]] && ex_params="--force"
      case $r in
      origin|_backup*|tom) # {{{
        if ! $verbose; then
          ! $repo_printed && echo -e "[${CGreen}${repo/$HOME/~}${COff}]" && repo_printed=true
          echo -e -n "  [$r]$(_add_spaces $((${#r}+4)))"
        fi
        ;;& # }}}
      origin|_backup*) # {{{
        local isRemote=false
        if [[ $remoteUrl == *@* || $remoteUrl == *:*  ]]; then
          isRemote=true
        fi
        ! $isRemote && [[ ! -d $remoteUrl ]] && echo "[${CRed}NOT EXIST${COff}]" && continue
        st="$($git_cmd $ex_params $r 2>&1)"
        echo "$label_done"
        ;; # }}}
      tom) # {{{
        st=$(mnt.sh --silent -D gh -r "$git_cmd $ex_params tom" 2>&1)
        echo "$label_done"
        ;; # }}}
      *) $verbose && echo "[${CGold}SKIPPED${COff}]";;
      esac
    done # }}}
    if ! $skipSubmodules; then
      local repoUpdateFile=$TMP_PATH/.repo-update r=$(basename $repo)
      local tLocal="$(git log -1 --format="%cd" --date=unix $(git rev-parse --abbrev-ref HEAD))"
      r="$(echo "$r" | sed 's/[.,-]/_/g')"
      if [[ -e $repoUpdateFile ]] && command grep -q "^tLastSync_$r=" $repoUpdateFile; then
        sed -i 's/^tLastSync_'$r'=.*/tLastSync_'$r'='$tLocal'/' $repoUpdateFile
      else
        echo "tLastSync_$r=$tLocal" >>$repoUpdateFile
      fi
    fi
    popd >/dev/null
  done # }}}
  return 0
} # }}}
rbb() { # {{{
  local dir=$(_gitdir)
  [[ "$?" != "0" ]] && return 1

  local dst=$1
  local branch=$2

  _dbg -n "Rebasing $branch on $dst... "
  [[ $(git rev-list --max-count=1 $dst) == $(git merge-base $branch $dst) ]] && _dbg "Up to date" && return 0
  _dbg ""

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
  _dbg $cmd
  eval $cmd

  return 0
} # }}}
stash_toggle()  { # stash-toggle # {{{
  local pppid="${1:-$(command ps --no-headers -o cmd,pid | tac | grep -A1 "^git" | sed -n '2p' | awk '{print $2}')}"
  local stash_f="$TMP_MEM_PATH/git-stash-$pppid"
  local stash=$(git status --short)
  [[ -z $stash ]] && stash=false || stash=true
  if $stash; then
    touch $stash_f
    git stash -q
  elif [[ -e $stash_f ]]; then
    rm -f $stash_f
    [[ ! -z $(git stash list) ]] && git stash pop -q
  fi
} # }}}
svn_rb() { # {{{
  local dir=$(_gitdir)
  [[ "$?" != "0" ]] && return 1
  local branch_map=".gitbranches"
  [[ ! -e "$branch_map" ]] && _dbg "File with branches map ($branch_map) does not exist" && return 1
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
_do_sync() { # {{{
  local params=$@ parRemote= parBranch= skipBackup= verbose=false quiet=false resetH=false interactive=true dots=true repoUpdateFile=$TMP_PATH/.repo-update skipSubmodules=false repo=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --skip-backup) skipBackup=true;;
    --do-backup) skipBackup=false;;
    --remote) shift; parRemote+=" $1";;
    --branch) shift; parBranch=$1;;
    --reset)  resetH=true; [[ -z $skipBackup ]] && skipBackup=true;;
    --verbose|-v) verbose=true;;
    --quiet) quiet=true; verbose=false;;
    --no-dots) dots=false;;
    --interactive)    interactive=true;;
    --no-interactive) interactive=false;;
    --skip-submodules) skipSubmodules=true;;
    --repo) shift; repo=$1;;
    esac
    shift
  done # }}}
  [[ -z $repo ]] && repo="$(basename "$PWD")" && echo "Repo name not provided, getting it from dir name [$repo]" >/dev/stderr
  [[ -z $skipBackup ]] && skipBackup=false
  $verbose && dots=false
  if [[ -z $parBranch ]]; then # {{{
    parBranch="$(git rev-parse --abbrev-ref HEAD)"
    [[ $parBranch == 'HEAD' ]] && parBranch=
  fi # }}}
  local remotes="$parRemote origin _backup-gl _backup-gw _backup-hdd _backup-usb tom _backup"
  local done_remotes= remote
  local cmd="git-cmds.sh --test _do_sync $params --repo $repo --skip-submodules --skip-backup $(! $verbose && echo "--quiet")"
  export cmd
  source $BIN_PATH/bash/colors
  local dir=${PWD/$HOME/~}
  local tLastSync="tLastSync_$repo" tLocal="$(git log -1 --format="%cd" --date=unix $parBranch)"
  [[ -e $repoUpdateFile ]] && source $repoUpdateFile
  tLastSync="${!tLastSync}"
  [[ -z $tLastSync ]] && tLastSync=0
  if ! $skipSubmodules; then
    r="$(echo "$repo" | sed 's/[.,-]/_/g')"
    if [[ -e $repoUpdateFile ]] && command grep -q "^tLastSync_$r=" $repoUpdateFile; then
      sed -i 's/^tLastSync_'$r'=.*/tLastSync_'$r'='$tLocal'/' $repoUpdateFile
    else
      echo "tLastSync_$r=$tLocal" >>$repoUpdateFile
    fi
  fi
  local shaLocal="$(git log -1 --format="%H" $parBranch)"
  if ! $quiet; then # {{{
    if $dots; then
      $ALIASES progress --mark --msg "Repository [${CGreen}${dir}${COff}]$(_add_spaces $((${#dir}+3)) 3)"
    elif ! $verbose; then
      echo -en "Repository [${CGreen}${dir}${COff}]$(_add_spaces $((${#dir}+20)))"
    fi
  fi # }}}
  (
    unset -f $(declare -F | awk '{print $3}')
    git submodule --quiet foreach 'command cd $PWD; $cmd || true'
  )
  $verbose && echo -en "Repository [${CGreen}${dir}${COff}]$(_add_spaces $((${#dir}+20)))"
  for remote in $remotes; do
    local remoteUrl=$(git config --get remote.$remote.url)
    remoteUrl=${remoteUrl/\~/$HOME}
    if [[ $remoteUrl == http* ]]; then # {{{
      $verbose && echo "[${CGold}FOREIGN${COff}]"
      return 0
    fi # }}}
    if [[ $done_remotes == *$remote* && $remote != "_backup" ]]; then # {{{
      $verbose && echo "[${CGold}Skipping ($remote)${COff}]"
      continue
    fi # }}}
    done_remotes+=" $remote"
    [[ $(git remote) != *$remote* ]] && continue
    ! $quiet && ! $dots && echo "[${CCyan}Syncing from $remote...${COff}]"
    if git fetch --recurse-submodules=no $remote; then
      local shaRemote="$(git log -1 --format="%H" $remote/$parBranch)" shaBase="$(git merge-base $remote/$parBranch $parBranch)"
      local stash=$(git status --short)
      [[ -z $stash ]] && stash=false || stash=true
      $stash && git stash -q
      if [[ $shaBase == $shaRemote ]]; then
        if ! $skipBackup; then # {{{
          $verbose && echo "Backing up..."
          git backup
        fi # }}}
      else
        git tag -d tmp/sync >/dev/null 2>&1
        git tag tmp/sync >/dev/null 2>&1
        if git rebase -q $remote/$parBranch $parBranch; then # {{{
          if ! $skipBackup; then # {{{
            $verbose && echo "Backing up..."
            git backup
          fi # }}}
          # }}}
        else
          if [[ $tLastSync -ge $tLocal ]]; then # {{{
            git rebase --abort
            git reset --hard $remote/$parBranch
            if ! $skipBackup; then # {{{
              $verbose && echo "Backing up..."
              git backup
            fi # }}} }}}
          elif $resetH; then # {{{
            git rebase --abort
            git reset --hard $remote/$parBranch
            if ! $skipBackup; then # {{{
              $verbose && echo "Backing up..."
              git backup
            fi # }}} }}}
          elif $interactive; then # {{{
            ! $quiet && $dots && { $ALIASES progress --unmark; dots=false; }
            git rebase --abort
            git reset --hard
            echo "Resolve confilicts and exit shell..." >/dev/stderr
            if $SHELL </dev/tty >/dev/tty && ! $skipBackup; then # {{{
              $verbose && echo "Backing up..."
              git backup
            fi # }}} }}}
            $ALIASES progress --mark --msg "Repository [${CGreen}${dir}${COff}]$(_add_spaces $((${#dir}+3)) 3)"
          else # {{{
            ! $quiet && $dots && { $ALIASES progress --unmark;  dots=false; }
            echo "Rebase was aborted due to conflicts..." >/dev/stderr
            git rebase --abort
            git reset --hard
          fi # }}}
        fi
      fi
      $stash && git stash pop -q
      break
    fi
  done
  ! $quiet && $dots && $ALIASES progress --unmark
} # }}}
sync() { # {{{
  local remote= branch=
  local repos=$PWD repo= r=
  local params=
  if [[ $1 == '@@' ]]; then # {{{
    local ret="--all --all-all --env --remote -r --branch -b --skip-backup --do-backup --interactive --reset --no-dots"
    local args=("$@")
    case ${args[$((${#args[*]}-1))]} in
    -b|--branch) ret="$(git branch | sed 's/^..//')";;
    -r|--remote) ret="$(git remote)";;
    esac
    echo $ret
    return 0
  fi # }}}
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --all-all) repos=$GIT_REPOS;;
    --all | --env) repos="$BASH_UPDATE_REPOS";;
    -r|--remote) shift; remote+=" --remote $1";;
    -b|--branch) shift; branch="--branch $1";;
    *) params+=" $1";;
    esac
    shift
  done # }}}
  for repo in $repos; do # {{{
    if [[ " $GIT_REPOS $BASH_UPDATE_REPOS " == *" $repo "* ]]; then
      [[ -e $BIN_PATH/setup_updater.sh ]] && $BIN_PATH/setup_updater.sh --saveTime
      break
    fi
  done # }}}
  source $BIN_PATH/bash/colors
  for r in $repos; do # {{{
    [[ $r == @* ]] && continue
    r=${r/:*}
    [[ ! -e $r ]] && continue
    pushd $r >/dev/null
    _do_sync $params --repo $(basename $r) $remote $branch
    popd >/dev/null
  done # }}}
} # }}}
commit_fast() { # commit-fast # {{{
  local dir=$(_gitdir)
  [[ "$?" != "0" ]] && return 1
  if git diff --cached --quiet; then
    git diff --quiet && git ls-files -o --directory --exclude-standard | sed q1 >/dev/null 2>&1 && return 0
    git add -A
  fi
  local msg=
  case $1 in
  -m)  msg="$2";;
  -m*) msg="${1/-m}";;
  *)   msg="[$($ALIASES date)] ${1:-"Fast commit"}";;
  esac
  local template=$(git config --get utils.commit-fast)
  # e.g. git config --add user.commit-fast 'printf "%s%s" "$(date +"%Y%m%d")" "$( [[ ! -z $1 ]] && echo ": $@" || echo "")"'
  [[ ! -z $template ]] && msg="$(eval $template)"
  git commit --no-verify -q -m "$msg"
} # }}}
bash_switches() { # bash-switches,bsw bbb # {{{
  local dir=$(_gitdir)
  [[ "$?" != "0" ]] && return 1
  local state=${1:-false}
  git config utils.bash.showDirtyState $state
  git config utils.bash.showUntrackedFiles $state
  git config utils.bash.showStashState $state
  git config utils.bash.completeAdd $state
} # }}}
_usage() { # {{{
  _dbg "Incorrect command: $(basename $0) [$@]"
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
  [[ -z $@ ]] && set -- -d default
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
range_diff() { # range-diff # {{{
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
log() { # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "--fzf -l --this"
    git ls-files $GIT_PREFIX| sed 's/^/.\//'
    return 0
  fi # }}}
  local logMethod='log --pretty=date-first --date=relative' params= range= files= c= max=15 br=HEAD fzfUse=false d=
  local fzfParams='--pretty=date-first --date=format:"%Y-%m-%d-%H%M%S"'
  local fzfThisDir=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --fzf)  fzfUse=true; logMethod=log; br=;;
    -l)     logMethod=$2; $fzfUse && fzfParams=; shift;;
    --this) fzfThisDir=true;;
    -*)     params+="$1 ";;
    *) # {{{
      if [[ $1 == /* || -e $1 || -e $GIT_PREFIX$1 ]]; then
        if [[ $1 == /* || -e $1 ]]; then
          files+="$1 "
        else
          files+="$GIT_PREFIX$1 "
        fi
        max=100
      elif git log --pretty='%h' --all | command grep -q "\<$1\>"; then
        for i; do
          git info -p $i
        done
        exit 0
      else
        br=$1
      fi
      ;; # }}}
    esac
    shift
  done # }}}
  if $fzfUse; then # {{{
    $fzfThisDir && [[ -z $files && ! -z $GIT_PREFIX ]] && files="${GIT_PREFIX%/}/"
    if $FZF_INSTALLED; then
      fzf_tools() { # {{{
        show_change() { # {{{
          local sha=$1
          git log --pretty=fuller --date=local -1 "$sha"
          echo; echo '    ----'
          git diff $sha~..$sha --name-status | sed -e 's/^../    /'
          echo '    ----'; echo
          git diff -w $sha~..$sha | \
            if [[ $2 == '--as-diff' ]] && which colordiff >/dev/null 2>&1; then colordiff -u; else cat -; fi
        } # }}}
        local sha="$(echo "$2" | sed 's/.*: \([0-9a-z]\{5,\}\) - .*/\1/')"
        [[ -z $sha ]] || ! git log --pretty='%h' --all | command grep -q "\<$sha\>" && return 1
        case $1 in
        --preview) # {{{
          show_change $sha --as-diff
          ;; # }}}
        --send | --view) # {{{
          local list= l=
          while read l; do
            [[ -d "$l" ]] && continue
            list+="$l "
          done < <(git diff $sha~..$sha --name-status | awk '{print $2}')
          ;;& # }}}
        --view) # {{{
          vim --Fast <(show_change $sha) $list </dev/tty >/dev/tty 2>>$HOME/l.tmp
          ;; # }}}
        --send) # {{{
          local i=
          list="$(echo "$list" | sed 's|^|'$PWD'/|')"
          for i in $list; do
            [[ ! -d $i ]] && $ALIASES fzf_exe -c pane -f $i
            sleep 1
          done
          ;; # }}}
        esac
      } # }}}
      export -f fzf_tools
      local shas= prompt="Log"
      if [[ ! -z "$files" ]]; then # {{{
        local f="$(echo $files)" suffix=
        [[ "$f" == *\ * ]] && suffix=" ... "
        f="${f%% *}"
        if [[ -e "$f" ]]; then
          f="$(command cd "$(dirname "$f")" && pwd)/$(basename "$f")"
          [[ -d "$f" ]] && suffix="/$suffix" && f="${f%/}"
          f="${f#$PWD/}"
          if [[ ${#f} -gt 15 ]]; then
            local fTmp=".../$(basename "$(dirname "$f")")/$(basename "$f")"
            [[ ${#fTmp} -lt ${#f} ]] && f="$fTmp"
          fi
          prompt+=": $f$suffix"
        else
          prompt+=": $f"
        fi
      fi # }}}
      prompt+="> "
      shas="$(eval git $logMethod $fzfParams --color $br $([[ ! -z $files ]] && echo "-- $files") \
        | fzf -m +s --ansi  --height 90% \
          --prompt  "$prompt" \
          --preview 'fzf_tools --preview "{}"' \
          --bind    'f2:execute(fzf_tools --view "{}")' \
          --bind    'f3:execute(fzf_tools --send "{}")' \
        | sed 's/.*: \([0-9a-z]\{5,\}\) - .*/\1/')"
      if [[ $? == 0 && ! -z "$shas" ]]; then # {{{
        if [[ -t 1 ]]; then
          source $HOME/.bashrc --do-basic
          echo -n "$shas" | tr '\n' ' ' | ccopy
        else
          echo "$shas"
        fi
      fi # }}}
    else
      eval git $logMethod $fzfParams --color $br $([[ ! -z $files ]] && echo "-- $files")
    fi # }}}
  else # {{{
    c=$(($(git rev-list --count $br)-1))
    [[ $c -gt $max ]] && c=$max
    range="$br~$c..$br"
    git $logMethod $params $range $([[ ! -z $files ]] && echo "-- $files")
  fi # }}}
  return 0
} # }}}
cba() { # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "1 -1 -b -s " {-,+}{15,30,100}
    echo "master"
    git log -n 30 --pretty='%h'
    return 0
  fi # }}}
  local d= c= first=HEAD fzf_p= gitlog= firstRun=true stashed=false changed=false pattern='-------' cnt=${GIT_CBA_MAX:-30}
  local backup=false use_smart=true useFirst=false autoQuit=false autoQuitAsk=true curHead=
  # Submodules # {{{
  (
    sm= err=0
    while read i; do
      case $i in
      Entering\ *) # {{{
        sm=$(echo $i | awk '{print $2}' | sed "s/'//g");; # }}}
      \?\?\ *) # {{{
        continue;; # }}}
      *) # {{{
        [[ -z $sm ]] && continue
        command cd $sm
        git cba $@ +b </dev/tty >/dev/tty
        err=$?
        command cd ->/dev/null 2>&1
        [[ $err != 0 ]] && return $err
        sm=;; # }}}
      esac
    done < <(git submodule foreach --recursive git status --short)
  ) # }}}
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -1 | 1)  useFirst=true; autoQuit=true; [[ $1 == '-1' ]] && autoQuitAsk=false;;
    -[0-9]*) cnt=${1#-};;
    -b)      backup=true;;
    +b)      backup=false;;
    -s)      use_smart=false;;
    +*)      cnt="${1#+}";;
    *) # {{{
      if [[ -e $1 || -e $GIT_PREFIX$1 ]]; then
        d="-- $GIT_PREFIX$1"
      elif git branch --all | command grep -q "$1"; then
        first="$1"
      else
        c="$1"
      fi;; # }}}
    esac
    shift
  done # }}}
  [[ $(git rev-list --count HEAD) -lt $cnt ]] && cnt=$(($(git rev-list --count HEAD)-1))
  curHead="$(git log -1 --pretty=%h)"
  fzf_p="--height=80% --layout=reverse-list --no-sort +m --ansi -1 -0 \
      --prompt='Fix-Up> ' \
      --preview='git sh {2}' --preview-window=down:hidden"
  gitlog="log --pretty=format:'%C(auto)%h%Creset %C(auto)%d%Creset %s %Cgreen(%cr)' --color=always"
  [[ ! -z $GIT_CBA_QUERY ]] && fzf_p+=" --query='$GIT_CBA_QUERY '"
  if [[ -z $c ]]; then # {{{
    while ! git diff --quiet $d || ! git diff --cached --quiet $d; do
      firstRun=false
      if git diff --cached --quiet $d; then
        if git diff --quiet $([[ ! -z $d ]] && echo "-- $d"); then
          $firstRun && echo "Nothing to commit" >/dev/stderr && return 0
          break
        fi
        git add -p $d
      fi
      if git diff --cached --quiet; then
        break
      fi
      c="$( \
        { $useFirst || echo "$pattern"
          commits=
          if $use_smart; then
            $autoQuit && [[ $(git status --short | wc -l) -gt 1 ]] && autoQuit=false
            commits="$(eval git $gitlog $(git merge-base $first HEAD~$cnt).. $GIT_CBA_LOG_PARAMS -- $(git status --short | awk '/^M/ {print $2}'))"
          fi
          if [[ ! -z "$commits" ]]; then
            echo "$commits" | { $useFirst && head -n1 || cat -; }
          else
            eval git $gitlog $(git merge-base $first HEAD~$cnt).. $GIT_CBA_LOG_PARAMS $commits
          fi
        } \
        | eval fzf $fzf_p  \
        | awk '{print $1}' \
      )"
      [[ $? == 0 ]] || return 1
      [[ ! -z $c ]] || break
      if [[ "$c" == "$pattern" ]]; then
        first="$(git merge-base $first HEAD~$cnt)"
        git commit --no-verify
      else
        first="$(git merge-base $first ${c}~)"
        git commit --fixup=$c --no-verify
        $useFirst && echo -e "\n---\n"
      fi
      changed=true
    done
    $firstRun && first="$(git merge-base $first HEAD~$cnt)" && changed=true
    $changed || return 0 # }}}
  else # {{{
    first="${c}~"
    [[ $c == HEAD* ]] && first+='~'
    git commit --fixup=$c --no-verify
  fi # }}}
  ! git diff --quiet && git stash >/dev/null 2>&1 && stashed=true
  if $autoQuit; then # {{{
    git log --graph --color=always $curHead~.. | sed -e '$s/^\*/ /'
    echo
    if $autoQuitAsk; then # {{{
      local k=
      k="$($ALIASES progress --wait 5s --msg "ok?" --no-err --keys "qn")"
      if [[ $? == 0 ]]; then
        export VIM_ENV="+:quit"
      elif [[ ${k,,} == 'q' ]]; then
        return
      fi
    fi # }}}
  fi # }}}
  git rebase -i --autosquash $first
# # could be use to open editor silently
#   GIT_EDITOR=/bin/ed git rebase -i --autosquash $first <<-EOF
# 			wq
# 		EOF
  $stashed && git stash pop >/dev/null 2>&1
  $backup && git backup
} # }}}
# }}}
# MAIN {{{
cmd="${1:-_usage}"
shift
if [[ $cmd != "--test" && $cmd != @@* ]]; then
  params=
  while [[ ! -z $1 ]]; do
    params+=" \"$1\""
    shift
  done
fi
! declare -f echorm >/dev/null 2>&1 && [[ -e $ECHOR_PATH/echor ]] && source $ECHOR_PATH/echor
case "$cmd" in # {{{
@@*) # {{{
  [[ $cmd == '@@' ]] && { cmd="$2"; shift 2; } || cmd="${cmd#@@}"
  if [[ $cmd == '@@' || -z $cmd ]]; then
    sed -n '/^[a-zA-Z][^ ]*() *{\( *# *\(.*\)\)\? *# *{{{/s/^\(.*\)() *{\( *# \(.*\)\)\? *# *{{{/ \1 \3 /p' $0 # }}} # }}}
    exit 0
  fi
  cmd="${cmd//-/_}" params="@@"
  case $cmd in
  l | lf | lgo) cmd=log;;
  esac
  while [[ ! -z $1 ]]; do
    params+=" \"$1\""
    shift
  done;; # }}}
--test) # {{{
  cmd=$1; shift; params="$@";; # }}}
*) # {{{
  found=false
  while read n a; do
    a="${a//,/ }"
    [[ " $a " == *\ $cmd\ * || $cmd == $n ]] && found=true && cmd=$n && break
  done <<<"$(sed -n '/^[a-zA-Z][^ ]*() *{\( *# *\(.*\)\)\? *# *{\{3\}/s/^\(.*\)() *{\( *# \(.*\)\)\? *# *{\{3\}/ \1 \3 /p' $0)" #  } } } }
  ! $found && cmd="_usage \"$cmd\""
  ;; # }}}
esac # }}}
echorm "$cmd $params"
eval $cmd $params
exit $?
# }}}

