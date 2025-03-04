#!/usr/bin/env bash
# vim: fdl=0

_net-is-home() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "-if -v --env --return-ifa --skip-mac"
    return 0
  fi # }}}
  local ifaces="$NET_IFACES" verbose=false env="HOME" returnIfa=false skipMac=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --env)        env="${2^^}"; shift;;
    -if)          ifaces="$2"; shift;;
    --return-ifa) returnIfa=true;;
    --skip-mac)   skipMac=true;;
    -v)           verbose=true;;
    esac; shift
  done # }}}
  local -n net="NET_${env}" net_gwAddr="NET_${env}_GW_ADDR" net_gwMac="NET_${env}_GW_MAC"
  [[ ! -z $net && ( ! -z $net_gwMac || $skipMac == true ) ]] || { echor -c $verbose "missing envs"; return 10; }
  is-installed ifconfig $(! $skipMac && echo "arp") || { echor -c $verbose "missing installation"; return 11; }
  [[ ! -z $ifaces ]] || { echor -c $verbose "missing ifaces"; return 12; }
  local gwAddr=${net_gwAddr:-$net.1} ifa= desiredNet=false mac=
  for ifa in $ifaces; do # {{{
    [[ $(ifconfig $ifa 2>/dev/null | awk '/inet:? / {print $2}') == $net.* ]] || continue
    if ! $skipMac; then # {{{
      if ! $IS_MAC; then
        mac="$(arp -i $ifa -D $gwAddr | awk '/\<'"${gwAddr//./\\.}"'\> / {print $3}')"
      else
        mac="$(arp -i $ifa -a | awk '/\<'"${gwAddr//./\\.}"'\>/ {print $4}')"
      fi
    fi # }}}
    if $skipMac || [[ $mac == $net_gwMac ]]; then # {{{
      desiredNet=true
      echor -c $verbose "found [$ifa]"
      break
    fi # }}}
  done # }}}
  $desiredNet || { echor -c $verbose "not $env"; return 1; }
  $returnIfa && echo "$ifa"
  return 0
} # }}}
_net-is-home "$@"

