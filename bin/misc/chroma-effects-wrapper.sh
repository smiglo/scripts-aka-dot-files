#!/usr/bin/env bash

colorConv() { # {{{
  local ret=${colors[${1,,}]}
  [[ -z $ret ]] && ret=$1
  echo $ret
} # }}}

declare -A colors
colors[red]="255 0   0"
colors[green]="0   255 0"
colors[blue]="0   0   255"
colors[cyan]="0   255 255"
colors[yellow]="255 255 0"
colors[orange]="255 165 0"
colors[nice-red]="200 0 0"
colors[nice-green]="200 200 0"
colors[nice-orange]="200 40 0"

if [[ $1 == '@@' ]]; then # @@:new # {{{
  case $2 in
  --delay) echo "1 3 5 10 30 60";;
  --blink* ) echo ${!colors[*]};;
  --kbd) xinput --list | grep keyboard | sed -n '/Razer.*Chroma/s/.*Razer \(.*\) Chroma.*/\L\1/p' | sort -u;;
  --brightness) echo "10 20 25 50 100";;
  --static) echo "${!colors[*]} R,G,B";;
  *)
    if [[ $@ =~ .*--blink\ =\ [0-9] ]]; then
      echo ${!colors[*]}
    else
      echo "-v --no-delay --delay --reset --blink --blink= -h --help --kbd --reset-all"
      echo "--breath-random --breath-single --breath-dual --reactive --spectrum --starlight-single --static --wave --ripple-single --ripple-random --brightness"
      echo --blink={1,2,3}
    fi;;
  esac
  exit 0
fi # }}}

chroma="$SCRIPT_PATH/bin/oth/chroma-effects.py"
verbose=false

defSleep="${CHROMA_DEFAULT_SLEEP:-3}"
defBrightness="${CHROMA_DEFAULT_BRIGHTNESS:-10}"
defColor="${CHROMA_DEFAULT_COLOR:-cyan}"
defBlinkColor="red"
$chroma --test || exit 0

case $OS_KIND in
ubunt) kbdList=$(xinput --list | grep keyboard | sed -n '/Razer.*Chroma/s/.*Razer \(.*\) Chroma.*/\L\1/p' | sort -u);;
arch)  kbdList=$(libinput list-devices | sed -n '/Razer.*Chroma/s/.*Razer \(.*\) Chroma.*/\L\1/p' | sort -u);;
esac
if [[ $kbdList =~ ornata ]]; then
  export RAZER_KEYBOARD="ornata"
elif [[ $kbdList =~ cynosa ]]; then
  export RAZER_KEYBOARD="cynosa"
fi

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -v) # {{{
    verbose=true;; # }}}
  --help | -h) # {{{
    echo "$(basename $0) [-v] [--delay N|--no-delay] [--reset] [--blink|--blink=DELAY [COLOR]] [--test]"
    echo
    echo "Extented parameters:"
    $chroma -h
    echo
    exit 0;; # }}}
  --kbd) # {{{
    export RAZER_KEYBOARD="$2"; shift;; # }}}
  --reset-all) # {{{
    [[ $kbdList =~ cynosa ]] && $0 --kbd cynosa
    [[ $kbdList =~ ornata ]] && $0 --kbd ornata
    exit 0;; # }}}
  *) break;;
  esac; shift
done # }}}

case $RAZER_KEYBOARD in
ornata) # {{{
  defSleep="${CHROMA_ORNATA_SLEEP:-3}"
  defColor="${CHROMA_ORNATA_COLOR:-nice-orange}"
  defReset="--wave LEFT --delay 0.3 --wave RIGHT --delay 0.3"
  defReset+=" $defReset";; # }}}
cynosa) # {{{
  defSleep="${CHROMA_CYNOSA_SLEEP:-1}"
  defBrightness=45
  defColor="${CHROMA_CYNOSA_COLOR:-nice-green}";; # }}}
esac

defCmd="$chroma --brightness $defBrightness; $chroma --static $(colorConv $defColor)"

if [[ -z $1 ]]; then # {{{
  case $OS_KIND in
  ubuntu)
    if is-installed gsettings && ${CHROMA_SET_KBD_INTERVAL:-false}; then
      gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval 20
      gsettings set org.gnome.desktop.peripherals.keyboard delay 300
    fi;;
  esac
  set -- $defReset --reset
fi # }}}

while [[ ! -z $1 ]]; do
  cmd=$1
  fullCmd=
  case $cmd in
  --no-delay);;
  --delay) [[ $2 != 0 ]] && fullCmd="sleep $2"; shift;;
  --reset) fullCmd="$defCmd";;
  --test)  $chroma --test; exit $?;;
  --*) # {{{
    args= first=true
    while [[ ! -z $2 && $2 != '--'* ]]; do # {{{
      if $first; then
        args+=" $(colorConv "${2//,/ }")"
        first=false
      else
        args+=" $2"
      fi
      shift
    done # }}}
    case $cmd in
    --blink)   sleepTime=$defSleep;;&
    --blink=*) sleepTime=${cmd#--blink=};;&
    --blink | --blink=*) # {{{
      fullCmd="$chroma --starlight ${args:-$(colorConv $defBlinkColor)}; $chroma --brightness 100; sleep $sleepTime; "
      [[ -z $2 ]] && fullCmd+="$defCmd"
      ;; # }}}
    --*) fullCmd="$chroma $cmd $args";;
    esac;; # }}}
  esac
  shift
  [[ -z $fullCmd ]] && continue
  $verbose && echo $fullCmd
  eval $fullCmd
  if [[ ! -z $1 && $1 != '--delay' && $1 != '--no-delay' ]]; then
    case $cmd in
    --delay | --brightness | --blink | --blink=*);;
    *) echo "sleep"; sleep $defSleep;;
    esac
  fi
done
