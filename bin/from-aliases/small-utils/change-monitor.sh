#!/usr/bin/env bash
# vim: fdl=0

_change-monitor() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    --dst) echo "FILE @@-f";;
    -d) echo "DELAY 1 5 10 30";;
    *)  echo "--dst -d -s --stop @@-f @@-d -? -S";;
    esac
    return 0
  fi # }}}
  local dst=$TMP_MEM_PATH/change-monitor.$$ dstChanged=false toMonitor="." delay=5 useProgress=true stopOnChange=false silent=false
  local dstTmp=$dst.tmp
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --dst) dst="$2"; dstChanged=true; shift;;
    -\?)   dstChanged=false;;
    -d | --delay) delay="$2"; shift;;
    -S) silent=true;;
    -s) useProgress=false;;
    --stop) stopOnChange=true;;
    *) toMonitor="$@"; shift $#; break;;
    esac; shift
  done # }}}
  $stopOnChange || $dstChanged ||$silent || echor "file: $dst"
  local i= k= list= shaLast= sha=
  for i in $toMonitor; do # {{{
    if [[ -d $i ]]; then
      list+=" $(find "$i" \
          -name '*.tmp' -prune \
          -o -name '*.out' -prune \
          -o -name '*.o'   -prune \
          -o -name 'Session*.vim'   -prune \
          -o \( -path '*/.vim/*' \)   -prune \
          -o \( -path '*/.git/*' \)   -prune \
          -o \( -path '*/.venv*/*' \) -prune \
          -o \( -path '*/.tmp/*' \)   -prune \
          -o -name "$(basename $dst)" -prune \
          -o -type f -print)"
    elif [[ -f $i ]]; then
      list+=" $i"
    fi
  done # }}}
  [[ -z ${list// /} ]] && return 1
  mkdir -p "$(dirname "$dst")" >/dev/null
  $useProgress && progress-dot --init --dots-in-packet 10 --packets-in-row 3
  sha1sum $list >"$dst"
  shaLast=$(sha1sum "$dst")
  local exitByChange=true
  while true; do # {{{
    sleep-precise -s
    sha1sum $list>"$dstTmp"
    mv "$dstTmp" "$dst"
    sha="$(sha1sum "$dst")"
    if $useProgress; then
      if [[ $sha == $shaLast ]]; then
        progress-dot
      else
        progress-dot --dot=yellow:
      fi
    fi
    if [[ $sha != $shaLast ]]; then
      shaLast=$sha
      $stopOnChange && break
    fi
    if ! read -t $(sleep-precise -i $delay) -s -n1 k; then
      [[ -e $dst ]] || { exitByChange=false; break; }
      continue
    fi
    case ${k,,} in
    q) exitByChange=false; break;;
    esac
  done # }}}
  $useProgress && progress-dot --end
  $exitByChange && return 0 || return 1
} # }}}
_change-monitor "$@"

