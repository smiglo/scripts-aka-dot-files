#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  case $3 in
  -f) # {{{
    get-file-list '*.log'; get-file-list '*.txt';; # }}}
  -r) # {{{
    if [[ $@ =~ \ ?-f\ +([^\ ]+) ]]; then
      f=${BASH_REMATCH[1]} # vim: {
      sed -n -e '/^#.* }\{3\}/d' -e 's/^#\+ \+\([^ ]\+\) # {\{3\}/\1/p' -e 's/^#\+ \+\([^ ]\+\)$/\1/p' "$f" # vim: }
    else
      echo "---"
    fi;; # }}}
  *) # {{{
    echo "-f -r -rS -rE -R --smart"
    echo --{,no-}keep
    ;; # }}}
  esac
  exit 0
fi # }}}
region= regionS= regionE= f= keep_first_last=false isStdin=false
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -f)     f="$2"; shift;;
  -r)     region="$2"; shift;;
  -R) # {{{
    regionS="$(echo "$2" | sed -n '1 s/[~: ].*//p')"
    regionE="$(echo "$2" | sed -n '2 s/[~: ].*//p')"
    [[ -z $regionS || -z $regionE ]] && die "no regions"
    keep_first_last=true
    shift;; # }}}
  -rS)       regionS="$2"; shift;;
  -rE)       regionE="$2"; shift;;
  --keep)    keep_first_last=true;;
  --no-keep) keep_first_last=false;;
  --smart) # {{{
    shift && matching-section "$@"
    exit;; # }}}
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
  [[ -z $region ]] && die "No region provided"
  foldet=true isStdin=false
  regionS="^# \(.* \)\?$region\( .*\)\? # {\{3\}" # vim: }
  if ! grep -q "$regionS" "$f"; then # {{{
    regionS="^# \(.* \)\?$region\( .*\)\?$"
    ! grep -q "$regionS" "$f" && die "Start region [$region] not found"
    foldet=false
  fi # }}}
  if $foldet; then # {{{ # vim: {
    regionE="^# \(.* \)\?$region\( .*\)\? # \?}\{3\}" # vim: {
    ! grep -q "$regionE" "$f" && regionE="^# }\{3\}"
    ! grep -q "$regionE" "$f" && die "End region [$region] not found" # }}}
  else # {{{
    regionE="^$"
  fi # }}}
  # }}}
else # {{{
  [[ -z $regionE ]] && regionE="^$"
fi # }}}
sed -n '/'"$regionS"'/,/'"$regionE"'/p' "$f" | { $keep_first_last && cat - || sed -e '1d' -e '$d'; }
if $isStdin; then # {{{
  rm -f "$f"
fi # }}}
