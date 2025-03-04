#!/usr/bin/env bash
# vim: fdl=0

_cp-struct() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -f) echo "CONTENT-FILE";;
    *)  echo "-f -v -m --move FILE.. DST";;
    esac
    return 0
  fi # }}}
  local dst= move=false contentFile=$TMP_MEM_PATH/cp.struct.$$ userCF=false tarP=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -f) contentFile=$2; userCF=true; shift;;
    -v) tarP="-v";;
    -m | --move) move=true;;
    *) break;;
    esac; shift
  done # }}}
  if [[ ! -t 0 ]]; then
    cat - >$contentFile
  elif ! $userCF; then
    if [[ $# == 1 ]]; then
      find-short +tee=false . | fzf --prompt "Files > " >$contentFile
    else
      rm -f $contentFile
      while [[ ! -z $2 ]]; do
        echo "$1" >>$contentFile
        shift
      done
      [[ -e $1 ]] && echo "$1" >>$contentFile && shift
    fi
  fi
  dst=$1
  [[ -s $contentFile ]] || eval $(die -r "no content")
  [[ ! -z "$dst" ]] || dst="out"
  [[ -e "$dst" ]] || mkdir -p "$dst" >/dev/null
  tar $tarP -cf - -T $contentFile | tar -C $dst -xf -
  [[ $? == 0 ]] || eval $(die -r "copy has failed")
  if $move; then # {{{
    local i=
    while read i; do
      rm -rf "$i"
    done <<<$(cat $contentFile)
  fi # }}}
  $userCF || rm -f $contentFile
} # }}}
_cp-struct "$@"

