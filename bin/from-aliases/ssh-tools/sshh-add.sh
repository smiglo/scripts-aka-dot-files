#!/usr/bin/env bash
# vim: fdl=0

_screen_lock() { # {{{
  local colors=( 'red' 'green' 'yellow' 'blue' 'magenta' 'cyan' ) tmp=
  local c1="0"
  local c2="$(( ($c1 + 1 + $RANDOM % (${#colors[*]} - 1)) % ${#colors[*]} ))"
  local cmatrix_cmd="nice -n 15 cmatrix -u ${CMATRIX_SPEED:-5} -b"
  if ${SSHH_ADD_LOCK_NO_PWD:-false} || [[ -z $SSHH_ADD_LOCK_NO_PWD && -z $SSH_AGENT_LOCK_PWD ]] || [[ "$(tmux display-message -pF '#{client_tty}')" !=  *"/0" && $(tmux list-clients | wc -l) -gt 1 ]] ; then # {{{
    eval $cmatrix_cmd -C ${colors[$(($RANDOM % ${#colors[*]}))]}
    return
  fi # }}}
  if [[ ! -z $SSH_AGENT_LOCK_PWD ]]; then # {{{
    local timeout="$SSH_AGENT_LOCK_PRE_TIMEOUT"
    local from_tmux=false
    while [[ ! -z $1 ]]; do
      case $1 in
      --tmux)
        from_tmux=true;
        if [[ ( ! -z $TMUX_SESSION && $(tmux show-option -t $TMUX_SESSION -qv @lock_allowed) == 'false' ) || $(tmux show-option -gqv @lock_allowed) == 'false' ]]; then
          tmux display-message "Locking disabled"
          return 0
        fi;;
      *) timeout="$1";;
      esac
      shift
    done
    mutex-init "ssh-lock" --no-trap --auto-clean-after 0
    if ! mutex-lock; then
      eval $cmatrix_cmd -C ${colors[$c1]}
      $from_tmux && tmux display-message "Cannot lock ssh-agent, mutex locked" || echo "Cannot lock ssh-agent, mutex locked" >/dev/stderr
      sleep 1
      return 1
    fi
    [[ -z $SSHH_ADD_LOCK_TS_FILE ]] && local SSHH_ADD_LOCK_TS_FILE="$MEM_KEEP/cmatrix.ts"
    local cTime=$EPOCHSECONDS
    local cmatrixLockTime=0 cmatrixLockFileCreated=0
    if [[ $SSHH_ADD_LOCK_TS_FILE != '-' ]]; then
      [[ -e $SSHH_ADD_LOCK_TS_FILE ]] && source $SSHH_ADD_LOCK_TS_FILE
      if [[ $cmatrixLockFileCreated -lt $(date +%s -d "today 0:00") ]]; then
        rm -f $SSHH_ADD_LOCK_TS_FILE
        cmatrixLockTime=0 cmatrixLockFileCreated=$cTime
        update-file $SSHH_ADD_LOCK_TS_FILE --var cmatrixLockFileCreated $cTime
      fi
    fi
    if [[ ! -z $timeout && $timeout != 0 ]]; then
      [[ $timeout == -1 ]] && timeout=$((3 * 60 * 60))
      [[ $timeout -lt 5 ]] && timeout=5
      reset
      run-for-some-time --cmd "$cmatrix_cmd -C ${colors[$c1]}; reset" --watchdog-cmd 'cmatrix' --wait $((timeout-2)):2
      if [[ $? != 255 ]]; then
        read -s -n 10000 -t 0.5 tmp
        [[ $SSHH_ADD_LOCK_TS_FILE != '-' ]] && $ALIASES_SCRIPTS/file-tools/update-file.sh $SSHH_ADD_LOCK_TS_FILE --var cmatrixLockTime "$((cmatrixLockTime + $EPOCHSECONDS - cTime))"
        mutex-unlock; mutex-deinit
        return 0
      fi
    fi
    { # {{{
      /usr/bin/expect - <<-EOF
				set timeout -1
				spawn ssh-add -x
				match_max 100000
				expect "Enter lock password: "
				send -- "$::env(SSH_AGENT_LOCK_PWD)\r"
				expect "Again: "
				send -- "$::env(SSH_AGENT_LOCK_PWD)\r"
				expect eof
			EOF
    } >/dev/null 2>&1 # }}}
    # }}}
  else # {{{
    local err= locked=false
    echormf "Locking ssh-agent...\n"
    while true; do
      ssh-add -x 2>/dev/null
      case $? in
      0) locked=true; break;;
      2) echormf 0 "Cannot connect to ssh-agent\n"; break;;
      esac
      echormf 0 "Password mismatch, try again...\n"
    done
  fi # }}}
  while true; do # {{{
    eval $cmatrix_cmd -C ${colors[$c2]}
    reset
    if $locked; then # {{{
      local checkHome=false
      [[ ! -z $SSH_AGENT_LOCK_PWD ]] && checkHome=true
      if [[ $cmatrixLockFileCreated -gt $(date +%s -d "today 0:00") ]]; then
        if $checkHome; then
          progress --mark --msg "Unlocking after $(time2s --to-hms $((EPOCHSECONDS - cTime)))/$(time2s --to-hms $((cmatrixLockTime + $EPOCHSECONDS - cTime)))"
        else
          echormf 0 "Unlocking after $(time2s --to-hms $((EPOCHSECONDS - cTime)))/$(time2s --to-hms $((cmatrixLockTime + $EPOCHSECONDS - cTime)))..."
        fi
      elif $checkHome; then
        progress --mark --msg "Unlocking"
      fi
      while true; do # {{{
        local homeNet=false
        if $checkHome; then # {{{
          net-is-home && homeNet=true
          progress --unmark --err=$homeNet; checkHome=false
        fi # }}}
        if $homeNet; then # {{{
          {
            /usr/bin/expect - <<-EOF
							set timeout -1
							spawn ssh-add -X
							match_max 100000
							expect "Enter lock password: "
							send -- "$::env(SSH_AGENT_LOCK_PWD)\r"
							expect eof
						EOF
          } >/dev/null 2>&1 # }}}
        else # {{{
          run-for-some-time --cmd "ssh-add -X 2>/dev/null" --wait 12:2
        fi # }}}
        local err=$?
        if [[ $err == 255 ]]; then # {{{
          while true; do
            local cNew="$(( ($c2 + 1 + $RANDOM % (${#colors[*]} - 1)) % ${#colors[*]} ))"
            [[ $cNew != $c1 ]] && c2=$cNew && break
          done
          continue 2
        fi # }}}
        [[ $err == 0 ]] && break 2
        echormf 0 "Incorrent password, try again...\n"
      done # }}}
    fi # }}}
  done # }}}
  [[ $SSHH_ADD_LOCK_TS_FILE != '-' ]] && $ALIASES_SCRIPTS/file-tools/update-file.sh $SSHH_ADD_LOCK_TS_FILE --var cmatrixLockTime "$((cmatrixLockTime + $EPOCHSECONDS - cTime))"
  mutex-unlock
  mutex-deinit
  if [[ ! -z $SSHH_ADD_LOCK_POST ]]; then
    if [[ -x ${SSHH_ADD_LOCK_POST/ *} ]]; then
      $SSHH_ADD_LOCK_POST
    else
      eval $SSHH_ADD_LOCK_POST
    fi
  fi
  return 0
} # }}}
_sshh-add() { # @@ # {{{
  local key_location="$HOME/.ssh/keys"
  local key= keys= k= params=
  if [[ $1 == '@@' ]]; then # {{{
    local ret=
    keys="$(ls *.pub 2>/dev/null)"
    if [[ ! -z $keys ]]; then
      for key in $keys; do
        key=${key/.pub}
        key=${key#id_}
        ret+=" $key"
      done
    fi
    keys="$(find -L $key_location -name '*.pub')"
    if [[ ! -z $keys ]]; then
      for key in $keys; do
        key=${key/.pub}
        key=${key/$key_location\/}
        key=${key#id_}
        ret+=" $key"
      done
    fi
    ret+=" $(ssh-add --help 2>&1 | grep  ^"  -" | cut -d' ' -f3)"
    ret+=" --lock -v --keys --tmux-lock --tmux-unlock"
    ret+=" -l -d -D"
    echo $ret
    return 0
  fi # }}}
  local params=$@
  if [[ -z $params ]]; then # {{{
    keys="$(find -L $key_location -maxdepth 1 -not -name '*_pwd*' -name '*.pub')"
    for key in $keys; do
      key=${key/.pub}
      [[ -e $key ]] && params+=" ${key/$key_location\/}"
    done
  fi # }}}
  set -- $params
  params="$SSHH_ADD_PARAMS"
  key=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in # {{{
    --tmux-lock) # {{{
      tmux-lock-toggle --lock
      return 0;; # }}}
    --tmux-unlock) # {{{
      tmux-lock-toggle --unlock
      return 0;; # }}}
    --lock) # {{{
      shift
      _screen_lock "$@"
      return 0;; # }}}
    -l | -d | -D) ssh-add $1; return;;
    -v) echormf +;;
    --keys) shift; break;;
    -*) params+=" $1";;
    *) break;;
    esac # }}}
    shift
  done # }}}
  for k; do # {{{
    [[ $k == -* ]] && continue
    [[ $k == 'STOP' ]] && shift $# && break
    [[ ! -e $k && -e id_$key ]] && k="id_$k"
    if [[ ! -e $k ]]; then
      if [[ -e $key_location/$k ]]; then
       k=$key_location/$k
      elif [[ -e $key_location/id_$k ]]; then
       k=$key_location/id_$k
      fi
    fi
    [[ ! -e $k ]] && echormf 0 "Key file [$1] not found" && return 1
    key+=" $k"
  done; shift $# # }}}
  local fSshAsk=$TMP_MEM_PATH/ssh-ask.sh list=
  which keep-pass.sh >/dev/null 2>&1 && list="$(keep-pass.sh --list-all-keys)"
  local kList="$(ssh-add -l | awk '{print $3}')"
  for k in $key; do # {{{
    [[ $k == -* ]] && continue
    echo "$kList" | grep -q "^$k$" && continue
    local kName=${k##*/}
    local paramK=SSHH_ADD_PARAMS_${kName^^}
    paramK=${paramK//-/_}
    local cmd="ssh-add $params ${!paramK} $k"
    if echo "$list" | grep -q "^$kName$" && keep-pass.sh --get --key $kName --no-intr >/dev/null 2>&1; then
      if [[ ! -e $fSshAsk ]]; then
        cat >$fSshAsk <<-'EOF'
					#!/usr/bin/env bash
					read k
					keep-pass.sh --get --key $k --no-intr
				EOF
        chmod +x $fSshAsk
      fi
      cmd="SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=$fSshAsk $cmd <<<$kName"
    fi
    echormf -f? && echorv -M 1 cmd
    local out="$(eval $cmd 2>&1)"
    echormf 2 "$out"
  done # }}}
  [[ -e $fSshAsk ]] && rm -f $fSshAsk
  return 0
} # }}}
_sshh-add "$@"

