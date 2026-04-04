#!/usr/bin/env bash
# vim: fdl=0

import-module echor

doClean=false
doCleanImage=false
doCommit=false
doAdvance=false
doStart=false
doRemove=false
doStatic=false
iName="ubu"
cName="ubu"
platform=

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -f | --full | -F | --Full)
    doClean=true; doCommit=true; doAdvance=true; doStart=true
    case $1 in
    -F | --Full) doRemove=true; doCleanImage=true;;
    esac;;
  --rm) doRemove=true;;
  --platform=*) platform="$1";;
  --static) doStatic=true;;
  -C | --clean) doClean=true;;
  -c | --commit) doCommit=true;;
  -a | --advance) doAdvance=true;;
  -i | --image) iName=$2; shift;;
  *) cName=$1;;
  esac; shift
done # }}}

if [[ -n $platform ]]; then
  iName="$iName.${platform##*/}"
  cName="$cName.${platform##*/}"
fi

if $doStatic; then
  [[ $cName != *"-static" ]] && cName="$cName-static"
fi

if $doClean; then # {{{
  echor "Cleaning $cName..."
  if ! $doCleanImage; then
    $ALIASES_SCRIPTS/docker-tools/docker.sh rm $cName
  else
    $ALIASES_SCRIPTS/docker-tools/docker.sh clean $cName
  fi
fi # }}}

echor "Building $cName // $iName..."

dockerCmd="docker"

$dockerCmd build \
  $platform \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g) \
  --build-arg SCRIPT_PATH=${SCRIPT_PATH#$HOME\/} \
  -t $iName . || die docker "Fail: build"

echor "Running $cName..."
$ALIASES_SCRIPTS/docker-tools/docker.sh run $platform --no-start $($doStatic && echo "--static") $cName $iName || die docker "Fail: run"

if $doCommit; then # {{{
  echor "Committing $iName..."
  $dockerCmd commit $cName $iName$($doStatic && echo ":static" || echo ":latest") || die docker "Fail: commit"
  if $doAdvance; then # {{{
    if $doRemove; then
      $ALIASES_SCRIPTS/docker-tools/docker.sh rm $cName
    else
      $ALIASES_SCRIPTS/docker-tools/docker.sh rm $cName-prev || true
      $dockerCmd container rename $cName $cName-prev || die docker "Fail: cannot rename"
    fi
    $ALIASES_SCRIPTS/docker-tools/docker.sh run --no-start $cName $iName$($doStatic && echo ":static" || echo ":latest") || die docker "Fail: run(2)"
  fi # }}}
fi # }}}

if $doStart; then # {{{
  echor "Starting $iName..."
  $ALIASES_SCRIPTS/docker-tools/docker.sh start $cName || die docker "Fail: start"
fi # }}}
