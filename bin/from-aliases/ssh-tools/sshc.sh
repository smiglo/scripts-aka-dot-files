#!/usr/bin/env bash
# vim: fdl=0

_sshc() { # {{{
  __sshc_socket_term() { # {{{
    local host=$1 t=$2
    ssh -q -oControlPath=$t -O exit $host >/dev/null 2>&1
  } # }}}
  local host=$1; shift
  local t=$(mktemp -u --tmpdir ssh.sock.XXXXXXXXXX)
  local fHost="$CLIP_FILE.ssh"
  local fRemote="${fHost/$HOME/\~}"
  dbg --init -v=I --ts-abs --out=$TMP_MEM_PATH/clip-ssh.log --name="sshc: $host" --id=hide
  dbg I "cfg: host: $host, p: $@, fr: $fRemote, t: $t, fh: $fHost"
  dbg D "establishing master connection"
  ssh -q -f -oControlMaster=yes -oControlPath=$t $@ $host "sleep 9999" || return 1
  dbg D "making pipe on remote"
  ssh -q -S$t $host "[[ -p $fRemote ]] || mkfifo $fRemote" || { __sshc_socket_term $host $t; return 1; }
  (
    set -e; set -o pipefail
    dbg I "waiter: start (h: $host, fr: $fRemote, fh: $fHost)"
    while true; do
      dbg I "waiter: waiting"
      ssh -q -S$t -tt $host "cat $fRemote" 2>/dev/null >$fHost
      dbg I "waiter: new data: $(head -n1 $fHost)"
      cat $fHost | xc --put
    done &
  )
  dbg I "connecting"
  ssh -q -S$t $host || { __sshc_socket_term $host $t; return 1; }
  dbg D "cleaning"
  ssh -q -S$t $host "rm $fRemote"
  __sshc_socket_term $host $t
  dbg I "bye"
} # }}}
_sshc "$@"

