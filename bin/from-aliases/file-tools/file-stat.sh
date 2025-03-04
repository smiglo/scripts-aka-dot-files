#!/usr/bin/env bash
# vim: fdl=0

_file-stat() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -m | --mode)   echo "c create m modif a access size";;
    -f | --format) echo "$DATE_FMT $DATE2_FMT $TIME_FMT relative raw";;
    *)
      echo "-m --mode -f --format -r --relative -p --pretty -c @@-f A C M a c m size %s"
      echo "--relative-to="{${EPOCHSECONDS:-$(epochSeconds)},7:00};;
    esac
    return 0
  fi # }}}
  local mode="modif" files= f= fOrig= value= format= pretty=false colorsOn= now=${EPOCHSECONDS:-$(epochSeconds)} err=0 verbose=true
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -c)              colorsOn=true;;
    -f | --format)   format="$2"; shift;;
    -m | --mode)     mode="$2"; shift;;
    A | C | M | \
    a | c | m | \
    size)            mode="${1,,}";;
    -p | --pretty)   pretty=true;;
    -r | --relative) format="relative";;
    --relative-to=*) format="relative"; now="$(time2s -o abs-s "${1#--relative-to=}")";;
    -s)              verbose=false;;
    size)            mode="size";;
    %*)              mode="$1";;
    *)               files+="$1 ";;
    esac; shift
  done # }}}
  if [[ -z "$files" ]]; then
    [[ ! -t 0 ]] && files="$(cat -)"
    [[ -z "$files" ]] && return 1
  fi
  [[ ! -t 1 && -z $colorsOn ]] && colorsOn=false
  for f in $files; do
    fOrig="$f"
    [[ -h "$f" ]] && f="$(readlink -f "$f")"
    [[ ! -e "$f" ]] && echor -c $verbose "File [$f] not exists" && err=1 && continue
    case $mode in # {{{
    a | access)  value=$(command stat -c %X "$f");;
    c | create)  value=$(command stat -c %W "$f");;
    m | modif)   value=$(command stat -c %Y "$f");;
    size)        value=$(command stat -c %s "$f");    [[ -z $format ]] && format="raw";;
    %*)          value=$(command stat -c $mode "$f"); [[ -z $format ]] && format="raw";;
    esac # }}}
    [[ -z $value ]] && echor -c $verbose "No value for [$f]" && err=1 && continue
    $pretty && echo -n "$(cl file "$fOrig" - " : ")"
    case $format in # {{{
    relative | '') # {{{
      [[ $format == 'relative' ]] && value="$(time2s --to-hms $(time2s --diff $now @$value))"
      cl ts "$value";; # }}}
    raw) # {{{
      cl info "$value";; # }}}
    *) # {{{
      date +"$format" -d "@$value";; # }}}
    esac # }}}
  done
  return $err
} # }}}
_file-stat "$@"

