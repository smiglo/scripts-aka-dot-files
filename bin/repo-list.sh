#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  case $3 in
  -r | --repos)
    find . -maxdepth 3 -type d -path '*/build-*' -prune -o -name .git -exec dirname {} \;
    echo "REPO-LIST REPO-FILE";;
  *) echo "-a --all -i --ignore -l --list -r --repos -R  --show-changed --stat=all --stat=changed"
  esac
  exit 0
fi # }}}

if ! declare -Fx __git_ps1 >/dev/null || ! declare -Fx __git_eread; then # {{{
  promptFile="${GIT_PROMPT_STATUS_FILE:-$BASH_PATH/completion.d/git/git-prompt.sh}"
  if [[ -e $TMUX_STATUS_RIGHT_GIT_INTERNAL_PS1 ]]; then
    source $TMUX_STATUS_RIGHT_GIT_INTERNAL_PS1
  elif [[ -e $promptFile ]]; then
    source $promptFile
  else
    die "__git_ps1 not found"
  fi
fi # }}}

set -o noglob

isStdOut=true
[[ -t 1 ]] || isStdOut=false
repos=
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

include="$REPO_LIST_INCLUDE_DEFAULT"
show_all=true
show_list=false
stat_reg="[*]"
while [[ ! -z $1 ]]; do
  case $1 in
  -a | --all) include=;;
  -i | --ignore) include+=" -path "$2" -o"; shift;;
  -l | --list) show_list=true;;
  -r | --repos) # {{{
    repos="$2"
    [[ -e $repos && ! -d $repos ]] && repos="$(cat $repos)"
    shift;; # }}}
  -R) repos=;;
  --show-changed) show_all=false;;
  --stat=all) stat_reg="[*%]";;
  --stat=changed) stat_reg="[*]";;
  esac; shift
done
if [[ ! -z $include ]]; then
  include="( ${include% -o} )"
fi
if [[ -z $repos ]]; then
  cmd=
  cmd+="find . "
  for i in $REPO_EXCLUDE_SEARCH_PATH './build-*' './.repo'; do
    cmd+="-path '$i' -prune -o "
  done
  [[ ! -z $REPO_BROWSE_PATH_EXTRA ]] && cmd+="-path '*/$REPO_BROWSE_PATH_EXTRA/*' -prune -o "
  cmd+="-type d -name .git -exec dirname {} \;"
  repos="$(eval $cmd | sort)"
fi
for r in $repos; do
  (
    cd $r
    stat="$(__git_ps1 "%s")"
    [[ $stat =~ ^\((.*)\)\ *(.*)$ ]]
    b=${BASH_REMATCH[1]}; stat=${BASH_REMATCH[2]}
    if $show_list; then
      if $isStdOut && [[ $stat =~ $stat_reg ]]; then
        printfc "%yellow:$r"
      elif [[ $stat =~ $stat_reg ]] || $show_all; then
        echo "$r"
      fi
    else
      if $isStdOut && [[ $stat =~ $stat_reg ]]; then
        printfc "%yellow:$r $(git log -1 --format=%H) $b $stat"
      elif [[ $stat =~ $stat_reg ]] || $show_all; then
        echo "$r $(git log -1 --format=%H) $b $stat"
      fi
    fi
  )
done

