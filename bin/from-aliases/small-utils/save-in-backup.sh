#!/usr/bin/env bash
# vim: fdl=0

_save-in-backup() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "-s -d --dir -v -vv"
    return 0
  fi # }}}
  local s= d= dir=$BACKUP_PATH verbose=0 isRemote=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -s)    s="$2"; shift;;
    -d)    d="$2"; shift;;
    -v)    verbose=1;;
    -vv)   verbose=2;;
    --dir) dir=$2; shift
    esac; shift
  done # }}}
  [[ -z $dir ]] && return 100
  if $SHARABLE_REAL && [[ ! -z $SHARABLE_PATH && $dir == $SHARABLE_PATH* ]]; then
    ! ping -c1 -w1 8.8.8.8 >/dev/null 2>&1 && echormf "No connectivity" && return 10
    [[ ! -e $SHARABLE_PATH/.mounted ]] && echormf "Not connected" && return 11
    isRemote=true
  fi
  [[ -t 0 && -t 1 && -z $s && -z $d ]] && return 0
  if [[ -t 1 || $d != '-' ]]; then # {{{
    [[ -z $d && ! -z $s ]] && d="$dir/$(basename "$s")"
    [[ -z $d ]] && echormf 0 "No dst file" && return 1
    [[ $d == '/'* || $d = './'* ]] || d="$dir/$d"
    if [[ ! -e "$(dirname "$d")" ]]; then
      mkdir -p "$(dirname "$d")" >/dev/null 2>&1 || return 2
    fi
  elif [[ $d == '-' ]]; then
    d=
  fi # }}}
  if [[ -z $s ]]; then # {{{
    [[ ! -t 0 ]] && s="-"
    [[ -z $s ]] && echormf 0 "No src file" && return 1
  fi # }}}
  local err=0 stderr='/dev/stderr'
  [[ $verbose -lt 2 ]] && stderr='/dev/null'
  if [[ ! -z $d ]]; then
    if $isRemote; then
      eval run-for-some-time $(is-installed -w timeout && echo "--use-timeout") --wait 10s --cmd "cat \"$s\" >\"$d\""
    else
      cat "$s" >"$d"
    fi
    err=$?
  else
    cat "$s"; err=$?
  fi 2>$stderr
  [[ $err != 0 && $verbose -ge 1 ]] && echormf 0 "Cannot save (e:$err) file '$s' -> '$d'"
  return $err
} # }}}
_save-in-backup "$@"


