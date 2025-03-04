#!/usr/bin/env bash
# vim: fdl=0

_hl() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    echo "+l --lines ++ +-"
    echo "+cCOLOR@PHRASE"
    echo +c={Gray,Red,Green,Yellow,Blue,Pink,Cyan,Gold,Hls,Search}
    return 0
  fi # }}}
  local cmd_root="$GREP_DEFAULT_PARAMS --text --line-buffered --color=yes"
  local params=() cnt=0 lines=false add_lines=false lines_colors=($(echo "48;5;235 48;5;232")) c= add_default=false
  [[ -z $1 ]] && set -- ++
  __util_hl_getPhrase() { # {{{
    local phrase="$1"
    phrase="${phrase//;/\\;}"
    phrase="${phrase//\\|/|}"
    phrase="${phrase//|/\\\\\\|}"
    echo "$phrase"
  } # }}}
  while true; do # {{{
    while [[ ! -z "$1" ]]; do # {{{
      case "$1" in # {{{
      ++)       add_default=true;;
      +-)       add_default=false;;
      +c*)      # {{{
                if ! $lines && ! $add_lines; then # {{{
                  [[ ! -z ${params[$cnt]} ]] && cnt=$(($cnt+1))
                  local phrase="$1"
                  case $1 in
                  +c) phrase="+c=$2"; shift;;
                  esac
                  params[$cnt]+=" \"$(__util_hl_getPhrase "$phrase")\""
                  # }}}
                else # {{{
                  c=${1/+c}
                  [[ -z $c ]] && c=$2 && shift
                  case $(echo ${c,,}) in
                  gr|gray|grey)   c='48;5;8';;
                  r|red)          c='48;5;1';;
                  g|green)        c='48;5;2';;
                  y|yellow)       c='48;5;3';;
                  b|blue)         c='48;5;4';;
                  p|pink)         c='48;5;5';;
                  c|cyan)         c='48;5;6';;
                  [0-9]*\;[0-9]*) c="$c";;
                  [0-9]*)         c="48;5;$c";;
                  esac
                  lines_colors=($(echo "$c 48;5;232" | sed -e 's/\[//g' -e 's/m//g'))
                fi # }}}
                ;; # }}}
      +l)       add_lines=true;;&
      --lines)  lines=true;;&
      +l|--lines) # {{{
                c="$2"
                if [[ ! -z $c && $c != +c* ]]; then
                  shift
                  lines_colors=()
                  for c in $c; do
                    case $c in
                    *\;*) lines_colors+=" $c";;
                    *)   lines_colors+=" 48;5;$c";;
                    esac
                  done
                  lines_colors=($(echo "$lines_colors" | sed -e 's/\[//g' -e 's/m//g'))
                fi;; # }}}
      -e)       params[$cnt]+=" -e \"$(__util_hl_getPhrase "$2")\""; shift;;
      -*)       params[$cnt]+=" $1";;
      *)        params[$cnt]+=" -e \"$(__util_hl_getPhrase "$1")\"";;
      esac # }}}
      shift
    done # }}}
    if ! $add_default || [[ -z $HL_DEFAULTS ]]; then
      break
    fi
    add_default=false
    eval set -- $HL_DEFAULTS
  done # }}}
  unset -f __util_hl_getPhrase
  if $lines; then
    [[ -z $COff ]] && source $BASH_PATH/colors
    # Sed fixes grep's color reset markup and interpretation of '&' in gawk's gensub
    sed -e 's/&/\\&/' -e 's/\[m/\[0m/g' -e 's/\[[kK]//g' | \
    gawk \
      -v c1=${lines_colors[0]} -v c2=${lines_colors[1]} -v c_off=${COff} \
      '{
        o = gensub(/\[([0-9;]+)m/, "[\\1;" ((NR%2) ? c2 : c1) "m", "G")
        o = gensub(/^.*$/, "[" ((NR%2) ? c2 : c1) "m" o c_off, "G", o)
        print o
      }'
    return
  fi
  cnt=${#params[*]}
  local cmd=
  local i=
  for (( i=0; i<$cnt; i++ )); do
    [[ ! -z $cmd ]] && cmd+=" | "
    cmd+="$ALIASES_SCRIPTS/grep-tools/grep-wrapper.sh --cmd-grep +tee=false +-fzf $cmd_root ${params[$i]} -e \"\$\""
  done
  [[ -z $cmd ]] && return 1
  if $add_lines; then
    [[ ! -z $cmd ]] && cmd+=" | "
    cmd+=" hl --lines \"${lines_colors[*]}\""
  fi
  echorm -m hl -f? && echorv cmd
  eval $cmd
} # }}}
_hl "$@"

