#!/usr/bin/env bash
# vim: fdl=0

import-module echor

use_dir=true
if [[ $1 == "@@" ]]; then # @@:new # {{{
  case $2 in
  -t | --type)
    echo "tar tar-bz2 tar-gz bz2 gz zip rar Z 7z";;
  -f | --file)
    echoe "here"
    echo "@@-fb+";;
  *)
    echo "-t --type"
    echo "-f --file"
    archives="$(ls | command grep ".tar\|.tar.bz2\|.tbz2\|.tar.gz\|.tgz\|.bz2\|.gz\|.zip\|.rar\|.Z\|.7z")"
    case " $@ " in
    *' -d '*  | *' --dir '*    ) use_dir=true;;
    *' -nd '* | *' --no-dir '* ) use_dir=false;;
    esac
    if $use_dir; then
      echo "-nd --no-dir"
      for i in $archives; do
        dir=${i/*\/}
        dir=${dir%.*}
        [[ ! -d $dir ]] && echo "$i"
      done
    else
      echo "-d --dir"
      echo "$archives"
    fi;;
  esac
  exit 0
fi # }}}

file= type=
while [[ ! -z $1 ]]; do
  case $1 in
  -d  | --dir)    use_dir=true;;
  -nd | --no-dir) use_dir=false;;
  -t  | --type)   type="$2"; shift;;
  -f  | --file)   file="$2"; shift;;
  *)              file=$1;;
  esac
  shift
done
[[ ! -f $file ]] && echormf 0 "[$1] is not a valid file!" && exit 1
if $use_dir; then
  dir=${file/*\/}
  dir=${dir%.*}
  command mkdir $dir
  command cd $dir
  [[ $file != /* ]] && file="../$file"
fi
usePV=true
! type pv &>/dev/null && usePV=false
cmd=
case "$type:$file" in
tar:*     | *:*.tar)            cmd="tar xf";;
tar-bz2:* | *:*.tar.bz2|*.tbz2) cmd="tar xjf";;
tar-gz:*  | *:*.tar.gz|*.tgz)   cmd="tar xzf";;
bz2:*     | *:*.bz2)            cmd="bunzip2";;
gz:*      | *:*.gz)             cmd="gunzip";;
zip:*     | *:*.zip)            cmd="unzip"; usePV=false;;
rar:*     | *:*.rar)            cmd="unrar x";;
Z:*       | *:*.Z)              cmd="uncompress";;
7z:*      | *:*.7z)             cmd="7z x";;
*:*) echormf 0 "[$file] cannot be extracted via >extract<"; exit 1;;
esac
is-installed -w ${cmd%% *} || die "${cmd%% *} not installed"
if $usePV; then
  cmd="pv -p $file | $cmd -"
  echo $cmd
  eval $cmd
else
  cmd="$cmd $file"
  echo $cmd
  progress --mark --dots --msg "Extracting '$file'"
  eval $cmd 1>/dev/null
  progress --unmark
  echo
fi
