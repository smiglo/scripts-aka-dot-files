#!/usr/bin/env bash
# vim: fdl=0

case "$1" in # {{{
--list) # {{{
  echo "l lf lgo info";; # }}}
@@*) # {{{
  shift 2
  case $1 in
  l | lf | lgo) # {{{
    shift
    git lgo @@ "$@";; # }}}
  info) # {{{
    git for-each-ref refs/heads/ | awk '{print $3}' | sed -e '/HEAD/d' -e 's|refs/heads/||'
    for o in $(git remote); do
      case $o in
      local | origin);;
      *) continue;;
      esac
      git for-each-ref --sort=-committerdate refs/remotes/$o | awk '{print $3}' | sed -e '/HEAD/d' -e 's|refs/remotes/||' | tail -n 5
    done;; # }}}
  esac;; # }}}
esac
# }}}
