#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  find . -maxdepth 1 -type f -perm -u+x
  declare -F | awk '{print $3}' | sed -n -e '/^_/d' -e '/^\(.\)\{,6\}$/p'
  exit 0
fi # }}}

cmd= args= verbose=false
while [[ ! -z 1 ]]; do # {{{
  case $1 in
  -v) verbose=true;;
  *)  cmd=$1; shift; break;;
  esac
  shift
done # }}}

args="$@"
[[ -z $cmd ]] && cmd="echo"
if [[ -e "$cmd" ]]; then # {{{
  (
    $verbose && set -xv
    xargs -r -I{} "$cmd" $args "{}"
  )
  # }}}
elif declare -F "$cmd" >/dev/null 2>&1; then # {{{
  (
    $verbose && set -xv
    xargs -r -I{} $(which bash) -c "$(declare -f $cmd); $cmd $args {}"
  )
  # }}}
else # {{{
  if [[ $cmd != *{}* && $cmd != *\$1* && $cmd != *\$@* ]]; then
    if [[ -z $args ]]; then
      cmd+=" \$1"
    else
      cmd+=" {}"
    fi
  fi
  args="${args# }" && args="${args% }"
  (
    $verbose && set -xv
    xargs -r -I{} $(which bash) -c 'f() { '"eval $cmd"'; }; f '"$args"' {}'
  )
fi # }}}
