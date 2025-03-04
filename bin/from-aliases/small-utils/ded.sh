#!/usr/bin/env bash
# vim: fdl=0

_ded() { # @@ # {{{
  is-installed dedoc || evar $(die "dedoc not installed: cargo install dedoc...")
  local dedocDir="${DEDOC_HOME:-$HOME/.dedoc}"
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -m | --module) [[ -e $dedocDir/docsets ]] && get-file-list --pwd $dedocDir/docsets | sed 's/~.*//' || echo "---";;
    *) echo "-m --module -e --edit -f --full";;
    esac
    return 0
  fi # }}}
  local module="${DEDOC_MODULE:-cpp}" dedInfoF="$dedocDir/devdocs.info" query= full=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -e | --edit) [[ -e $dedInfoF ]] && vim --Fast $dedInfoF; return 0;;
    -f | --full) full=true;;
    -m | --module) module=$2; shift;;
    *) query="$@"; shift $#;;
    esac; shift
  done # }}}
  [[ -e $dedocDir/docsets/$module ]] || module="$(get-file-list --pwd $dedocDir/docsets -1 "$module*")"
  local isOut=true
  [[ -t 1 ]] || isOut=false
  local lang=
  case $module in # {{{
  c | cpp)   lang='cpp';;
  cmake)     lang='cmake';;
  bash | sh) lang='bash';;
  python*)   lang='python';;
  esac # }}}
  [[ ! -z $lang ]] && lang="-l $lang"
  local r= i= entry= key=
  if [[ ! -e $dedInfoF ]]; then
    (
      echo "# vim: ft=cpp fdm=marker fdl=0 nolist"
      echo
    ) >$dedInfoF
  fi
  while true; do # {{{
    n=3
    $full && n=1
    r=$(dedoc ss $module | tail -n+$n | \
      if ! $full; then
        awk '!($2 in a) { a[$2]; print; }'
      else
        cat -
      fi | \
      fzf --prompt "$module> " --query="$query" --print-query --expect ctrl-r)
    [[ -z $r ]] && break
    query="$(echo "$r" | sed -n 1p)"
    key="$(echo "$r" | sed -n 2p)"
    r="$(echo "$r" | sed 1,2d)"
    case $key in
    ctrl-r) query=; continue;;
    esac
    while read i entry; do
      dedoc ss $module -o $i >$dedInfoF.tmp
      if ! grep -q "^# $entry #" $dedInfoF; then # {{{
        (
          echo "# $entry # {{{"
          cat $dedInfoF.tmp
          echo "# }}}"
        ) >>$dedInfoF
      fi # }}}
      $isOut && cat $dedInfoF.tmp | $BAT_PRG $lang -p
      rm $dedInfoF.tmp
    done <<<"$(echo "$r")"
  done # }}}
} # }}}
_ded "$@"

