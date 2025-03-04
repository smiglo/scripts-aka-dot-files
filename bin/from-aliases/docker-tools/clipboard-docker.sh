#!/usr/bin/env bash
# vim: fdl=0

if ${DOCKER_CLIP_USE_TCP:-true}; then # {{{
  mode="TCP"
  hostIn=${DOCKER_CLIP_PORT_IN:-3034}
  hostOu=${DOCKER_CLIP_PORT_OU:-3033}
  dockIn=$hostOu
  dockOu=$hostIn
  # sudo ufw allow from 172.17.0.0/24 proto tcp to any port ${hostIn} && sudo ufw enable # }}}
else # {{{
  mode="FIFO"
  hostIn=${DOCKER_CLIP_D2H:-$CLIP_FILE.d2h}
  hostOu=${DOCKER_CLIP_H2D:-$CLIP_FILE.h2d}
  dockIn=${hostOu/$HOME/$DOCKER_HOST}
  dockOu=${hostIn/$HOME/$DOCKER_HOST}
fi # }}}

delay=${DOCKER_CLIP_POLLING:-2}
dbgLvl=${DOCKER_CLIP_DBG_LVL:-D}

writer() { # {{{
  local dataOu=$1 sum=0000000 sumLast=0000000 fTmp=$TMP_MEM_PATH/$(basename $CLIP_FILE).w fSum=$TMP_MEM_PATH/clip-doc.sum
  dbg --set --name="wrt"
  case $mode in
  TCP) # {{{
    local pOHost=$2 ncP="-N"
    $IS_MAC && ncP="-c"
    dbg I "cfg: d-out: $dataOu, f-tmp: ${fTmp/$HOME/\~}, host: $pOHost, ncP: $ncP";; # }}}
  FIFO) # {{{
    dbg I "cfg: d-out: $dataOu, f-tmp: ${fTmp/$HOME/\~}";; # }}}
  esac
  local show_waiting=true
  while true; do
    $show_waiting && dbg D "waiting" && show_waiting=false
    xclip --get >$fTmp
    [[ -s $fTmp ]] || { sleep $delay; continue; }
    sum=$(sha1sum $fTmp | cut -d' ' -f 1)
    [[ -s $fSum ]] && sumLast=$(<$fSum)
    [[ $sum == $sumLast ]] && sleep $delay && continue
    dbg I "writing: [${sumLast:0:7} > ${sum:0:7}]: $(head -n1 $fTmp)..."
    sumLast=$sum
    echo "$sumLast" >$fSum
    case $mode in
    TCP)  cat $fTmp | netcat $ncP $pOHost $dataOu;;
    FIFO) cat $fTmp >$dataOu;;
    esac
    dbg D "written"
    show_waiting=true
    sleep $delay
  done
} # }}}
reader() { # {{{
  local dataIn=$1 sum=0000000 sumLast=0000000 fTmp=$TMP_MEM_PATH/$(basename $CLIP_FILE).r fSum=$TMP_MEM_PATH/clip-doc.sum
  dbg --set --name="rdr"
  case $mode in
  TCP) # {{{
    local pIHost=$2 ncP=
    $IS_MAC && ncP="-s"
    dbg I "cfg: d-out: $dataOu, f-tmp: ${fTmp/$HOME/\~}, host: $pIHost, ncP: $ncP";; # }}}
  FIFO) # {{{
    dbg I "cfg: d-out: $dataOu, f-tmp: ${fTmp/$HOME/\~}";; # }}}
  esac
  while true; do
    dbg D "waiting"
    case $mode in
    TCP)  netcat -l $ncP $pIHost -p $dataIn >$fTmp;;
    FIFO) cat $dataIn >$fTmp;;
    esac
    sum=$(sha1sum $fTmp | cut -d' ' -f 1)
    [[ -s $fTmp ]] || continue
    dbg D "got, [${sum:0:7}]"
    [[ -s $fSum ]] && sumLast=$(<$fSum)
    if [[ $sum != $sumLast ]]; then
      dbg I "updating: [${sumLast:0:7} > ${sum:0:7}]: $(head -n1 $fTmp)..."
      sumLast=$sum
      echo "$sumLast" >$fSum
      cat $fTmp | xclip --put
    fi
  done
} # }}}

fPid=$MEM_KEEP/clip-doc.pid fLog=$TMP_MEM_PATH/clip-doc.log
export DBG_ID=CLIP_DOC
dbg --init -v=$dbgLvl --ts-abs --out=$fLog --name="clip" --id=show
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --dbg=*) dbgLvl=${1#--dbg=}; dbg --set -v=$dbgLvl;;
  -k | --kill) # {{{
    [[ -e $fPid ]] || exit 0
    pid=$(cat $fPid)
    ps ax -o pid= | grep -q "^\s*$pid$" || exit 0
    dbg I "killing on pid: $pid"
    kill-rec $pid
    case $mode in
    FIFO) # {{{
      [[ -p $dataOu ]] && rm $dataOu
      [[ -p $dataIn ]] && rm $dataIn;; # }}}
    esac
    exit 0;; # }}}
  esac; shift
done # }}}
if [[ -e $fPid ]]; then # {{{
  pid=$(< $fPid)
  ! ps ax -o pid= | grep -q "^\s*$pid$" || { dbg W "already running on pid: $pid"; die "already running on pid: $pid"; }
fi # }}}
echo "$BASHPID" >$fPid
dbg I "mode: $mode, pid: $BASHPID, delay: $delay"
if ! $IS_DOCKER; then # {{{
  dataOu=$hostOu dataIn=$hostIn
  [[ $mode == "TCP" ]] && pOHost="127.0.0.1" && pIHost="127.0.0.1"
  # }}}
else # {{{
  dataOu=$dockOu dataIn=$dockIn
  [[ $mode == "TCP" ]] && pOHost="host.docker.internal" && pIHost=""
fi # }}}
case $mode in
TCP) # {{{
  is-installed netcat || { dbg E "netcat not found"; die "netcat not foud"; }
  dbg I "W: $dataOu, R: $dataIn, host: $pOHost"
  reader $dataIn $pIHost &
  writer $dataOu $pOHost &
  ;; # }}}
FIFO) # {{{
  dbg I "W: $dataOu, R: $dataIn"
  [[ ! -p $dataOu ]] && mkfifo $dataOu
  [[ ! -p $dataIn ]] && mkfifo $dataIn
  [[ -p $dataOu ]] || { dbg E "cannot create $dataOu"; die "cannot create $dataOu"; }
  [[ -p $dataIn ]] || { dbg E "cannot create $dataIn"; die "cannot create $dataIn"; }
  reader $dataIn &
  writer $dataOu &
  ;; # }}}
esac
wait

