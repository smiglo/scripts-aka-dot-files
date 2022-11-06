#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == @@ ]]; then # {{{
  f=
  case $3 in
  --copy)        f="$VIM_ENC_DEFAULT_COPY_FILE";;&
  --gui-pattern) f="$VIM_ENC_DEFAULT_COPY_FILE";;&
  --copy | --gui-pattern)
    ret="---" p=
    [[ ! -z "$f" ]] && p="$(sed -n '/^# Patterns:/s/# Patterns: *//p' "$f")"
    echo "${p:-$ret}";;
  *) # {{{
    echo --help --copy --gui --{,no-}{edit,header,plain} -- @@-f
    [[ " $@ " == *" --gui "* ]] && echo "--gui-pattern -g";; # }}}
  esac
  exit 0
fi # }}}
parseFile() { # {{{
  local wtd=$1 in="$2" out="$3"
  local isPlain=true wasErr=false rawInput= enc= dec=
  while read l; do
    if [[ $wtd == encrypt ]]; then # {{{
      case $l in
      '# ENC.k@'*) # {{{
        isPlain=false wasErr=false rawInput=
        [[ "$l" =~ ^'# '(DEC|ENC)'.k@'([^ #]+) ]] && key="${BASH_REMATCH[2]}"
        echo "${l/\# ENC.k@/\# DEC.k@}"
        continue;; # }}}
      '# ENC'*) # {{{
        if ! $wasErr; then
          enc="$(echo -en "$rawInput" | encryptor --key $key)"
          echo "$enc"
        else
          echo -en "$rawInput"
        fi
        echo "${l/\# ENC/\# DEC}"
        isPlain=true enc=
        continue;; # }}}
      '# DEC:FAIL') # {{{
        wasErr=true
        continue;; # }}}
      esac # }}}
    elif [[ $wtd == decrypt ]]; then # {{{
      case $l in
      '# DEC.k@'*) # {{{
        echo "${l/\# DEC.k@/\# ENC.k@}"
        isPlain=false rawInput=
        [[ "$l" =~ ^'# '(DEC|ENC)'.k@'([^ #]+) ]] && key="${BASH_REMATCH[2]}"
        continue;; # }}}
      '# DEC'*) # {{{
        dec="$(echo -en "$rawInput" | encryptor -d --key $key)"
        if [[ $? == 0 && ! -z $dec ]]; then
          echo "$dec"
        else
          echo "# DEC:FAIL"
          echo -en "$rawInput"
        fi
        echo "${l/\# DEC/\# ENC}"
        isPlain=true dec=
        continue;; # }}}
      esac # }}}
    fi
    if $isPlain; then
      echo "$l"
    else
      rawInput+="$l\n"
    fi
  done < <(cat "$in") >"$out"
} # }}}

! declare -F encryptor >/dev/null && source $HOME/.bashrc --do-basic
[[ -z $VIM_ENC_DEFAULT_GUI_FILE ]] && source $BASH_PATH/runtime --force
! declare -F encryptor >/dev/null && echo "The encryptor function not found" >/dev/stderr && exit 1

in= out= removeOut=true edit= otherFiles= addHeader= plain= pattern= batchMode=false copy=false fromNote=false gui=false vimGuiCmd="gvim" isGui=
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --help) # {{{
    exit 0;; # }}}
  --edit)        edit=true;;
  --header)      addHeader=true;;
  --plain)       plain=true;;
  --no-edit)     edit=false;;
  --no-header)   addHeader=false;;
  --no-plain)    plain=false;;
  --from-note)   fromNote=true batchMode=true edit=true;;
  --copy)        copy=true pattern="$2" batchMode=true; shift;;
  --gui)         gui=true isGui=true batchMode=true;;
  -g)            isGui=false vimGuiCmd="vim";;
  --gui-pattern) pattern="$2"; shift;;
  --)            shift; otherFiles="$@"; shift $#;;
  *) # {{{
    if [[ -t 0 ]] || $batchMode; then
      in="$1"
      [[ $2 != '--' ]] && out="$2" && shift
      [[ -z $out ]] && out="$TMP_MEM_PATH/$(basename "$in").note" || removeOut=false
      $batchMode && removeOut=true
    else
      in="-" out="$1"
      [[ -z $out ]] && out="$TMP_MEM_PATH/stdin.note" || removeOut=false
    fi;; # }}}
  esac
  shift
done # }}}
if [[ -z $in ]]; then # {{{
  if $copy; then
    [[ -z "$in" ]] && in="$VIM_ENC_DEFAULT_COPY_FILE"
  elif $gui; then
    [[ -z "$in" ]] && in="$VIM_ENC_DEFAULT_GUI_FILE"
  fi
  ( [[ -z "$in" && ! -t 0 ]] && ! $batchMode ) && in="-" && out="$TMP_MEM_PATH/stdin.note"
  [[ -z $in ]] && echo "Source file not set" >/dev/stderr && exit 1
fi # }}}
rm -f "$out"

if $batchMode; then # {{{
  [[ -z $edit      ]] && edit=false
  [[ -z $addHeader ]] && addHeader=false
  [[ -z $plain     ]] && plain=true
fi # }}}
if [[ -z $edit ]]; then # {{{
  [[ -t 1 ]] && edit=true || edit=false
fi # }}}
if [[ -z $plain ]]; then # {{{
  [[ -t 1 ]] && plain=false || plain=true
fi # }}}
if [[ -z $addHeader ]]; then # {{{
  if ! $edit || [[ ! -t 1 || -s "$in" ]]; then
    addHeader=false
  else
    addHeader=true
  fi
fi # }}}

if $copy; then # {{{
  [[ -z $pattern ]] && exit 1
  v="$(cat "$in" | $0 | sed -n '/^'$pattern': */s/'$pattern': *//p')"
  [[ ! -z "$v" ]] && echo "$v" | { [[ -t 1 ]] && ccopy || cat -; }
  exit 0
  # }}}
elif $gui; then # {{{
  cat "$in" | $0 \
    | { [[ ! -z $pattern ]] && sed -n '/^'$pattern': */p' || cat -; } \
    | { sed 's/^\([^#]\+\): \(.*\)/\1\n\2\n/' | sed -e '/^$/d' -e '/^# /d'; } \
    | { [[ ! -z $pattern ]] && sed '/^'$pattern' */d' || cat -; } \
    | { if [[ -t 1 ]] || $isGui; then
          $vimGuiCmd - --fast -c 'set ro noswapfile' -c 'nnoremap <silent> y \"+y$ <Bar> :sleep 2 <Bar> :quitall!<CR>' -c 'nnoremap <silent> <Esc> :quitall!<CR>'
        else
          cat -
        fi; }
  exit 0
fi # }}}

if [[ -s "$in" || "$in" == '-' ]]; then
  parseFile decrypt "$in" "$out"
else
  rm -f "$out"
  echo >"$out"
fi
if $addHeader; then # {{{
  info="$(cat <<-EOF
				# enc-info: For encrypted sections use the following syntax:
				# enc-info: # ENC.k@KEY-NAME # {{{
				# enc-info: __content__
				# enc-info: # ENC # }}}
				# enc-info:
				
			EOF
  )"
  sed -i '1i '"$(echo "$info" | sed 's/$/\\/')" "$out"
  sed -i '/^# enc-info:/s/\\$//' "$out"
fi # }}}

err=false
if [[ -e "$out" ]] && ( ! $edit || vim --fast -c FastClipboard -c 'set cul nobk fdl=0 isk+=-' -p "$out" $otherFiles </dev/tty >/dev/tty ); then
  $addHeader && sed -i '/^# enc-info:/d' "$out"
  toOutput="$out"
  if $edit; then # {{{
    if ( [[ ! -t 0 ]] && ! $fromNote && $removeOut ); then
      in="/dev/stdout" && toOutput=""
    fi
    parseFile encrypt "$out" "$in" | { $plain && sed '/^# \(ENC\|DEC\)/d' || cat -; }
    # [[ ! -z $toOutput && ! -t 1 ]] && toOutput="$in"
  fi # }}}
  if [[ ! -t 1 && ! -z "$toOutput" ]]; then # {{{
    cat "$toOutput" | { $plain && sed '/^# \(ENC\|DEC\)/d' || cat -; }
  fi # }}}
else
  err=true
fi

if $removeOut || $err; then # {{{
  rm -f "$out"
fi # }}}

