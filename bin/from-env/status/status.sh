#!/usr/bin/env bash
# vim: fdl=0

_status() { # ring buffer a.k.a circular file # @@ # {{{
  local tmpPath=$TMP_MEM_PATH sharedPath=$SHARABLE_PATH/tmp i=
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -f) # {{{
      get-file-list 'status-*.txt'
      for i in $(echo ${!STATUS_*} | tr ' ' '\n' | grep '_FILE$'); do
        echo ${!i}
      done;; # }}}
    -n) # {{{
      echo "- -0 -1 3 5 10";; # }}}
    --percent)  # {{{
      30 50 70;; # }}}
    *) # {{{
      if [[ " $@ " == *" --shared "* ]]; then
        [[ -e $sharedPath ]] && get-file-list --pwd $sharedPath 'status-*.txt'
      else
        [[ -e $tmpPath ]] && get-file-list --pwd $tmpPath 'status-*.txt'
      fi | sed -e 's/^status-//' -e 's/\.txt//'
      echo "--shared -f -F -i --info - -n --new NAME --ts --ts-abs --ts-rel --no-ts --in --out --percent 30% --backup --backup=FILE"
      ;; # }}}
    esac
    return 0
  fi # }}}
  local shared=false new=false f=${STATUS_FILE} n= name= tsAdd=${STATUS_TS_ADD:-true} tsRel=${STATUS_TS_REL:-true} showFileName=false mode= percent= backup=false backupFile=
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --shared)    shared=true;;
    --new)       new=true;;
    --no-ts)     tsAdd=false;;
    --ts)        tsAdd=true;;
    --ts-abs)    tsAdd=true tsRel=false;;
    --ts-rel)    tsAdd=true tsRel=true;;
    --percent)   percent=$2; shift;;
    --backup)    backup=true;;
    --backup=*)  backup=true; backupFile="${1#--backup=}";;
    -f)          f=$2; shift;;
    -F)          showFileName=true;;
    -n)          n=$2; shift;;
    -i | --info) # {{{
      f=$INFO_FILE
      if [[ ! -t 0 ]]; then
        n= tsAdd=true tsRel=false
      elif [[ -t 1 ]]; then
        [[ -z $n ]] && n='-'
      else
        [[ -z $n ]] && n=1
      fi;; # }}}
    --in)        mode='in';;
    --out)       mode='out';;
    -)           f='/dev/stderr'; mode='in'; n=; tsRel=false;;
    [0-9]*%)     percent=${1%\%};;
    *)           [[ -e $1 || $1 == '/'* || $1 == './'* ]] && f=$1 || name=$1;;
    esac; shift
  done # }}}
  if [[ -z $f ]]; then # {{{
    $shared && f=$sharedPath || f=$tmpPath
    mkdir -p $f
    f+="/status-${name:-$$}.txt"
  fi # }}}
  if $showFileName; then # {{{
    echo $f
    return 0
  fi # }}}
  if [[ -z $mode ]]; then # {{{
    if [[ ! -t 0 ]]; then
      mode='in'
    else
      [[ ! -t 1 ]] && return 1
      mode='out'
    fi
  fi # }}}
  if $new; then # {{{
    rm -f $f
    touch $f
    [[ $mode == 'out' ]] && return 0
  fi # }}}
  case $mode in
  'out') # {{{
    if [[ $n == '-'* ]]; then
      [[ -z $name ]] && name="$(basename $f)" && name="${name%.*}"
      [[ -t 1 ]] && set-title "status: $name"
      tail -F -q $([[ $n != '-' ]] && echo "-n ${n#-}") $f 2>/dev/null
    elif [[ ! -e $f ]]; then
      return 1
    else
      tail -n${n:-1} $f
    fi;; # }}}
  'in') # {{{
    [[ -t 0 ]] && return 1
    local l=
    (
      [[ -e $f ]] || touch $f
      linesF=0; linesF=$(cat $f | wc -l)
      while IFS= read -r l; do
        [[ -z $l ]] && break
        if [[ ! -z $n ]]; then # {{{
          local lines="1"
          [[ $lines -gt $n ]] && n=$lines
          if [[ $((linesF+lines)) -gt $n ]] && type ed >/dev/null 2>&1; then # {{{
            local linesToRemove=$((linesF+lines-n))
            if [[ ! -z $percent ]]; then
              linesToRemove="$(echo "$linesF ${percent%\%}" | awk '{print $1*$2/100}')"
              $backup && cp $f ${backupFile:-$f.bak}
            fi
            ed $f >/dev/null <<-EOF
								1,${linesToRemove}d
								wq
						EOF
            linesF=$((linesF - linesToRemove))
          fi # }}}
        fi # }}}
        if $tsAdd; then # {{{
          if $tsRel; then
            local ts=
            [[ -e "$f" ]] && ts="$(file-stat -r "$f")"
            if [[ -z $ts ]]; then
              ts=$(date +$TIME_FMT)
              echo "$ts: $l"
            else
              printf "%8s: %s\n" "$ts" "$l"
            fi
          else
            echo "$(date +$TIME_FMT): $l"
          fi # }}}
        else # {{{
          echo "$l" # }}}
        fi >>$f
        linesF=$((linesF + 1))
      done < <(cat -)
    ) ;; # }}}
  esac
  return 0
} # }}}
_status "$@"

