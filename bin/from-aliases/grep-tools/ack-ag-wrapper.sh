#!/usr/bin/env bash
# vim: fdl=0

_ack-ag-wrapper() { # {{{
  if [[ $1 == @@ ]]; then
    echo "--cmd-ag --cmd-ack --cmd-rg +tee=false +tee=true +-fzf +fzf"
    return 0
  fi
  local cmd=
  local use_tee=true use_fzf= fzf_params=
  while [[ ! -z $1 ]]; do
    case $1 in
    --cmd-*) cmd=${1/--cmd-};;
    +tee=*)  use_tee=${1/+tee=};;
    +-fzf | +-f)
             use_fzf=false;;
    +fzf | +f)
             use_fzf=$FZF_INSTALLED;;
    +fzf=*)  use_fzf=${1/+fzf=}; $use_fzf && use_fzf=$FZF_INSTALLED;;
    +fzf-*)  fzf_params+=" $1";;
    *)       break;;
    esac
    shift
  done
  if [[ -z $use_fzf ]]; then # {{{
    if [[ ! -t 1 ]]; then
      use_fzf=false
    else
      use_fzf="$(echo ",$FZF_USAGE," | command grep -o ',\s*ACK-AG-WRAPPER:[^,]\+,' | command grep -o 'true\|false')"
      [[ -z $use_fzf ]] && use_fzf=$FZF_INSTALLED
    fi
  fi # }}}
  if [[ -z $cmd ]] || ! which $cmd >/dev/null 2>&1; then
    echo "Program [$cmd] not found, falling back to grep..." >/dev/stderr
    sleep 0.5
    while [[ ! -z $1 ]]; do
      case $1 in
      -|--) shift; break;;
      -*)   shift;;
      *)    break;;
      esac
    done
    $ALIASES_SCRIPTS/grep-tools/grep-wrapper.sh --cmd-grep +tee=$use_tee +fzf=$use_fzf $fzf_params -R "$@" *
    return $?
  fi
  local params= prompt=
  case $cmd in
  ack*) params+=" $ACK_OPTIONS"; prompt="ack: ${@: -1}> ";;
  ag*)  params+=" --silent $AG_OPTIONS"; prompt="ag: ${@: -1}> ";;
  rg*)  prompt="rg: ${@: -1}> ";;
  esac
  if $use_tee && [[ -t 1 ]] && ! $use_fzf; then
    case $cmd in
    ack*) params+=" --color";;
    ag*)  params+=" --color";;
    rg*)  params+=" --color always";;
    esac
  fi
  $ALIASES_SCRIPTS/grep-tools/output-to-file.sh --no-sort $use_tee +fzf=$use_fzf $fzf_params +fzf-p "--prompt '$prompt'" $cmd $params $@
} # }}}
_ack-ag-wrapper "$@"

