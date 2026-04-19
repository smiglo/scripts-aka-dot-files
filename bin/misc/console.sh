#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  ret="-l --log-path --file --link --no-link"
  if [[ -z $DEV_USB_SERIAL ]]; then
    if $IS_MAC; then
      ret+=" $(get-file-list '/dev/tty.usbserial*') $(get-file-list '/dev/tty.PL2303*')"
    else
      ret+=" $(get-file-list '/dev/ttyUSB*')"
    fi
  else
      ret+=" $(get-file-list "$DEV_USB_SERIAL")"
  fi
  echo "$ret"
  exit 0
fi # }}}
if ! is-installed -f getLogPath; then # {{{
  getLogPath() {
    local path="${LOG_PATH:-$TMP_PATH/logs}"
    [[ ! -e $path ]] && mkdir -p $path
    if [[ $1 != '--full' && $path = $PWD* ]]; then
      path=".${path#$PWD}"
    fi
    path="${path%/}"
    [[ -z $path ]] && path='.'
    echo $path
  }
fi # }}}
if ! is-installed -f genLogFilename; then # {{{
  genLogFilename() {
    local DATE=$(date +$DATE_FMT)
    local suffix=
    [[ ! -z $1 ]] && suffix="-$1"
    echo "log-${DATE}${suffix}.log"
  }
fi # }}}
in_loop=false port= log_filename= log_path="$(getLogPath)" minirc=$HOME/.minirc.dfl auto_filename=true link=true speed=
[[ ! -z $DEV_USB_SERIAL ]] && port="$(get-file-list -1 "$DEV_USB_SERIAL")"
while [[ ! -z "$1" ]]; do # {{{
  case "$1" in
  -l) in_loop=true;;
  --log-path) shift; log_path="$1";;
  --file) shift; log_filename="$1";;
  --link) link=true;;
  --no-link) link=false;;
  --speed) shift; speed="$1";;
  *)
    if [[ $1 == /dev/* ]]; then
      port="$1"
    elif [[ -d $1 ]]; then
      log_path="$1"
    else
      log_filename="$1"
    fi;;
  esac
  shift
done # }}}
if [[ -z $port ]]; then # {{{
  if $IS_MAC; then
    port="$(get-file-list -1 '/dev/tty.usbserial*')"
    [[ -z $port ]] && port="$(get-file-list -1 '/dev/tty.PL2303*')"
  else
    port=$(get-file-list -1 '/dev/ttyUSB*')
  fi
fi # }}}
[[ -n $port ]] || die "Serial adapter not found"
[[ -e $port ]] || die "Serial adapter [$port] not connected"
[[ -e $minirc ]] || cp $SCRIPT_PATH/console/minirc.dfl $minirc
$ENV_SCRIPTS/file-tools/update-file.sh $minirc --line "pu port " "pu port $port"
[[ ! -z $speed ]] && $ENV_SCRIPTS/file-tools/update-file.sh $minirc --line "pu baudrate " "pu baudrate $speed"
[[ ! -z $log_filename ]] && auto_filename=false
sed -i '/^pu \(logfname\|logconn\|logxfer\)/d' $minirc
( echo "pu logfname"; echo "pu logconn"; echo "pu logxfer" ) >>$minirc
while true; do # {{{
  if $auto_filename; then # {{{
    log_filename="$log_path/$(genLogFilename)"
    $link && ln -sf $(realpath --relative-to $PWD $log_filename) last.log
  fi # }}}
  set-title "L: ${log_filename##*/}"
  minicom -c on -C $log_filename
  $in_loop && continue || break
done # }}}
