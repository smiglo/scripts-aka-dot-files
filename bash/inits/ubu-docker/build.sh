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
case $(uname -m):$DOCKER_DEFAULT_PLATFORM in
arm64:*/amd64)
  iName="ubu-amd64"
  cNmae="ubu-amd64";;
esac

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --amd64)
    export DOCKER_DEFAULT_PLATFORM="linux/amd64"
    iName="$iName-amd64"
    cName="$cName-amd64";;
  -f | --full | -F | --Full)
    doClean=true; doCommit=true; doAdvance=true; doStart=true
    case $1 in
    -F | --Full) doRemove=true; doCleanImage=true;;
    esac;;
  --rm) doRemove=true;;
  --static) doStatic=true;;
  -C | --clean) doClean=true;;
  -c | --commit) doCommit=true;;
  -a | --advance) doAdvance=true;;
  -i | --image) iName=$2; shift;;
  *) cName=$1;;
  esac; shift
done # }}}

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

confF="ubu.conf"
touch $confF
if [[ ! -z $DOCKER_UBU_CONF ]]; then
  cp $DOCKER_UBU_CONF $confF || die docker "Fail: cannot get conf-file [$DOCKER_UBU_CONF]"
fi

confExt="-"
[[ -e $DOCKER_CONF_EXT ]] && confExt=${DOCKER_CONF_EXT#$HOME\/}

dockerCmd="docker"

$dockerCmd build \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g) \
  --build-arg SCRIPT_PATH=${SCRIPT_PATH#$HOME\/} \
  --build-arg DOCKER_CONF_EXT=$confExt \
  -t $iName . || die docker "Fail: build"

rm $confF

echor "Running $cName..."
$ALIASES_SCRIPTS/docker-tools/docker.sh run -ns $($doStatic && echo "--static") $cName $iName || die docker "Fail: run"

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
    $ALIASES_SCRIPTS/docker-tools/docker.sh run -ns $cName $iName$($doStatic && echo ":static" || echo ":latest") || die docker "Fail: run(2)"
  fi # }}}
fi # }}}

if $doStart; then # {{{
  echor "Starting $iName..."
  $ALIASES_SCRIPTS/docker-tools/docker.sh start $cName || die docker "Fail: start"
fi # }}}

