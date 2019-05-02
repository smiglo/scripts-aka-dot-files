#!/bin/bash
# vim: fdl=0

# ----------------------------
# Env configuration
# ----------------------------
# KEEP_PASS_JOURNAL
# KEEP_PASS_KEYS
# KEEP_PASS_KEY_
# KEEP_PASS_DICT
# KEEP_PASS_PARAMS
# KEEP_PASS_GEN_PARAMS
# KEEP_PASS_GET_PARAMS
# ----------------------------

if [[ $1 == '--complete' ]]; then # {{{
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo "Must be sourced (source $0 --complete)" >/dev/stderr && exit 1
  __complete_keep_pass() { # {{{
    local cur=${COMP_WORDS[COMP_CWORD]} opts= first="${COMP_WORDS[1]}"
    [[ $COMP_CWORD == 1 ]] && first=
    case ${COMP_WORDS[COMP_CWORD-1]} in
    --cnt) # {{{
      opts+=" $(echo {1..10})";; # }}}
    --journal) # {{{
      ;; # }}}
    --key) # {{{
      local journalFiles="$KEEP_PASS_JOURNALS" f=
      [[ -z $journalFiles ]] && journalFiles="$KEEP_PASS_JOURNAL"
      [[ -e "$PWD/keep-pass.journal" && " $journalFiles " != *\ "$PWD/keep-pass.journal"\ * ]] && journalFiles+=" $PWD/keep-pass.journal"
      for f in $journalFiles; do
        [[ -e "$f" ]] && opts+=" $(sed -e '/^#/ d' -e '/^$/ d' -e 's/\(^[^:]*\).*:\s\+.*/\1/' "$f")"
      done;; # }}}
    --save) # {{{
      ;; # }}}
    *) # {{{
      case $first in
      --gen) # {{{
        opts+=" --cnt --upper --special --digit --no-sp --upper-first --save --update --padding --no-padding --plain"
        opts+=" --in --in="
        opts+=" --pass --pass= --no-pass";; # }}}
      --get | '') # {{{
        opts+=" --pass --pass= --key --seq --no-intr" ;;& # }}}
      --list-keys) # {{{
        opts+=" --all";& # }}}
      --list-all-keys) # {{{
        opts+=" -d -dd";; # }}}
      '') # {{{
        opts+=" -v -vv -vvv --journal"
        opts+=" --gen --get --has-key --list-keys --list-all-keys";; # }}}
      esac;; # }}}
    esac
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
  } # }}}
  cmd="${BASH_SOURCE[0]}" && cmd="${cmd##*/}"
  complete $COMPLETE_DEFAULT_PARAMS -F __complete_keep_pass "$cmd"
  unset cmd
  return 0
fi # }}}

LC_ALL=C
dictFile="${KEEP_PASS_DICT:-$(dirname "$(readlink -f "$0")")/keep-pass.dict}"
journalMainFile=
[[ ! -e "$dictFile" ]] && echo "Dictionary file not found ($dictFile)" >/dev/stderr && exit 1
end="65433"
letters=(11111 13161 15553 22241 23664 25136 26515 32225 33466 34323 35143 35561 41351 43251 44146 44611 46624 51223 52513 56326 62265 62533 63334 64532 64626 65255)
# info:      a     b     c     d     e     f     g     h     i     j     k     l     m     n     o     p     q     r     s     t     u     v     w     x     y     z
digits=(65434 65435 65436 65441 65442 65443 65444 65445 65446 65451)
# info:     0     1     2     3     4     5     6     7     8     9
specials=(66563 66564 66565 66566 66611 66612 66613 66614 66615 66616 66621 66622 66623 66624 66625 66626 66631 66632 66634 66635 66641 66643 66645 66646 66652 66653 66655 66656 66661 66662 66663 66664 66666)
# info  : space     `     ~     ^     _     {     }     [     ]     \     |     '     <     >     ,     .     /    !     "     #     $     %     &     (     )     *     +     -     :     ;     =     ?     @
verbose=0
if [[ ! -z "$KEEP_PASS_KEYS" ]]; then # {{{
  if [[ -e "$KEEP_PASS_KEYS" ]]; then
    source "$KEEP_PASS_KEYS"
  elif [[ "$KEEP_PASS_KEYS" != /* || "$KEEP_PASS_KEYS" == //* ]]; then
    source <(eval "$KEEP_PASS_KEYS")
  fi
fi # }}}

getJournals() { # {{{
  [[ ! -z $journalMainFile ]] && echo "$journalMainFile" && return 0
  local journalFiles="$KEEP_PASS_JOURNALS"
  [[ -z $journalFiles ]] && journalFiles="$KEEP_PASS_JOURNAL"
  [[ -e "$PWD/keep-pass.journal" && " $journalFiles " != *\ "$PWD/keep-pass.journal"\ * ]] && journalFiles="$PWD/keep-pass.journal $journalFiles"
  echo "$journalFiles"
} # }}}
getRand() { # {{{
  echo "$(($1 + $RANDOM % ($2-$1+1)))"
}
testRand() { # {{{
  for ((i=0; i<${3:-10}; i++)); do
    echo "$(getRand $1 $2)"
  done
} # }}}
# }}}
genWordSeq() { # {{{
  local i= r=
  while [[ -z $r || $r -gt $end ]]; do
    r=
    for ((i=0; i<5; i++)); do
      r+="$(getRand 1 6)"
    done
  done
  echo "$r"
} # }}}
genDigitSeq() { # {{{
  local i="$(getRand 1 ${#digits[@]})"
  echo "${digits[$(($i-1))]}"
} # }}}
genSpecialSeq() { # {{{
  local i="$(getRand 1 ${#specials[@]})"
  echo "${specials[$(($i-1))]}"
}
testSeq() { # {{{
  [[ -z $1 ]] && return 1
  for ((i=0; i<${2:-10}; i++)); do
    local seq="$($1)"
    echo "$seq: $(getWord $seq)"
  done
} # }}}
# }}}
getWord() { # {{{
  [[ $1 == 66563 ]] && echo " " && return 0
  awk '/^'$1'\s/ {print $2}' "$dictFile"
} # }}}
getWordValue() { # {{{
  local v="${1,,}"
  case $v in
    . | \? | / | [ | ] | \\ | \| | ^ | \( | \) | $ | +)
    v="\\$v";;
  esac
  awk '/\s'$v'$/ {print $1}' "$dictFile"
} # }}}
encode() { # {{{
  local src= ret= i=0 v= d= decode=false
  [[ $1 == '-d' ]] && decode=true && shift
  src="$1"
  if $decode; then # {{{
    for ((i=0; i<${#src}; i++)); do
      v="${src:$i:1}"
      case $v in
      [A-Z]) d="$(($(printf "%d" "'$v")+10-0x41))";;
      [a-z]) d="$(($(printf "%d" "'$v")+36-0x61))";;
      *)     d="$v";;
      esac
      ret+="$d"
    done
    # }}}
  else # {{{
    while [[ $i -lt ${#src} ]]; do
      v="${src:$i:2}"
      if [[ $v =~ ^[0-9]{2}$ && ${v#0} -gt 9 && ${v#0} -le 61 ]]; then
        if [[ $v -le 35 ]]; then
          d="$(echo -e "\u00$(printf "%x" $((0x41+$v-10)))")"
        else
          d="$(echo -e "\u00$(printf "%x" $((0x61+$v-36)))")"
        fi
        i="$(($i+2))"
      else
        d="${src:$i:1}"
        i="$(($i+1))"
      fi
      ret+="$d"
    done
  fi # }}}
  echo "$ret"
} # }}}
encrypt() { # {{{
  local src= ret= decrypt=false pass= params= interactive=
  [[ $1 == '-d' ]] && decrypt=true && shift
  src="$1" pass="$2" interactive="${3:-true}"
  params="enc -aes-256-cbc -salt -a -A"
  if [[ ! -z $pass ]]; then
    if $decrypt && [[ $pass == @* ]]; then
      local mkey="$KEEP_PASS_MASTER_KEY"
      if [[ -z $mkey ]]; then
        $interactive || { echo '---'; return 0; }
        read -r -s -p "Enter Master Key: " mkey && echo
        [[ -z $mkey ]] && return 1
      fi
      pass="$(echo "${pass:1}" | eval openssl $params -d -pass pass:'$mkey' 2>/dev/null)" || return 1
    fi
    params+=" -pass pass:'$pass'"
  elif ! $interactive; then
    echo '---'
    return 0
  fi
  $decrypt && params+=" -d" || params+=" -e"
  ret="$(echo "$src" | eval openssl $params 2>/dev/null)" || return 1
  echo "$ret"
} # }}}
getPass() { # {{{
  local i= w= oldIFS="$IFS" phrase= \
    seq= upper= spaces= upper_first= IFS="$IFS" use_pass=false pass= padding= do_encode=true interactive=true
  set -- $KEEP_PASS_GET_PARAMS "$@"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --key)     phrase="$2"; shift;;
    --seq)     seq="$2"; shift;;
    --pass=*)  pass="${1#--pass=}";&
    --pass)    use_pass=true;;
    --no-intr) interactive=false;;
    *)         phrase="$1";;
    esac
    shift
  done # }}}
  if [[ ! -z $phrase ]]; then # {{{
    local f= line=
    for f in $(getJournals); do
      [[ ! -e $f ]] && continue
      line="$(command grep "^$phrase\(:.*\)\{0,1\}:\s\+" "$f" | head -n1)"
      [[ ! -z $line ]] && break
    done
    seq="$(echo "$line" | sed 's/.*:\s\+//')"
    [[ -z $seq ]] && return 1
    if [[ ${seq:0:1} == '*' && -z $pass ]]; then
      local passV="$(echo "$line" | sed 's/\(.*\):\s\+.*$/\1/')"
      passV="${passV#*:}"
      passV="KEEP_PASS_KEY_${passV^^}"
      passV="${passV//-/_}"
      pass="${!passV}"
    fi
  fi # }}}
  [[ ${seq:0:1} == '*' ]] && use_pass=true && seq="${seq:1}"
  if $use_pass; then # {{{
    seq="$(encrypt -d "$seq" "$pass" "$interactive")"
    [[ $? != 0 || -z $seq ]] && echo "Error during encryption" >/dev/stderr && return 1
    [[ $verbose -ge 1 ]] && echo "$seq"
    [[ $seq == '---' ]] && echo "$seq" && return 0
  fi # }}}
  [[ ${seq:0:1} != '+' ]] && seq="$(encode -d "$seq")" || { seq="${seq:1}"; do_encode=false; }
  [[ $verbose -ge 2 ]] && echo "$seq"
  IFS=":" read -r seq upper spaces upper_first padding <<< "$seq"
  IFS="$oldIFS"
  [[ -z $seq ]] && return 0
  if $do_encode; then # {{{
    seq="$(echo "${seq// }" | sed 's/.\{5\}/& /g')"
    [[ $spaces == 1 ]] && spaces=true || spaces=false
    [[ $upper_first == 1 ]] && upper_first=true || upper_first=false
    ! $spaces && words='-'
    for i in $seq; do # {{{
      w="$(getWord "$i")"
      [[ $verbose -ge 3 ]] && echo "$i: [$w]"
      $upper_first && w="$(echo "$w" | sed 's/\(.\)\(.*\)/\U\1\L\2/')"
      $spaces && words+=" "
      words+="$w"
    done # }}}
    words="${words:1}"
    if [[ ! -z $upper ]]; then # {{{
      for upper in ${upper//,/ }; do
        upper="$(($upper%${#words}))"
        local f= i= t= first=$upper
        f="${words::$upper}"
        i="${words:$upper:1}"
        while [[ ! $i =~ [a-z] ]]; do
          f+="$i"
          upper="$(($upper+1))"
          [[ $upper == $first ]] && break
          [[ $upper == ${#words} ]] && f= && upper=0
          i="${words:$upper:1}"
        done
        t="${words:$(($upper+1))}"
        words="${f}${i^^}${t}"
      done
    fi # }}}
    # }}}
  else # {{{
    words="$seq"
  fi # }}}
  echo "$words"
} # }}}
genPass() { # {{{
  local cnt=4 i= v= seq= words= pass= params= input= info= \
    upper=false special=false digit=false spaces=true upper_first=false use_pass=false read_input=false \
    save=false add_padding=true do_encode=true update=false check=
  set -- $KEEP_PASS_GEN_PARAMS "$@"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --cnt)         cnt="$2"; shift;;
    --upper)       upper=true;;
    --special)     special=true;;
    --digit)       digit=true;;
    --no-sp)       spaces=false;;
    --upper-first) upper_first=true;;
    --pass=*)      pass="${1#--pass=}";&
    --pass)        use_pass=true;;
    --no-pass)     use_pass=false;;
    --in=*)        input="${1#--in=}";&
    --in)          read_input=true; spaces=false;;
    --update)      update=true;&
    --save)        save=true; info="$2"; pass=true; shift;;
    --no-padding)  add_padding=false;;
    --padding)     add_padding=true;;
    --plain)       do_encode=false; add_padding=false; spaces=false; seq="$2"; shift;;
    *)             seq="$1";;
    esac
    shift
  done # }}}
  if $read_input; then # {{{
    [[ -z $input ]] && read -r -p 'Enter input: ' input
    seq=
    local uppers= vv= j= k=
    i=0
    while [[ $i -lt ${#input} ]]; do
      v="${input:$i:1}"
      vv="$(printf "%d" "'$v")"
      case $v in
      [a-z] | [A-Z]) # {{{
        j="$i"
        while [[ $j -lt ${#input} ]]; do # {{{
          case ${input:$j:1} in
            [A-Z]) uppers+=",$(($j + $(getRand 0 3)*${#input}))";;
            [a-z]) ;;
            *)     break;;
          esac
          j="$(($j+1))"
        done # }}}
        while [[ $i -lt $j ]]; do # {{{
          k="$j"
          while [[ $k -gt $i ]]; do
            vv="$(getWordValue ${input:$i:$k-$i})"
            [[ ! -z $vv ]] && seq+="$vv" && break
            k="$(($k-1))"
          done
          [[ $verbose -ge 3 ]] && echo "${input:$i:$k-$i}: [$vv]"
          i="$k"
        done # }}}
        ;; # }}}
      [0-9]) # {{{
        v="$(($vv-0x30))"
        v="${digits[$v]}"
        seq+="$v"
        i="$(($i+1))" ;; # }}}
      *) # {{{
        v="${v//\*/\\*}" v="${v//\?/\\?}"
        v="$(getWordValue "$v")"
        seq+="$v"
        i="$(($i+1))";; # }}}
      esac
    done
    seq+=":"
    seq+="${uppers:1}"
    seq+=":"
    seq+=":"
    if $add_padding; then # {{{
      seq+=":"
      for ((i=0; i<5+$(getRand 1 6); i++)); do
        seq+="$(getRand 10 287)"
      done
    fi # }}}
  fi # }}}
  if [[ -z $seq ]]; then # {{{
    $special && cnt="$(($cnt+1))" && special="$(getRand 0 $(($cnt-1)))"
    if $digit; then # {{{
      cnt="$(($cnt+1))"
      digit="$(getRand 0 $(($cnt-1)))"
      [[ $digit == $special ]] && digit="$((($special+$(getRand 1 $(($cnt-1))))%$cnt))"
    fi # }}}
    for ((i=0; i<$cnt; i++)); do # {{{
      if [[ $i == $special ]]; then
        seq+="$(genSpecialSeq)"
      elif [[ $i == $digit ]]; then
        seq+="$(genDigitSeq)"
      else
        seq+="$(genWordSeq)"
      fi
    done # }}}
  fi # }}}
  if [[ $seq != *:* ]]; then # {{{
    seq+=":"
    $upper && seq+="$(getRand 0 $(($cnt*6)))"
    seq+=":"
    $spaces && seq+="1"
    seq+=":"
    $upper_first && seq+="1"
    if $add_padding; then # {{{
      seq+=":"
      for ((i=0; i<5+$(getRand 1 6); i++)); do
        seq+="$(getRand 10 287)"
      done
    fi # }}}
  fi # }}}
  [[ $verbose -ge 2 ]] && echo "$(basename "$0") --seq $seq"
  $do_encode && seq="$(encode "$seq")" || seq="+$seq"
  if $use_pass; then # {{{
    [[ $verbose -ge 2 ]] && echo "$(basename "$0") --seq $seq"
    if [[ -z $pass && $info == *:* ]]; then # {{{
      local passV="$(echo "$info" | sed 's/\(.*\):\s\+.*$/\1/')"
      passV="${passV#*:}"
      passV="KEEP_PASS_KEY_${passV^^}"
      pass="${!passV}"
    fi # }}}
    while [[ -z $pass ]]; do # {{{
      read -r -s -p "Enter pass: " pass && echo
      [[ ! -z $pass ]] && break
      read -p 'No pass specified, proceed without encryption [y/n] ? ' i
      case ${i,,} in
      y) break;;
      esac
    done # }}}
    if [[ ! -z $pass ]]; then # {{{
      seq="*$(encrypt "$seq" "$pass")"
      params="--pass=$pass"
    fi # }}}
  fi # }}}
  [[ $verbose -ge 1 ]] && echo -e "$(basename "$0") ${params:-\b} --seq $seq" || echo "$seq"
  if $save; then # {{{
    [[ -z $info ]] && info="$(command date +"%Y%m%d-%H%M%S")"
    local entry="${info// /-}:" journalFile="$KEEP_PASS_JOURNAL"
    if [[ ! -z $journalMainFile ]]; then
      journalFile="$journalMainFile"
    elif [[ -e "$PWD/keep-pass.journal" ]]; then
      journalFile="$PWD/keep-pass.journal"
    fi
    [[ -z $journalFile ]] && echo "Journal file not found" >/dev/stderr && return 1
    while [[ ${#entry} -lt 18 ]]; do entry+=' '; done
    entry+="\t"
    entry+="$seq"
    if $update; then
      sed -i -e "/^${entry%%:*}\(:.*\)\{0,1\}:\s\+.*/ d" "$journalFile"
    elif hasKey "${entry%%:*}"; then
      echo "The key '${entry%%:*}' already exists"
    fi
    echo -e "$entry" >> "$journalFile"
  fi # }}}
  check="$(getPass $params --seq $seq)"
  [[ $verbose -ge 1 ]] && echo "$check"
  check="$(echo "$check" | tail -n1)"
  if [[ "$check" != "$input" && ! -z $input ]]; then
   echo "Decrypted phrase does not match input"
   echo "Input  : $input"
   echo "Phrase : $check"
   return 1
 fi
} # }}}
hasKey() { # {{{
  local f=
  for f in $(getJournals); do
    [[ -e $f ]] && command grep -q "^$1\(:.*\)\{0,1\}:\s\+" "$f" && return 0
  done
  return 1
} # }}}
listKeys() { # {{{
  local f= i= d= files="$KEEP_PASS_JOURNAL" all=false details=0
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --all) all=true;;
    -d)    details=1;;
    -dd)   details=2;;
    esac
    shift
  done # }}}
  if $all; then # {{{
    files="$(getJournals)"
  elif [[ ! -z $journalMainFile ]]; then
    files="$journalMainFile"
  elif [[ -e "$PWD/keep-pass.journal" ]]; then
    files="$PWD/keep-pass.journal"
  fi # }}}
  for f in $files; do # {{{
    [[ -e "$f" ]] || continue
    if [[ $details -gt 0 ]]; then # {{{
      d="$(dirname "$f")"
      d="${d/$HOME/\~}"
      [[ $details == 1 ]] && d="${d##*/}"
    fi # }}}
    for i in $(sed -e '/^#/ d' -e '/^$/ d' -e 's/\(^[^:]*\).*:\s\+.*/\1/' "$f"); do # {{{
      if [[ $details == 2 ]]; then
        printf "%-60s : %s\n" "$d/${f##*/}" "$i"
      elif [[ $details == 1 ]]; then
        printf "%-35s : %s\n" "$d/${f##*/}" "$i"
      else
        echo "$i"
      fi
    done # }}}
  done | sort -u # }}}
} # }}}
set -- $KEEP_PASS_PARAMS "$@"
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -v)        verbose=1;;
  -vv)       verbose=2;;
  -vvv)      verbose=3;;
  --journal) journalMainFile="$2"; shift;;
  *)         break;;
  esac
  shift
done # }}}
case $1 in
--get)             shift; getPass "$@";;
--gen)             shift; genPass "$@";;
--has-key)         shift; hasKey "$1";;
--list-keys)       shift; listKeys $@;;
--list-all-keys)   shift; listKeys --all $@;;
--test)            shift; $@;;
*)                 getPass "$@";;
esac

