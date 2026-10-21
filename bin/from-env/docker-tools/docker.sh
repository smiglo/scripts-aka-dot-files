#!/usr/bin/env bash
# vim: fdl=0

[[ -z $DOCKER_CONTAINER_DEFAULT ]] && export DOCKER_CONTAINER_DEFAULT='ubu'
[[ -z $DOCKER_IMAGE_DEFAULT ]] && export DOCKER_IMAGE_DEFAULT='ubu'
if [[ $1 == '@@' ]]; then # {{{
  containers="$(docker container ls -a --format "{{.Names}}")"
  images="$(docker image ls -a --format "{{.Repository}}")"
  case $3 in
  -c) echo "$containers $DOCKER_CONTAINER $DOCKER_CONTAINER_DEFAULT";;
  -i) echo "$images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";;
  advance) echo "$containers";;
  attach-to-vm) echo "clean";;
  build) echo "--platform=linux/amd64 $images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";;
  clean) echo "$containers -";;
  commit) # {{{
    echo "$containers $DOCKER_CONTAINER $DOCKER_CONTAINER_DEFAULT"
    echo "$images $DOCKER_IMAGE $DOCKER_IMAGE_DEFAULT";; # }}}
  exec) echo "$containers";;
  i | image) echo "prune";;
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
    echo "s start stop root exec clean rm irm replace ls build run commit advance"
    echo "container image images"
    $IS_MAC && echo "attach-to-vm"
    ;; # }}}
  esac
  exit 0
fi # }}}
cName=${DOCKER_CONTAINER:-$DOCKER_CONTAINER_DEFAULT} iName=${DOCKER_IMAGE:-$DOCKER_IMAGE_DEFAULT}
case $cName in
ubu-amd64) iName="ubu-amd64";;
esac
cSet=false iSet=false out=/dev/null
containerList="$(docker container ls -a --format ". {{.Names}} : {{.Image}}")"
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
  [[ -z $cName ]] && die "no container specified"
  cName="${cName%-next}"
  cNameNext="$cName-next"
  [[ $containerList == *". $cNameNext "* ]] || die "no such container [$cNameNext]"
  [[ $containerList == *". $cName "* ]] && docker container remove $cName
  docker container rename $cNameNext $cName;; # }}}
attach-to-vm) # {{{
  $IS_MAC || die "only on mac"
  case $1 in
  '')
    echoe "inspect large log files in /var/lib/docker/containers/"
    docker run --rm -it --privileged --pid=host alpine nsenter -t1 -m -u -n -i sh;;
  c | clean)
    docker run --rm --privileged --pid=host alpine nsenter -t1 -m -u -n -i find /var/lib/docker/containers/ -name '*-json.log*' -delete;;
  esac;; # }}}
build) # {{{
  platform=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --platform=*) platform=$1;;
    *) break
    esac; shift
  done # }}}
  $iSet || { iName=${1:-$iName}; shift; }
  [[ -z $iName ]] && die "no image specified"
  case $iName in
  ubu | ubu.*) # {{{
    (
      cd $SCRIPT_PATH/inits/ubu-docker
      ./build.sh $platform
    ) ;; # }}}
  *) # {{{
    $isSet || [[ -z $platform ]] || iName="$iName.${platform##*/}"
    docker build $platform "$@" -t $iName .;; # }}}
  esac;; # }}}
clean) # {{{
  $cSet || cName= # mandatory: container name on removal
  [[ ! -z $cName ]] || { cName=$1; shift; }
  [[ -z $cName ]] && die "no container specified"
  [[ ! -z $iName ]] || { iName=$1; shift; }
  [[ $containerList == *". $cName "* ]] || die "no such container [$cName]"
  if [[ $iName = '-' ]]; then
    iName=$cName
  elif [[ -z $iName ]]; then
    iName="$(echo "$containerList" | sed '/ '"$cName "'/s/.* : //')"
  fi
  docker rm $cName
  docker irm $iName;; # }}}
commit) # {{{
  if ( $cSet && $iSet ) || (( $# == 0 )); then
    :
  elif (( $# >= 2 )); then
    cName=$1; shift
    iName=$1; shift
  else
    die "both container & image must be specified"
  fi
  [[ -z $cName || -z $iName ]] && die "no container/image specified"
  [[ $iName == *:* ]] || iName="$iName:latest"
  iNamePrev="${iName%:latest}:prev"
  docker image ls -a --format "{{.Repository}}" | grep -q "$iNamePrev" && docker image rm $iNamePrev
  docker image tag $iName $iNamePrev
  docker commit $cName $iName;; # }}}
exec) # {{{
  $cSet || { cName=${1:-$cName}; shift; }
  [[ -z $cName ]] && die "no container specified"
  docker exec "${@:--it}" $cName /bin/bash;; # }}}
irm) # {{{
  $iSet || iName= # mandatory: container name on removal
  [[ -z $iName ]] || set -- $iName
  [[ -z $1 ]] && die "no image specified"
  for iName; do
    docker image rm $iName >$out
  done;; # }}}
ls) # {{{
  docker ps -a
  echo
  docker images;; # }}}
replace) # {{{
  doStart=true
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --no-start)   doStart=false;;
    -s | --start) doStart=true;;
    *)   break;;
    esac
  done # }}}
  $cSet || cName= # mandatory: container name
  [[ ! -z $cName ]] || { cName=$1; shift; }
  [[ -z $cName ]] && die "no container specified"
  docker commit $cName
  docker rm $cName
  docker run $cName
  if $doStart; then
    docker start $cName
  fi;; # }}}
root) # {{{
  $cSet || { cName=${1:-$cName}; shift; }
  [[ -z $cName ]] && die "no container specified"
  docker exec -u 0:0 "${@:--it}" $cName /bin/bash;; # }}}
rm) # {{{
  $cSet || cName= # mandatory: container name on removal
  [[ -z $cName ]] || set -- $cName
  [[ -z $1 ]] && die "no container specified"
  for cName; do
    docker stop $cName >$out
    docker rm $cName >$out
  done;; # }}}
run) # {{{
  paramsDefault="-dit" doStart= staticImage=false platform= addPorts=
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
  [[ -z $cName || -z $iName ]] && die "no container/image specified"
  if [[ -n $platform ]]; then
    $cSet || cName="$cName.${platform##*/}"
    $iSet || iName="$iName.${platform##*/}"
  fi
  pName=${cName%%[-.]*}
  pName="DOCKER_RUN_${pName^^}_PARAMS"
  declare -n paramsEnv=${pName//[-]/_}
  err=255
  $staticImage && [[ $cName != *"-static" ]] && cName="$cName-static"
  [[ $containerList == *". $cName "* ]] && cName="$cName-next"
  [[ $containerList == *". $cName "* ]] && die "container already exists [$cName]"
  case $cName in
  ubu | ubu-* | ubu.*) # {{{
    if [[ -z $addPorts ]]; then
      [[ $cName == "ubu" ]] && addPorts=true || addPorts=false
    fi
    paramsPorts=
    if $addPorts; then
      paramsPorts="
-p 127.0.0.1:3030-3032:3030-3032
-p 127.0.0.1:${DOCKER_PORT_OU:-3033}:${DOCKER_PORT_OU:-3033}
-p 127.0.0.1:4022:${DOCKER_PORT_SSH:-22}"
    fi
    [[ -z $doStart ]] && doStart=true
    dockerShare=${DOCKER_SHARE_PATH:-$HOME/share} hDir="/home/tom"
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
    docker run \
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
    [[ $err == 0 ]] && docker start $cName; err=$?
    if $staticImage && [[ $err == 0 ]]; then # {{{
      docker exec -it $cName bash -c \
        "rm -rf $hDir/projects-my ; \
          mkdir -p $hDir/projects-my/ ; \
          cp -r $ENV_PATH/scripts $hDir/projects-my/ ; \
          cp -r $ENV_PATH/vim     $hDir/projects-my/ ; \
          ln -sf $hDir/projects-my/scripts/inits/ubu-docker/docker-post.sh $hDir/tools/docker-post.sh ; \
          rm -rf $hDir/projects-my/scripts/bash/profiles/*"
      err=$?
    fi # }}}
    [[ $err == 0 ]] && docker exec -it $cName $hDir/env/scripts/bin/setup-env.sh --no-gui --all -p -; err=$?
    ;; # }}}
  *) # {{{
    if declare -f doc_ext >/dev/null 2>&1; then
      doc_ext run \
        --log-opt max-size=10m --log-opt max-file=3 \
        $cName $iName $(eval echo "$paramsEnv") $paramsDefault "$@"
      err=$?
    fi
    if [[ $err == 255 ]]; then
      docker run \
        --log-opt max-size=10m --log-opt max-file=3 \
        $(eval echo "$paramsEnv") $paramsDefault "$@" --name $cName $iName
      err=$?
    fi;; # }}}
  esac
  [[ -z $doStart ]] && doStart=false
  [[ $err == 0 ]] || die $err "err occurred [$err]"
  if $doStart; then
    docker start $cName
  fi;; # }}}
start | s) # {{{
  $cSet || { cName=${1:-$cName}; shift; }
  [[ -z $cName ]] && die "docker no container specified"
  docker container ls -a --format "{{.Names}}" | grep -q "^$cName$" || docker run --no-start $cName $iName
  docker start $cName
  pidClip=
  case $cName in
  ubu | ubu-*)
    exec 3>&2; exec 2> /dev/null
    $ENV_SCRIPTS/docker-tools/clipboard-docker.sh &
    pidClip=$!
    exec 2>&3; exec 3>&-;;
  esac
  set-title "$cName"
  docker attach $cName
  if [[ ! -z $pidClip ]]; then
    $ENV_SCRIPTS/docker-tools/clipboard-docker.sh --kill
  fi;; # }}}
stop) # {{{
  $cSet || { cName=${1:-$cName}; shift; }
  [[ -z $cName ]] && die "no container specified"
  docker stop $cName >$out;; # }}}
i) # {{{
  docker image "$@";; # }}}
c) # {{{
  docker container "$@";; # }}}
*) # {{{
  docker $cmd "$@";; # }}}
esac
