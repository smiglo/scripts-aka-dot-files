#!/usr/bin/env bash
# vim: fdl=0

_get-file-list() { # @@ # {{{
  local cmd="ls -d" pwd="." files="*" narrow= verbosity=0 monitor=false monitorSha=false regEx= reverse=false accessMode=false
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    --pwd) echo "@@-d";;
    -n)    echo "1 2 3 5 10";;
    *)     echo "-v -vv --cmd --pwd -1 -n -a -t --mon --mon-sha -r -R -l";;
    esac
    return 0
  fi # }}}
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --)    shift; break;;
    --cmd) cmd="$2"; shift;;
    --pwd) pwd="$2"; shift;;
    --mon) monitor=true;;
    --mon-sha) monitor=true; monitorSha=true;;
    -a)    accessMode=true;;
    -r)    regEx="$2"; shift;;
    -R)    reverse=true;;
    -1)    narrow=1;;
    -l)    narrow=1; reverse=true;;
    -n)    narrow="$2"; shift;;
    -v)    verbosity=1;;
    -vv)   verbosity=2;;
    -*)    cmd+=" $1";;
    *)     files="$@"; break;;
    esac
    shift
  done # }}}
  set +f
  [[ ! -e $pwd ]] && echo "Path [$pwd] does not exist" >/dev/stderr && return 1
  [[ $pwd != '.' ]] && cd "$pwd"
  if $monitor; then # {{{
    cmd="ls -t $files 2>/dev/null | head -n1"
    local listLast= list= shaLast= sha=
    while true; do # {{{
      list="$(eval $cmd 2>/dev/null)"
      [[ ! -z $list ]] && sha="$(sha1sum $list 2>/dev/null)" || sha=
      if ( $monitorSha && [[ "$shaLast" != "$sha" ]] ) || [[ "$listLast" != "$list" ]]; then
        shaLast="$sha"
        listLast="$list"
        [[ ! -z "$list" ]] && echo "$list"
      fi
      sleep 5
    done # }}}
    [[ $pwd != '.' ]] && cd - >/dev/null 2>&1
    return 0
  fi # }}}
  if [[ -z $regEx ]]; then
    if [[ "$(eval echo "$files")" == "$files" && ! -e "$files" ]]; then
      [[ $pwd != '.' ]] && cd - >/dev/null 2>&1
      return 1
    fi
    cmd="$cmd $files"
  else
    local findParams='-maxdepth 1' findPre="./"
    [[ $regEx == */* ]] && findParams= && findPre=
    cmd="find . $findParams -regex '$findPre$regEx' -exec $cmd {} \; | sed 's|^\./||'"
  fi
  $accessMode && cmd+=" | file-stat --mode a --pretty 2>/dev/null | sort -k3,3n | awk '{print \$1}'"
  $reverse && cmd+=" | tac"
  [[ ! -z $narrow ]] && cmd+=" | head -n $narrow"
  if [[ $verbosity -ge 1 ]]; then
    echo "$(eval $cmd)" >/dev/stderr
    if [[ $verbosity -ge 2 ]]; then
      eval "$cmd"
    else
      eval "$cmd" 2>/dev/null
    fi
  else
    eval "$cmd" 2>/dev/null
  fi
  [[ $pwd != '.' ]] && cd - >/dev/null 2>&1
  return 0
} # }}}
_get-file-list "$@"

