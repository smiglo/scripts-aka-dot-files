#!/usr/bin/env bash
# vim: fdl=0

_update-file() { # @@ # {{{
  local wtd="update-line"
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -wtd | --what-to-do) echo "update-var add-to-var update-line remove-line insert-before insert-after comment-line";;
    *)
      echo "-wtd --what-to-do"
      echo "--update-var --add-to-var --update-line --remove-line --insert-before --insert-after --comment-line"
      echo "-a --add --ins -rl -ul --line -uv --var -cl --comment";;
    esac
    return 0
  fi # }}}
  local file=
  [[ -t 0 ]] && file="$1" && shift
  if [[ -t 0 && "$file" != '-' ]]; then
    [[ ! -e "$file" ]] && touch "$file"
  else
    file="$TMP_MEM_PATH/update-file-$$.stdin"
    cat - >"$file"
  fi
  local fileOut="$TMP_MEM_PATH/update-file-$$.tmp"
  cp "$file" "$fileOut"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in # {{{
    -wtd | --what-to-do) wtd="$2"; shift;;
    --update-var | --add-to-var | --update-line | --remove-line | --insert-before | --insert-after | --comment-line) wtd="${1#--}";;
    -a | --add )  wtd="add-to-var";;
    --ins)        wtd="insert-after";;
    -rl)          wtd="remove-line";;
    -ul | --line) wtd="update-line";;
    -uv | --var)  wtd="update-var";;
    -cl | --comment) wtd="comment-line";;
    *) break;;
    esac; shift # }}}
    local match= newVal= update=false
    match="$1" && shift
    [[ -z $match ]] && echo "Match pattern not provided" >/dev/stderr && return 1
    case $wtd in # {{{
    update-var | add-to-var | update-line | insert-before | insert-after)
      newVal="$1" && shift
      [[ -z $newVal ]] && echo "New value not provided [$match]" >/dev/stderr && return 1;;
    esac # }}}
    case $wtd in # {{{
    update-var | add-to-var) grep -q "^[^#]*$match=" "$fileOut" && update=true;;
    *)                       grep -q "$match"        "$fileOut" && update=true;;
    esac # }}}
    case $wtd in # {{{
    update-var) # {{{
      if $update; then
        sed -i \
          -e '/^[^#]*'"$match"='/s/\(.*'"$match"'\)=.*/\1="'"$newVal"'"/' \
          -e '/^[^#]*'"$match"'+=/d' \
          "$fileOut"
      else
        echo "export $match=\"$newVal\"" >>"$fileOut"
      fi;; # }}}
    add-to-var) # {{{
      if $update; then
        tac "$fileOut" \
          | awk -v m="$match" -v v="$newVal" '/^[^#]*'"$match"'\+?=/ && !x {printf "export %s+=\"%s\"\n", m, v; x=1} 1' \
          | tac >"$fileOut.$$"
        mv "$fileOut.$$" "$fileOut"
      else
        echo "export $match=\"$newVal\"" >>"$fileOut"
      fi;; # }}}
    update-line) # {{{
      if $update; then
        sed -i '/'"$match"'/s/.*/'"${newVal//\//\\/}"'/' "$fileOut"
      else
        echo "$newVal" >>"$fileOut"
      fi;; # }}}
    comment-line) # {{{
      if $update; then
        sed -i '/'"$match"'/s/.*/# \0/' "$fileOut"
        sed -i '/# # .*'"$match"'/s/# \(.*\)/\1/' "$fileOut"
      fi;; # }}}
    remove-line) # {{{
      sed -i '/'"$match"'/d' "$fileOut" ;; # }}}
    insert-before) # {{{
      if $update; then
        sed -i -e "$(grep -n "$match" "$fileOut" | head -1 | cut -f1 -d':')i $newVal" "$fileOut"
      else
        echo "$newVal" >>"$fileOut"
      fi;; # }}}
    insert-after) # {{{
      if $update; then
        sed -i -e "$(grep -n "$match" "$fileOut" | tail -1 | cut -f1 -d':')a $newVal" "$fileOut"
      else
        echo "$newVal" >>"$fileOut"
      fi;; # }}}
    *) # {{{
      echo "Invalid WhatToDo [$1]" >/dev/stderr && return 1;; # }}}
    esac # }}}
  done # }}}
  if [[ -t 0 && -t 1 ]]; then # {{{
    mv "$fileOut" "$file" # }}}
  else # {{{
    cat "$fileOut"
    rm "$fileOut"
    if [[ ! -t 0 || "$file" == *-$$.stdin  ]]; then
      rm "$file"
    fi
  fi # }}}
} # }}}
_update-file "$@"

