#!/usr/bin/env bash
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
    local cur=${COMP_WORDS[COMP_CWORD]} opts= first="${COMP_WORDS[1]}" i=2
    if [[ -z $KEEP_PASS_JOURNAL_SHARED && ! -z $SHARED_BASH_PATH && -e "$SHARED_BASH_PATH/keep-pass.journal" ]]; then
      local KEEP_PASS_JOURNAL_SHARED="$SHARED_BASH_PATH/keep-pass.journal"
    fi
    if [[ -z $KEEP_PASS_JOURNAL ]]; then
      if [[ -e "$APPS_CFG_PATH/keep-pass/keep-pass.journal" || -z $KEEP_PASS_JOURNAL_SHARED ]]; then
        local KEEP_PASS_JOURNAL="$APPS_CFG_PATH/keep-pass/keep-pass.journal"
      fi
    fi
    while true; do
      case $first in
      -v | -vv | -vvv | --journal) first="${COMP_WORDS[i]}"; i=$((i+1));;
      *) break;;
      esac
    done
    [[ $COMP_CWORD == 1 ]] && first=
    case ${COMP_WORDS[COMP_CWORD-1]} in
    --cnt) # {{{
      opts+=" $(echo {1..10})";; # }}}
    --journal) # {{{
      local journalFiles="$KEEP_PASS_JOURNALS $KEEP_PASS_JOURNAL $KEEP_PASS_JOURNAL_SHARED"
      [[ -e "$PWD/keep-pass.journal" && " $journalFiles " != *\ "$PWD/keep-pass.journal"\ * ]] && journalFiles="$PWD/keep-pass.journal $journalFiles"
      opts="$journalFiles"
      ;; # }}}
    --key | --save) # {{{
      local journalFiles="$KEEP_PASS_JOURNALS $KEEP_PASS_JOURNAL $KEEP_PASS_JOURNAL_SHARED" f=
      [[ -e "$PWD/keep-pass.journal" && " $journalFiles " != *\ "$PWD/keep-pass.journal"\ * ]] && journalFiles+=" $PWD/keep-pass.journal"
      for f in $journalFiles; do
        [[ -e "$f" ]] || continue
        if [[ " ${COMP_WORDS[*]} " == *" --gen "* ]]; then
          opts+=" $(sed -e '/^#/ d' -e '/^$/ d' -e 's/\(^[^:]*.*\):\s\+.*/\1/' "$f")"
        else
          opts+=" $(sed -e '/^#/ d' -e '/^$/ d' -e 's/\(^[^:]*\).*:\s\+.*/\1/' "$f")"
        fi
      done;; # }}}
    -t) # {{{
      opts+="- 0 60 120";; # }}}
    -p | --parts) # {{{
      [[ $first == '--gen-ios-pass' ]] && opts+="2 3 4 5 10";; # }}}
    -l | --seg-len) # {{{
      [[ $first == '--gen-ios-pass' ]] && opts+="3 5 6 10";; # }}}
    *) # {{{
      case $first in
      --gen) # {{{
        opts+=" --cnt --upper --special --digit --no-sp --upper-first --save --key --update --padding --no-padding --plain --pass-save --no-pass-save"
        opts+=" --in --in= --seq --seq="
        opts+=" --pass --pass= --no-pass";; # }}}
      --get | '') # {{{
        opts+=" --pass --pass= --key --seq --no-intr" ;;& # }}}
      --list-keys) # {{{
        opts+=" --all";& # }}}
      --list-all-keys) # {{{
        opts+=" -d -dd";; # }}}
      --set-master-key) # {{{
        opts+=" -t";; # }}}
      --gen-ios-pass) # {{{
        opts+="-p --parts -l --seg-len";; # }}}
      *) # {{{
        opts+=" -v -vv -vvv --journal"
        opts+=" --gen --get --key --save --has-key --list-keys --list-all-keys --set-master-key --help --gen-ios-pass";; # }}}
      esac;; # }}}
    esac
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
  } # }}}
  cmd="${BASH_SOURCE[0]}" && cmd="${cmd##*/}"
  complete $COMPLETE_DEFAULT_PARAMS -F __complete_keep_pass "$cmd"
  unset cmd
  return 0
fi # }}}

dbg() { # {{{
  local p= l=
  [[ $1 == '-e' || $1 == '-n' ]] && p=$1 && shift
  l=$1; shift
  [[ -z $1 ]] && return 0
  echorm $p $l "DBG#$(printf '%02d' $l): $@"
  return 0
} # }}}
err() { # {{{
  echorm -F + "ERR: $@"
} # }}}
echorm --name keep-pass
LC_ALL=C
dictFile="${KEEP_PASS_DICT:-$(dirname "$(readlink -f "$0")")/keep-pass.dict}"
journalMainFile=
[[ ! -e "$dictFile" ]] && err "Dictionary file not found ($dictFile)" && exit 1
end="65433"
letters=(11111 13161 15553 22241 23664 25136 26515 32225 33466 34323 35143 35561 41351 43251 44146 44611 46624 51223 52513 56326 62265 62533 63334 64532 64626 65255)
# info:      a     b     c     d     e     f     g     h     i     j     k     l     m     n     o     p     q     r     s     t     u     v     w     x     y     z
digits=(65434 65435 65436 65441 65442 65443 65444 65445 65446 65451)
# info:     0     1     2     3     4     5     6     7     8     9
specials=(66563 66564 66565 66566 66611 66612 66613 66614 66615 66616 66621 66622 66623 66624 66625 66626 66631 66632 66634 66635 66641 66643 66645 66646 66652 66653 66655 66656 66661 66662 66663 66664 66666)
# info  : space     `     ~     ^     _     {     }     [     ]     \     |     '     <     >     ,     .     /    !     "     #     $     %     &     (     )     *     +     -     :     ;     =     ?     @
verbose=0
if [[ -z $KEEP_PASS_JOURNAL_SHARED && ! -z $SHARED_BASH_PATH && -e "$SHARED_BASH_PATH/keep-pass.journal" ]]; then
  export KEEP_PASS_JOURNAL_SHARED="$SHARED_BASH_PATH/keep-pass.journal"
else
  echorm 1 "No shared journal"
fi
if [[ -z $KEEP_PASS_JOURNAL ]]; then
  if [[ -e "$APPS_CFG_PATH/keep-pass/keep-pass.journal" || -z $KEEP_PASS_JOURNAL_SHARED ]]; then
    export KEEP_PASS_JOURNAL="$APPS_CFG_PATH/keep-pass/keep-pass.journal"
  else
    echorm 1 "No apps journal"
  fi
fi
[[ -z $KEEP_PASS_KEYS ]] && export KEEP_PASS_KEYS="$APPS_CFG_PATH/keep-pass/keep-pass.keys"
[[ -e $APPS_CFG_PATH/keep-pass ]] || command mkdir -p $APPS_CFG_PATH/keep-pass/
if [[ ! -z "$KEEP_PASS_KEYS" ]]; then # {{{
  if [[ -e "$KEEP_PASS_KEYS" ]]; then
    source "$KEEP_PASS_KEYS"
  elif [[ "$KEEP_PASS_KEYS" != /* || "$KEEP_PASS_KEYS" == //* ]]; then
    source <(eval "${KEEP_PASS_KEYS#//}")
  else
    echorm 1 "No keys"
  fi
fi # }}}

getJournals() { # {{{
  [[ ! -z $journalMainFile ]] && echo "$journalMainFile" && return 0
  local journalFiles="$KEEP_PASS_JOURNALS $KEEP_PASS_JOURNAL $KEEP_PASS_JOURNAL_SHARED"
  [[ -e "$PWD/keep-pass.journal" && " $journalFiles " != *\ "$PWD/keep-pass.journal"\ * ]] && journalFiles="$PWD/keep-pass.journal $journalFiles"
  echorv -M 1 journalFiles
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
  [[ $1 == ' ' ]] && echo "66563" && return 0
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
setMasterKey() { # {{{
  local mkey= timeout= tries=3
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -t) timeout="$2"; [[ $timeout == '-' || $timeout == '0' ]] && timeout=''; shift;;
    *)  mkey="$1";;
    esac
    shift
  done # }}}
  if [[ ! -z $KEEP_PASS_MASTER_KEY && $KEEP_PASS_MASTER_KEY != //*  ]]; then
    rm -f "$KEEP_PASS_MASTER_KEY"
  fi
  while [[ $tries -gt 0 ]]; do
    if [[ -z $mkey ]]; then
      if read $([[ ! -z $timeout ]] && echo "-t $timeout") -s -p "${CYellow}Enter master key:${COff} " mkey >/dev/stderr; then
        [[ -z $mkey ]] && echore && return 1
      fi
      echore
    fi
    if [[ ! -z $KEEP_PASS_MASTER_KEY_SALT ]]; then # {{{
      dbg 2 "Hashing master key: $mkey + $KEEP_PASS_MASTER_KEY_SALT"
      local python= i=
      for i in python{3,2,}; do which $i >/dev/null 2>&1 && python=$i && break; done
      [[ -z $python ]] && err "Python not installed" && return 1
      mkey="$(bash -c \
        "f() { \
          $python -c 'import bcrypt,sys; print(bcrypt.hashpw(sys.argv[1].encode(\"utf-8\"), sys.argv[2].encode(\"utf-8\")));' \"\$1\" \"\$2\"; \
        }; f '$mkey' '$KEEP_PASS_MASTER_KEY_SALT'" \
        | cut -c32-62 \
      )"
    else
      mkey="$(echo "$mkey" | sha1sum | cut -d' ' -f1)"
    fi # }}}
    if [[ ! -z $KEEP_PASS_MASTER_KEY_VERIFY ]] && ! encrypt -d "$KEEP_PASS_MASTER_KEY_VERIFY" "$mkey" >/dev/null 2>&1; then
      err "Key verification failed"
      tries=$((tries-1))
      [[ $tries == 0 ]] && return 1
      mkey=
      continue
    fi
    break
  done
  if [[ -z $KEEP_PASS_MASTER_KEY || $KEEP_PASS_MASTER_KEY == //*  ]]; then # {{{
    echo "export KEEP_PASS_MASTER_KEY=\"$mkey\""
    return 0
  fi # }}}
  echo -n "$mkey" >"$KEEP_PASS_MASTER_KEY"
  chmod 400 $KEEP_PASS_MASTER_KEY
  mkey="$(echo "$mkey" | sha1sum)"
  return 0
} # }}}
getMasterkey() { # {{{
  local mkey="$KEEP_PASS_MASTER_KEY" interactive="${1:-true}"
  if [[ ! -z $mkey && $mkey == /* && $mkey != //*  ]]; then
    [[ -e $mkey ]] && mkey="$(cat "$mkey")" || mkey=
  elif [[ $mkey == //* ]]; then
    mkey="${mkey:1}"
  fi
  [[ ! -z $mkey ]] && echo "$mkey" && return 0
  $interactive || return 1
  read -r -s -p "Enter Master Key: " mkey >/dev/stderr && echor
  [[ -z $mkey ]] && return 1
  if [[ ! -z $KEEP_PASS_MASTER_KEY_SALT ]]; then # {{{
    dbg 2 "Hashing master key: $mkey + $KEEP_PASS_MASTER_KEY_SALT"
    local python= i=
    for i in python{3,2,}; do which $i >/dev/null 2>&1 && python=$i && break; done
    [[ -z $python ]] && err "Python not installed" && return 1
    mkey="$(bash -c \
      "f() { \
        $python -c 'import bcrypt,sys; print(bcrypt.hashpw(sys.argv[1].encode(\"utf-8\"), sys.argv[2].encode(\"utf-8\")));' \"\$1\" \"\$2\"; \
      }; f '$mkey' '$KEEP_PASS_MASTER_KEY_SALT'" \
    )"
  else
    mkey="$(echo "$mkey" | sha1sum | cut -d' ' -f1)"
  fi # }}}
  echo "$mkey"
} # }}}
encrypt() { # {{{
  local src= ret= decrypt=false pass= params= interactive= err=0
  [[ $1 == '-d' ]] && decrypt=true && shift
  src="$1" pass="$2" interactive="${3:-true}"
  params="enc -aes-256-cbc -salt -a -A -md md5"
  if [[ ! -z $pass ]]; then
    if [[ $pass == @* ]]; then
      pass="${pass:1}"
      if [[ $pass != @* ]]; then
        local mkey="$(getMasterkey $interactive)"
        dbg 2 "Master key: $mkey"
        [[ -z $mkey ]] && ! $interactive && { echo '---'; return 0; }
        pass="$(echo "$pass" | eval openssl $params -d -pass pass:'$mkey' 2>/dev/null)" || return 1
        dbg 2 "Decrypted password: $pass"
      fi
    fi
    params+=" -pass pass:'$pass'"
  elif ! $interactive && $decrypt; then
    echo '---'
    return 0
  fi
  $decrypt && params+=" -d" || params+=" -e"
  if echo "$src" | eval openssl $params 2>/dev/null >"$TMP_MEM_PATH/kp.$$.pwd"; then
    cat "$TMP_MEM_PATH/kp.$$.pwd"
  else
    err=1
  fi
  rm -f "$TMP_MEM_PATH/kp.$$.pwd"
  return $err
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
  dbg 1 "seq-0 : $seq ph: $phrase"
  if [[ ! -z $phrase ]]; then # {{{
    local f= line=
    for f in $(getJournals); do
      [[ ! -e $f ]] && continue
      line="$(command grep "^$phrase\(:.*\)\{0,1\}:\s\+" "$f" | head -n1)"
      [[ ! -z $line ]] && break
    done
    seq="$(echo "$line" | sed 's/.*:\s\+//')"
    dbg 3 "seq-p : $seq"
    [[ -z $seq ]] && return 1
    if [[ ${seq:0:1} == '*' && -z $pass ]]; then
      local passV="$(echo "$line" | sed 's/\(.*\):\s\+.*$/\1/')"
      passV="${passV#*:}"
      passV="KEEP_PASS_KEY_${passV^^}"
      dbg 3 "passV: $passV"
      passV="${passV//-/_}"
      pass="${!passV}"
      dbg 3 "pass: $pass"
    fi
  fi # }}}
  [[ ${seq:0:1} == '*' ]] && use_pass=true && seq="${seq:1}"
  if $use_pass; then # {{{
    seq="$(encrypt -d "$seq" "$pass" "$interactive")"
    [[ $? != 0 || -z $seq ]] && err "Error during decryption" && return 1
    dbg 3 "seq-dp: $seq"
    [[ $seq == '---' ]] && echo "$seq" && return 0
  fi # }}}
  [[ ${seq:0:1} != '+' ]] && seq="$(encode -d "$seq")" || { seq="${seq:1}"; do_encode=false; }
  dbg 2 "seq-de: $seq"
  IFS=":" read -r seq upper spaces upper_first padding <<< "$seq"
  dbg 3 "seq-sp: s: $seq u: $upper sp: $spaces uf: $upper_first p: $padding"
  IFS="$oldIFS"
  [[ -z $seq ]] && return 0
  if $do_encode; then # {{{
    seq="$(echo "${seq// }" | sed 's/.\{5\}/& /g')"
    dbg 3 "seq-se: $seq"
    [[ $spaces == 1 ]] && spaces=true || spaces=false
    [[ $upper_first == 1 ]] && upper_first=true || upper_first=false
    ! $spaces && words='-'
    for i in $seq; do # {{{
      w="$(getWord "$i")"
      dbg 3 "$i: [$w]"
      $upper_first && w="$(echo "$w" | sed 's/\(.\)\(.*\)/\U\1\L\2/')"
      $spaces && words+=" "
      words+="$w"
    done # }}}
    words="${words:1}"
    dbg 3 "words: $words"
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
        dbg 3 "upper: $upper: [$f|$i|$t]"
        words="${f}${i^^}${t}"
      done
    fi # }}}
    # }}}
  else # {{{
    words="$seq"
  fi # }}}
  echo -n "$words"
} # }}}
genPass() { # {{{
  local cnt=4 i= v= seq= words= pass= params= input= info= \
    upper=false special=false digit=false spaces=true upper_first=false use_pass=false read_input=false \
    save=false add_padding=true do_encode=true update=false check= save_pass= passV= key=
  set -- $KEEP_PASS_GEN_PARAMS "$@"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --cnt)             cnt="$2"; shift;;
    --upper)           upper=true;;
    --special)         special=true;;
    --digit)           digit=true;;
    --no-sp)           spaces=false;;
    --upper-first)     upper_first=true;;
    --pass=*)          pass="${1#--pass=}";&
    --pass)            use_pass=true;;
    --no-pass)         use_pass=false;;
    --in=*)            input="${1#--in=}";&
    --in)              read_input=true; spaces=false;;
    --seq=*)           seq="${1#--seq=}";;
    --seq)             seq="$2"; shift;;
    --update | --key)  update=true;&
    --save)            save=true; info="$2"; use_pass=true; shift;;
    --no-padding)      add_padding=false;;
    --padding)         add_padding=true;;
    --pass-save)       save_pass=true;;
    --no-pass-save)    save_pass=false;;
    --plain)           do_encode=false; add_padding=false; spaces=false; seq="$2"; shift;;
    *) # {{{
      if [[ $# == 2 ]]; then
        save=true
        use_pass=true
        info="$1"
        shift
      fi
      input="$1"
      read_input=true
      spaces=false
      shift $#;; # }}}
    esac
    shift
  done # }}}
  if $read_input; then # {{{
    [[ -z $input ]] && read -r -p 'Enter input: ' input >/dev/stderr
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
          dbg 3 "${input:$i:$k-$i}: [$vv]"
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
  dbg 2 "$(basename "$0") --seq $seq"
  $do_encode && seq="$(encode "$seq")" || seq="+$seq"
  if $use_pass; then # {{{
    dbg 2 "$(basename "$0") --seq $seq"
    if [[ -z $pass && $info == *:* ]]; then # {{{
      passV="$(echo "$info" | sed 's/\(.*\):\s\+.*$/\1/')"
      passV="${passV#*:}"
      passV="KEEP_PASS_KEY_${passV^^}"
      pass="${!passV}"
      dbg 2 "Pass: $pass from var $passV"
      ${save_pass:-true} && [[ -z $pass ]] && save_pass=true
    fi # }}}
    while [[ -z $pass ]]; do # {{{
      read -r -s -p "Enter pass: " pass >/dev/stderr && echor
      [[ ! -z $pass ]] && break
      read -p 'No pass specified, proceed without encryption [y/n] ? ' >/dev/stderr
      case ${i,,} in
      y) break;;
      esac
    done # }}}
    if [[ ! -z $pass ]]; then # {{{
      if ${save_pass:-false} \
         && [[ ! -z "$KEEP_PASS_KEYS" ]] && [[ -e "$KEEP_PASS_KEYS" || ( "$KEEP_PASS_KEYS" == /* && "$KEEP_PASS_KEYS" != //* ) ]]; then # {{{
        local mkey="$(getMasterkey true)"
        if [[ -z $mkey ]]; then
          local answ=
          while read -p "Do you want to store key in plain format [y/N]? " answ; do
            case ${answ^^} in
            Y) break;;
            N | '') return 0;;
            esac
          done || return 1
        fi
        if [[ ! -z $mkey ]]; then
          if [[ -z $passV ]]; then
            passV="KEEP_PASS_KEY_TMP_PASS_$((1+(RANDOM%1000)))"
            dbg 2 "Pass-enc: $passV=\"@$(encrypt "$pass" "$mkey")\""
          fi
          echo "export $passV=\"@$(encrypt "$pass" "$mkey")\"" >>"$KEEP_PASS_KEYS"
        else
          echo "export $passV=\"$pass\"" >>"$KEEP_PASS_KEYS"
        fi
      fi # }}}
      seq="*$(encrypt "$seq" "$pass")"
      params="--pass=$pass"
    fi # }}}
  fi # }}}
  if [[ $verbose -ge 1 ]]; then
    dbg 1 "$(basename "$0") ${params:-\b} --seq $seq"
  else
    ! $save && echo "$seq"
  fi
  check="$(getPass $params --seq $seq)"
  dbg 1 "check: [$check]"
  check="$(echo "$check" | tail -n1)"
  if [[ "$check" != "$input" && ! -z $input ]]; then # {{{
   err "Decrypted phrase does not match input"
   err "Input  : $input"
   err "Phrase : $check"
   return 1
  fi # }}}
  if $save; then # {{{
    [[ -z $info ]] && info="$(command date +"%Y%m%d-%H%M%S")"
    local entry="${info// /-}:" journalFile="${KEEP_PASS_JOURNAL:-$KEEP_PASS_JOURNAL_SHARED}"
    if [[ ! -z $journalMainFile ]]; then
      journalFile="$journalMainFile"
    elif [[ -e "$PWD/keep-pass.journal" ]]; then
      journalFile="$PWD/keep-pass.journal"
    fi
    [[ -z $journalFile ]] && err "Journal file not found" && return 1
    while [[ ${#entry} -lt 18 ]]; do entry+=' '; done
    entry+="\t"
    entry+="$seq"
    key="${entry%%:*}"
    if hasKey "$key"; then
      if $update; then
        sed -i '/^'"$key"':/s/^.*/'"${entry//\//\\\/}"'/' "$journalFile"
      else
        dbg 0 "The key '$key' already exists"
        sed -i '/^'"$key"':/{s/^/# /;a'"$entry"'
          ;}' "$journalFile"
      fi
    else
      echo -e "$entry" >> "$journalFile"
    fi
  fi # }}}
  return 0
} # }}}
hasKey() { # {{{
  local f=
  for f in $(getJournals); do
    [[ -e $f ]] && command grep -q "^$1:" "$f" && return 0
  done
  return 1
} # }}}
listKeys() { # {{{
  local f= i= d= files="${KEEP_PASS_JOURNAL:-$KEEP_PASS_JOURNAL_SHARED}" all=false details=0
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
# IOS like pass # {{{
iosDigits='0123456789'
iosVovels='aeiouy'
iosConsonants='bcdfghjklmnpqrstvwz'
iosGetChar() { # {{{
  local i=$(getRangeValue ${#1})
  echo "${1:$i:1}"
} # }}}
iosIsVovel() { # {{{
  [[ ! -z $1 && $iosVovels == *$1* ]]
} # }}}
genIOSLikePass() { # {{{
  local parts=3 charsInPart=6
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -p | --parts) parts="$2"; shift;;
    -l | --seg-len) charsInPart="$2"; shift;;
    esac; shift
  done # }}}
  local charCount=$((parts * charsInPart))
  local idxDigit=$(getRangeValue $charCount)
  local idxUpper=$(((idxDigit + 1 + $(getRangeValue $((charCount - 1)))) % charCount))
  local idx=0 l= out=
  for ((;parts>0;parts--)); do # {{{
    local i=$charsInPart next='letter'
    for ((i=0; i <$charsInPart; i++)); do # {{{
      [[ $idx == $idxDigit ]] && next='digit'
      case $next in
      'letter') l=$(iosGetChar "$iosVovels$iosConsonants"); iosIsVovel $l && next='conso' || next='vovel';;
      'conso')  l=$(iosGetChar "$iosConsonants"); next='letter';;
      'vovel')  l=$(iosGetChar "$iosVovels"); next='conso';;
      'digit')  l=$(iosGetChar "$iosDigits"); next='letter';;
      esac
      [[ $idx == $idxUpper ]] && l=$(echo "$l" | tr '[a-z]' '[A-Z]')
      out+="$l"
      idx=$((idx + 1))
    done # }}}
    [[ $parts -gt 1 ]] && out+='-'
  done # }}}
  echo "$out"
} # }}}
# }}}
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
echorm -f?
[[ $? == 10 ]] && echorm -f $verbose
case $1 in
--help) # {{{
  echor "Usage:"
  echor "  $(basename "$0") --gen [--save] name:env-pwd phrase"
  echor "  $(basename "$0") --gen [--key name:env-pwd] phrase"
  echor "  $(basename "$0") [--get] [--key] name"
  echor "  $(basename "$0") [--gen-ios-pass [-p|--parts number] [-l|--seg-len number]"
  # echor "  $(basename "$0") --test encrypt env-pwd \$KEEP_PASS_MASTER_KEY"
  exit 0;; # }}}
--get)             shift; getPass "$@";;
--gen)             shift; genPass "$@";;
--save)            genPass "$@";;
--has-key)         shift; hasKey "$1";;
--list-keys)       shift; listKeys $@;;
--list-all-keys)   shift; listKeys --all $@;;
--set-master-key)  shift; setMasterKey $@;;
--test)            shift; $@;;
--gen-ios-pass)    shift; genIOSLikePass $@;;
*)                 getPass "$@";;
esac

