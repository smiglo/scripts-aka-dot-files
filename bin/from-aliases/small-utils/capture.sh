#!/usr/bin/env bash
# vim: fdl=0

_capture() { # @@ # {{{
  local captureFile=$CAPTURE_FILE
  if [[ -z $CAPTURE_FILE ]]; then
    captureFile="$TMP_MEM_PATH/capture.txt"
    $IS_DOCKER && captureFile="${captureFile/$HOME/$DOCKER_HOST}"
  fi
  if [[ $1 == '@@' ]]; then # {{{
    case $3 in
    -m | --mode) echo "append override edit";;
    -t | --title) echo "TITLE";;
    -f | --file)
      get-file-list --pwd "$(dirname "$captureFile")" '*.txt'
      get-file-list --pwd "$(dirname "$captureFile")" '*.out';;
    *) echo "-f --file -t --title - -m --mode -e --edit -n --new -i -s"
    esac
    return 0
  fi # }}}
  local tmp=$TMP_MEM_PATH/out.$$ title= mode="append" out="/dev/stdout"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -t | --tile) title="$2"; shift;;
    -f | --file) # {{{
      case $2 in
      */* | -) captureFile="$2";;
      *) captureFile="$(dirname "$captureFile")/$2";;
      esac; shift;; # }}}
    -e | --edit) mode="edit";;
    -n | --new)  mode="override";;
    -i) echo "$captureFile"; return 0;;
    -s) out="/dev/null";;
    -) captureFile="-";;
    esac; shift
  done # }}}
  case $mode in
  edit) # {{{
    vim $captureFile;; # }}}
  append | override) # {{{
    case $mode in
    override) rm -f $captureFile;;
    esac
    [[ -t 0 ]] && echor "not in pipie" && return 1
    echo "# $([[ ! -z $title ]] && echo "$title # ")$(date +$DATE_FMT) # {{{" >>$tmp
    /bin/cat - | tee -a $tmp >$out
    echo "# }}}" >>$tmp
    if [[ $captureFile != '-' ]]; then
      [[ -e $captureFile ]] && cat $captureFile >>$tmp
      mv $tmp $captureFile
    else
      /bin/cat $tmp
    fi
    rm -rf $tmp;; # }}}
  esac
}
export PHISTORY_IGNORED_COMMANDS+=":capture" # }}}
_capture "$@"


