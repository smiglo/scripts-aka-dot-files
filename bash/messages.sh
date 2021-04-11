#!/usr/bin/env bash

[[ -z $TMP_MEM_PATH ]] && source $HOME/.bashrc --do-min

[[ -e $RUNTIME_PATH/messages-conf.sh ]] && source $RUNTIME_PATH/messages-conf.sh
[[ -e $TMP_PATH/.messages-conf.sh ]] && source $TMP_PATH/.messages-conf.sh

[[ -z $MSG_RECEIVER_SEND_METHOD ]] && MSG_RECEIVER_SEND_METHOD="_msg_default_sender_"
if [[ "$MSG_RECEIVER_SEND_METHOD" == '_msg_ssh_sender_' ]]; then
  [[ -z "$MSG_RECEIVER_SSH_HOST" ]] && echo "MSG_RECEIVER_SSH_HOST not defined" && exit 1
  [[ -z "$MSG_RECEIVER_SSH_USER" ]] && echo "MSG_RECEIVER_SSH_USER not defined" && exit 1
fi

[[ -z $msg_receiver_file ]] && msg_receiver_file="$TMP_MEM_PATH/.messages.txt"

if [[ "$1" == 'login' ]]; then
  debug=false
  $debug && log_file=$TMP_MEM_PATH/msg_receiver.log

  log() {
    $debug && echo "$($ALIASES date): $1" >>$log_file
  }

  _msg_receiver_() {
    rm -f $msg_receiver_file
    touch $msg_receiver_file
    log "Waiting"
    local chromaCmd="chroma-effects-wrapper.sh"
    tail -F $msg_receiver_file 2>/dev/null | while read line; do
      log "New Msg [$line]"
      [[ -z "$line" ]] && log "Skipped-1" && continue
      local title= msg= rest= icon= timeout=
      IFS='|' read title msg rest <<<$(echo "$line")
      [[ -z "$title" ]] && log "Skipped-2" && continue
      if [[ $title == 'BLINK' ]]; then
        log "Blink"
        which $chromaCmd >/dev/null 2>&1 && $chromaCmd --test && [[ ! -z $msg ]] || continue
        $chromaCmd $msg
        continue
      fi
      title="$(echo "$title" | xargs)"
      msg="$(echo "$msg" | xargs)"
      rest="$(echo "$rest" | xargs)"
      IFS='|' read icon timeout rest<<<$(echo "$rest")
      if $IS_MAC; then
        terminal-notifier -title "$title" -message "${msg:-$title}" 1>/dev/null 2>&1
      else
        notify-send -i "${icon:-emblem-important}" $([[ ! -z $timeout ]] && echo -t $timeout) -u 'critical' "$title" "$msg"
      fi
      log "Message [$title, $msg] has been sent"
    done
    log "Exiting"
  }
  if ( $IS_MAC && which terminal-notifier >/dev/null 2>&1 ) || which notify-send >/dev/null 2>&1; then
    log "Starting"
    _msg_receiver_
  else
    echo "Notification backend not present" >/dev/stderr
  fi
else
  _msg_default_sender_() {
    local b="$1" i=; shift
    for i; do
      b+="|$i"
    done
    echo "$b" >>$msg_receiver_file
  }

  _msg_ssh_sender_() {
    local b="$1" i=; shift
    for i; do
      b+="|$i"
    done
    echo "$b" | ssh $MSG_RECEIVER_SSH_USER@$MSG_RECEIVER_SSH_HOST cat ">>" $msg_receiver_file
  }

  _msg_sender_() {
    [ -z "$1" ] && return
    $MSG_RECEIVER_SEND_METHOD "$@"
  }
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    alias sendMsg='_msg_sender_'
  else
    _msg_sender_ "$@"
  fi
fi

