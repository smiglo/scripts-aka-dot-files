#!/usr/bin/env bash
# vim: fdl=0

_iface-ip() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    ifconfig | sed -n '/^[^ \t]\+:/s/: .*//p' | grep -vE "lo[0-9]*$([[ ! -z $IFACE_IGNORED ]] && echo "|${IFACE_IGNORED#|}")"
    return 0
  fi # }}}
  local addName=false useIp=true
  is-installed ip || useIp=false
  [[ -z $1 ]] && addName=true && set -- $(iface-ip @@)
  [[ ! -z $1 ]] || eval $(die "no ifaces found")
  for iface; do
    (
      if $useIp; then
        v="$(ip addr show $iface 2>/dev/null | sed -n '/inet /s/.*inet \([^/]\+\).*/\1/p')"
      else
        v="$(ifconfig $iface 2>/dev/null | sed -n '/inet:\? /s/.*inet:\? \([^ /]\+\).*/\1/p')"
      fi
      set -o pipefail
      echo "$($addName && echo "$iface: ")${v:--}"
    )
  done | { if [[ -t 1 ]] && $addName && is-installed column; then column -t; else /bin/cat -; fi; }
} # }}}
_iface-ip "$@"

