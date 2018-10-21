#!/bin/bash

LETTERS=(A B C D E F G H I J K L M N O P R S T U V W X Y Z Ą Ć Ę Ń Ó Ś Ż Ź)
ROWS=4
COLS=4
SEP=' '

while [[ ! -z $1 ]]; do
  case $1 in
    --sep) SEP=$2; shift;;
    -r) ROWS=$2; shift;;
    -c) COLS=$2; shift;;
    *)  WORDS=("${@}"); LEN=${#WORDS[*]}; break;;
  esac
  shift
done

[[ $ROWS -le $(($LEN+2)) ]] && ROWS=$(($LEN+2))
wLen=0
for i in ${!WORDS[*]}; do
  [[ ${#WORDS[$i]} -gt $wlen ]] && wLen=${#WORDS[$i]}
done
[[ $COLS -le $(($wLen+2)) ]] && COLS=$(($wLen+2))

start=$((($ROWS-$LEN)/2))
j=0
while [[ $j -lt $ROWS ]]; do
  idx=
  w=
  if [[ $j -ge $start && $j -lt $(($start+$LEN)) ]]; then
    w=${WORDS[$(($j-$start))]}
    wLen=${#w}
    idx=$((1 + $RANDOM % ($COLS-$wLen-1)))
  fi
  i=0
  while [[ $i -lt $COLS ]]; do
    if [[ ! -z $idx && $i -ge $idx && $i -lt $(($idx+$wLen)) ]]; then
      printf "%s%s"  "${w:$(($i-$idx)):1}" "$SEP"
    else
      printf "%s%s"  "${LETTERS[$(($RANDOM % ${#LETTERS[*]}))]}" "$SEP"
    fi
    i=$(($i+1))
  done
  printf "\n"
  j=$(($j+1))
done

