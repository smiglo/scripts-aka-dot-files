#!/usr/bin/env bash
# vim: fdl=0

grep-wrapper() { # @@ # {{{
  if [[ $1 == '@@' ]]; then
    echo "+fzf +-fzf"
    echo "+i +I"
    echo "+cCOLOR@PHRASE"
    echo +c={Gray,Red,Green,Yellow,Blue,Pink,Cyan,Gold,Hls,Search}
    return 0
  fi
  local cmd="grep"
  local params="-s"
  local args=
  local color=
  local use_colors=
  local query="${@: -2}"
  local use_fzf= fzf_params= fzf_prompt= smart_case=true
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --cmd-*)
      cmd=${1/"--cmd-"}
      case $cmd in
      pgrep) cmd="grep"; args+=" -P";;
      esac;;
    +c=*)    color=${1/"+c="};;
    +c)      color=$2; shift;;
    +c*@*)   args+=" -e \"${1#*@}\""; color=${1%%@*} && color=${color/"+c"};;
    +c*)     color=${1/"+c"};;
    +tee=*)  ;;
    +tee)    ;;
    +-fzf | +-f) use_fzf=false;;
    +fzf  | +f)  use_fzf=$FZF_INSTALLED;;
    +fzf-prompt) fzf_prompt="$2"; shift;;
    +fzf=*)  use_fzf=${1/+fzf=}; $use_fzf && use_fzf=$FZF_INSTALLED;;
    +fzf-*)  fzf_params+=" $1";;
    +I)      smart_case=false; params+=" -i";;
    +i)      smart_case=false;;
    -i)      smart_case=false; params+=" -i";;
    --colors | --no-colors) use_colors="$1" params="${params/--color}";;
    -*)      args+=" $1";;
    *)       args+=" \"$1\""; $smart_case && [[ $1 != ${1,,} ]] && smart_case=false;;
    esac
    shift
  done # }}}
  $smart_case && params+=" -i"
  if [[ ! -z $color ]]; then # {{{
    [[ $use_colors != "--no-colors" ]] && use_colors="--colors" && params+=" --color=yes"
    case $(echo ${color,,}) in
    gr|gray|grey)   GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=01;30/');;
    r|red)          GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=01;31/');;
    g|green)        GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=01;32/');;
    y|yellow)       GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=01;33/');;
    b|blue)         GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=01;34/');;
    p|pink)         GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=01;35/');;
    c|cyan)         GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=01;36/');;
    gold)           GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=38;5;220/');;
    hls)            GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=38;5;208/');;
    search)         GREP_COLORS=$(echo $GREP_COLORS | sed 's/mt=[0-9;]*/mt=38;5;214/');;
    [0-9]*\;[0-9]*) GREP_COLORS=$(echo $GREP_COLORS | sed "s/mt=[0-9;]*/mt=$color/");;
    [0-9]*)         GREP_COLORS=$(echo $GREP_COLORS | sed "s/mt=[0-9;]*/mt=01;38;5;$color/");;
    *=*)            GREP_COLORS=$(echo $GREP_COLORS | sed "s/mt=[0-9;]*/$color/");;
    esac
  fi # }}}
  export GREP_COLORS
  if $IS_MAC; then
    grep --version | head -n1 | grep -q 'GNU' || export GREP_COLOR=${GREP_COLORS/mt=}
  fi
  case $cmd in
  *grep) params="--color --binary-files=binary $params";;
  esac
  if [[ -t 0 ]]; then # {{{
    [[ $args != *-h* ]] && params+=" -Hn"
  fi # }}}
  local err=
  if [[ ! -t 1 ]]; then # {{{
    [[ -z $use_fzf ]] && use_fzf=false
    [[ -z $use_colors ]] && use_colors="--no-colors"
  else
    [[ -z $use_colors ]] && use_colors="--colors"
  fi # }}}
  if [[ -z $use_fzf ]]; then # {{{
    if [[ ! -t 1 ]]; then
      use_fzf=false
    else
      eval $FZF_USAGE
      use_fzf=${fzfUsageA[grep]:-$FZF_INSTALLED}
    fi
  fi # }}}
  if [[ ! -z $use_colors ]]; then # {{{
    params=" $params "
    params="${params/--color }"
    params="${params/--color=yes}"
    params="${params/--color=no}"
  fi # }}}
  set - "$args"
  # echoe -w "$use_tee +fzf=$use_fzf \"eval $cmd\" $params \"$@\"
  [[ -z $fzf_prompt ]] && fzf_prompt="grep: $query> "
  case $use_colors in
  --colors) # {{{
    case $cmd in
    rg*) params+=" --color=always";;
    *)   params+=" --color=yes";;
    esac;; # }}}
  --no-colors) # {{{
    params+=" --color=never";; # }}}
  esac
  if $use_fzf; then
    eval $cmd $params "$@" | fzf --prompt "$fzf_prompt" -m --sort --ansi $fzf_params
  else
    eval $cmd $params "$@"
  fi
} # }}}
grep-wrapper "$@"
