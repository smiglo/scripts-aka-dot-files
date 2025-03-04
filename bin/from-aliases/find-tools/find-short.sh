#!/usr/bin/env bash
# vim: fdl=0

_find-short() { # @@ # {{{
  if [[ $1 == '@@' ]]; then
    echo "-+tee=false +tee=true +-fzf +fzf +find --full -f -tf -td"
    return 0
  fi
  local use_tee=true use_fzf= fallback=false params= query= find_force=false find_full=false ddir="."
  ! which fdfind >/dev/null 2>&1 && find_force=true
  while [[ ! -z $1 ]]; do
    case $1 in
    +t | +tee)   use_tee=true;;
    +tee=*)      use_tee=${1/+tee=};;
    +-fzf | +-f) use_fzf=false;;
    -f | --full) find_full=true; find_force=true;;
    +fzf)        use_fzf=$FZF_INSTALLED;;
    +fzf=*)      use_fzf=${1/+fzf=}; $use_fzf && use_fzf=$FZF_INSTALLED;;
    +find | +f)  find_force=true;;
    -tf)         params+=" -type f"; find_force=true;;
    -td)         params+=" -type d"; find_force=true;;
    *) # {{{
      query="$1"
      if [[ $# -gt 1 ]]; then
        ddir=$1 && shift
        if [[ $1 != -* ]]; then
          query="$1"
          params+=" -name"
        else
          query="$2"
        fi
        local msg="Falling back to find command: 'find $ddir $params ${@@Q} -print'"
        progress --msg "$msg" --dots --cnt 30 --no-err --out /dev/stderr || return 0
        fallback=true
      fi
      break;; # }}}
    esac
    shift
  done
  if [[ -z $use_fzf ]]; then
    use_fzf=$FZF_INSTALLED
    [[ ! -t 1 ]] && use_fzf=false
  fi
  $find_force && [[ -z $@ ]] && fallback=true
  if ! $fallback; then
    if ! $find_force && [[ -z $1 ]]; then
      echormf "fdfind $1"
      $ALIASES_SCRIPTS/grep-tools/output-to-file.sh $use_tee +fzf=$use_fzf +fzf-p "--prompt 'fd: $query> '" --no-err fdfind "$1"
    else
      local ddir="."
      [[ -d $1 ]] && ddir="$1" && shift
      params="-path '*/.git' -prune -o $params"
      echormf "find $ddir $params $([[ ! -z $1 ]] && echo "-name ${1@Q}") \"-print\""
      $ALIASES_SCRIPTS/grep-tools/output-to-file.sh $use_tee +fzf=$use_fzf +fzf-p "--prompt 'find: $query> '" --no-err \
        eval "find $ddir \
          $(! $find_full && [[ ! -z "$F_FIND_EXCLUDE" ]] && echo "-path '$F_FIND_EXCLUDE' -prune -o") \
          $params $([[ ! -z $1 ]] && echo "-name ${1@Q}")  -print | tail -n+2 | cut -c3-"
    fi
  else
    params="-path '*/.git' -prune -o $params"
    echormf "find $ddir $params ${@@Q} -print"
    $ALIASES_SCRIPTS/grep-tools/output-to-file.sh $use_tee +fzf=$use_fzf +fzf-p "--prompt 'find: $query> '" --no-err \
      eval "find $ddir $params ${@@Q} -print | tail -n+2 | cut -c3-"
  fi
  return $?
} # }}}
_find-short "$@"

