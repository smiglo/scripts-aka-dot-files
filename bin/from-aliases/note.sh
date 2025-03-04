#!/usr/bin/env bash
# vim: fdl=0

_note() { # @@ # {{{
  if [[ $1 == @@ ]]; then # {{{
    case $3 in
    --note | -f | -n) echo "@@-f";;
    --tmux) tmux display-message -p -F '#D:#S:#W';;
    *) # {{{
      echo "-v -h -p25 -p50 -p75 --tmux --show-note-file --cat - --help"
      echo -f -n --note{,-{global,tmux,sharable}}
      echo "-g -s"
      local i=
      for i in ${!NOTE_FILE_*}; do
        i="${i#NOTE_FILE_}"
        echo "--note-${i,,}"
      done
      ;; # }}}
    esac
    return 0
  fi # }}}
  local files= paneId= paramsSplit= res=
  local cmd="vim-enc.sh --from-note" cmdDelim="--"
  local fromTmux=false showNoteFilename=false doCat=false
  local buffer="$TMP_MEM_PATH/notes-for-$$.txt"
  local noteFile=
  local noteFileGlobal="${NOTE_FILE_GLOBAL:-$APPS_CFG_PATH/notes.txt}"
  local noteFileSharable="${NOTE_FILE_SHARABLE:-$SHARABLE_PATH/notes.txt}"
  local noteFileTmux="$TMUX_SESSION_PATH/notes.txt"
  if [[ -z $1 ]]; then
    if [[ -t 1 ]]; then
      set -- $NOTE_PARAMS_DEFAULT
    else
      set -- --cat
    fi
  fi
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    -f | -n | --note)      noteFile="$2"; shift;;
    -g | --note-global)    noteFile="$noteFileGlobal";;
    -s | --note-sharable)  noteFile="$noteFileSharable";;
    --note-tmux)      noteFile="$noteFileTmux";;
    --note-*) # {{{
      local i= n= found=false
      n=${1#--note-} && n="NOTE_FILE_${n^^}"
      for i in ${!NOTE_FILE_*}; do
        if [[ $i == $n ]]; then
          noteFile="${!n}"
          found=true
          break
        fi
      done
      ! $found && echo "Note location not found for $1" >/dev/stderr && return 1;; # }}}
    --show-note-file) showNoteFilename=true;;
    -v | -h | -p*)    paramsSplit+="$1 ";;
    -  | --cat)       doCat=true;;
    --tmux) # {{{
      [[ ! -n $TMUX ]] && return 1
      [[ -z $1 ]] && echo "Missing source paramter" >/dev/stderr && return 1
      shift
      [[ -z "$paramsSplit" ]] && paramsSplit="${NOTE_PARAMS_SPLIT:--h -p50}"
      [[ " $paramsSplit " == *\ -v\ * && $(tmux display-message -p -F '#{pane_height}') -lt 16 ]] && paramsSplit="${paramsSplit/-v/-h}"
      paneId="$(tmux split-window $paramsSplit -P -F '#{pane_id}' "source \$HOME/.bashrc --do-basic; \note --tmux-batch $(echo $@)")"
      while true; do # {{{
        res=$(tmux display-message -p -t "$paneId" -F '#{pane_id}' 2>/dev/null)
        [[ -z $res ]] && break
        sleep 0.5
      done # }}}
      return 0;; # }}}
    --tmux-batch) # {{{
      # local session= wndName= pId= oIFS=$IFS
      # IFS=":"; read pId session wndName < <(echo "$2"); IFS=$oIFS
      shift 2
      fromTmux=true
      noteFile="${NOTE_FILE_TMUX:-$NOTE_FILE}"
      [[ -z $1 ]] && set -- $NOTE_PARAMS_TMUX
      case $1 in
      -g)      noteFile="$noteFileGlobal";;
      -s | -)  noteFile="$noteFileSharable";;
      -t)      noteFile="$noteFileTmux";;
      -n:*)    noteFile="${1#n:}";;
      -- | '') noteFile=;;
      -*) # {{{
        local i= n= found=false
        n=${1#-} && n="NOTE_FILE_${n^^}"
        for i in ${!NOTE_FILE_*}; do
          if [[ $i == $n ]]; then
            noteFile="${!n}"
            found=true
            break
          fi
        done
        ! $found && echo "Note location not found for $1" >/dev/stderr && return 1;; # }}}
      esac
      shift $#;; # }}}
    --help) # {{{
      cat >/dev/stderr <<-EOF
				# For encrypted parts use:
				# ENC.k@KEY-NAME # {{{
				__content__
				# ENC # }}}
			EOF
      return 0;; # }}}
    esac
    shift
  done # }}}
  [[ -z $noteFile ]] && noteFile="$(get-file-list -t -1 'note*.txt*')"
  [[ -z $noteFile ]] && noteFile="$NOTE_FILE"
  [[ -z "$paramsSplit" ]] && paramsSplit="${NOTE_PARAMS_SPLIT:--h -p50}"
  [[ " $paramsSplit " == *\ -v\ * && $(tmux display-message -p -F '#{pane_height}') -lt 16 ]] && paramsSplit="${paramsSplit/-v/-h}"
  if [[ -z "$noteFile" ]]; then # {{{
    if [[ -n $TMUX ]]; then
      noteFile="$UTILS_PATH/notes.txt"
    else
      noteFile="$noteFileGlobal"
    fi
  fi # }}}
  if $showNoteFilename; then # {{{
    echo "$noteFile"
    return 0
  fi # }}}
  if $doCat; then # {{{
    cat "$noteFile"
    return 0
  fi # }}}
  ! which "${cmd%% *}" >/dev/null 2>&1 && cmd="vim --fast -p" && cmdDelim=""
  if [[ ! -e "$noteFile" ]]; then
    [[ -d "$(dirname "$noteFile")" ]] || mkdir -p "$(dirname "$noteFile")"
    touch "$noteFile"
  fi
  if ! $fromTmux && [[ ! -t 0 ]]; then # {{{
    files+="$buffer "
    cat - >"$buffer"
  fi # }}}
  [[ -z "$files" ]] && files="$noteFile" || files="$noteFile $cmdDelim $files"
  set-title "Note: ${noteFile/$HOME/\~}"
  $cmd $files
  rm -f "$buffer"
} # }}}
_note "$@"

