#!/usr/bin/env bash
# vim: fdl=0

ip="${1:-1}" network="$2"
[[ -z $network ]] && case $ip in *.*.*.*) network=${ip%.*};; esac
[[ -z $network ]] && network="${NET:-$NET_HOME}"
read -a network <<<"${network//./ } -"
case $ip in # {{{
?*.*.*.*) ;;
.*.*.* | [0-9]*.*.*)    ip="${network[0]}.${ip#.}";;
.*.*   | [0-9]*.*)      ip="${network[0]}.${network[1]}.${ip#.}";;
.*     | [0-9]*)        ip="${network[0]}.${network[1]}.${network[2]}.${ip#.}";;
esac # }}}
echo "$ip"

