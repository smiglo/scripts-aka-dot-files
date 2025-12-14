#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '--impl' ]]; then # {{{
  shift
  list="$PP_DEFAULT_KEY"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -k | --key) list="$2"; shift; break;;
    -) list=;;
    *) list="$@"; break;;
    esac; shift
  done # }}}
  [[ ! -z $list ]] || list="$(keep-pass.sh --list-all-keys | fzf --prompt 'key > ' --preview 'keep-pass.sh --get --key {1} --no-intr')"
  [[ ! -z $list ]] || exit 1
  [[ ! -z $PWD_S_EVAL ]] && eval $PWD_S_EVAL
  for i in $list; do # {{{
    v="$(keep-pass.sh --get --key $i)"
    [[ ! -z $v ]] || { echoe -w "cannot find key '$i'"; continue; }
    cnt=0
    while [[ ! -z $v ]]; do
      cnt=$((cnt+1))
      j="${v%% :: *}"
      [[ $j == $v ]] && v="" || v="${v#* :: }"
      [[ -z $v && $i =~ [^-]*-([^-]*)(-.*)? ]] && j+="${PWD_S[${BASH_REMATCH[1]}]}"
      if [[ -t 1 ]]; then
        echo -en "$j" | xclip --put
        ${PP_FORCE_XCLIP_KILL:-false} && killall -9 xclip
        if [[ ! -z $v || ! $list =~ \ ?$i$ ]]; then
          read -s -p "copied ($i$([[ ! -z $v || $cnt -gt 1 ]] && echo "/$cnt")), press a key"; echo
        else
          echo "copied ($i$([[ ! -z $v || $cnt -gt 1 ]] && echo "/$cnt"))"
        fi >/dev/stderr
      else
        echo "$j"
      fi
      j=""
    done
  done # }}}
  [[ -t 1 ]] && read -st3 -n1
  exit 0
fi # }}}
pp() { # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -k | --key) keep-pass.sh --list-all-keys;;
    *)
      echo "-k --key -"
      echo "$PP_DEFAULT_KEY $PP_KEYS";;
    esac
    return 0
  fi # }}}
  local ppFile="$(dirname $(readlink -f $(which keep-pass.sh)))/keep-pass-pp.sh"
  if [[ -t 1 ]]; then
    tmux-popup --no-wait --no-show --no-i --title "pp" -E "$ppFile" --impl "$@"
    clr --hist
  else
    $ppFile --impl "$@"
  fi
} # }}}
compl-add pp

