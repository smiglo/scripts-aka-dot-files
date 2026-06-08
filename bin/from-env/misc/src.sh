#!/usr/bin/env bash
# vim: fdl=0

declare -a files=( # {{{
  $SCRIPT_PATH/dot-files/bashrc:--force
  $BASH_PATH/cfg:--force
  $BASH_PATH/colors:--force
  $BASH_PATH/completion.basic
  $BASH_PATH/completion:--force
  $BASH_PATH/env:--force
  $BASH_PATH/essentials
  $BASH_PATH/runtime
  $BASH_PATH/runtime-post:--force
  $BASH_PATH/unicode
)
$IS_VIRTUAL_OS && files+=( $BASH_PATH/runtime-virtos.bash )
files+=( $(find $RUNTIME_PATH -maxdepth 1 -type f -name '*.bash') )
$IS_DOCKER && [[ ! -e $RUNTIME_PATH/runtime-common.bash && -e $HOST/.runtime/runtime-common.bash ]] && files+=( "$HOST/.runtime/runtime-common.bash" )
for i in $PROFILES_PATH/*; do
  [[ -e $i ]] || continue
  files+=( $(find -L $i -maxdepth 1 -type f \( -name 'cfg' -o -name 'runtime' -o -name '*.bash' \) ) )
done
files+=( $(find $BASH_PATH/env.d -maxdepth 1 -type f) )
[[ -n $SRC_FILES ]] && files+=( $SRC_FILES )
# }}}

get-modified() { # {{{
  local lastUpdate=0 srcF="$ENV_SNAPSHOT/.src.${TMUX_PANE:-main}"
  if [[ -e $srcF ]]; then
    lastUpdate="$(command stat -c %Y $srcF)"
  elif [[ -e $ENV_SNAPSHOT/set ]]; then
    lastUpdate="$(command stat -c %Y $ENV_SNAPSHOT/set)"
  fi
  for f in ${files[@]}; do
    (( $(command stat -c %Y ${f%%:*}) > lastUpdate )) || continue
    echo "$f"
  done
} # }}}
file-parser() { # {{{
  sed \
    -e '/^\s*$/d' \
    -e 's|:.*||' \
    -e 's|.*/profiles/\([^/]\+\)/|\1:|' \
    -e 's|.*/env\.d/|env:|' \
    -e 's|.*/dot-files/|dots:|' \
    -e 's|.*/bash/|bash:|' \
    -e 's|.*/\.runtime/|rt:|'
} # }}}

if [[ $1 == "@@" ]]; then # @@:new # {{{
  if [[ " $@ " =~ \ (-f|--full)\  ]]; then
    printf "%s\n" "${files[@]}" | file-parser
  else
    echo "-v -s -f --full -"
    get-modified | file-parser
  fi
  exit 0
fi # }}}
declare -A pathMap=( # {{{
  [bash]="$BASH_PATH"
  [dots]="$SCRIPT_PATH/dot-files"
  [env]="$SCRIPT_PATH/bash/env.d"
  [rt]="$RUNTIME_PATH"
) # }}}
for i in $RUNTIME_PATH/profiles/*; do # {{{
  [[ -e $i ]] || continue
  pathMap[${i##*/}]="$i"
done # }}}
j= files= verbose=false
if [[ -n $1 ]]; then
  while [[ -n $1 ]]; do # {{{
    case $1 in
    -v) verbose=true;;
    -s) verbose=false;;
    -f | --full)
      shift
      files="$@"
      [[ -n $files ]] || exit 1
      shift $#;;
    -)
      shift $#
      files="$(printf "%s\n" "${files[@]}" | file-parser | fzf -0 -1 --multi --sort)"
      [[ -n $files ]] || exit 0
      verbose=true;;
    *) files="$@"; shift $#;;
    esac; shift
  done # }}}
else
  files="$(get-modified)"
  verbose=true
fi
[[ -n $files ]] || die 0 src "up to date"
for i in $files; do # {{{
  if [[ $i != /* ]]; then
    prefix=${i%%:*}
    i="${pathMap[$prefix]}/${i#*:}"
  fi
  for j in ${!files[@]}; do
    j="${files[$j]}"
    case $j in
    $i | $i:*)
      params=
      [[ $j == *:* ]] && params=${j#*:} && j=${j%%:*}
      echoe $verbose -c -m src "source $j $params"
      echo  $j $params
      break;;
    esac
  done
done # }}}
