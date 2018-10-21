#!/bin/bash

fill() {
  str=$1
  while [[ ${#str} -lt $2 ]] ; do
    str="${3:-" "}$str"
  done
  echo $str
}

c=0
for j in {0..15}; do
  for i in {0..15}; do
    printf "\x1b[38;5;${c}mcolour$(fill $c 3 "0") "
    c=$((c+1))
  done
  printf "\n"
done

