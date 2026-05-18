#!/usr/bin/env bash
# vim: fdl=0

mode=$1; shift
case $mode in
'') # {{{
  find -L $APPS_CFG_PATH -maxdepth 1 -name 'env-ext'
  find -L $PROFILES_PATH -maxdepth 2 -path '*/env-ext'
  exit 0;; # }}}
get-plugins) # {{{
  ret=
  file="$1"; shift
  [[ -n $file ]] || die " file is empty"
  [[ -e $RUNTIME_PATH/$file ]] && ret+=" $RUNTIME_PATH/$file"
  inProfiles=
  for i in $PROFILES_PATH/*; do
    [[ -e $RUNTIME_PATH/$file.${i##*/} ]] && ret+=" $RUNTIME_PATH/$file.${i##*/}"
    [[ -e $i/$file ]] && inProfiles+=" $i/$file"
  done
  ret+=" $inProfiles"
  [[ -e $APPS_CFG_PATH/$file ]] && ret+=" $APPS_CFG_PATH/$file"
  echo "$ret"
  exit 0;; # }}}
call) # {{{
  all=false
  while [[ ! -z $1 ]]; do
    case $1 in
    --all) all=true;;
    *) what=$1; shift; break;;
    esac; shift
  done
  [[ -n $what ]] || die "function not passed"
  unset -f $what
  called=false
  for where in $($0 list); do
    source $where
    declare -F $what >/dev/null 2>&1 || continue
    $what "$@"
    (( $? == 0 )) && called=true
    $all || break
  done
  $called || exit 1
  exit 0;; # }}}
call=*) # {{{
  where=${mode#call=}; what=$1; shift
  unset -f $what
  [[ -e $where ]] || exit 1
  source $where
  declare -F $what >/dev/null 2>&1 || exit 254
  $what "$@";; # }}}
get) # {{{
  ENV_FUNC_GETTER[get-unicode-char]="unicode-chars"
  ENV_FUNC_GETTER[xclip]="clipboard"
  mode="call"
  while [[ ! -z $1 ]]; do
    case $1 in
    --source) mode="source";;
    --call) mode="call";;
    *) func=$1; shift; break;;
    esac; shift
  done
  file=${ENV_FUNC_GETTER[$func]}
  [[ $file == /* ]] || file="$BASH_PATH/env.d/$file"
  [[ -e $file ]] || die "file $file for $func not found"
  case $mode in
  call)
    source $file
    $func "$@";;
  source)
    cat $file;;
  esac;; # }}}
esac
