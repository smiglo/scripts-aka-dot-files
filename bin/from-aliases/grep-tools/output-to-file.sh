#!/usr/bin/env bash
# vim: fdl=0

_output-to-file() { # @@ # {{{
  if [[ $1 == '@@' ]]; then
    echo "+tee=true +tee=false --ignore=err +fzf +-fzf --no-err --no-sort"
    return 0
  fi
  local use_tee=true
  local ignoreErr=false
  local colors= sort_params= errout="/dev/stderr"
  local use_fzf= fzf_params="--exit-0 --layout=reverse-list --no-sort --multi --height 100% --expect 'ctrl-p' --expect 'ctrl-s'"
  while [[ ! -z $1 ]]; do
    case $1 in
    true|false)   use_tee=$1;;
    +tee=*)       use_tee="${1/+tee=}";;
    --ignore-err) ignoreErr=true;;
    --sort-*)     sort_params+=" ${1#--sort-}";;
    --no-sort)    sort_params='NO-SORT';;
    --colors)     colors="--color=always";;
    --no-colors)  colors="--color=never";;
    +-fzf | +-f)  use_fzf=false;;
    +fzf  | +f)   use_fzf=$FZF_INSTALLED;;
    +fzf=*)       use_fzf=${1/+fzf=}; $use_fzf && use_fzf=$FZF_INSTALLED;;
    +fzf-p)       fzf_params+=" $2"; shift;;
    +fzf-*)       fzf_params+=" ${1#+fzf-}";;
    --no-err)     errout="/dev/null";;
    *)            cmd=$1; shift; break;;
    esac
    shift
  done
  [[ -z $sort_params ]] && sort_params="$OUTPUT_TO__SORT_PARAMS"
  [[ -z $cmd || $cmd == '-' ]] && cmd='cat -'
  if [[ -z $use_fzf ]]; then # {{{
    if [[ ! -t 1 ]]; then
      use_fzf=false
    else
      use_fzf="$(echo ",$FZF_USAGE," | grep -o ',\s*OUTPUT-TO-FILE:[^,]\+,' | grep -o 'true\|false')"
      [[ -z $use_fzf ]] && use_fzf=$FZF_INSTALLED
    fi
  fi # }}}
  local use_eval=
  if [[ $cmd == eval\ * ]]; then
    use_eval="eval "
    cmd=${cmd/eval }
  fi
  if $use_fzf; then
    case $cmd in
    ag* | ack* ) colors="--nocolor";;
    *grep*)      colors="--color=never";;
    esac
  fi
  local err= tmpFile=$TMP_MEM_PATH/otf-$$.tmp file="/dev/null"
  [[ ! -z $GREP_LAST_PATH && ! -e $GREP_LAST_PATH ]] && mkdir -p $GREP_LAST_PATH
  if $use_tee; then # {{{
    if [[ ! -z $GREP_LAST_PATH ]]; then
      file="$GREP_LAST_PATH/last-$(date +$DATE_FMT).txt"
      [[ -n $TMUX ]] && file="$GREP_LAST_PATH/$(tmux display-message -p -t $TMUX_PANE -F '#S-#I-#P')-$(date +$DATE_FMT).txt"
    fi
    (
      echo "$cmd $@" | sed 's/--[^ ]*//g' | sed 's/  \+/ /g' | sed 's/ \+$//'
      echo "# "${PWD/$HOME/\~}
      echo "# "${file/$HOME/\~}
      echo "# sum"
      echo
    ) >$file
  fi # }}}
  ${DBG_SHOW_CMD:-false} && echormf "$use_eval $cmd $colors \"$@\""
  if $use_fzf; then # {{{
    $use_eval $cmd $colors "$@" 2>$errout | { [[ $sort_params == 'NO-SORT' ]] && cat - || sort -st':' -k1,1 -k2,2n $sort_params; } >$tmpFile
    err=${PIPESTATUS[0]}
    if [[ $err == 0 ]]; then
      local res="$(cat $tmpFile | { $use_tee && tee -a $file || cat -; }  | { eval fzf $fzf_params; })"
      local key="$(echo "$res" | sed -n 1p)"
      res="$(echo "$res" | sed  1d)"
      case $key in
      ctrl-p) cat $tmpFile;;
      ctrl-s) [[ ! -z $res ]] && echo "$res" | xc; [[ ! -t 1 ]] && echo "$res";;
      '')     [[ ! -z $res ]] && echo "$res";;
      esac
    fi # }}}
  else # {{{
    $use_eval $cmd $colors "$@" 2>$errout \
    | { [[ $sort_params == 'NO-SORT' ]] && cat - || sort -st':' -k1,1 -k2,2n $sort_params; } \
    | { $use_tee && tee -a $file || cat -; }
    err=${PIPESTATUS[0]}
  fi # }}}
  if $use_tee; then # {{{
    if [[ ! -z $GREP_LAST_PATH ]] && ( [[ $err == 0 ]] || $ignoreErr ) && [[ -e $tmpFile ]]; then
      local sum="$(cat $tmpFile | sort | sha1sum | cut -d' ' -f1)" i= found=false
      for i in $(find $GREP_LAST_PATH -type f | sort); do
        [[ "$(sed -n '4{p;q}' $i)" == "# sum: $sum" ]] && rm $file && file=$i && found=true && break
      done
      if ! $found; then
        sed -i -e '4s/.*/# sum: '"$sum"'/' -e "s/\x1B\[[0-9;]*[mGK]//g" $file
        if [[ -n $TMUX ]]; then
          ln -sf $file $GREP_LAST_PATH/$(tmux display-message -p -t $TMUX_PANE -F '#S-#I-#P')
          ln -sf $file $GREP_LAST_PATH/$(tmux display-message -p -t $TMUX_PANE -F '#S-#I')
          ln -sf $file $GREP_LAST_PATH/$TMUX_SESSION
        fi
        ln -sf $file $GREP_LAST_PATH/last
      fi
    else
      rm $file
    fi
  fi # }}}
  rm -f $tmpFile
  return $err
} # }}}
_output-to-file "$@"

