#!/usr/bin/env bash
# vim: fdl=0

_weather() { # @@ # {{{
  if [[ $1 == '@@' ]]; then
    echo "--loop -1 -2"
    return 0
  fi
  local LOOP_TIME=$(( 4 * 60 * 60 ))
  local loop=false org_city='Wroclaw' c= day= params= ver=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --loop) loop=true; echo "$2" | grep -q '^[0-9]\+' && LOOP_TIME=$(($2 * 60 * 60)) && shift;;
    -1)     ;;
    -2)     ver="format=v2";;
    -d)     day=$2;            shift;;
    +)      params+="&$2";     shift;;
    +*)     params+="&${1#+}"       ;;
    *)      org_city="$@";     break;;
    esac
    shift
  done # }}}
  local city="$org_city" noRespTry=2
  [[ ! -z $params ]] && params="?${params:1}"
  while true; do # {{{
    clear
    local refreshTime=$((2 * 60))
    if [[ ! -n $TMUX || "$(tmux display-message -t $TMUX_PANE -p -F '#{pane_width}')" -ge 125  ]]; then # {{{
      if net --wait=10s; then # {{{
        for c in ${city:-$org_city}; do
          c="$(echo ${c:0:1} | tr '[a-z]' '[A-Z]')${c:1}"
          [[ $c == '-' ]] && c=
          set-title "${c:-$org_city}"
          if [[ ! -z $day ]]; then # {{{
            case $day in
            Mon|Tue|Wed|Thu|Fri|Sat|Sun);;
            *) day="${day,,}"
                day="$(echo ${day:0:1} | tr '[a-z]' '[A-Z]')${day:1}";;&
            esac
            case $day in
              Mon|Tue|Wed|Thu|Fri|Sat|Sun);;
              *) day=;;
            esac
          fi # }}}
          local p= err=0
          [[ ! -z $params ]] && p+="$params"
          [[ ! -z $ver ]] && p+="&$ver"
          [[ ! -z $p ]] && p="?${p:1}"
          curl -s -4 -m 3 http://wttr.in/$c$p 2>/dev/null \
          | { [[ ! -z $day ]] && sed -n -e "1p" -e "/\<$day\>/,+9 {x;p;d;}; x" || cat -; } \
          | { [[ ! -z "$WEATHER_2CHAR_ICONS" ]] && sed 's/\('"$WEATHER_2CHAR_ICONS"'\)/\0 /g' || cat -; }
          if [[ ${PIPESTATUS[0]} == 0 ]]; then
            refreshTime=$LOOP_TIME
            noRespTry=2
          else
            echor "No response"
            [[ $noRespTry -gt 0 ]] && noRespTry=$((noRespTry - 1))
            [[ $noRespTry -gt 0 ]] && refreshTime=5 || refreshTime=$((5 * 60))
            break
          fi
        done
      else
        echor "No connection"
      fi # }}}
    else
      echor "Pane is too small"
    fi # }}}
    ! $loop && break
    local key= # {{{
    read -t $refreshTime key
    [[ $? != 0 ]] && continue
    set -- $key
    [[ -z $1 ]] && ver=
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      q)  break 2;;
      1)  ver=;;
      2)  ver='format=v2';;
      c)  city="$org_city";;
      -)  city="-";;
      d | d*)
          if [[ $1 == 'd' ]]; then
            day="$2"
            shift
          else
            c="${1:1}"
            case ${c,,} in
            mon | tue | wed | thu | fri | sat | sun) day="$c";;
            *) city="$@"; break;;
            esac
          fi;;
      *)  city="$@"; break;;
      esac
      shift
    done # }}} # }}}
  done # }}}
} # }}}
_weather "$@"

