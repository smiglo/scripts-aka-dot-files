#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '--impl' ]]; then # {{{
  shift
  isStdOut=true list="$PP_DEFAULT_KEY"
  [[ -t 1 ]] || isStdOut=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -k | --key) list="$2"; shift; break;;
    *) list="$@"; break;;
    esac; shift
  done # }}}
  [[ ! -z $list ]] || exit 1
  for i in $list; do # {{{
    v="$(keep-pass.sh --get --key $i)"
    [[ ! -z $v ]] || { echor "cannot find key '$i'"; continue; }
    cnt=0
    while [[ ! -z $v ]]; do
      cnt=$((cnt+1))
      j="${v%% :: *}"
      [[ $j == $v ]] && v="" || v="${v#* :: }"
      echo "$j" | { if $isStdOut; then ccopy; else /bin/cat -; fi; }
      j=""
      if $isStdOut; then # {{{
        if [[ ! -z $v || $list == *\ * && $list != *\ $i ]]; then
          read -s -p "copied ($i$([[ ! -z $v || $cnt -gt 1 ]] && echo "/$cnt")), press a key"; echo
        else
          echo "copied ($i$([[ ! -z $v || $cnt -gt 1 ]] && echo "/$cnt"))"
        fi
      fi >>/dev/stderr # }}}
    done
  done # }}}
  if ${PP_AS_POPUP:-false} && $isStdOut; then # {{{
    sleep 1
    clear
  fi # }}}
  exit 0
fi # }}}
pp() { # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -k | --key) keep-pass.sh --list-all-keys;;
    *)
      echo "-k --key"
      echo "$PP_DEFAULT_KEY $PP_KEYS";;
    esac
    return 0
  fi # }}}
  local ppFile="$(dirname $(readlink -f $(which keep-pass.sh)))/keep-pass-pp.sh"
  if ${PP_AS_POPUP:-false} && [[ -t 1 ]]; then
    tmux-popup --no-wait --title "pp" "$ppFile" --impl "$@"
  else
    $ppFile --impl "$@"
  fi
  if [[ -t 1 ]]; then # {{{
    clr --hist
  fi # }}}
} # }}}
compl-add pp
export HISTIGNORE+=":pp:keep-pass-pp.sh"

