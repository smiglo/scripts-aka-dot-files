#!/usr/bin/env bash
# vim: fdl=0

_dum() { # @@ # {{{
  if [[ $1 == @@ ]]; then # {{{
    local ret=
    if $IS_MAC; then # {{{
      local i=
      for i in $(mount | awk '/\/Volumes\// { print $3 }'); do
        [[ $i == *MobileBackups ]] && continue
        ret+=" $i"
      done
      for i in $(mount | awk '/\/Volumes\// { print $1 }'); do
        [[ $i == localhost* ]] && continue
        ret+=" $i"
      done # }}}
    else # {{{
      ret="$(mount | awk '/\/media\/'$USER'\// { print $3 }')"
    fi # }}}
    echo "${ret:----}"
    return 0
  fi # }}}
  local src="$1"; shift
  [[ -z $src ]] && ! $IS_MAC && src="$(get-file-list -t -1 "/media/$USER/*")"
  [[ -z $src ]] && echor "Mountpoint not specified" && return 1
  while [[ ! -z $src ]]; do
    local err=
    [[ ! -e $src ]] && echor "Mountpoint does not exist [$src]" && return 1
    progress --mark --msg "Unmounting $src" --dots --delay 0.1
    if $IS_MAC; then # {{{
      if [[ $src == /dev/* ]]; then
        diskutil unmountDisk $src >/dev/null && diskutil eject $src >/dev/null
      elif [[ $src == /Volumes/* ]]; then
        diskutil unmount "$src" >/dev/null
      fi # }}}
    else # {{{
      if [[ $src == /dev/* ]]; then
        umount $src
      elif [[ $src == /media/* ]]; then
        umount $src
      else
        ( set -xv
          sudo umount $src
        )
      fi
    fi # }}}
    err=$?
    progress --unmark --err=$err
    src="$1"; shift
  done
  return $err
} # }}}
_dum "$@"

