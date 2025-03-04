#!/usr/bin/env bash
# vim: fdl=0

_net() { # @@ # {{{
  # Errors: # {{{
  # 1  - no ping to IP
  # 2  - no ping to DNS
  # 10 - no ping to gateway
  # 11 - no gateway address # }}}
  if [[ $1 == '@@' ]]; then # {{{
    echo "-s --silent -v -vv -h --help -d --details --speed -l --loop -f --fix -ff --fix-first" --no-{f,fix} --wait{,={10,60}s,-{msg,check}}
    echo --loop={5s,15t,5s20t,10t3s,5}
    echo -ll -ll={1s,5s,30s} -lle --every
    return 0
  fi # }}}
  local mtr=false speed=false out=/dev/null fix="${NET_CHECK_FIX:-false}" showHelp=false
  local waitFor=false waitTime=30s waitMsg="Waiting for Internet connection... " waitJustCheck=false
  local addressGateway= addressIP="8.8.8.8" addressDNS="google.pl" loop=false loopForever=false loopFSleep=5 every=false
  local readKey= readTimeout=2 loopTries=15 echormParams="-nh" silent=false
  echormf + 1
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -s | --silent)     echormf -; fix=false; silent=true;;
    -v)                echormf + 1;;
    -vv)               echormf + 2; echormParams=""; out=/dev/stdout;;
    -h | --help)       showHelp=true;;
    -d | --details)    speed=true; mtr=true;;
    --speed)           speed=true;;
    -f  | --fix)       fix=true;;
    --every)           every=true;;
    -lle | -ll | -ll=*) # {{{
      case $1 in
      -lle)  every=true;;
      -ll=*) loopFSleep=${1#-ll=} && loopFSleep=${loopFSleep%s};;
      esac
      loopForever=true; loop=true;; # }}}
    -l | --loop | --loop=*) # {{{
      if [[ $1 == '--loop='* ]]; then # {{{
        if [[ ${1#--loop=} =~ ^([0-9]+s)?([0-9]+t)?([0-9]+s)?$ ]]; then
          if [[ ! -z ${BASH_REMATCH[1]} ]]; then
            readTimeout="${BASH_REMATCH[1]}" && readTimeout=${readTimeout%s}
          elif [[ ! -z ${BASH_REMATCH[3]} ]]; then
            readTimeout="${BASH_REMATCH[3]}" && readTimeout=${readTimeout%s}
          fi
          if [[ ! -z ${BASH_REMATCH[2]} ]]; then
            loopTries="${BASH_REMATCH[2]}" && loopTries=${loopTries%t}
          fi
        elif [[ ${1#--loop=} =~ ^([0-9]+)$ ]]; then
          readTimeout="${BASH_REMATCH[1]}"
        fi
      fi # }}}
      loop=true;; # }}}
    --no-f | --no-fix) fix=false;;
    --wait)            waitFor=true;;
    --wait-check)      waitJustCheck=true;;
    --wait=*)          waitFor=true; waitTime=${1#--wait=};;
    --wait-msg)        waitMsg="$2"; shift;;
    -ff | --fix-first) # {{{
        if [[ -z $NET_CHECK_FIX_COMMAND ]]; then
          vim /etc/resolv.conf </dev/tty >/dev/tty
        else
          $NET_CHECK_FIX_COMMAND
        fi;; # }}}
    *) # {{{
      if [[ $1 =~ ^[0-9]+\.[0-9]+.[0-9]+.[0-9]+ ]]; then
        addressIP="$1"
      else
        addressDNS="$1"
      fi;; # }}}
    esac
    shift
  done # }}}
  local pingParams="-c1 -w1" ts= err=0 colorsOn=
  [[ ! -t 2 ]] && colorsOn=false
  [[ ! -t 1 ]] && fix=false
  $IS_MAC && pingParams="-c1 -t1"
  if $waitFor; then # {{{
    local cnt=$(time2s $waitTime -o s)
    while true; do
      $silent && sleep-precise -s
      ping $pingParams $addressIP >/dev/null 2>&1 && return 0
      $waitJustCheck && return 1
      $silent || break
      cnt=$((cnt - 1))
      [[ $cnt == 0 ]] && return 1
      read -s -n1 -t $(sleep-precise -i 1) && return 1
    done
    progress --msg "$waitMsg" --cmd "ping $pingParams $addressIP" --dots --wait $waitTime --key --err
    return $?
  fi # }}}
  if $showHelp; then # {{{
    # Gateway address # {{{
    if which ip >/dev/null 2>&1; then
      addressGateway="$(ip route show | awk '/^default/ {print $3}' | head -n1)"
    elif which route >/dev/null 2>&1; then
      if ! $IS_MAC; then
        addressGateway="$(route -n | awk '/^0.0.0.0/{print $2}' | head -n1)"
      else
        addressGateway="$(route -n get default | awk '/gateway:/{print $2}' | head -n1)"
      fi
    fi # }}}
    echo "Return errors:"
    echo "1:   No ping to $(cl ip $addressIP)"
    echo "2:   No ping to $(cl ip $addressDNS)"
    echo "10:  No ping to gateway ($(cl ip $addressGateway))"
    echo "11:  No gateway address"
    echo
    echo "When run with --wait, then they are:"
    echo "1:   Timeout"
    echo "12:  Key Enter"
    echo "255: Key Q/N"
    echo
    return 0
  fi # }}}
  # IP Address # {{{
  local gatewayOk=false try=0
  $loopForever && progress-dot --init -r 6 --align
  while true; do
    if ! $loopForever; then # {{{
      echormf -C -n 1 "$($loopForever && echo "%ts:{$(time2s --to-HMS)}: ")Checking ping to IP (%ip:{$addressIP}) address... "
      echormf -nl 2 # }}}
    else # {{{
      sleep-precise -s
    fi # }}}
    ts="$(get-ts)"
    err=0; ping $pingParams $addressIP >$out 2>&1 || err=1
    ts="$(get-ts -o s.ms $ts)"
    if [[ $err == 0 ]]; then # {{{
      if ! $loopForever; then
        echormf -C $echormParams 1 "%ok:OK (%ts:{$ts})"
        break
      else
        progress-dot --dot=ok
      fi # }}}
    else # {{{
      if ! $loopForever; then # {{{
        echormf -C $echormParams 1 "%err:FAIL (%ts:{$ts})"
        echormf -C 2 "No ping to IP (%ip:{$addressIP}) address" # }}}
      else # {{{
        progress-dot --dot=err
        sleep-precise
      fi # }}}
      try=$(((try+1)%$loopTries))
      [[ $try == 0 ]] && gatewayOk=false
      if ! $gatewayOk; then # {{{
        while true; do
          local addressGatewayNew= updated=false
          $loopForever && sleep-precise -s
          # Gateway address # {{{
          if which ip >/dev/null 2>&1; then
            addressGatewayNew="$(ip route show | awk '/^default/ {print $3}' | head -n1)"
          elif which route >/dev/null 2>&1; then
            if ! $IS_MAC; then
              addressGatewayNew="$(route -n | awk '/^0.0.0.0/{print $2}' | head -n1)"
            else
              addressGatewayNew="$(route -n get default | awk '/gateway:/{print $2}' | head -n1)"
            fi
          fi # }}}
          [[ $addressGateway != $addressGatewayNew ]] && addressGateway=$addressGatewayNew && updated=true
          if [[ ! -z $addressGateway ]]; then # {{{
            if ! $loopForever; then # {{{
              echormf -C -n 1 "$($loopForever && echo "%ts:{$(time2s --to-HMS)}: ")Checking ping to gateway (%ip:{$addressGateway}$($updated && cl - "/" info "updated"))... "
              echormf -nl 2
            fi # }}}
            ts="$(get-ts)"
            err=0; ping $pingParams $addressGateway >$out 2>&1 || err=1
            ts="$(get-ts -o s.ms $ts)"
            if [[ $err == 0 ]]; then # {{{
              if ! $loopForever; then # {{{
                echormf -C $echormParams 1 "%ok:OK (%ts:{$ts})" # }}}
              else # {{{
                progress-dot --dot=ok:G
                sleep-precise
              fi # }}}
              gatewayOk=true try=0
              break # }}}
            else # {{{
              if ! $loopForever; then # {{{
                echormf -C $echormParams 1 "%err:FAIL (%ts:{$ts})"
                echormf -C 2 "No ping to gateway (%ip:{$addressGateway})" # }}}
              else # {{{
                progress-dot --dot=err:G
              fi # }}}
              if ! $loop || ( read -t $readTimeout -n1 -s readKey </dev/tty && [[ $readKey == '' || ${readKey,,} == 'q' ]] ) ; then # {{{
                return 10
              fi # }}}
            fi # }}} # }}}
          else # {{{
            if ! $loopForever; then # {{{
              echormf -C 1 "Checking ping to gateway (%ip:{0.0.0.0})... %err:FAIL" # }}}
            else # {{{
              progress-dot --dot=err:G
            fi # }}}
            if ! $loop || ( read -t $readTimeout -n1 -s readKey </dev/tty && [[ $readKey == '' || ${readKey,,} == 'q' ]] ) ; then # {{{
              return 11
            fi # }}}
          fi # }}}
        done
      fi # }}}
      if ! $loop || ( read -t $readTimeout -n1 -s readKey </dev/tty && [[ $readKey == '' || ${readKey,,} == 'q' ]] ) ; then # {{{
        return 1
      fi # }}}
    fi # }}}
    if $loopForever; then # {{{
      sleep-precise
      if ! $every; then
        for ((i=1; i<loopFSleep; i++)); do
          progress-dot --dot
          read -s -n 1 -t 0.97 && break 2
        done
      else
        read -s -n 1 -t 0.01 && break
      fi
    fi # }}}
  done # }}}
  # DNS Address # {{{
  while true; do
    if ! $loopForever; then # {{{
      echormf -C -n 1 "$($loopForever && echo "%ts:{$(time2s --to-HMS)}: ")Checking ping to DNS (%ip:{$addressDNS}) address... "
      echormf -nl 2 # }}}
    else # {{{
      sleep-precise -s
    fi # }}}
    ts="$(get-ts)"
    err=0; ping $pingParams $addressDNS >$out 2>&1|| err=1
    ts="$(get-ts -o s.ms $ts)"
    if [[ $err == 0 ]]; then # {{{
      if ! $loopForever; then
        echormf -C $echormParams 1 "%ok:OK (%ts:{$ts})"
      else
        progress-dot --dot=ok:D
        sleep-precise
      fi
      break # }}}
    else # {{{
      if ! $loopForever; then # {{{
        echormf -C $echormParams 1 "%err:FAIL (%ts:{$ts})"
        echormf -C 2 "No ping to DNS (%ip:{$addressDNS}) address"
        if $fix; then # {{{
          if [[ -z $NET_CHECK_FIX_COMMAND ]]; then
            vim /etc/resolv.conf </dev/tty >/dev/tty && fix=false && continue
          else
            $NET_CHECK_FIX_COMMAND && continue
          fi
        fi # }}} # }}}
      else # {{{
        progress-dot --dot=err:D
        sleep-precise
      fi # }}}
      if ! $loop || ( read -t $readTimeout -n1 -s readKey </dev/tty && [[ $readKey == '' || ${readKey,,} == 'q' ]] ) ; then # {{{
        return 2
      fi # }}}
    fi # }}}
  done # }}}
  $loopForever && progress-dot --end
  if $speed; then # {{{
    speedtest
  fi # }}}
  if $mtr; then # {{{
    mtr $addressDNS
  fi # }}}
} # }}}
_net "$@"

