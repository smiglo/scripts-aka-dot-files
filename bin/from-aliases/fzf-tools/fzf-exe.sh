#!/usr/bin/env bash
# vim: fdl=0

_fzf-exe() { # @@ # {{{
  if [[ "$1" == '@@' ]]; then # {{{
    case $3 in
    -c) echo "prev pane";;
    -f) echo "@@-f";;
    --pane) # {{{
      local idd=$(tmux display-message -p '#S:#I.#P') id= p=
      while read id p; do
        [[ $id == $idd ]] && continue
        if $IS_MAC; then
          pstree $p | grep -q '[M]acOS/Vim'
        else
          pstree -Ac $p | grep -q -e '---vim'
        fi && echo $id
      done < <(tmux list-panes -a -F '#S:#I.#P #{pane_pid}')
      ;; # }}}
    *) # {{{
      echo "-c -f -l"
      if false; then :;
      elif [[ "$@" == *'-c pane'* ]]; then echo "--pane";
      elif [[ "$@" == *'-c prev'* ]]; then echo "--cnt --prev";
      fi;; # }}}
    esac
    return 0
  fi # }}}
  local cmd= file= line= params= pane='.1' prev_lines_before=10 max_prev_lines=999
  local prev_lines_cnt=$max_prev_lines
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -c) shift; cmd=$1;;
    -f) shift; file=$1; [[ ! -e $file ]] && file=${file/ *};;
    -l) shift; line=$1; [[ $line =~ ^[0-9]+$ ]] || line=;;
    *)  case $cmd in
        prev) case $1 in
              --cnt)  shift; local prev_lines_cnt=$1;;
              --prev) shift; local prev_lines_before=$1;
              esac;;
        pane) case $1 in
              --pane) shift; pane=$1;;
              esac;;
        esac;;
    esac
    shift
  done # }}}
  [[ ! -z $cmd ]]  || { echo "Command not specified" >/dev/stderr; sleep 1; return 0; }
  [[ ! -z $file ]] || { echo "File not specified"; >/dev/stderr sleep 1; return 0; }
  file="$(echo "$file" | sed "s/\x1B\[[0-9;]*[mGK]//g")"
  [[ $file == \~* ]] && file=${file/\~/$HOME}
  [[ ! -z $line ]] && line="$(echo "$line" | sed "s/\x1B\[[0-9;]*[mGK]//g")"
  if [[ $file =~ ^([^:]+):([0-9]+)[:-].*$ ]]; then # {{{
    file=${BASH_REMATCH[1]}
    line=${BASH_REMATCH[2]}
  fi # }}}
  file="${file%%:*}"
  [[ ! -e $file ]] && file="${file%-*}"
  [[ -f $file || $cmd == 'prev' ]] || { echo "Canot open [$file]" >/dev/stderr; sleep 1; return 0; }
  case $cmd in # {{{
  less | vim) # {{{
    case $cmd in
    less)       params="-N";;
    vim)        params="-cl -c FastVim";;
    esac
    [[ ! -z $line ]] && params+=" +$line"
    params+=" $file"
    case $cmd in
    vim)        params+=" -c 'normal! zv' ";;
    esac;; # }}}
  prev) # {{{
    [[ -z $line ]] && line='1'
    local first_line=$(($line-$prev_lines_before))
    [[ $first_line -lt 1 ]] && first_line='1';; # }}}
  pane) # {{{
    local ppid=$(tmux display-message -t $pane -p -F '#{pane_pid}')
    if ! $IS_MAC; then
      pstree -Ac $ppid | grep -q -e '---vim'
    else
      pstree $ppid | grep -q -i -e 'vim'
    fi || { echo "Vim not found in pane '$pane'" >/dev/stderr; sleep 1; return 0; };; # }}}
  *) # {{{
    { echo "Unknown command [$cmd]" >/dev/stderr; sleep 1; return 0; };; # }}}
  esac # }}}
  case $cmd in # {{{
  prev) # {{{
    [[ -h $file ]] && echo -e "File ${file##*/} links to $(readlink $file)\n" && file="$(readlink -f $file)"
    if [[ -f $file ]]; then
      local t="$(file --mime $file)"
      [[ "$t" =~ binary ]] && echo "$file is a binary" && return 0
      if which highlight >/dev/null 2>&1; then
        [[ ${file##*/} != *.* && ( "$t" =~ shellscript || "$t" =~ text/plain ) ]] && t="-S bash" || t=""
        highlight -O ansi $t $file 2>/dev/null || cat $file
      else
        cat $file
      fi | cat -n - | cut -c3- | tail -n+$first_line | head -n $prev_lines_cnt | hl +cY "^\s*$line\s"
    elif [[ -d $file ]]; then
      ! which tree >/dev/null 2>&1 && echo "$file is a directory" && return 0
      tree -C $file 2>/dev/null | head -200
    else
      echo "Not supported entity [$file]"
    fi;; # }}}
  pane) # {{{
    [[ $file != /* ]] && file="$PWD/$file"
    if is-installed realpath; then
      local paneCwd="$(tmux display-message -p -t $pane -F '#{pane_current_path}')"
      file="$(realpath --relative-to "$paneCwd" "$file")"
    fi
    tmux send-keys -t $pane ":call RelTabEdit(\"$file\")"
    if [[ ! -z $line ]]; then
      tmux send-keys -t $pane "zR${line}gg"
    fi;; # }}}
  *) # {{{
    $cmd $params </dev/tty >/dev/tty;; # }}}
  esac # }}}
} # }}}
_fzf-exe "$@"

