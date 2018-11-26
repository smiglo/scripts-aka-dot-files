#!/bin/bash
# vim: fdl=0

if [[ -z $TICKET_PATH || ! -e $TICKET_PATH ]]; then # {{{
  echo "Cannot access ticket path [$TICKET_PATH]" >/dev/stderr
  [[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 1 ||  return 1
fi # }}}
ISSUES=
for i in $(find $TICKET_PATH -maxdepth 4 -name \*-data.txt | sort); do # {{{
  dn="$(dirname $i)"
  [[ -e $dn/.done ]] && continue
  command grep -q "^# j-info: .*[^-]DONE" $i && continue
  i="${i##*/}" && i="${i%-data.txt}" && i="${i#.}"
  [[ $(basename $dn) != $i ]] && continue
  ISSUES+=" $i"
done # }}}
unset i dn
echo $ISSUES
unset ISSUES
# echo "is=[$ISSUES]" >/dev/stderr

