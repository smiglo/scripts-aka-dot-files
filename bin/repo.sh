#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  if [[ $2 == --shorts ]]; then # {{{
    echo "!d -D --diff-ign"
    echo "!dd -D"
    exit 0
  fi # }}}
  case $(compl-short -i $3) in
  -r | --repos) find . -maxdepth 2 -type d -path '*/build-*' -prune -o -name .git -exec dirname {} \;;;
  --base) # {{{
    ret="$(git branch --all 2>/dev/null | sed -e 's|\*||' -e 's|remotes/||' -e 's|->||')"
    echo "${ret:----}";; # }}}
  *) case " $@" in # {{{
    *\ --dump-rev*) echo "--skip-clean --tags --info --full --short --log --base --skip-master --date --date-first --log-p --plain --diff-ign";;
    *\ --commit*)   echo "-b --bash";;
    *)
      echo "--help"
      echo "-r --repos -R -b --bash --exit-on-fail --no-colors -D --diff-ign --plain +br"
      echo -l --{,no-}list
      echo --commit{,-all}
      echo --dump-rev{,-all}
      [[ $2 != '--' ]] && compl-short --shorts
      [[ ! -z $REPO_EXCLUDE_SEARCH_PATH || ! -z $REPO_BROWSE_PATH_EXTRA ]] && echo "-a --all"
      echorm -f? && echo "-s" || echo "-v"
      ;; # }}}
  esac;;
  esac
  exit 0 # }}}
elif [[ $1 == --help ]]; then # {{{
  compl-help repo.sh
  exit 0
fi # }}}

# setup # {{{
echorm -M -?
all=false
colors=
dumpRevAll=false
dumpRevBaseBranch=
dumpRevInfo=false
dumpRevInfoFull=false
dumpRevSkipClean=true
dumpRevTags=
dumpRevMaxCommits=6
dumpRevSkipMasters=false
dumpRevPlain=false
dumpRevDumpDiff=true
err=0
exitOnFail=false
findCommitAllBranches=false
findCommitDo=false
findCommitRegEx=
list=false
list_addBranch=false
whatToDo=
wtd=
if [[ -t 0 ]]; then
  this_dir=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ ! -z $this_dir ]]; then
    repos=$this_dir
  else
    repos="${REPO_LIST:-$REPO_LIST_DEFAULT} $REPOS_TO_INCLUDE"
    [[ -e $repos && ! -d $repos ]] && repos="$(cat $repos)"
  fi
else
  repos="$(cat -)"
fi
repos_tmp=
for i in $repos; do
  [[ -e $i ]] && repos_tmp+=" $i"
done
repos="$repos_tmp"
cRepo= cBr= cDirty= cSha= cOff=
git_log_params="--pretty=tb --graph"
defaultParams="--dump-rev"
# }}}
[[ $@ = '-b' ]] && set -- $@ --repos -
if [[ ! -t 1 && -z $1 ]]; then # {{{
  defaultParams="--dump-rev"
fi # }}}
if [[ -z $1 ]]; then
  echorm "Using default args: $defaultParams"
  set -- $defaultParams
fi
eval set -- $(compl-short --shorts --args "$@")
[[ $1 == -D ]] && shift && set -- $defaultParams "$@"
echorm 2 "Args [$@]"
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -a | --all)      all=true;;
  -r | --repos) # {{{
    repos="$2"
    if [[ $repos == '-' ]]; then
      repos="$($0 --dump-rev -l)"
    elif [[ -e $repos && ! -d $repos ]]; then
      repos="$(cat $repos)"
    fi
    shift;; # }}}
  -R)              repos=;;
  -b | --bash)     [[ -z $whatToDo ]] && whatToDo='run-bash'; wtd="$SHELL </dev/tty >/dev/tty 2>/dev/stderr"; echorm -; exitOnFail=true;;
  -l | --list)     list=true;;
  +br)             list=true; list_addBranch=true; whatToDo='dump-rev';;
  --no-list)       list=false;;
  --no-colors)     colors=false;;
  --colors)        colors=true;;
  --exit-on-fail)  exitOnFail=true;;
  --dump-rev-all)  dumpRevAll=true;&
  --dump-rev)      whatToDo='dump-rev';;
  --skip-clean)    dumpRevSkipClean=true;;
  --plain)         git_log_params="${git_log_params/--graph} --no-merges"; dumpRevPlain=true;;
  --date)          git_log_params="$git_log_params --pretty=date-first --date=relative}";;
  --date-local)    git_log_params="$git_log_params --pretty=date-first --date=local}";;
  --log-p)         git_log_params="$git_log_params $2"; shift;;
  --no-skip-clean) dumpRevSkipClean=false;;
  --skip-master)   dumpRevSkipMasters=true;;
  --tags)          dumpRevTags="$2"; shift;;
  --info)          dumpRevInfo=true; list=false;;
  --full)          dumpRevInfoFull=true;  dumpRevInfo=false; list=false;;
  --short | --log) dumpRevInfoFull=false; dumpRevInfo=false; list=false;;
  --base)          dumpRevBaseBranch=$2; shift;;
  --max-commits)   dumpRevMaxCommits=$2; shift;;
  --diff-ign)      dumpRevDumpDiff=false;;
  --commit-all)    findCommitAllBranches=true;&
  --commit)        whatToDo='find-commit'; findCommitRegEx="$2"; shift; [[ ! -z $2 ]] && findCommitDo=true;;
  -s)              echorm -;;
  -v)              echorm +;;
  *)               whatToDo="$@"; shift $#;;
  esac; shift
done # }}}
isStdout=true
[[ -t 1 ]] || isStdout=false
if ${colors:-false} || [[ -z $colors && -t 1 ]]; then # {{{
  cRepo=$CCyan cBr=$CYellow cDirty=$CRed cSha=$CGreen cOff=$COff
  git_log_params+=" --color=always"
fi # }}}
if [[ -z $repos ]]; then # {{{
  cmd=
  cmd+="find . "
  if ! $all; then
    for i in $REPO_EXCLUDE_SEARCH_PATH; do
      cmd+="-path '$i' -prune -o "
    done
    [[ ! -z $REPO_BROWSE_PATH_EXTRA ]] && cmd+="-path '*/$REPO_BROWSE_PATH_EXTRA/*' -prune -o "
  fi
  cmd+="-type d -name .git -exec dirname {} \;"
  repos="$(eval $cmd | sort)"
  smod=
  for i in $repos; do # {{{
    pushd $i &>/dev/null
    smod+="$(git submodule status | awk '!/^-/ { print $2}' | sed 's|^|'$i/'|')"
    popd &>/dev/null
  done # }}}
  repos="$( ( echo "$repos"; echo "$smod" ) | sort)"
fi # }}}
if $list; then # {{{
  case $whatToDo in
  find-commit | dump-rev | run-bash);;
  *) echo "$repos" | tr ' ' '\n' | sed '/^\s*$/d' | sort; exit 0;;
  esac
fi # }}}
mS="{{"; mS+="{"
mE="}}"; mE+="}"
[[ $(echorm -f??) -ge 3 ]] && set -xv
for repo in $repos; do # {{{
  pushd $repo &>/dev/null
  echorm "$repo"
  case $whatToDo in
  find-commit) # {{{
    if git log $($findCommitAllBranches && echo '--all') --format='%s' | grep -q "$findCommitRegEx"; then
      if ! $findCommitDo; then # {{{
        if ! $list; then
          echo "$repo:"
          for sha in $(git log $($findCommitAllBranches && echo '--all') --pretty=short2 | grep "$findCommitRegEx" | awk '{print $1}'); do
            git log --color -1 --pretty=date-first --date=local $sha | grep --color=yes "$findCommitRegEx"
            if $findCommitAllBranches; then
              echo "On branches:"
              git branch -r --contains $sha | sed 's/^/  /'
            fi
          done | sed 's/^/  /'
          echo
        else
          echo "$repo"
        fi # }}}
      else # {{{
        sha=$(git log --pretty=short2 | grep "$findCommitRegEx" | head -n1 | awk '{print $1}')
        git log --color $($findCommitAllBranches && echo '--all') --date=local | grep --color=yes "$findCommitRegEx"
        eval $wtd
        err=$?
      fi # }}}
    fi;; # }}}
  dump-rev | '') # {{{
    isClean=false stat="$(git status --short)"
    br="$(git rev-parse --abbrev-ref HEAD)"
    sha="$(git log -1 --pretty=%h)"
    if [[ $br == 'HEAD'* ]]; then # {{{
      [[ $(git branch | awk '/\*/') =~ '(HEAD detached at '(.*)')' ]] && br=${BASH_REMATCH[1]} || br="$(git describe --contains --all HEAD 2>/dev/null)"
      [[ $br == $sha ]] && br=
      [[ -z $br ]] && br="$(git name-rev --name-only HEAD)"
      [[ -z $br ]] && br="$(git rev-parse --short HEAD 2>/dev/null)";
      [[ -z $br ]] && br=$sha
    fi # }}}
    br=$(echo "$br" | sed -e 's|remotes/||' -e 's|tags/b/|b/|')
    [[ -z "$stat" ]] && isClean=true
    ! $isClean && [[ ! -z "$REPO_BROWSE_CLEAN_CHECK" && $(echo "$stat" | wc -l) == 1 && "$stat" =~ $REPO_BROWSE_CLEAN_CHECK ]] && isClean=true
    while true; do
      if ! $dumpRevAll; then # {{{
        case $br in
        tags/*/b-* | tags/*/b@*)
          $isClean && break;;
        *tmp* | */tb/* | tb/*);;
        tags/*)
          $isClean && break
          [[ -z $dumpRevTags || ! $br =~ $dumpRevTags ]] && break;;
        [0-9]*.[0-9]*.[0-9]*) break;;
        v[0-9]*.[0-9]*)       break;;
        master)                         $isClean && break;;
        b/*)                            $isClean && break;;
        devel | next | origin/* | HEAD) $isClean && break;;
        home-work | tb/mods)            $isClean && break;;
        *)
          while true; do
            [[ "$br" =~ [a-z]{2,}/[a-z]+-[0-9]+/ ]] && break
            $isClean && $dumpRevSkipClean && break 2
            [[ "$br" =~ m/[0-9a-z]{20,} ]] && $isClean && break 2
            $dumpRevSkipMasters && [[ "$br" =~ master(~[0-9]*)? ]] && break 2
            $dumpRevSkipMasters && [[ ! -z $REPO_BROWSE_MASTER_BRANCH &&   "$br" =~ $REPO_BROWSE_MASTER_BRANCH ]] && break 2
            [[ ! -z $REPO_BROWSE_TAGS          &&   "$br" =~ $REPO_BROWSE_TAGS          ]] && break 2
            [[ ! -z $dumpRevTags               && ! "$br" =~ $dumpRevTags               ]] && break 2
            break
          done;;
        esac
      fi # }}}
      if ! $list; then # {{{
        if $dumpRevInfo; then # {{{
          c_sha=$cSha
          ! $isClean && c_sha=$cDirty
          echo "${cRepo}$repo${cOff}: ${cBr}$br${cOff} ${c_sha}$sha${cOff}" # }}}
        else # {{{
          echo "$(! $dumpRevPlain && echo "# Repo: ")${cRepo}$repo${cOff}: ${cBr}$br${cOff}: ${cSha}$(git log -1 --format="%h" $br)${cOff}$(! $dumpRevPlain && echo " # $mS")"
          if ! $isClean && $dumpRevDumpDiff; then # {{{
            git diff
          fi | \
          if $isStdout && which colordiff >/dev/null 2>&1; then
            colordiff -u -w | sed 's/^/  /'
          elif $dumpRevPlain; then
            sed 's/^/  /'
          else
            cat -
          fi
          i=
          branchesMaster="m/master master"
          branchesMasterOth=$({ git br; git tag; } | sed 's/^[ *]*//' | grep "^b/master/" | sort -r | head -n5)
          branchesSprint=$(git br -a | sed 's|^ *remotes/||' | grep "sprint_[0-9]\{2,4\}$" | sort -t '_' -k2,2rn | head -n10)
          tags=$(git tag | grep "tmp/b-*")
          for ii in $branchesMaster $branchesMasterOth $branchesSprint $tags; do
            ! git merge-base --is-ancestor $ii $br 2>/dev/null && continue
            if [[ -z $i ]] || git merge-base --is-ancestor $i $ii 2>/dev/null; then
              i=$ii
            fi
          done
          found=false
          for i in $i $dumpRevBaseBranch m/master master; do # {{{
            if git merge-base --is-ancestor $i $br 2>/dev/null; then
              oneLess=
              ! $dumpRevPlain && oneLess='~'
              if [[ $i != $br || ! -z $oneLess ]]; then
                echo "$(git log $git_log_params $i$oneLess..$br)" |  sed 's/\s\+$//' | { $dumpRevPlain && sed 's/^/  /' || cat -; } | sed 's/\s\+$//'
                if $dumpRevInfoFull && [[ ! -z "$(git diff $i..$br)" ]]; then # {{{
                  echo "# Diff # $mS" # }}}
                  dist="$(git log $i~..$br | wc -l)"
                  if [[ $dist -gt $dumpRevMaxCommits ]]; then
                    echo "# Base branch $i is too far ($dist), shrinking to last $dumpRevMaxCommits commits"
                    i="$br~$dumpRevMaxCommits"
                  fi
                  git diff $i..$br | \
                  if $isStdout && which colordiff >/dev/null 2>&1; then
                    colordiff -u -w | sed 's/^/  /'
                  elif $dumpRevPlain; then
                    sed 's/^/  /'
                  else
                    cat -
                  fi
                  echo "# Diff # $mE"
                fi # }}}
              fi
              found=true
              break
            fi
          done # }}}
          if ! $found; then # {{{
            echo "# Master is not a base branch, showing last 5 commits$($dumpRevInfoFull && [[ ! -z "$(git diff $br~..$br)" ]] && echo " and diff for one")"
            echo "$(git log $git_log_params $br~5..$br)" | sed 's/\s\+$//' | { $dumpRevPlain && sed 's/^/  /' || cat -; } | sed 's/\s\+$//'
            if $dumpRevInfoFull && [[ ! -z "$(git diff $br~..$br)" ]]; then
              echo "# Diff # $mS"
              git diff $br~..$br
              echo "# Diff # $mE"
            fi
          fi # }}}
          ! $dumpRevPlain && echo "# Repo # $mE" || echo
        fi # }}}
        # }}}
      else # {{{
        echo "$repo$($list_addBranch && echo " : $br")"
      fi # }}}
      break
    done;; # }}}
  run-bash) # {{{
    eval $wtd
    err=$?;; # }}}
  *) # {{{
    eval "$whatToDo"
    err=$?;; # }}}
  esac
  popd &>/dev/null
  [[ $err != 0 ]] && $exitOnFail && break
  # }}}
done | \
  if ! $list && [[ -t 1 ]]; then # {{{
    case $whatToDo in
    dump-rev)
      if $dumpRevInfo; then
        column -t
      else
        cat -
      fi;;
    *) cat -
    esac
  else
    cat -
  fi # }}}
if $exitOnFail; then # {{{
  exit $err
fi # }}}

