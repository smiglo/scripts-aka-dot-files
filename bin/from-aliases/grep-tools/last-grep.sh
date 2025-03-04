#!/usr/bin/env bash
# vim: fdl=0

_last-grep() { # @@ # {{{
  [[ -z $GREP_LAST_PATH ]] && return 1
  if [[ $1 == '@@' ]]; then # {{{
    if [[ $2 == 1 ]]; then
      local ret="+fzf -L -l -a -s -w -p --clean -f --file -F --follow"
      [[ -n $TMUX ]] && ret+=" $(cd $GREP_LAST_PATH; ls ${TMUX_SESSION}-* 2>/dev/null | grep -v '.txt')"
      echo $ret
    else
      case $3 in
      -a) echo "$(cd $GREP_LAST_PATH; ls *.txt 2>/dev/null )";;
      -L) echo "$(cd $GREP_LAST_PATH; ls 2>/dev/null | grep -v ".txt\|last" | sed -e 's/\(-[0-9]\{,2\}\)\{1,2\}$//' | sort -u)";;
      esac
      if [[ -n $TMUX ]]; then
        case $3 in
        -p) echo "$(cd $GREP_LAST_PATH; ls $(tmux display-message -p -t $TMUX_PANE -F '#S-#I-#P')-* 2>/dev/null | grep -v '.txt')";;
        -w) echo "$(cd $GREP_LAST_PATH; ls $(tmux display-message -p -t $TMUX_PANE -F '#S-#I')-*    2>/dev/null | grep -v '.txt')";;
        -s) echo "$(cd $GREP_LAST_PATH; ls ${TMUX_SESSION}-*       2>/dev/null | grep -v '.txt')";;
        esac
      fi
    fi
    return 0
  fi # }}}
  local f=
  local clean=false
  local show_file=false
  local show_greps=false
  local follow_link=false
  local use_fzf="$(echo ",$FZF_USAGE," | grep -o ',\s*LAST-GREP:[^,]\+,' | grep -o 'true\|false')"
  [[ -z $use_fzf ]] && use_fzf=$FZF_INSTALLED
  if [[ ! -z $1 ]]; then
    while [[ ! -z $1 ]]; do
      case $1 in
        -l) f=last;;
        -p) if [[ -n $TMUX ]]; then [[ -z $2 ]] && f=$(tmux display-message -p -t $TMUX_PANE -F '#S-#I-#P') || { f=$2; shift; }; fi;;
        -w) if [[ -n $TMUX ]]; then [[ -z $2 ]] && f=$(tmux display-message -p -t $TMUX_PANE -F '#S-#I')    || { f=$2; shift; }; fi;;
        -s) if [[ -n $TMUX ]]; then [[ -z $2 ]] && f=$TMUX_SESSION                         || { f=$2; shift; }; fi;;
        -L) if [[ -n $TMUX ]]; then [[ -z $2 ]] && f=$TMUX_SESSION                         || { f=$2; shift; }; fi; show_greps=true;;
        -f | --file)   show_file=true;;
        -F | --follow) follow_link=true;;
        +-fzf | +-f)   use_fzf=false;;
        +fzf  | +f)    use_fzf=$FZF_INSTALLED;;
        +fzf=*)        use_fzf=${1/+fzf=}; $use_fzf && use_fzf=$FZF_INSTALLED;;
        --clean)       clean=true;;
        -a)            ! $clean && { f=$2; shift;} || f=ALL;;
        *)             f=$1;;
      esac
      shift
    done
  else
    show_greps=true
    [[ -n $TMUX ]] && f="$TMUX_SESSION" || f=last
  fi
  if $show_greps; then
    local out=$TMP_MEM_PATH/grep-last-list-$f.txt
    rm -f $out
    for i in $(ls -t $GREP_LAST_PATH/${f}*.txt); do
      echo ${i/$HOME/\~}": $(head -n1 $i)" >>$out
    done
    if $use_fzf; then
      cat $out | fzf --prompt 'last-finds> ' --exit-0 --no-sort --no-multi --height 100%
    else
      vim --scratch -c 'setlocal conceallevel=2' $out
    fi
    return 0
  fi
  if $clean; then
    if [[ -z $f ]]; then
      f=last.txt
      [[ -n $TMUX ]] && f=$(tmux display-message -p -t $TMUX_PANE -F '#S-#I')
    elif [[ $f == ALL ]]; then
      f=
    fi
    rm -f $GREP_LAST_PATH/$f*
    return 0
  fi
  if [[ ! -z $f ]]; then
    f=$GREP_LAST_PATH/$f
    [[ ! -e $f ]] && return 1
    if $show_file; then
      [[ -h $f ]] && readlink $f || echo $f
      return 0
    fi
    if $use_fzf; then
      cat $($follow_link && echo $(readlink -f $f) || echo $f) | fzf --prompt 'last-finds> ' --exit-0 --no-sort --no-multi --height 100%
    else
      vim --scratch -c 'setlocal conceallevel=2' $($follow_link && echo $(readlink -f $f) || echo $f)
    fi
    return $?
  else
    local files=( $GREP_LAST_PATH/last.txt )
    [[ -n $TMUX ]] && files=( \
        $GREP_LAST_PATH/$(tmux display-message -p -t $TMUX_PANE -F '#S-#I-#P') \
        $GREP_LAST_PATH/$(tmux display-message -p -t $TMUX_PANE -F '#S-#I') \
        $GREP_LAST_PATH/$TMUX_SESSION \
        $GREP_LAST_PATH/last \
      )
    for f in ${files[*]}; do
      if [[ -e $f ]]; then
        if $show_file; then
          [[ -h $f ]] && readlink $f || echo $f
          return 0
        fi
        if $use_fzf; then
          cat $($follow_link && echo $(readlink -f $f) || echo $f) | fzf --prompt 'last-finds> ' --exit-0 --no-sort --no-multi --height 100%
        else
          vim --scratch -c 'setlocal conceallevel=2' $($follow_link && echo $(readlink -f $f) || echo $f)
        fi
        return $?
      fi
    done
  fi
  return 1
} # }}}
_last-grep "$@"

