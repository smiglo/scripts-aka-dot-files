#!/usr/bin/env bash
# vim: fdl=0

_docker() { # {{{
  [[ -z $DOCKER_CONTAINER_DEFAULT ]] && export DOCKER_CONTAINER_DEFAULT='ubu'
  [[ -z $DOCKER_IMAGE_DEFAULT ]] && export DOCKER_IMAGE_DEFAULT='ubu'
  local dockerCmd="docker"
  if [[ $1 == '@@' ]]; then # {{{
    local containers="$($dockerCmd container ls -a --format "{{.Names}}")"
    local images="$($dockerCmd image ls -a --format "{{.Repository}}")"
    case $3 in
    -c) echo "$containers $DOCKER_CONTAINER $DOCKER_CONTAINER_DEFAULT";;
    -i) echo "$images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";;
    advance) echo "$containers";;
    build) echo "--amd64 $images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";;
    clean) echo "$containers -";;
    commit) # {{{
      echo "$containers $DOCKER_CONTAINER $DOCKER_CONTAINER_DEFAULT"
      echo "$images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";; # }}}
    exec) echo "$containers";;
    i | image) echo "prune";;
    irm) echo "$images";;
    ls) echo "---";;
    replace) echo "-ns -s";;
    root) echo "$containers";;
    rm) echo "$containers";;
    run) # {{{
      echo "-ns -s --static"
      echo "- -d -i -t -dit"
      echo "$containers $DOCKER_CONTAINER $DOCKER_CONTAINER_DEFAULT"
      echo "$images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";; # }}}
    start | s) echo "$containers";;
    stop) echo "$containers";;
    *) # {{{
      echo "-c -i --dbg"
      echo "c i"
      echo "s start stop root exec clean rm irm replace ls build run commit advance"
      echo "container image images";; # }}}
    esac
    return 0
  fi # }}}
  local cName=${DOCKER_CONTAINER:-$DOCKER_CONTAINER_DEFAULT} iName=${DOCKER_IMAGE:-$DOCKER_IMAGE_DEFAULT}
  case $cName in
  ubu-amd64) iName="ubu-amd64";;
  esac
  local cSet=false iSet=false out=/dev/null
  local containerList="$($dockerCmd container ls -a --format ". {{.Names}} : {{.Image}}")"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --dbg) out=/dev/stderr;;
    -c) cName=$2; cSet=true; shift;;
    -i) iName=$2; iSet=true; shift;;
    *) break;;
    esac; shift
  done # }}}
  [[ -z $1 ]] && set -- ls
  cmd=$1; shift
  case $cmd in
  advance) # {{{
    $cSet || cName= # mandatory: container name advance
    [[ ! -z $cName ]] || { cName=$1; shift; }
    [[ -z $cName ]] && eval $(die "no container specified")
    cName="${cName%-next}"
    cNameNext="$cName-next"
    [[ $containerList == *". $cNameNext "* ]] || eval $(die "no such container [$cNameNext]")
    [[ $containerList == *". $cName "* ]] && $dockerCmd container remove $cName
    $dockerCmd container rename $cNameNext $cName;; # }}}
  build) # {{{
    local arch= buildArchP=
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      --amd64) # {{{
        export DOCKER_DEFAULT_PLATFORM="linux/amd64"
        buildArchP="--amd64"
        arch="--platform=$DOCKER_DEFAULT_PLATFORM";; # }}}
      *) break
      esac; shift
    done # }}}
    $iSet || { iName=${1:-$iName}; shift; }
    [[ -z $iName ]] && eval $(die "no image specified")
    case $iName in
    ubu | ubu-*) # {{{
      (
        cd $SCRIPT_PATH/bash/inits/ubu-docker
        ./build.sh $buildArchP
      ) ;; # }}}
    *) # {{{
      $dockerCmd build $arch "$@" -t $iName .;; # }}}
    esac;; # }}}
  clean) # {{{
    $cSet || cName= # mandatory: container name on removal
    [[ ! -z $cName ]] || { cName=$1; shift; }
    [[ -z $cName ]] && eval $(die "no container specified")
    [[ ! -z $iName ]] || { iName=$1; shift; }
    [[ $containerList == *". $cName "* ]] || eval $(die "no such container [$cName]")
    if [[ $iName = '-' ]]; then
      iName=$cName
    elif [[ -z $iName ]]; then
      iName="$(echo "$containerList" | sed '/ '"$cName "'/s/.* : //')"
    fi
    _docker rm $cName
    _docker irm $iName;; # }}}
  commit) # {{{
    if ( $cSet && $iSet ) || (( $# == 0 )); then
      :
    elif (( $# >= 2 )); then
      cName=$1; shift
      iName=$1; shift
    else
      eval $(die "both container & image must be specified")
    fi
    [[ -z $cName || -z $iName ]] && eval $(die "no container/image specified")
    [[ $iName == *:* ]] || iName="$iName:latest"
    local iNamePrev="${iName%:latest}:prev"
    $dockerCmd image ls -a --format "{{.Repository}}" | grep -q "$iNamePrev" && $dockerCmd image rm $iNamePrev
    $dockerCmd image tag $iName $iNamePrev
    $dockerCmd commit $cName $iName;; # }}}
  exec) # {{{
    $cSet || { cName=${1:-$cName}; shift; }
    [[ -z $cName ]] && eval $(die "no container specified")
    $dockerCmd exec "${@:--it}" $cName /bin/bash;; # }}}
  irm) # {{{
    $iSet || iName= # mandatory: container name on removal
    [[ -z $iName ]] || set -- $iName
    [[ -z $1 ]] && eval $(die "no image specified")
    for iName; do
      $dockerCmd image rm $iName >$out
    done;; # }}}
  ls) # {{{
    $dockerCmd ps -a
    echo
    $dockerCmd images;; # }}}
  replace) # {{{
    local doStart=true
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      -ns) doStart=false;;
      -s)  doStart=true;;
      *)   break;;
      esac
    done # }}}
    $cSet || cName= # mandatory: container name
    [[ ! -z $cName ]] || { cName=$1; shift; }
    [[ -z $cName ]] && eval $(die "no container specified")
    _docker commit $cName
    _docker rm $cName
    _docker run $cName
    if $doStart; then
      _docker start $cName
    fi;; # }}}
  root) # {{{
    $cSet || { cName=${1:-$cName}; shift; }
    [[ -z $cName ]] && eval $(die "no container specified")
    $dockerCmd exec -u 0:0 "${@:--it}" $cName /bin/bash;; # }}}
  rm) # {{{
    $cSet || cName= # mandatory: container name on removal
    [[ -z $cName ]] || set -- $cName
    [[ -z $1 ]] && eval $(die "no container specified")
    for cName; do
      $dockerCmd stop $cName >$out
      $dockerCmd rm $cName >$out
    done;; # }}}
  run) # {{{
    local paramsDefault="-dit" doStart= staticImage=false
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      -ns) doStart=false;;
      -s)  doStart=true;;
      --static) staticImage=true;;
      -)   paramsDefault=;;
      -*)  paramsDefault+=" $1";;
      *)   break;;
      esac; shift
    done # }}}
    $cSet || { cName=${1:-$cName}; shift; }
    $iSet || { iName=${1:-$iName}; shift; }
    [[ -z $cName || -z $iName ]] && eval $(die "no container/image specified")
    local pName=${cName%%-*}
    pName="DOCKER_RUN_${pName^^}_PARAMS"
    local -n paramsEnv=${pName//[-]/_}
    local err=255
    $staticImage && [[ $cName != *"-static" ]] && cName="$cName-static"
    [[ $containerList == *". $cName "* ]] && cName="$cName-next"
    [[ $containerList == *". $cName "* ]] && eval $(die "container already exists [$cName]")
    case $cName in
    ubu | ubu-*) # {{{
      [[ -z $doStart ]] && doStart=true
      local dockerShare=${DOCKER_SHARE_PATH:-$HOME/share} hDir="/home/tom"
      [[ -e $HOME/.runtime/docker.ubu ]] || mkdir -p $HOME/.runtime/docker.ubu >/dev/null
      sed -i '/\[127.0.0.1\]:4022/d' $HOME/.ssh/known_hosts*
      [[ -e $dockerShare ]] || mkdir -p $dockerShare >/dev/null
      $dockerCmd run \
        -u $(id -u):$(id -g) \
        --hostname $iName \
        --add-host=host.docker.internal:host-gateway \
        -p 127.0.0.1:3030-3032:3030-3032 \
        -p 127.0.0.1:${DOCKER_PORT_OU:-3033}:${DOCKER_PORT_OU:-3033} \
        -p 127.0.0.1:4022:${DOCKER_PORT_SSH:-22} \
        --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
        --tmpfs /tmpfs:exec,mode=1777 \
        -v $HOME:/home/host \
        -v $HOME/.runtime/docker.ubu:$hDir/.runtime \
        -v $HOME/projects:$hDir/projects \
        -v $dockerShare:$hDir/share \
        $(eval echo "$paramsEnv") \
        $paramsDefault \
        -w /home/tom \
        --name $cName $iName \
        /bin/bash
      err=$?
      [[ $err == 0 ]] && $dockerCmd start $cName; err=$?
      if $staticImage && [[ $err == 0 ]]; then # {{{
        $dockerCmd exec -it $cName bash -c \
          "rm -rf $hDir/projects-my ; \
            mkdir -p $hDir/projects-my/ ; \
            cp -r $MY_PROJ_PATH/scripts $hDir/projects-my/ ; \
            cp -r $MY_PROJ_PATH/vim     $hDir/projects-my/ ; \
            ln -sf $hDir/projects-my/scripts/bash/inits/ubu-docker/docker-post.sh $hDir/tools/docker-post.sh ; \
            rm -rf $hDir/projects-my/scripts/bash/profiles/*"
        err=$?
      fi # }}}
      [[ $err == 0 ]] && $dockerCmd exec -it $cName $hDir/tools/docker-post.sh --yes; err=$?
      ;; # }}}
    *) # {{{
      if declare -f doc_ext >/dev/null 2>&1; then
        doc_ext run $cName $iName $paramsEnv $paramsDefault "$@"
        err=$?
      fi
      if [[ $err == 255 ]]; then
        $dockerCmd run $paramsEnv $paramsDefault "$@" --name $cName $iName
        err=$?
      fi;; # }}}
    esac
    [[ -z $doStart ]] && doStart=false
    [[ $err == 0 ]] || eval $(die $err "err occurred [$err]")
    if $doStart; then
      _docker start $cName
    fi;; # }}}
  start | s) # {{{
    $cSet || { cName=${1:-$cName}; shift; }
    [[ -z $cName ]] && eval $(die "docker no container specified")
    $dockerCmd container ls -a --format "{{.Names}}" | grep -q "^$cName$" || _docker run -ns $cName $iName
    $dockerCmd start $cName
    local pidClip=
    case $cName in
    ubu | ubu-*)
      exec 3>&2; exec 2> /dev/null
      $ALIASES_SCRIPTS/docker-tools/clipboard-docker.sh &
      pidClip=$!
      exec 2>&3; exec 3>&-;;
    esac
    set-title "$cName"
    $dockerCmd attach $cName
    if [[ ! -z $pidClip ]]; then
      $ALIASES_SCRIPTS/docker-tools/clipboard-docker.sh --kill
    fi;; # }}}
  stop) # {{{
    $cSet || { cName=${1:-$cName}; shift; }
    [[ -z $cName ]] && eval $(die "no container specified")
    $dockerCmd stop $cName >$out;; # }}}
  i) # {{{
    $dockerCmd image "$@";; # }}}
  c) # {{{
    $dockerCmd container "$@";; # }}}
  *) # {{{
    $dockerCmd $cmd "$@";; # }}}
  esac
} # }}}
_docker "$@"

