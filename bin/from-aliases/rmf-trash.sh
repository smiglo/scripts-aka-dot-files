#!/usr/bin/env bash
# vim: fdl=0

_rmfTrash() { # @@ # {{{
  rmf_rm_report() { # {{{
    local p=$1
    p=${p/$HOME/'~'}
    echo "$p --> ${out/$TRASH\/}" >> $LOGS
  } # }}}
  rmf_to_trash() { # {{{
    local out=${1/*\/}
    local out=$TRASH/$DATE-$out
    rmf_rm_report $1
    mv $1 $out
  } # }}}
  rmf_clean() { # {{{
    unset rmf_rm_report
    unset rmf_to_trash
    unset rmf_clean
    unset rmf_purge
    unset rmf_ls
    unset rmf_rm
    unset rmf_help
  } # }}}
  rmf_purge() { # {{{
    local timestamp_now="$(echo $DATE | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')"
    local i= timestamp= diff= err=
    if [[ ! -z $to_remove ]]; then
      for i in $to_remove; do
        rm -rf $TRASH/$i || { err=$?; echo "Fail to purge [$i]" >/dev/stderr; return $err; }
      done
      return 0
    fi
    for i in $(ls $TRASH); do
      timestamp="$(echo $i | cut -c-15 | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')"
      diff=$(($(date -d "$timestamp_now" +"%s") - $(date -d "$timestamp" +"%s")))
      if [[ diff -gt $RMF_PURGE_DELTA ]]; then
        if ! $dry; then
          echo "Remove [$i]" >/dev/stderr
          rm -rf $TRASH/$i || { err=$?; echo "Fail to purge [$i]" >/dev/stderr; return $err; }
        else
          echo "Would remove [$i]" >/dev/stderr
        fi
      fi
    done
  } # }}}
  rmf_ls() { # {{{
    local i=
    for i in $(ls $TRASH); do
      echo -e "$i \t [$(du -sh $TRASH/$i | sed -e 's/\/.*//' -e 's/\s//g')]"
    done
  } # }}}
  rmf_rm() { # {{{
    local err=
    [[ ! -z $to_remove ]] || { echo "List of files is empty" >/dev/stderr; return 1; }
    if ! $use_trash; then
      rm -rf $to_remove || { err=$?; echo "Fail to remove [$to_remove]" >/dev/stderr; return $err; }
      return 0
    fi
    local i= id_i= key= j= answer= answer_global=
    for i in $to_remove; do
      [[ $i != /* ]] && i=$PWD/$i
      if [[ $i == $TRASH/* ]]; then
        rm -rf $i || { err=$?; echo "Fail to remove [$i]" >/dev/stderr; return $err; }
        continue
      fi
      [[ $i == */ ]] && i=${i%/}
      id_i=$(stat -c "%d" $i)
      if [[ $id_i == $ID_TRASH ]]; then
        rmf_to_trash $i || { err=$?; echo "Fail to move to trash [$i]" >/dev/stderr; return $err; }
        continue
      fi
      answer=$answer_global
      while [[ -z $answer ]]; do
        echo -n "File [$i] on different FS. Remove permanently or move to Trash [Yr/nmt]? " >/dev/stderr
        read key
        case $key in
        n|N|m|M|t|T) answer='N';;&
        y|Y|r|R|'')  answer='Y';;&
        N|Y)         answer_global=$answer;;
        esac
      done
      case $answer in
      N) rmf_to_trash $i || { err=$?; echo "Fail to move to trash [$i]" >/dev/stderr; return $err; }; break;;
      Y) rm -rf $i       || { err=$?; echo "Fail to remove [$i]" >/dev/stderr; return $err; }; break;;
      esac
    done
  } # }}}
  rmf_help() { # {{{
    echo "Usage:" >/dev/stderr
    echo "  rmf [-n|--no-trash] [-t|--use-trash] FILES" >/dev/stderr
    echo "  rmf --purge [--dry] [--all] FILES" >/dev/stderr
    echo "  rmf --ls" >/dev/stderr
    echo "  rmf --help" >/dev/stderr
    echo >/dev/stderr
  } # }}}
  local TRASH=${RMF_TRASH_PATH:-$TMP_PATH/.trash}
  if [[ $1 == '@@' ]]; then
    local i= ret='-n --no-trash -t --use-trash --purge --ls --help'
    for i in ${COMP_WORDS[*]}; do
      [[ $i == '--purge' ]] && ret="--dry --all $(ls $TRASH)"
      [[ $i == '--ls' ]] && ret=''
      [[ $i == '--help' ]] && ret=''
    done
    echo $ret
    rmf_clean
    return 0
  fi
  local LOGS=${RMF_LOG_FILE:-$TRASH/.log-book.log}
  local DATE=$(date +$DATE_FMT)
  local RMF_PURGE_DELTA=${RMF_PURGE_DELTA:-$((7*24*60*60))}
  [[ ! -e $TRASH ]] && mkdir -p $TRASH
  local ID_TRASH=$(stat -c "%d" $TRASH)
  local use_trash=${RMF_USE_TRASH:-true} dry=${RMF_DRY_RUN:-false} to_remove= cmd='rm' err=
  while [[ ! -z $1 ]]; do
    case $1 in
    --ls|--purge|--help) cmd="${1/--}";;
    --dry)            dry=true;;
    --all)            RMF_PURGE_DELTA=0;;
    -n|--no-trash)    use_trash=false;;
    -t|--use-trash)   use_trash=true;;
    *) case $cmd in
        purge) to_remove+=" $1";;
        rm) [[ -e $1 ]] && to_remove+=" $1";;
        esac;;
    esac
    shift
  done
  rmf_$cmd
  err=$?
  rmf_clean
  return $?
} # }}}
_rmfTrash "$@"

