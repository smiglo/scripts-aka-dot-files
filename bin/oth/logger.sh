#!/usr/bin/env bash
# vim: fdl=0

[[ -z $logger_level ]] && logger_level='NONE'
[[ -z $logger_debug_out ]] && logger_debug_out='/dev/stderr'

logger() { # {{{
  set +xv
  if [[ $1 == '@@' ]]; then # {{{
    local levels="1 2 3 4 5 - NONE E ERR ERROR W WARN WARNING I INFO D DBG DEBUG T TRACE"
    case ${4:-$3} in
    --init | --reinit)
      case $3 in
      --init) echo "$levels";;
      *) echo "logger-name";;
      esac;;
    --set-level) echo "$levels";;
    *) echo "--help --end --reinit --init --set-level";;
    esac
    return 0
  fi # }}}
  case $1 in # {{{
  '') # {{{
    [[ $logger_level -ge 5 ]] && set -xv
    return 0;; # }}}
  --help) # {{{
    (
      echo "logger --init|--reinit [LEVEL] [LOGGER_NAME] - Set a maximum level"
      echo "      LEVEL                                  - One of: [ NONE/-, ERROR/ERR/E, WARNING/WARN/W, INFO/I, DEBUG/DBG/D, TRACE/T ]"
      echo "                                               When TRACE, then 'set -xv' is enabled"
      echo "      LOGGER_NAME                            - A name"
      echo "logger [LEVEL] msg1                          - Print a message with given level, if level omitted, then it is INFO"
      echo "logger --end                                 - End work"
      echo
    ) >/dev/stderr
    [[ $logger_level -ge 5 ]] && set -xv
    return 0;; # }}}
  --end | --reinit) # {{{
    logger_level="$(logger --set-level 'NONE')"
    ;;& # }}}
  --init | --reinit) # {{{
    [[ ! -z $2 ]] && logger_level="$(logger --set-level $2)"
    [[ ! -z $3 ]] && logger_name="$3"
    [[ $logger_level -ge 5 ]] && set -xv
    return 0
    ;; # }}}
  --end) # {{{
    return 0;; # }}}
  --set-level) # {{{
    case $2 in
    [0-9])               echo "$2";;
    - | NONE)            echo "0";;
    E | ERR  | ERROR)    echo "1";;
    W | WARN | WARNING)  echo "2";;
    I | INFO)            echo "3";;
    D | DBG  | DEBUG)    echo "4";;
    T | TRACE)           echo "5";;
    *)                   return 1;;
    esac
    return 0;; # }}}
  esac # }}}
  [[ ${logger_level:-0} == 0 ]] && return 0
  local levels=(- ERR WARN INFO DBG TRACE) l="$(logger --set-level INFO)" v=
  v="$(logger --set-level "$1")" && l="$v" && shift
  if [[ $l -le $logger_level ]]; then
    [[ ! -z $logger_name ]] && printf "%s: " "$logger_name"
    printf "%-6s: %s\n" "${levels[$l]}" "$@"
  fi >>${logger_debug_out:-/dev/stderr}
  [[ $logger_level -ge 5 ]] && set -xv
  return 0
} # }}}
complete $COMPLETE_DEFAULT_PARAMS -F _completion_generic logger
timeMeasure() { # {{{
  local tNow="$(command date +"%s%N")"
  if [[ $1 == '@@' ]]; then # {{{
    case ${4:-$3} in
    --test) echo "-v 50 100 200";;
    --out)  echo "/dev/stderr /dev/stdout";;
    -v | --var \
      | -r | --reset | --end \
      | --add-unit | --round=* | -s \
      | --msg) echo "---";;
    -u) echo "s ms us ns";;
    *)  echo  "--test --get-time -v --var -r --reset --end --add-unit --round=0 --round=1 --round=3 --round=6 --round= --msg -s -u -p --plain --no-plain --out -0 --from-0 -0-abs --from-0-abs $(command date +%s%N) -?"
    esac
    return 0
  fi # }}}
  local t0= tLast= unit=s round= addUnit=false msg= silent=${LOGGER_TIME_SILENT} d= plain= out='/dev/stderr' from0Abs=false from0=false
  local LC_NUMERIC=
  local tLastVariable=${LOGGER_TIME_VARIABLE:-time-measure-var}
  if [[ $1 == '--test' ]]; then # {{{
    shift
    local i= cnt=100 testOverhead= testOverhead_diff= testTmp= testTmp_diff= verify=false
    while [[ ! -z $1 ]] || false; do
      case $1 in
      -v) verify=true;;
      *)  cnt=$1;;
      esac; shift
    done
    [[ ! -z $2 ]] && cnt=$2
    [[ $3 == '-v' ]] && verify=true
    LOGGER_TIME_OVERHEAD=
    timeMeasure -v testOverhead
    for ((i=0; i<$cnt; i++)); do # {{{
      timeMeasure -v testTmp
    done &>/dev/null # }}}
    timeMeasure -v testOverhead -u ns -s
    export LOGGER_TIME_OVERHEAD="$(calc -qp "round($testOverhead_diff*0.70/$cnt)")"
    if $verify; then # {{{
      echo "# Without verify:" >/dev/stderr
      echo "export LOGGER_TIME_OVERHEAD=$LOGGER_TIME_OVERHEAD # ns" >/dev/stderr
      echo >/dev/stderr
      local j= sleepTime= sleepTime_diff=
      for ((j=1; j<=5; j++)); do # {{{
        echo "Adjusting #$j..." >/dev/stderr
        local min=0 minAbove1=0
        for ((i=0; i<10; i++)); do # {{{
          timeMeasure -v sleepTime -r; sleep 1; timeMeasure -v sleepTime -u ns -s
          [[ $sleepTime_diff -lt 1000000000 && ( $min == 0       || $sleepTime_diff -lt $min       ) ]] && min=$sleepTime_diff
          [[ $sleepTime_diff -gt 1000000000 && ( $minAbove1 == 0 || $sleepTime_diff -lt $minAbove1 ) ]] && minAbove1=$sleepTime_diff
        done # }}}
        if [[ $min -gt 0 ]]; then # {{{
          min="$(calc -qp -- "(10^9-$min)")"
          min=$(calc -qp -- "round(1.2*$min)")
          echo "Adjusting overhead by ${min}ns" >/dev/stderr
          export LOGGER_TIME_OVERHEAD="$(calc -qp -- "$LOGGER_TIME_OVERHEAD-($min)")"
        elif [[ $minAbove1 -gt 0 ]]; then
          minAbove1="$(calc -qp -- "($minAbove1-10^9)")"
          echo "Adjusting(2) overhead by -${minAbove1}ns" >/dev/stderr
          export LOGGER_TIME_OVERHEAD="$(calc -qp -- "$LOGGER_TIME_OVERHEAD+($minAbove1)")"
        fi # }}}
      done # }}}
      for ((i=0; i<10; i++)); do # {{{
        timeMeasure -v sleepTime -r; sleep 1; timeMeasure -v sleepTime -u ns
      done # }}}
    fi # }}}
    echo "export LOGGER_TIME_OVERHEAD=$LOGGER_TIME_OVERHEAD # ns"
    return 0
  fi # }}}
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -v | --var) # {{{
      export LOGGER_TIME_VARIABLE="$2"
      tLastVariable=$LOGGER_TIME_VARIABLE
      shift;; # }}}
    -r | --reset) # {{{
      tName="$LOGGER_TIME_PREFIX${tLastVariable//-/_}"
      local -n ns_last=${tName}_ns_last ns_0=${tName}_ns_0 diff_s_last=${tName}_diff_s_last diff_s_0=${tName}_diff_s_0 accu_0=${tName}_accu_0
      ns_last= ns_0= diff_s_last= diff_s_0= accu_0=;; # }}}
    --end) # {{{
      tName="$LOGGER_TIME_PREFIX${tLastVariable//-/_}"
      unset LOGGER_TIME_VARIABLE ${tName}_ns_last ${tName}_ns_0 ${tName}_diff_s_last ${tName}_diff_s_0 ${tName}_accu_0
      return 0;; # }}}
    -\?) # {{{
      tName="$LOGGER_TIME_PREFIX${tLastVariable//-/_}"
      echo "LOGGER_TIME_VARIABLE=$LOGGER_TIME_VARIABLE"
      vGet --all $tName
      return 0;; # }}}
    --add-unit)   addUnit=true;;
    --round=*)    round=${1#--round=};;
    --msg)        msg="$2"; silent=false; shift;;
    --out)        out=$2; shift;;
    -p | --plain) plain=true;;
    --no-plain)   plain=false;;
    -s)           silent=true;;
    -u)           unit="$2"; shift;;
    --get-time)   echo "$tNow"; return 0;;
    -0-abs | --from-0-abs) from0Abs=true;; # does not change counters
    -0     | --from-0)     from0=true;;    # does not change counters
    [0-9]*)       tLast="$1"; t0="$1";;
    esac; shift
  done # }}}
  tName="$LOGGER_TIME_PREFIX${tLastVariable//-/_}"
  local -n ns_last=${tName}_ns_last ns_0=${tName}_ns_0 diff_s_last=${tName}_diff_s_last diff_s_0=${tName}_diff_s_0 accu_0=${tName}_accu_0
  [[ -z $tLast ]] && tLast=$ns_last
  t0=$ns_0
  if [[ -z $tLast ]]; then # First run: just collect time # {{{
    ns_last="$(command date +"%s%N")"
    ns_0=$ns_last
    accu_0=0
    return 0
  fi # }}}
  local tDiffLast=$(calc -qp -- "($tNow - $tLast - (${LOGGER_TIME_OVERHEAD:-0}))")
  local tDiff0=$(   calc -qp -- "($tNow - $t0    - (${LOGGER_TIME_OVERHEAD:-0}))")
  [[ $tDiffLast == -* ]] && tDiffLast=$(calc -qp -- "($tNow - $tLast)")
  [[ $tDiff0    == -* ]] && tDiff0=$(   calc -qp -- "($tNow - $t0)")
  if ! ${silent:-false}; then # {{{
    local tDiff=$tDiffLast
    $from0Abs && tDiff=$tDiff0
    $from0    && tDiff=$accu_0
    case $unit in # {{{
    s)   d=9; unit=s;  [[ -z $round ]] && round=3;;
    ms)  d=6; unit=ms; [[ -z $round ]] && round=0;;
    us)  d=3; unit=us; [[ -z $round ]] && round=0;;
    ns)  d=0; unit=ns; [[ -z $round ]] && round=0;;
    *)   d=0; unit=ns; [[ -z $round ]] && round=0;;
    esac # }}}
    tDiff=$(calc -qp -- "($tDiff/(10^$d))")
    ! $addUnit && unit=
    LC_NUMERIC=en_US.UTF-8
    if [[ ! -t 1 ]]; then
      [[ -z $plain ]] && plain=true
    fi
    if ! ${plain:-false}; then
      printf "%s: %0.0${round}f%s\n" "${msg:-$tLastVariable}" "$tDiff" "$unit" >$out
    else
      printf "%0.0${round}f%s\n" "$tDiff" "$unit">$out
    fi
  fi # }}}
  if $from0 || $from0Abs; then return 0; fi
  diff_s_last=$(calc -qp -- "($tDiffLast / 1000000000)")
  diff_s_0=$(   calc -qp -- "($tDiff0    / 1000000000)")
  accu_0=$(     calc -qp -- "($accu_0    + $tDiffLast)")
  ns_last="$(command date +"%s%N")"
  return 0
} # }}}
complete $COMPLETE_DEFAULT_PARAMS -F _completion_generic timeMeasure

logger_level="$(logger --set-level "$logger_level")"

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case $1 in
  --log) # {{{
    shift; logger "$@";; # }}}
  --time) # {{{
    shift; timeMeasure "$@";; # }}}
  esac
fi

