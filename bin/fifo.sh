#!/usr/bin/env bash
# vim: fdl=0

mode=
fifo=
loop=false
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --init) mode="init";;
  --put)  mode="put";;
  --get)  mode="get";;
  -f)     fifo="$2"; shift;;
  --clean) mode="clean";;
  --loop)  loop=true;;
  esac; shift
done # }}}

if [[ -z $mode ]]; then # {{{
  [[ ! -t 0 ]] && mode="put" || mode="get"
fi # }}}
if [[ -z $fifo ]]; then # {{{
  case $mode in
  get | clean) die "pipe is missing";;
  esac
  fifo="$MEM_KEEP/fifo.$PPID"
  echo $fifo
fi # }}}
if [[ ! -p $fifo ]]; then # {{{
  case $mode in
  put | get) die "no fifo found: $fifo";;
  clean) exit 0;;
  esac
fi # }}}
if $loop; then # {{{
  case $mode in
  put) die "no loop mode in 'put'";;
  get) mode="get-while";;
  esac
fi # }}}
case $mode in
init) # {{{
  if [[ -e $fifo ]]; then
    [[ -p $fifo ]] || die "not a fifo: $fifo"
  else
    mkfifo $fifo
  fi
  ;; # }}}
put) # {{{
  /bin/cat - >$fifo
  ;; # }}}
put-while) # {{{
  while true; do
    /bin/cat - >$fifo
  done
  ;; # }}}
get) # {{{
  /bin/cat $fifo
  ;; # }}}
get-while)
  tail --pid=$PPID -F $fifo
  ;; # }}}
clean) # {{{
  rm -rf $fifo
  ;; # }}}
esac

