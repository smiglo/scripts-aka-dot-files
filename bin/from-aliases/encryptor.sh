#!/usr/bin/env bash
# vim: fdl=0

_encryptor() { # @@ # {{{
  local src= dst=
  local cipher="aes-256-cbc" params= encode="-e" use_base64="-a" use_hash_pass=true pass= edit=false persistent=false make_link=false key=
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    --key)  which keep-pass.sh >/dev/null 2>&1 && keep-pass.sh --list-all-keys;;
    *) # {{{
      if [[ " $@ " == *\ -d\ * || " $@ " == *\ --edit\ * ]]; then
        get-file-list '*.enc' | sed -e 's|^|./|'
      else
        echo '--stdin --stdout --no-hash-pass -d --hash-pass --pass --key --edit --pers --bin'
        get-file-list | sed -e '/\.dec$/d' -e 's|^|./|'
      fi
      ;; # }}}
    esac
    return 0
  fi # }}}
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --stdin) src="--stdin";;
    --stdout) dst="--stdout";;
    --hash-pass) use_hash_pass=true;;
    --no-hash-pass) use_hash_pass=false;;
    --pass) pass="$2"; shift;;
    --key)  pass="$(keep-pass.sh --key "$2")"; key="$2"; shift;;
    --edit) edit=true; encode="-d";;
    --pers) persistent=true;;
    --bin)  use_base64=;;
    -v) echormf +;;
    -d) encode="-d";;
    -*) params+=" $1";;
    *)
      if [[ -z $src ]]; then
        src=$1
        [[ $src == *.enc || $src == *.enc.* ]] && encode="-d"
      elif [[ -z $dst ]]; then
        dst=$1
      fi;;
    esac
    shift
  done # }}}
  [[ $src == '--stdin' ]] && src=""
  [[ ! -t 0 && -z $src ]] && src=""
  [[ ! -t 1 && -z $dst ]] && dst="--stdout"
  if [[ ! -z $src ]]; then # {{{
    if [[ -z $pass && $src =~ ^.*\.k@([^.]*)(\..*){0,1}$ ]]; then
      if [[ ! -z ${BASH_REMATCH[1]} ]]; then
        if keep-pass.sh --has-key "${BASH_REMATCH[1]}"; then
          pass="$(keep-pass.sh --key "${BASH_REMATCH[1]}")"
        else
          echo "No key '${BASH_REMATCH[1]}' in keep-pass journals" >/dev/stderr
          return 1
        fi
      fi
    fi
    if [[ -z $dst && -t 1 ]]; then
      dst="${src%.dec}"
      if [[ $encode == '-e' ]]; then
        [[ ! -z $key ]] && dst="${dst/.k@*./.}.k@$key"
        dst+=".enc"
      else
        ! $persistent && dst="$TMP_MEM_PATH/${src##*/}" && make_link=true
        dst="${dst/.k@*./.}" && dst="${dst%.enc}.dec"
      fi
    fi
  fi # }}}
  [[ $dst == '--stdout' ]] && dst=""
  $edit && dst="$TMP_MEM_PATH/${src##*/}" && dst="${dst%.enc}" && touch $dst
  if $use_hash_pass; then # {{{
    if [[ -z $pass ]]; then # {{{
      if [[ $encode == '-e' ]]; then # {{{
        local p1= p2=
        while [[ -z $pass ]]; do
          read -s -p "Pass  : " p1 >/dev/stderr </dev/tty
          echo >/dev/stderr
          read -s -p "Retype: " p2 >/dev/stderr </dev/tty
          echo >/dev/stderr
          [[ $p1 == $p2 ]] && pass=$p1$p2 || echormf "Do not match"
        done
        p1=
        p2=
      else
        read -s -p "Pass: " pass >/dev/stderr </dev/tty
        echo >/dev/stderr
        pass=$pass$pass
      fi # }}}
    else
        pass=$pass$pass
    fi # }}}
  fi # }}}
  local cmd="openssl enc -$cipher -md md5 $use_base64 $params" shaCmd="sha256sum" err=0
  echormf "$cmd $encode $([[ ! -z $src ]] && echo "-in $src") $([[ ! -z $dst ]] && echo "-out $dst")"
  $use_hash_pass && cmd+=" -pass file:<(echo $pass | $shaCmd | cut -c1-64)"
  if [[ ! -z $src && ! -e $src ]]; then # {{{
    if ! $edit; then
      echo "Source file [$src] does not exist" >/dev/stderr
      return 1
    else
      err=0
    fi
  else
    eval $cmd $encode $([[ ! -z $src ]] && echo "-in $src") $([[ ! -z $dst ]] && echo "-out $dst") 2>/dev/null || err=1
  fi # }}}
  if [[ $err == 0 ]]; then
    if $edit; then
      chmod go-rwx "$dst"
      if $EDITOR "$dst"; then
        eval $cmd -e $([[ ! -z $src ]] && echo "-out $src") $([[ ! -z $dst ]] && echo "-in $dst") 2>/dev/null || err=1
      else
        err=1
      fi
      sed -i -e 's/.*/a/g' -e 's/\x0a/a/' "$dst"
      rm -rf "$dst"
    elif $make_link; then
      ln -sf "$dst" "${dst##*/}"
    fi
  fi
  pass="$(head -c 10 /dev/random | $shaCmd | cut -c1-40)"
  return $err
} # }}}
_encryptor "$@"

