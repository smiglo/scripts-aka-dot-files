#!/bin/bash

indent() {
  [ $1 == 0 ] && return
  for ji in $(seq 1 $1); do
    echo -en $sep
  done
}

_echo() {
  echo ${1//+/ }
}

list() {
  local dir=$1
  pushd $dir >/dev/null
  dir="$PWD/"
  dir=${dir/$d}
  for i in $(ls .); do
    # indent $2
    if [ -d $i ]; then
      list $i $(($2 + 1 ))
    else
      _echo ${dir/\/}$i
    fi
  done
  popd >/dev/null
}

pushd ${1-.} >/dev/null

d=$PWD
sep="\t"

list $d 0

popd >/dev/null

