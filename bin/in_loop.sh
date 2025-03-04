#!/usr/bin/env bash

DELAY=10
FUNC=

FUNC="$1"
[[ -z $FUNC ]] && echo "$(basename $0) FUNCTION [--delay secs]" && exit 1
shift

while [[ ! -z "$1" ]]; do
  case $1 in
  --delay) shift; DELAY=$1;;
  esac
  shift
done

while true; do
  echo -n "$(date +$DATE_FMT): "
  eval "$FUNC"
  [[ $? != 0 ]] && break;
  sleep $DELAY
done

