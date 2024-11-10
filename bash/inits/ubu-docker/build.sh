#!/usr/bin/env bash
# vim: fdl=0

doClean=false
doCommit=false
doAdvance=false
doStart=false
doRemove=false
iName="ubu"
cName="ubu"

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -f | --full) doClean=true; doCommit=true; doAdvance=true; doStart=true;;
  --rm) doRemove=true;;
  -C | --clean) doClean=true;;
  -c | --commit) doCommit=true;;
  -a | --advance) doAdvance=true;;
  -i | --image) iName=$2; shift;;
  *) cName=$1;;
  esac; shift
done # }}}

if $doClean; then # {{{
  echor "Cleaning $cName..."
  doc clean $cName
fi # }}}

echor "Building $cName // $iName..."
docker build \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g) \
  --build-arg SCRIPT_PATH=${SCRIPT_PATH#$HOME\/} \
  --build-arg DOCKER_CONF=$DOCKER_UBU_CONF \
  -t $iName . || die "Fail: build"

echor "Running $cName..."
doc run -ns $cName $iName || die "Fail: run"

if $doCommit; then # {{{
  echor "Committing $iName..."
  doc commit $iName || die "Fail: commit"
  if $doAdvance; then # {{{
    if $doRemove; then
      doc rm $cName
    else
      doc rm $cName-prev || true
      docker container rename $cName $cName-prev || die "Fail: cannot rename"
    fi
    doc run -ns $cName $iName || die "Fail: run(2)"
  fi # }}}
fi # }}}

if $doStart; then # {{{
  echor "Starting $iName..."
  doc start $cName || die "Fail: start"
fi # }}}

