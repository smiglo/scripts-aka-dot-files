#!/usr/bin/env bash
# vim: fdl=0

r= sl= cnt=
if [[ -t 0 ]]; then
  $ENV_SCRIPTS/find-tools/find-short.sh "$@"
else
  command cat -
fi \
| awk -F'/' '{print NF-1, $0}' \
| sort -n -k1,1 \
| cut -d' ' -f2-
