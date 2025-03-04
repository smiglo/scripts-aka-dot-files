declare -F | while read t t c; do
  which $c >/dev/null 2>&1 && echo $c
done  >list-f.tmp
alias | while read t c t; do
  c=${c%%=*}
  which $c >/dev/null 2>&1 && echo $c
done >list-a.tmp
declare -F | while read t t c; do
  type $c | tail -n+1 | sed 's/^/'"$c"'::/'
done >list-all-f.tmp
for i in $(cat list-f.tmp) $(cat list-a.tmp); do
  [[ -z $i || $i == _* ]] && continue
  echo "--> $i"
  command grep ":: \+.*\<$i\>" list-all-f.tmp | grep -v -e "-$i\|command $i"
done

