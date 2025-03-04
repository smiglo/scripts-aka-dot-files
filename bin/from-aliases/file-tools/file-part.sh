#!/usr/bin/env bash
# vim: fdl=0

_file-part() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -f) # {{{
      get-file-list '*.log'; get-file-list '*.txt';; # }}}
    -r) # {{{
      if [[ $@ =~ \ ?-f\ +([^\ ]+) ]]; then
        local f=${BASH_REMATCH[1]} # vim: {
        sed -n -e '/^#.* }\{3\}/d' -e 's/^#\+ \+\([^ ]\+\) # {\{3\}/\1/p' -e 's/^#\+ \+\([^ ]\+\)$/\1/p' "$f" # vim: }
      else
        echo "---"
      fi;; # }}}
    *) # {{{
      echo "-f -r -rS -rE -R --smart"
      echo --{,no-}keep
      ;; # }}}
    esac
    return 0
  fi # }}}
  local region= regionS= regionE= f= keep_first_last=false isStdin=false
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -f)     f="$2"; shift;;
    -r)     region="$2"; shift;;
    -R) # {{{
      regionS="$(echo "$2" | sed -n '1 s/[~: ].*//p')"
      regionE="$(echo "$2" | sed -n '2 s/[~: ].*//p')"
      [[ -z $regionS || -z $regionE ]] && return 1
      keep_first_last=true
      shift;; # }}}
    -rS)       regionS="$2"; shift;;
    -rE)       regionE="$2"; shift;;
    --keep)    keep_first_last=true;;
    --no-keep) keep_first_last=false;;
    --smart) # {{{
      shift && matching-section "$@"
      return;; # }}}
    *) # {{{
      if [[ ! -t 0 ]]; then
        region="$1"
      elif [[ -z $f && -e $1 ]]; then
        f="$1"
      else
        region="$1"
      fi;; # }}}
    esac; shift
  done # }}}
  if [[ -z $f && ! -t 0 ]]; then # {{{
    f="$TMP_PATH/file-part.$$"
    cat - >"$f"
    isStdin=true
  fi # }}}
  if [[ -z $regionS ]]; then # {{{
    [[ -z $region ]] && echormf 0 "No region provided" && return 1
    local foldet=true isStdin=false
    regionS="^# \(.* \)\?$region\( .*\)\? # {\{3\}" # vim: }
    if ! grep -q "$regionS" "$f"; then # {{{
      regionS="^# \(.* \)\?$region\( .*\)\?$"
      ! grep -q "$regionS" "$f" && echormf 0 "Start region [$region] not found" && return 1
      foldet=false
    fi # }}}
    if $foldet; then # {{{ # vim: {
      regionE="^# \(.* \)\?$region\( .*\)\? # \?}\{3\}" # vim: {
      ! grep -q "$regionE" "$f" && regionE="^# }\{3\}"
      ! grep -q "$regionE" "$f" && echormf 0 "End region [$region] not found" && return 1 # }}}
    else # {{{
      regionE="^$"
    fi # }}}
    # }}}
  else # {{{
    [[ -z $regionE ]] && regionE="^$"
  fi # }}}
  echormf 2 regionS regionE foldet
  cat "$f" | sed -n '/'"$regionS"'/,/'"$regionE"'/p' | { $keep_first_last && cat - || sed -e '1d' -e '$d'; }
  if $isStdin; then # {{{
    rm -f "$f"
  fi # }}}
  return 0
} # }}}
_file-part "$@"


