#!/usr/bin/env bash
# vim: fdl=0

# | work-parallel.sh script.sh:function

if [[ $1 == '@@' ]]; then # {{{
  case $3 in
  --cpu)        echo "1 2 12 24";;
  --single-cpu) echo "---";;
  --cmd)        echo "---";;
  --lines-max)  echo "10000 100000";;
  --file) # {{{
    get-file-list '*.log'; get-file-list '*.txt';; # }}}
  *) # {{{
    echo "--single-cpu --cpu --lines-max --cmd --file"
    echo --{,no-}progress
    ;; # }}}
  esac
  exit 0
fi # }}}
tester-buffer() { # {{{
  local n=100 i=
  declare -a aryIn
  declare -a aryOut
  while mapfile -t -n $n aryIn && ((${#aryIn[@]})); do
    mapfile -t -n $n aryOut < <(printf '%s\n' "${aryIn[@]}" | sed 's/^/-b- /')
    printf '%s\n' "${aryOut[@]}"
  done < <(cat -)
} # }}}
tester() { # {{{
  local n=100 i=
  declare -a aryIn
  while mapfile -t -n $n aryIn && ((${#aryIn[@]})); do
    for i in ${!aryIn[@]}; do # {{{
      echo "${aryIn[$i]}" | sed 's/^/-s- /'
    done # }}}
  done < <(cat -)
} # }}}
cmd_wrapper() { # {{{
  local fin="$1"
  if [[ ! -z $2 ]]; then # {{{
    local num="$(printf "%03d" $2)"
    fin+="$num"
  fi # }}}
  [[ -e "$fin" ]] || { echorm 0 "File [$fin] not found" && return 0; }
  local cmdWorker="$cmdWorker"
  if [[ $cmdWorker == *:* && -e "${cmdWorker%%:*}" ]]; then
    source ${cmdWorker%%:*} && cmdWorker=${cmdWorker#*:} # form: shell-script:function-to-call - for time optimisation
  fi
  cat "$fin" | eval "$cmdWorker" >"$fin.tmp"
} # }}}
f=
cmdWorker="cat -"
if [[ -e /proc/cpuinfo ]]; then
  cpu="$(awk '/siblings/ {print $3}' /proc/cpuinfo | head -n1)"
else
  cpu=4
fi
singleCPU=false
linesMax=10000
useProgress=
isWrapperMode=false
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --file)          f="$2"; shift;;
  --cpu)           cpu=$2; shift;;
  --single-cpu)    singleCPU=true;;
  --lines-max)     linesMax=$2; shift;;
  --no-progress)   useProgress=false;;
  --progress)      useProgress=true;;
  --cmd)           cmdWorker="$2"; shift;;
  --wrapper)       isWrapperMode=true; shift; break;;
  *)               cmdWorker="$@"; shift $#; break;;
  esac; shift
done # }}}
doRemove=false
if $isWrapperMode; then # {{{
  cmd_wrapper "$@"
  exit 0
fi # }}}
if [[ -z $useProgress ]]; then # {{{
  [[ -t 1 ]] && useProgress=true || useProgress=false
fi # }}}
if [[ $f == '-' || ( ! -t 0 && -z $f ) ]]; then # {{{
  f="$TMP_PATH/work-parallel.$$"
  doRemove=true
  cat - >"$f"
fi # }}}
[[ -z "$f" || ! -e "$f" || ! -s "$f" ]] && echorm 0 "File [$f] not found" && exit 1
cmdWorker="${cmdWorker#\'}"
cmdWorker="${cmdWorker%\'}"
[[ -z $cmdWorker ]] && echorm 0 "Empty command" && exit 1
lines=$(cat "$f" | wc -l)
is-installed parallel split || singleCPU=true
[[ $lines -gt $linesMax ]] || singleCPU=true
[[ $lines -gt $cpu ]]      || cpu=$lines
echorv -M cmdWorker
echorv -M f doRemove
echorv -M singleCPU cpu lines linesMax
progressShown=false
$useProgress && progressShown=true && progress --mark --msg "Working parrallel (?$(! $singleCPU && echo "true" || echo "false"), cpu: $cpu) [$cmdWorker]"
if $singleCPU; then # {{{
  cmd_wrapper "$f" # }}}
else # {{{
  split "$f" -d -n l/$cpu -a 3 -e "$f.w"
  parallel -j $cpu $(which bash) $0    \
    --cmd "$cmdWorker"                 \
    --wrapper                          \
    "$f.w" -- $(seq 0 $((cpu-1)))
  for i in $(seq 0 $((cpu-1))); do
    ii="$(printf "%03d" $i)"
    [[ -e "$f.w$ii.tmp" ]] && cat "$f.w$ii.tmp"
  done >"$f.tmp"
  rm -f "$f.w"*
fi # }}}
$progressShown && progress --unmark
cat "$f.tmp"
rm -f "$f.tmp"
if $doRemove; then # {{{
  rm -f "$f"
fi # }}}

