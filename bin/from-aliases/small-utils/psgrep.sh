#!/usr/bin/env bash
# vim: fdl=0

_psgrep() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -K | -k)
      echo "-9 -2 -6";;
    -o)
      echo "pid,cmd pid,user,start,cmd cmd";;
    -P)
      ps x -o pid=,command= \
      | sed -e '/ -bash/d' -e '/ bash /s/ bash / /' | awk '{print $1}' \
      | xargs ps -o comm= -p | sed 's|.*/||' | sort -u \
      | while read l; do printf "%q\n" "$l"; done;;
    *)
      echo "-p -a -o -K -k -P"
      ! $IS_MAC && echo "-t --tree"
      echo "Process";;
    esac
    return 0
  fi # }}}
  local phrase= i= mode='all' list= params="xh -o pid,start,tty,cmd" sigkill=-3 useFzf=false
  $IS_MAC && params="x -o pid=,start=,tty=,command="
  [[ -z $1 && -t 1 ]] && useFzf=true
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -p)   mode='pid';;
    -a)   params="a$params";;
    -o)   params="${params%% -o *} -o $2"; shift;;
    -k | -K) # {{{
      case $1 in
      -k) mode='kill-fzf';;
      -K) mode='kill';;
      esac
      [[ $2 =~ ^-[0-9]+$ ]] && sigkill=$2 && shift;; # }}}
    -t | --tree) # {{{
      $IS_MAC && eval $(die "tree not supported on OS/X")
      ps $params --forest | { if is-installed grcat; then grcat conf.ps; else /bin/cat -; fi; }
      return;; # }}}
    -P)   list+=" $2"; shift;;
    *)    list+=" $1";;
    esac; shift
  done # }}}
  local w="$(command ps $params | grep -v "psgrep\.sh")"
  for i in ${list:-^}; do
    echo "$w" | grep -iE "$i" | \
    case $mode in
    all) { if [[ -t 1 ]] && is-installed grcat && ! $useFzf; then grcat conf.ps; elif $useFzf; then fzf; else /bin/cat -; fi; };;
    pid)  awk '{print $1}';;
    kill) awk '{print $1}' | xargs kill $sigkill;;
    kill-fzf) fzf --prompt "kill $sigkill >" | awk '{print $1}' | xargs -r kill $sigkill
    esac
  done
}
alias pg="psgrep" # @@
# }}}
_psgrep "$@"


