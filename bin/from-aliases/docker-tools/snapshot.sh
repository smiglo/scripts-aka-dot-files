#!/usr/bin/env bash
# vim: fdl=0

_snapshot() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "-r --restore -f --file --plain"
    return 0
  fi # }}}
  local dst="${DOCKER_SNAPSHOT_DST:-$HOME/repo.bck/ubu-snapshot.tgz}"
  local useEnc=${DOCKER_SNAPSHOT_USE_ENC:-false}
  while [[ ! -z $1 ]]; do
    case $1 in
    -f | --file) dst="$(realpath "$2")"; shift;;
    --plain) useEnc=false;;
    -r | --restore) # {{{
      shift
      local tarParams="-v $@"
      [[ -e $dst ]] || eval $(die "snapshot not found")
      local tmpDir=$HOME/s.tmp
      mkdir -p $tmpDir >/dev/null
      (
        set -o pipefail
        if $useEnc; then
          encryptor --bin $([[ ! -z $SNAPSHOT_KEY ]] && echo "--key $SNAPSHOT_KEY") -d $dst
        else
          cat $dst
        fi | tar -C $tmpDir $tarParams -xz -f -
      )
      [[ $? == 0 ]] || { rm -rf $tmpDir; eval $(die "cannot untar"); }
      rsync -ahtpH --no-v --no-progress $tmpDir/ $HOME/
      rm -rf $tmpDir
      return 0;; # }}}
    *) break;;
    esac; shift
  done
  local tarParams="-v $@"
  local listExclude=
  if ${SNAPSHOT_INCLUDE_DEFAULT:-true}; then
    listExclude="tmp|\.cache|\.npm|\.tmux$|\.w3m|\.local|\.config|tools|\.cargo|\.rustup"
    listExclude="$(mount | sed -n '/host_mark/s|'"$HOME/"'||p' | awk '{print $3}' | grep -v '/' | sed 's|\.|\\.|' | tr '\n' '|')$listExclude"
  else
    listExclude=".*"
  fi
  local tarExclude=
  tarExclude+=" --exclude=__pycache__"
  local excludeDirs='\.local\/state\/tmux-fingers'
  [[ ! -z $SNAPSHOT_EXCLUDE ]] && excludeDirs+="\|$SNAPSHOT_EXCLUDE"
  (
    cd $HOME
    mkdir -p $(dirname $dst)
    tarList="$(for i in $(ls -Ah | grep -vE "$listExclude"); do find $i -type f; done | sed '/'"$excludeDirs"'/d')"
    [[ ! -z $SNAPSHOT_INCLUDE ]] && tarList+="\n$SNAPSHOT_INCLUDE"
    (
      set -o pipefail
      tar $tarExclude $tarParams -cz -T <(echo "$tarList") \
      | { if $useEnc; then encryptor --bin --key $SNAPSHOT_KEY; else cat -; fi } >$TMP_MEM_PATH/$(basename $dst)
    )
    if [[ $? == 0 && -s $TMP_MEM_PATH/$(basename $dst) ]]; then
      [[ -e $dst ]] && mv "$dst" "${dst%.tgz}-last.tgz"
      mv $TMP_MEM_PATH/$(basename $dst) $dst
    else
      echor "snapshot failed"
      rm -f $TMP_MEM_PATH/$(basename $dst)
    fi
  )
} # }}}
_snapshot "$@"

