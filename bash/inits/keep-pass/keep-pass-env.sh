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
  [[ ! -z $list ]] || list="$(keep-pass --list-all-keys | fzf --prompt 'key > ' --preview 'keep-pass --get --key {1} --no-intr')"
  [[ ! -z $list ]] || exit 1
  [[ ! -z $PWD_S_EVAL ]] && eval $PWD_S_EVAL
  for i in $list; do # {{{
    v="$(keep-pass --get --key $i)"
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
kp-pp() { # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -k | --key) keep-pass --list-all-keys;;
    *)
      echo "-k --key -"
      echo "$PP_DEFAULT_KEY $PP_KEYS";;
    esac
    return 0
  fi # }}}
  local ppFile="$SCRIPT_PATH/bash/inits/keep-pass/keep-pass-env.sh"
  if [[ -t 1 ]]; then
    tmux-popup --no-wait --no-show --no-i --title "pp" -E "$ppFile" --impl "$@"
    clr --hist
  else
    $ppFile --impl "$@"
  fi
}
compl-add kp-pp # }}}
kp-env() { # @@:new # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $2 in
    -e | --env)
      echo "GITHUB_TOKEN ENV";;
    -k | --key)
      keep-pass --list-all-keys | grep -E "^(g[hl]-t-)";;
    *)
      echo "-e --env"
      echo "-k --key"
      echo "ENV"
      keep-pass --list-all-keys | grep -E "^(g[hl]-t-)";;
    esac
    return 0
  fi # }}}
  local env= key=${KEEP_PASS_ENV_DEFAULT_KEY}
  while [[ -n $1 ]]; do # {{{
    case $1 in
    -e | --env) env="$2"; shift;;
    -k | --key) key="$2"; shift;;
    *)
      key="$1"
      (( $# >= 2 )) && env="$1" && key="$2"
      shift $#
    esac; shift
  done # }}}
  [[ -n $key ]] || eval $(die "key not set")
  if [[ -z $env ]]; then
    case $key in
    gh-t-*) env="GITHUB_TOKEN";;
    gl-t-*) env="GITLAB_TOKEN";;
    *)
      if [[ " $KEEP_PASS_ENV_KEY_MAP " == *" $key:"* ]]; then
        env=" $KEEP_PASS_ENV_KEY_MAP "
        env="${env/* $key:}"
        env="${env%% *}"
      else
        env="${key//[-]/_}"; env="${env^^}"
      fi;;
    esac
  fi
  key="$(keep-pass --get --key $key)" || eval $(die "cannot read key: $key")
  declare -n v=$env
  v="$key"
  export $env
}
compl-add --new kp-env # }}}
