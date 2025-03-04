#!/usr/bin/env bash
# vim: fdl=0

_time-measure-test() { # {{{
  local i= cnt=100 verify=false
  while [[ ! -z $1 ]] || false; do
    case $1 in
    -v) verify=true;;
    *)  cnt=$1;;
    esac; shift
  done
  [[ ! -z $2 ]] && cnt=$2
  [[ $3 == '-v' ]] && verify=true
  TIME_MEASURE_OVERHEAD=
  time-measure -v testOverhead -r
  for ((i=0; i<$cnt; i++)); do # {{{
    time-measure -v testTmp
  done &>/dev/null # }}}
  local diff=$(time-measure -v testOverhead -u ns --out /dev/stdout)
  time-measure -v testTmp --end
  time-measure -v testOverhead --end
  export TIME_MEASURE_OVERHEAD="$(calc -qp "round($diff*0.70/$cnt)")"
  if $verify; then # {{{
    echo "# Without verify:" >/dev/stderr
    echo "export TIME_MEASURE_OVERHEAD=$TIME_MEASURE_OVERHEAD # ns" >/dev/stderr
    echo >/dev/stderr
    local j=
    for ((j=1; j<=5; j++)); do # {{{
      echo "Adjusting #$j..." >/dev/stderr
      local min=0 minAbove1=0 sleepTime_diff=
      for ((i=0; i<10; i++)); do # {{{
        time-measure -v sleepTime -r; sleep 1; sleepTime_diff=$(time-measure -v sleepTime -u ns --out /dev/stdout)
        [[ $sleepTime_diff -lt 1000000000 && ( $min == 0       || $sleepTime_diff -lt $min       ) ]] && min=$sleepTime_diff
        [[ $sleepTime_diff -gt 1000000000 && ( $minAbove1 == 0 || $sleepTime_diff -lt $minAbove1 ) ]] && minAbove1=$sleepTime_diff
      done # }}}
      if [[ $min -gt 0 ]]; then # {{{
        min="$(calc -qp -- "(10^9-$min)")"
        min=$(calc -qp -- "round(1.2*$min)")
        echo "Adjusting overhead by ${min}ns" >/dev/stderr
        export TIME_MEASURE_OVERHEAD="$(calc -qp -- "$TIME_MEASURE_OVERHEAD-($min)")"
      elif [[ $minAbove1 -gt 0 ]]; then
        minAbove1="$(calc -qp -- "($minAbove1-10^9)")"
        echo "Adjusting(2) overhead by -${minAbove1}ns" >/dev/stderr
        export TIME_MEASURE_OVERHEAD="$(calc -qp -- "$TIME_MEASURE_OVERHEAD+($minAbove1)")"
      fi # }}}
    done # }}}
    for ((i=0; i<10; i++)); do # {{{
      time-measure -v sleepTime -r; sleep 1; time-measure -v sleepTime -u ns
    done # }}}
    time-measure -v sleepTime --end
  fi # }}}
  echo "export TIME_MEASURE_OVERHEAD=$TIME_MEASURE_OVERHEAD # ns" >/dev/stderr
  return 0
} # }}}
_time-measure-test "$@"

