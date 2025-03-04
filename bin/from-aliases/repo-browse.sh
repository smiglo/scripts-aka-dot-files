#!/usr/bin/env bash
# vim: fdl=0

_repo-browse() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "-c -C"
    echo "+m +tags +tb +tmp --all-dirty"
    [[ ! -z $REPO_BROWSE_PATH_EXTRA ]] && echo "+extra"
    return 0
  fi # }}}
  local addMaster=false addTags=false addTmpRepos=false addTBRepos=false addExtra=false wereParams=false allDirty=false
  local repoList="$TMP_MEM_PATH/repo-$([[ "${BASH_SOURCE[0]}" == "$0" ]] && echo $PPID || echo $$).nfo" cleanRepoFile=false
  [[ ! -z $1 ]] && wereParams=true
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -C)            cleanRepoFile=true; REPO_LAST_PWD="";;&
    -c | -C)       REPO_LAST_LIST="";;
    --all-dirty)   allDirty=true;;
    +extra)        addExtra=true; cleanRepoFile=true;;
    +m)            addMaster=true;;
    +tags)         addTags=true;;
    +tb)           addTBRepos=true;;
    +tmp)          addTmpRepos=true;;
    esac
    shift
  done # }}}
  git_preview() { # {{{
    local repo="$(echo "$1" | sed 's/\s*@.*//')"
    (
      cd $repo
      local stat="$(git status --short 2>/dev/null)"
      if [[ ! -z $stat ]]; then
        echo "Status:"
        echo -e "$stat" | sed 's/^/  /'
        echo
        echo "--------"
        echo
      fi
      git log -1 --format=medium --date=local --color HEAD
      echo
      echo "    --------"
      echo
      git show --name-status --color -r HEAD | sed 's/^/    /'
      echo
      echo "--------"
      echo
      git log -1 -p --color
      echo
    )
  }
  export -f git_preview
  # }}}
  [[ -z $REPO_LAST_LIST && -z $REPO_LAST_PWD ]] && echo "On the first run, all dirty repos are shown" >/dev/stderr && allDirty=true
  local listSrc= listDst="$REPO_LAST_LIST" listNew= wasPushd=false i= err=0 br= stat= clean=
  [[ ! -z "$REPO_LAST_PWD" ]] && wasPushd=true && pushd "$REPO_LAST_PWD" >/dev/null 2>&1
  if [[ -z "$REPO_LAST_LIST" ]] || $wereParams; then # {{{
    $cleanRepoFile && rm -f "$repoList"
    [[ -e "$repoList" ]] && listSrc="$(cat "$repoList")"
    if [[ -z "$listSrc" ]]; then
      $wasPushd && wasPushd=false && popd >/dev/null 2>&1
      local d= i=
      for d in $(eval find . $(! $addExtra && echo "-path '*/$REPO_BROWSE_PATH_EXTRA/*' -prune -o") -type d -name .git -print -a -prune); do
        d=$(echo $d | sed -e 's|^\./||' -e 's|/\.git||' -e 's|\.git|.|')
        echo "$d"
        pushd $d >/dev/null
        for i in $(git submodule status | awk '!/^-/{print $2}'); do
          echo "$d/$i"
        done
        popd >/dev/null
      done | sort >"$repoList"
      listSrc="$(cat "$repoList")"
    else
      echo -e "$listSrc" >"$repoList"
    fi
    export REPO_LAST_PWD="$PWD"
    listDst=""
  else
    listSrc="$listDst"
    listDst=""
  fi # }}}
  [[ -z "$listSrc" ]] && echo "No repos have been found" >/dev/stderr && return 1
  while read i; do # {{{
    i="$(echo "$i" | sed 's/\s*@.*//')"
    case $i in # {{{
    .repo/*) continue;;
    tmp/*) ! $addTmpRepos && continue;;
    tb-*)  ! $addTBRepos && continue;;
    *) [[ ! -z $REPO_BROWSE_PATH_EXTRA && $i == */"$REPO_BROWSE_PATH_EXTRA/buildhistory" ]] && continue;;
    esac # }}}
    cd "$i"
    br="$(git name-rev --name-only HEAD | sed -e 's|remotes/||')"
    stat="$(git status --short 2>/dev/null)"
    clean=false
    [[ -z "$stat" ]] && clean=true
    [[ ! -z "$REPO_BROWSE_CLEAN_CHECK" && "$stat" =~ $REPO_BROWSE_CLEAN_CHECK ]] && clean=true
    cd - >/dev/null 2>&1
    if ! $addTags; then
      if $clean || ! $allDirty; then
        case $br in
        tags/*) continue;;
        [0-9]*.[0-9]*.[0-9]*) continue;;
        v[0-9]*.[0-9]*) continue;;
        *) [[ ( ! -z $REPO_BROWSE_TAGS && "$br" =~ $REPO_BROWSE_TAGS ) ]] && continue;;
        esac
      fi
    fi
    if ! $addMaster; then
      if $clean || ! $allDirty; then
        case $br in
        master) [[ $i != tmp/* && $i != tb-* ]] && continue;;
        devel | next | origin/* | HEAD) continue;;
        home-work | tb/mods) $clean && continue;;
        *) [[ "$br" =~ master(~[0-9]*)? || ( ! -z $REPO_BROWSE_MASTER_BRANCH && "$br" =~ $REPO_BROWSE_MASTER_BRANCH ) ]] && continue;;
        esac
      fi
    fi
    listDst+="$i @${CYellow}${br:-master}${COff}$(! $clean && echo " ${CRed}DIRTY${COff}")\n"
  done <<<"$(echo -e "$listSrc")" # }}}
  while read i; do # {{{
    [[ -z $i ]] && continue
    listNew+="$i\n"
    i="$(echo "$i" | sed 's/\s*@.*//')"
    cd "${i%% @*}"
    $SHELL </dev/tty >/dev/tty 2>/dev/stderr
    err=$?
    cd - >/dev/null 2>&1
    [[ $err != 0 ]] && break
  done <<<"$(echo -e "$listDst" | sed '/^\s*$/d' | { which column &>/dev/null && column -t || cat -; } | fzf -0 -m --preview='git_preview {}' --preview-window=right:50% --ansi)" # }}}
  $wasPushd && wasPushd=false && popd >/dev/null 2>&1
  if [[ $err == 0 && ! -z $listNew ]]; then # {{{
    if [[ -z "$REPO_LAST_LIST" ]] || $wereParams; then
      export REPO_LAST_LIST="$listNew"
    fi
  fi # }}}
  unset git_preview
} # }}}
_repo-browse "$@"

