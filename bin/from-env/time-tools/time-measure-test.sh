#!/usr/bin/env bash
# vim: fdl=0

i= cnt=100 verify=false
while [[ ! -z $1 ]]; do
  case $1 in
  -v) verify=true;;
  *)  cnt=$1;;
  esac; shift
done
TIME_MEASURE_OVERHEAD=
time-measure -v testOverhead -r
for ((i=0; i<$cnt; i++)); do # {{{
  time-measure -v testTmp
done &>/dev/null # }}}
diff=$(time-measure -v testOverhead -u ns --out /dev/stdout)
echoe "diff=[$diff]"
time-measure -v testTmp --end
time-measure -v testOverhead --end
v=$(bc -l <<< "$diff*0.70/$cnt")
printf -v v "%.0f" "$v"
echoe "v=[$v]"
export TIME_MEASURE_OVERHEAD="$v"
if $verify; then # {{{
  echo "# Without verify:" >&2
  echo "export TIME_MEASURE_OVERHEAD=$TIME_MEASURE_OVERHEAD # ns" >&2
  echo >&2
  j=
  for ((j=1; j<=5; j++)); do # {{{
    echo "Adjusting #$j..." >&2
    min=0 minAbove1=0 sleepTime_diff=
    for ((i=0; i<10; i++)); do # {{{
      time-measure -v sleepTime -r; sleep 1; sleepTime_diff=$(time-measure -v sleepTime -u ns --out /dev/stdout)
      (( sleepTime_diff < 1000000000 && ( min == 0 || sleepTime_diff < min ) )) && min=$sleepTime_diff
      (( sleepTime_diff > 1000000000 && ( minAbove1 == 0 || sleepTime_diff < minAbove1 ) )) && minAbove1=$sleepTime_diff
    done # }}}
    time-measure -v sleepTime --end
    if (( min < 0 )); then # {{{
      min=$((1000000000 - min))
      min=$(bc -l <<< "1.2 * $min")
      printf -v min "%.0f" "$min"
      echo "Adjusting(1) overhead by ${min}ns" >&2
      export TIME_MEASURE_OVERHEAD=$((TIME_MEASURE_OVERHEAD - min))
    elif (( minAbove1 > 0 )); then
      minAbove1=$((minAbove1 - 1000000000))
      echo "Adjusting(2) overhead by -${minAbove1}ns" >&2
      export TIME_MEASURE_OVERHEAD=$((TIME_MEASURE_OVERHEAD + minAbove1))
    fi # }}}
  done # }}}
fi # }}}
echo "export TIME_MEASURE_OVERHEAD=$TIME_MEASURE_OVERHEAD # ns" >&2
