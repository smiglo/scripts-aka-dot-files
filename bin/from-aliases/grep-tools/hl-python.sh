#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  list="$(python $(dirname $0)/hl.py ---util-get-colors)"
  case $3 in
  -f) # {{{
    echo "-"
    get-file-list '*.json';; # }}}
  -p) # {{{
    echo "$list";; # }}}
  --name) # {{{
    echo "NAME";; # }}}
  --skip) # {{{
    echo "NAME"
    echo "\'"'[\ \"NAME1\"\ \"...\"\ ]'"\'";; # }}}
  *) # {{{
    if echo "$list" | grep -q -e "^${3:---}$"; then
      echo "REG-EXP"
    else
      echo "-p --name --skip --no-embed"
      echo "-D --no-default -f --reg-file -m --only-matching"
      echo "-c --colors -C --no-colors"
      echo "-v -vv -h --help"
      echo "REG-EXP"
    fi;; # }}}
  esac
  exit 0
fi # }}}
python $(dirname $0)/hl.py "$@"

