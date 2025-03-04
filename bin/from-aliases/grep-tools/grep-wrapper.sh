#!/usr/bin/env bash
# vim: fdl=0

_grep-wrapper() { # @@ # {{{
  if [[ $1 == '@@' ]]; then
    echo "+tee=true +tee=false +fzf +-fzf"
    echo "+i +I"
    echo "+cCOLOR@PHRASE"
    echo +c={Gray,Red,Green,Yellow,Blue,Pink,Cyan,Gold,Hls,Search}
    return 0
  fi
  local cmd="grep"
  [[ $1 != --cmd-* && $1 != +tee* ]] && { grep "$@";  return $?; }
  local params="$GREP_DEFAULT_PARAMS -s"
  local args=
  local oldColors=$GREP_COLORS
  local gnuGrep="$(grep --version | head -n1 | grep -q 'GNU' && echo 'true' || echo 'false')"
  $IS_MAC && ! $gnuGrep && oldColors=$GREP_COLOR
  local color=
  local use_colors=
  local ignoreErr=
  local query="${@: -2}"
  local use_fzf= fzf_params= fzf_prompt= use_tee= smart_case=true
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --cmd-*) cmd=${1/"--cmd-"}
              case $cmd in
              zgrep) ignoreErr='--ignore-err';;
              esac;;
    +c=*)    color=${1/"+c="};;
    +c)      color=$2; shift;;
    +c*@*)   args+=" -e \"${1#*@}\""; color=${1%%@*} && color=${color/"+c"};;
    +c*)     color=${1/"+c"};;
    +tee=*)  use_tee=${1/+tee=};;
    +tee)    use_tee=true;;
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
    params+=" --color=yes"
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
  $IS_MAC && ! $gnuGrep && export GREP_COLOR=${GREP_COLORS/mt=}
  local exclude=
  [[ -t 0 && $cmd != z* ]] && exclude=" --exclude-dir=.git --exclude-dir=.hg --exclude=tags --exclude='cscope*' $GREP_EXCLUDES"
  if [[ -t 0 ]]; then # {{{
    [[ $args != *-h* ]] && params+=" -Hn"
  fi # }}}
  if [[ -z $use_tee ]]; then # {{{
    [[ -t 0 ]] && use_tee=true || use_tee=false
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
      use_fzf="$(echo ",$FZF_USAGE," | grep -o ',\s*GREP:[^,]\+,' | grep -o 'true\|false')"
      [[ -z $use_fzf ]] && use_fzf=$FZF_INSTALLED
    fi
  fi # }}}
  if [[ ! -z $use_colors ]]; then
    params=" $params "
    params="${params/--color }"
    params="${params/--color=yes}"
    params="${params/--color=no}"
  fi
  set - "$args"
  echormf "$use_tee +fzf=$use_fzf $ignoreErr \"eval $cmd\" $params \"$@\" $exclude"
  [[ -z $fzf_prompt ]] && fzf_prompt="grep: $query> "
  $ALIASES_SCRIPTS/grep-tools/output-to-file.sh --no-sort $use_tee $use_colors +fzf=$use_fzf +fzf-p "--prompt '$fzf_prompt'" $fzf_params $ignoreErr "eval $cmd" $params "$@" $exclude
  err=$?
  export GREP_COLORS=$oldColors
  $IS_MAC && ! $gnuGrep && export GREP_COLOR=$oldColors
  return $err
} # }}}
_grep-wrapper "$@"

