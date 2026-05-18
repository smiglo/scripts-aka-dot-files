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
    build) echo "--platform=linux/amd64 $images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";;
    clean) echo "$containers -";;
    commit) # {{{
      echo "$containers $DOCKER_CONTAINER $DOCKER_CONTAINER_DEFAULT"
      echo "$images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";; # }}}
    exec) echo "$containers";;
    i | image) echo "prune";;
    inspect-vm) echo "---";;
    irm) echo "$images";;
    ls) echo "---";;
    replace) echo "--no-start -s --start";;
    root) echo "$containers";;
    rm) echo "$containers";;
    run) # {{{
      echo "--platform=linux/amd64 --no-start -s --start --static --add-ports"
      echo "- -d -i -t -dit"
      echo "$containers $DOCKER_CONTAINER $DOCKER_CONTAINER_DEFAULT"
      echo "$images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";; # }}}
    start | s) echo "$containers";;
    stop) echo "$containers";;
    *) # {{{
      echo "-c -i --dbg"
      echo "c i"
      echo "s start stop root exec clean rm irm replace ls build run commit advance inspect-vm"
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
    local platform=
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      --platform=*) platform=$1;;
      *) break
      esac; shift
    done # }}}
    $iSet || { iName=${1:-$iName}; shift; }
    [[ -z $iName ]] && eval $(die "no image specified")
    case $iName in
    ubu | ubu.*) # {{{
      (
        cd $SCRIPT_PATH/inits/ubu-docker
        ./build.sh $platform
      ) ;; # }}}
    *) # {{{
      $isSet || [[ -z $platform ]] || iName="$iName.${platform##*/}"
      $dockerCmd build $platform "$@" -t $iName .;; # }}}
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
  inspect-vm) # {{{
    docker run --rm -it --privileged --pid=host alpine nsenter -t 1 -m -u -n -i sh;; # }}}
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
      --no-start)   doStart=false;;
      -s | --start) doStart=true;;
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
    local paramsDefault="-dit" doStart= staticImage=false platform= addPorts=
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      --platform=*) platform=$1;;
      --no-start)   doStart=false;;
      --add-ports)  addPorts=true;;
      -s | --start) doStart=true;;
      --static) staticImage=true;;
      -)   paramsDefault=;;
      -*)  paramsDefault+=" $1";;
      *)   break;;
      esac; shift
    done # }}}
    $cSet || { cName=${1:-$cName}; shift; }
    $iSet || { iName=${1:-$iName}; shift; }
    [[ -z $cName || -z $iName ]] && eval $(die "no container/image specified")
    if [[ -n $platform ]]; then
      $cSet || cName="$cName.${platform##*/}"
      $iSet || iName="$iName.${platform##*/}"
    fi
    local pName=${cName%%[-.]*}
    pName="DOCKER_RUN_${pName^^}_PARAMS"
    local -n paramsEnv=${pName//[-]/_}
    local err=255
    $staticImage && [[ $cName != *"-static" ]] && cName="$cName-static"
    [[ $containerList == *". $cName "* ]] && cName="$cName-next"
    [[ $containerList == *". $cName "* ]] && eval $(die "container already exists [$cName]")
    case $cName in
    ubu | ubu-* | ubu.*) # {{{
      if [[ -z $addPorts ]]; then
        $cName == "ubu" && addPorts=true || addPorts=false
      fi
      paramsPorts=
      if $addPorts; then
        paramsPorts="
-p 127.0.0.1:3030-3032:3030-3032
-p 127.0.0.1:${DOCKER_PORT_OU:-3033}:${DOCKER_PORT_OU:-3033}
-p 127.0.0.1:4022:${DOCKER_PORT_SSH:-22}"
      fi
      [[ -z $doStart ]] && doStart=true
      local dockerShare=${DOCKER_SHARE_PATH:-$HOME/share} hDir="/home/tom"
      [[ -e $HOME/.runtime/docker.ubu ]] || mkdir -p $HOME/.runtime/docker.ubu >/dev/null
      [[ -e $dockerShare ]] || mkdir -p $dockerShare >/dev/null
      sed -i '/\[127.0.0.1\]:4022/d' $HOME/.ssh/known_hosts*
      mounts=
      for i in projects w; do
        [[ -e $HOME/$i ]] || continue
        [[ $paramsEnv == *\$hDir/$i* ]] && continue
        mounts+=" -v $HOME/$i:$hDir/$i"
      done
      caps=
      ${DOCKER_RUN_UBU_CAPS_GDB:-true} && caps+=" --cap-add=SYS_PTRACE --security-opt seccomp=unconfined"
      ${DOCKER_RUN_UBU_CAPS_TCPDUMP:-false} && caps+=" --cap-add=NET_ADMIN --cap-add=NET_RAW"
      $dockerCmd run \
        $platform \
        --log-opt max-size=10m --log-opt max-file=3 \
        -u $(id -u):$(id -g) \
        --hostname $iName \
        --add-host=host.docker.internal:host-gateway \
        $paramsPorts \
        $caps \
        --tmpfs /tmpfs:exec,mode=1777 \
        -v $ENV_PATH:$hDir/env \
        -v $HOME/.runtime/docker.ubu:$hDir/.runtime \
        -v $HOME:/home/host \
        -v $dockerShare:$hDir/share \
        $mounts \
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
            cp -r $ENV_PATH/scripts $hDir/projects-my/ ; \
            cp -r $ENV_PATH/vim     $hDir/projects-my/ ; \
            ln -sf $hDir/projects-my/scripts/inits/ubu-docker/docker-post.sh $hDir/tools/docker-post.sh ; \
            rm -rf $hDir/projects-my/scripts/bash/profiles/*"
        err=$?
      fi # }}}
      [[ $err == 0 ]] && $dockerCmd exec -it $cName $hDir/env/scripts/bin/oth/setup-env.sh --all -p -; err=$?
      ;; # }}}
    *) # {{{
      if declare -f doc_ext >/dev/null 2>&1; then
        doc_ext run $cName $iName $(eval echo "$paramsEnv") $paramsDefault "$@"
        err=$?
      fi
      if [[ $err == 255 ]]; then
        $dockerCmd run $(eval echo "$paramsEnv") $paramsDefault "$@" --name $cName $iName
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
    $dockerCmd container ls -a --format "{{.Names}}" | grep -q "^$cName$" || _docker run --no-start $cName $iName
    $dockerCmd start $cName
    local pidClip=
    case $cName in
    ubu | ubu-*)
      exec 3>&2; exec 2> /dev/null
      $ENV_SCRIPTS/docker-tools/clipboard-docker.sh &
      pidClip=$!
      exec 2>&3; exec 3>&-;;
    esac
    set-title "$cName"
    $dockerCmd attach $cName
    if [[ ! -z $pidClip ]]; then
      $ENV_SCRIPTS/docker-tools/clipboard-docker.sh --kill
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
