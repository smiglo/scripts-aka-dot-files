#!/usr/bin/env bash
# vim: fdl=0

_tm() { # @@ # {{{
  ! type tmux >/dev/null 2>&1 && return 1
  local buffers_path="$APPS_CFG_PATH/tmux/buffers" layouts_path="$APPS_CFG_PATH/tmux/layouts"
  local lFile="$layouts_path/l.layout"
  if [[ $1 == '@@' ]]; then # {{{
    local dir=${PWD/*\/}
    local sessions="$(tmux list-sessions -F '#S')"
    local ret=""
    if [[ $2 == 1 ]]; then
      ret="-d -a --attach -p --path -s --install --exec ${dir^^} $sessions -n --nest -b --buffers --b-dump --b-restore --l-dump --l-restore --l-edit ld lr --layout l"
      ret+=" --new --pane --env -e --switch --pids --session"
      ret+=" ss se sd sr pa"
    else
      case $4 in
      --session)   ret="-s --save -d --delete -e --edit -r --restore";;
      -a|--attach) ret="$sessions";;
      -p|--path)   ret="@@-d";;
      --b-restore) ret="$(cd $buffers_path; ls -Ad *)";;
      --pid)       ret="-a -s";;
      --env | -e) # {{{
        ret=" -w -v"
        ret+="$(tmux show-environment -g | awk -F'=' '/^[A-Z].*=/ && !/=\(\)/{print $1}')";; # }}}
      --pane) # {{{
        case $3 in
        \?\?)   ret="$(tmux list-panes -a -F '#T' | while read p; do printf "%q\n" "$p"; done)";;
        \?)     ret="$(tmux list-panes -s -F '#T' | while read p; do printf "%q\n" "$p"; done)";;
        --pane) ret="?? ? $(tmux list-windows -a -F '#S:#I')";;
        [0-9]) # {{{
          case $5$6$7 in
          [A-Z]*:[0-9]*) ret="$(tmux list-panes -t $5$6$7 -F '#T'  | while read p; do printf "%q\n" "$p"; done)";;
          esac;; # }}}
        *)      ret="- nl";;
        esac;; # }}}
      --l-dump | --l-restore | --l-edit | ld | lr) # {{{
        case $3 in
        --file) # {{{
          ret="-"
          [[ -e "$layouts_path/l.layout" ]] && ret+=" l"
          [[ -e "$layouts_path/predefined.layout" ]] && ret+=" predefined"
          [[ -e "$TMUX_SESSION_PATH/windows.save" ]] && ret+=" windows.save"
          ret+=" $(get-file-list '*.layout' | sed -e 's/^/.\//' -e 's/\.layout//g')"
          ret+=" $(get-file-list -d --pwd $layouts_path '*.layout' | head -n4 | sed -e 's/\.layout//g')"
          echo "$ret"
          return 0
          ;; # }}}
        --check) # {{{
          echo ret="PATH";; # }}}
        *)  # {{{
          case $4 in
          --l-dump | --l-restore | ld | lr) ret="--all -v --check --file . - $(tmux display-message -pF '#S #S:* #S:#W')";;
          --l-edit) ret="--file .";;
          esac;; # }}}
        esac;;& # }}}
      --l-dump | ld) # {{{
        ret+=" --paths --no-paths --ignore-backup -d --default -w"
        [[ -e $lFile ]] && ret+=" $(awk '!/^#/ && /^[^:]* /{print $1}' "$lFile")"
        ;; # }}}
      --l-restore | lr) # {{{
        ret+=" --all-all --cd --acd --mcd --no-cd --match -d --default -w -wd --choose --dst --set-pane-1 --no-pane-1"
        [[ " $@ " =~ \ --file\ +([^\ ]+) ]] && lFile="${BASH_REMATCH[1]}"
        case $lFile in
        l)            lFile="$layouts_path/l.layout";;
        predefined)   lFile="$layouts_path/predefined.layout";;
        windows.save) lFile="$TMUX_SESSION_PATH/$lFile";;
        */*)          ;;
        -)            ;;
        *)            lFile="$layouts_path/$lFile";;
        esac
        [[ -e "$lFile" ]] && ret+=" $(sed -e '/^#/d' -e '/^-/d' $lFile | awk '{print $1}')"
        ;; # }}}
      --layout | l) # {{{
        ret=" --swap -s"
        ret+=" orig o next n prev p save s even-horizontal even-vertical main-horizontal h main-vertical v tiled";; # }}}
      --switch) # {{{
        echo "--get"
        tmux list-panes -a -F '#S:#I.#P';; # }}}
      esac
    fi
    echo -e "$ret"
    return 0
  fi # }}}
  local title= inBackground=false utils= nest=false cmd= silent=false
  if [[ -n $TMUX ]]; then # {{{
    if [[ -e "./.layout" ]]; then
      if [[ -z $1 ]]; then
        tm --l-dump . --ignore-backup "last"
        set -- --l-restore . -d
      elif [[ $1 == '-' ]]; then
        shift
      fi
    fi # }}}
  else # {{{
    [[ -z $1 ]] && set -- -a
  fi # }}}
  case $1 in # {{{
  pa) shift; set -- --pids -a "$@";;
  ss) shift; set -- --session --save "$@";;
  se) shift; set -- --session --edit "$@";;
  sd) shift; set -- --session --delete "$@";;
  sr) shift; set -- --session --restore "$@";;
  esac # }}}
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    ld | lr | l    | \
    -a | --attach  | \
    -p | --path    | \
    -b | --buffers | \
    -e | --env     | \
    --b-dump       | \
    --b-restore    | \
    --install      | \
    --l-dump       | \
    --l-restore    | \
    --l-edit       | \
    --layout       | \
    --pane         | \
    --pids         | \
    --new          | \
    --switch       | \
    --session      | \
    --exec)
          case $1 in # {{{
          -a) utils='attach';;
          -p) utils='path';;
          -b) utils='buffers';;
          -e) utils='env';;
          l)  utils='layout';;
          ld) utils='l-dump';;
          lr) utils='l-restore';;
          *)  utils="${1#--}";
          esac # }}}
          shift; break;;
    -d)             inBackground=true;;
    -n | --nest)    nest=true;;
    -s)             silent=true;;
    *)              break;;
    esac
    shift
  done # }}}
  [[ ! -z $utils ]] || return 1
  local var= i= buffer_fix='buffer'
  case $utils in # {{{
  session) # {{{
    local dst="$TMUX_SESSION_PATH/windows.save"
    local name=$(tmux display-message -pF '#S:#W')
    case $1 in
    -s | --save) # {{{
      update-file $dst --update-line "^$name " "$(tm --l-dump --file -)";; # }}}
    -d | --delete) # {{{
      update-file $dst --remove-line "^$name ";; # }}}
    -e | --edit) # {{{
      vim $dst;; # }}}
    -r | --restore) # {{{
      shift
      tm --l-restore --file $dst --set-pane-1 "$@";; # }}}
    esac
    return 0;; # }}}
  env) # {{{
    local pGlob='-g' verbose=false
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      -w) pGlob=;;
      -v) verbose=true;;
      *)  break;;
      esac; shift
    done # }}}
    while [[ ! -z $1 ]]; do # {{{
      local i=$1 v= p=$pGlob w= e=; shift
      [[ $i == *=* ]] && v=${i#*=} && i=${i%%=*}
      w="$(tmux show-environment $p $i 2>/dev/null)"; e=$?
      if [[ $e != 0 ]]; then
        w="$(tmux show-environment $i 2>/dev/null)" && p=
      fi
      [[ $e == 0 ]] && $verbose && echor "Current value$([[ $p != '-g' ]] && echo " (-w)") : $w"
      if [[ -z $v ]]; then # {{{
        if [[ $1 == '-v' ]]; then
          shift && v=$1 && shift
        else
          v=${!i}
        fi
      fi # }}}
      tmux set-environment $p $i "$v"
      $verbose && echor "New value$([[ $p != '-g' ]] && echo " (-w)")     : $(tmux show-environment $p $i 2>/dev/null)"
    done # }}}
    return 0;; # }}}
  layout) # {{{
    local toChange= layoutV="$(tmux show-window-options -v '@layout' 2>/dev/null)" swap=false
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      --swap | -s) swap=true;;
      *) toChange="$1";;
      esac
      shift
    done # }}}
    if [[ -z $toChange ]]; then
      [[ ! -z "$layoutV" ]] && toChange='orig' || toChange="main-horizontal"
    fi
    case $toChange in # {{{
    o | orig) [[ ! -z $layoutV ]] && tmux select-layout "$layoutV" \; set-window-option -u '@layout';;
    s | save) tmux set-window-option '@layout' "$(tmux display-message -pF '#{window_layout}')";;
    *) [[ -z $layoutV ]] && tmux set-window-option '@layout' "$(tmux display-message -pF '#{window_layout}')";;&
    n | next) tmux next-layout;;
    p | prev) tmux previous-layout;;
    h)        toChange='main-horizontal';;&
    v)        toChange='main-vertical';;&
    *)        tmux select-layout "$toChange"; $swap && tmux swap-pane -t .1 \; select-pane -t .1;;
    esac # }}}
    ;; # }}}
  l-edit) # {{{
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      .) lFile="./.layout";;
      --file) # {{{
        lFile="$2"; shift
        case $lFile in
        l)            lFile="$layouts_path/l.layout";;
        predefined)   lFile="$layouts_path/predefined.layout";;
        windows.save) lFile="$TMUX_SESSION_PATH/$lFile";;
        */*)          ;;
        -)            ;;
        *)            lFile="$layouts_path/$lFile";;
        esac;; # }}}
      esac; shift
    done # }}}
    [[ ! -e $lFile && $lFile != "-" ]] && echo "Layout file does not exist" && return 1
    if [[  $lFile == "-" ]]; then
      cat - | vim --fast
    else
      vim --fast "$lFile"
    fi
    return 0;; # }}}
  l-dump | l-restore) # {{{
    local session= wName= all=false firstMatch=true entry= lOrig= l= e= all_all=false entries= file= paths= do_cd= real_paths= verbose=false match= ignoreBackup=false
    local dst= wId= wNo= setPane1=false
    lFile=
    read session wNo wName wId lOrig <<<$(tmux display-message -t $TMUX_PANE -pF '#S #I #S:#W #{window_id} #{window_layout}')
    entry="${wName//[\/]/-}"
    [[ -z $1 && -e "./.layout" ]] && lFile="./.layout"
    [[ ! -e "$layouts_path" ]] && mkdir -p "$layouts_path"
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      .) lFile="./.layout"; real_paths=true;;
      -) lFile="$layouts_path/l.layout";;
      --check) # {{{
        lFile="${2:-.}/.layout"
        [[ -e "$lFile" ]] || return 1
        if [[ ! -z 3 ]]; then
          grep -q -i "$3 " "$lFile" || return 2
        fi
        return 0;; # }}}
      --file) # {{{
        lFile="$2"; shift
        case $lFile in
        l)            lFile="$layouts_path/l.layout";;
        predefined)   lFile="$layouts_path/predefined.layout";;
        windows.save) lFile="$TMUX_SESSION_PATH/$lFile";;
        */*)          ;;
        -)            ;;
        *)            lFile="$layouts_path/$lFile";;
        esac;; # }}}
      -v) # {{{
        verbose=true;; # }}}
      --ignore-backup) # {{{
        ignoreBackup=true;; # }}}
      *) # {{{
        case $utils in
        l-dump) # {{{
          case $1 in
          --all)      all=true;;
          --paths)    real_paths=true;;
          --no-paths) real_paths=false;;
          -d | --default | -w) # {{{
            [[ -z $lFile ]] && lFile="./.layout"
            case $1 in
            -d | --default)  entry="default";;
            -w)              entry="$wName";;
            esac
            silent=true; real_paths=true; ignoreBackup=true;; # }}}
          *) entry="$1"; [[ -z $real_paths ]] && real_paths=false;;
          esac;; # }}}
        l-restore) # {{{
          case $1 in
          --all)     all=true;;
          --all-all) all_all=true;;
          --cd)      do_cd='auto';;
          --acd)     do_cd='auto';;
          --mcd)     do_cd=true;;
          --no-cd)   do_cd=false;;
          --choose)  firstMatch=false;;
          --dst)     dst="$2"; shift;;
          --match)   match="$2"; shift;;
          --set-pane-1) setPane1=true;;
          --no-pane-1)  setPane1=false;;
          -d | --default | -w | -wd) # {{{
            [[ -z $lFile ]] && lFile="./.layout"
            [[ -e "$lFile" ]] || return 1
            case $1 in
            -d | --default)  entry="default";;
            -w)              entry="$wName";;
            -wd)             entry="$wName defalt";;
            esac
            silent=true; real_paths=true;; # }}}
          *) [[ $entry == 'default' ]] && entry="$@ $entry" || entry="$@"; shift $#;;
          esac # }}}
        esac;; # }}}
      esac
      shift
    done # }}}
    case $utils in # {{{
    l-dump) # {{{
      [[ -z $real_paths ]] && real_paths=true
      [[ ! -t 1 ]] && lFile="/dev/stdout"
      [[ "$lFile" == '-' ]] && lFile='/dev/stdout'
      ;; # }}}
    l-restore) # {{{
      [[ -z $do_cd ]] && do_cd='auto'
      [[ ! -t 0 ]] && lFile="/dev/stdin"
      [[ "$lFile" == '-' ]] && lFile='/dev/stdin'
      [[ -z $dst ]] && dst=$session:$wNo
      ;; # }}}
    esac # }}}
    ;;& # }}}
  l-dump) # {{{
    [[ -z $lFile && -e './.layout' ]] && lFile="./.layout"
    [[ -z $lFile ]] && lFile="$layouts_path/l.layout"
    if $all; then # {{{
      local lFileOld="${lFile%.layout}.backup-$(date +"$DATE_FMT").layout" wId=
      [[ -e "$lFile" ]] && mv "$lFile" "$lFileOld"
      echo -e "# vim ft=conf\n" >"$lFile"
      [[ -e $lFileOld ]] && { awk '!/^#/ && /^[^:]* /' "$lFileOld"; echo ""; } >>"$lFile"
      tmux list-windows -a -F '#S:#W #S:#I #{window_layout}' | while read wName wId layout; do
        echo "$wName $layout # $(\
          tmux list-panes -t "$wId" -F ':#{pane_current_path}:' \
          | sed -e 's/::/~/g' -e 's/://g' \
          | tr '\n' ':' \
          | sed -e "s|$HOME|~|g" -e 's/:$//' \
          )" >>"$lFile"
      done # }}}
    else # {{{
      if [[ "$lFile" != '/dev/stdout' ]]; then # {{{
        if [[ -e "$lFile" ]]; then # {{{
          if $ignoreBackup; then
            sed -i "/^$entry /d" "$lFile"
          else
            sed -i "s/^$entry /# $(date +"$DATE2_FMT") \0/" "$lFile"
          fi
        else
          echo -e "# vim ft=conf\n" >"$lFile"
        fi # }}}
      fi # }}}
      if $real_paths; then # {{{
        echo "$entry $lOrig # $( \
          tmux list-panes -t "$wId" -F ':#{pane_current_path}:' \
          | sed -e 's/::/~/g' -e 's/://g' \
          | tr '\n' ':' \
          | sed -e "s|$HOME|~|g" -e 's/:$//' \
          )" >>"$lFile"
          # }}}
      else # {{{
        echo "$entry $lOrig # $( \
          tmux list-panes -t "$wId" -F '-' \
          | tr '\n' ':' \
          | sed -e 's/:$//' \
          )" >>"$lFile"
      fi # }}}
    fi # }}}
    return 0;; # }}}
  l-restore) # {{{
    [[ -z $lFile && -e './.layout' ]] && lFile="./.layout"
    [[ -z $lFile ]] && lFile="$layouts_path/l.layout"
    if [[ "$lFile" != "/dev/stdin" ]]; then
      [[ ! -e "$lFile" ]] && echor -cn $silent "Layout file [$lFile] not exist" && return 1
      if $all_all; then # {{{
        file="$(sed -e '/^#/d' -e 's/\s\s\+/ /g' "$lFile" | sort -k1,1)"
        tmux list-windows -a -F '#S:#W #{window_layout}' | while read entry lOrig; do
          if [[ -z $match ]]; then
            entries="$entry ${entry%%:*}:\\* ${entry%%:*}"
          else
            entries="$match-$entry"
          fi
          for e in $entries; do
            e="$(echo -e "$file" | grep "^$e ")"
            [[ -z "$e" ]] && continue
            read l paths <<<$(echo -e "$e" | head -n1 | cut -d' ' -f2,4-)
            [[ -z "$l" ]] && continue
            [[ "$l" != "$lOrig" ]] || break
            tmux select-layout -t "$entry" "$l" >/dev/null 2>&1 && $verbose && echo "lOrig_$entry=\"$lOrig\" # $e"
            break
          done
        done
        return 0 # }}}
      elif $all; then # {{{
        entry="$(sed -e '/^#/d' -e '/^\s*$/d' -e 's/\s\s\+/ /g' -e 's/ .* # / # /' "$lFile" | sort -k1,1 | fzf -1 -0 | cut -d' ' -f1)"
        read l paths <<<$(sed -n -e '/^'"$entry"' /p' "$lFile" | head -n1 | cut -d' ' -f2,4-) # }}}
      else # {{{
        local out= e_out=
        if [[ "$entry" == "$wName" ]]; then
          entries="$entry default $session:\\* $session@.* $session $(awk '!/^#/ && /^[^:]* / {print $1}' "$lFile")"
        else
          [[ -z "$entry" ]] && entry="$wName"
          entries="$entry default"
        fi
        # out="$(sed -n -e '/^# \([0-9]\+\) \('"${entry//\//\\/}"'\) \(.*\)/s/^# \([0-9]\+\) \('"${entry//\//\\/}"'\) \(.*\)/\2@\1 \3/p' "$lFile")"
        [[ ! -z $out ]] && out+="\n"
        for e in $entries; do
          e_out="$(grep -i "$e " "$lFile")"
          [[ -z "$e_out" ]] && continue
          if $firstMatch; then
            out+="$(echo "$e_out" | grep -v "^#")\n"
          else
            out+="$e_out\n"
          fi
          [[ $entry == *' '* ]] && break
        done
        [[ -z "$out" && "$entries" == 'default' ]] && out="$(grep -i "$wName " "$lFile")"
        out="$(echo -e "$out" | sed -e 's/\s\s\+/ /g')"
        if $firstMatch; then
          local _out="$(echo -e "$out" | grep "^$entry " | tail -n1)"
          [[ ! -z $_out ]] || _out="$(echo -e "$out" | sed -e '/^#/d' | tail -n1)"
          [[ ! -z $_out ]] && out="$_out" || { echor "cannot find entry"; out=""; }
        fi
        entry="$(echo -e "$out" | sed -e '/^#/d' -e '/^\s*$/d' -e 's/ .* # / # /' | sort -k1,1 -u | fzf -1 -0 | cut -d' ' -f1)"
        [[ "$entry" =~ ^(.*)@([0-9]+)$ ]] && entry="# ${BASH_REMATCH[2]} ${BASH_REMATCH[1]}"
        read l paths <<<$(echo -e "$out" | sed -n -e '/^#/d' -e '/^ /d' -e '/^'"$entry"' /p' | head -n1 | cut -d' ' -f2,4-)
      fi # }}}
    else
      read l paths <<<$(cat - | sed -n -e 's/\s\s\+/ /g' -e '/.* # .*/s|\(.* \)\{0,1\}\(.*\) # \(.*\)|\2 \3|p;t;' -e 's|\(.* \)\{0,1\}\(.*\)|\2|p')
    fi
    [[ -z "$l" ]] && echor -cn $silent "No layout found (entries: $entries)" && return 1
    local err=0
    if [[ ! -z $paths ]]; then # {{{
      local pDiff= pNow="$(tmux list-panes -t "$wName" -F '#{pane_current_path}' | tr '\n' ' ' | sed -e "s|$HOME|~|g" -e 's/\s\+$//' -e 's/ \+/:/g')" i=
      IFS=':' read -a pNow <<<$(echo "$pNow")
      IFS=':' read -a paths <<<$(echo "$paths")
      if [[ $err != 0 || ${#paths[*]} != ${#pNow[*]} ]]; then # {{{
        if [[ $do_cd == 'auto' ]]; then # {{{
          local pd=$((${#paths[*]} - ${#pNow[*]}))
          if [[ $pd -lt 0 ]]; then # {{{
            pd=$((-$pd))
            for i in $(seq 1 $pd); do
              [[ $(tmux display-message -t ".$i" -pF '#{pane_active}') == 1 ]] && i=$((i+1))
              tmux kill-pane -t $dst.$i
            done
          elif [[ $pd -gt 0 ]]; then
            for i in $(seq 1 $pd); do
              tmux split-window -t $dst -l 3 -d
              sleep 0.3
            done
          fi # }}}
        else
          echor -cn $silent "Different number of panes (${#paths[*]} vs ${#pNow[*]})"
        fi # }}}
      fi # }}}
      for i in ${!paths[*]}; do # {{{
        [[ ${paths[i]} == ${pNow[i]} || ${paths[i]} == '-' ]] && continue
        if [[ $do_cd == 'true' || $do_cd == 'auto' ]]; then
          if [[ $i -lt ${#pNow[*]} || $do_cd == 'auto' ]]; then
            local paneNo=$((i+1))
            local panePids="$(unset -f tm; pstree $(tmux display-message -t ".$paneNo" -pF '#{pane_pid}') | wc -l | xargs)"
            paths[i]="${paths[i]/\~/$HOME}"
            if [[ $panePids == 1 ]]; then
              tmux send-keys -t "$dst.$paneNo" " cd \"${paths[i]}\"; clear"
            elif ${setPane1:-false} && [[ $paneNo == 1 ]]; then
              tmux send-keys -t "$dst.$paneNo" " cd \"${paths[i]}\"; clear"
            else
              echor -c $verbose "pane[$paneNo]: skipping cd to '${paths[i]}'"
            fi
          fi
        else
          pDiff+="  $((i+1)): ${paths[i]}\n"
        fi
      done # }}}
      if [[ $do_cd == 'false' && ! -z $pDiff ]] && $verbose; then # {{{
        echo -en "Paths:\n$pDiff"
      fi # }}}
    fi # }}}
    [[ "$l" != "$lOrig" ]] && { tmux select-layout -t $dst "$l" >/dev/null 2>&1; err=$?; }
    [[ $err == 0 && "${l#*,}" != "${lOrig#*,}" ]] && $verbose && echo "lOrig=\"$lOrig\""
    return $err;; # }}}
  b-dump) # {{{
    if [[ ! -z $1 ]]; then
      buffers_path+="/$1"
      shift
    else
      buffers_path+="/$(date +"$DATE_FMT")"
    fi
    rm -rf $buffers_path
    ;;& # }}}
  b-restore) # {{{
    if [[ ! -z $1 ]]; then
      buffers_path+="/$1"
      shift
    else
      buffers_path+="/$(cd $buffers_path; ls -Adt * | tail -n1)"
    fi
    [[ ! -d $buffers_path ]] && echor -cn $silent "Buffer directory [$buffers_path] does not exis" && return 1
    buffers_path+="/restore.backup"
    ;;& # }}}
  b-restore | b-dump) # {{{
    mkdir -p $buffers_path
    local var=0
    for i in $(tmux list-buffers -F '#{buffer_name}' | grep "^buffer[0-9]\+" | sort); do
      tmux save-buffer -b $i $buffers_path/buffer$(printf "%04d" "$var").$buffer_fix
      var=$(($var+1))
    done
    ;;& # }}}
  b-restore) # {{{
    buffers_path="${buffers_path%/*}"
    for i in $(tmux list-buffers -F '#{buffer_name}' | grep "^buffer[0-9]\+"); do
      tmux delete-buffer -b $i >/dev/null 2>&1
    done
    for i in $(cd $buffers_path; ls *.$buffer_fix); do
      tmux load-buffer -b ${i%.$buffer_fix} $buffers_path/$i
    done
    ;; # }}}
  buffers) # {{{
    local buffers_path=$RUNTIME_PATH/tmux-buffers
    local tmp_buffer_file=$TMP_MEM_PATH/tmux-organize.tmp
    local to_remove=" $(tmux list-buffers -F '#{buffer_name}' | tr '\n' ' ') "
    tmux list-buffers -F '#{buffer_name}: #{buffer_sample}' | sed 's/^/pick /' >$tmp_buffer_file # {{{
    if [[ $(cd $buffers_path; echo .*.buffer) != '.*.buffer' ]]; then # {{{
      (
        echo
        echo "# Stored, hidden buffers:"
        for i in $(cd $buffers_path; ls .*.buffer | sed -e 's/^\.//' -e 's/\.buffer//'); do
          echo "# unhide $i: $(head -n1 $buffers_path/.$i.buffer)"
        done
      ) >>$tmp_buffer_file
    fi # }}}
    # Description # {{{
    (
      echo
      echo "# Commands:"
      echo "# p, pick = leave buffer as it is"
      echo "# e, edit = edit buffer's name and content, and save if not starts with '$buffer_fix'"
      echo "# r, rename = rename buffer and save if not starts with '$buffer_fix'"
      echo "# d, drop = remove buffer, also from filesystem if was saved"
      echo "# h, hide = remove buffer, hide on filesystem if was saved"
      echo "# u, unhide = add stored, hidden buffer"
      echo "# a, add = add buffer and save if not starts with '$buffer_fix'"
      echo "# s, save = save buffer if not starts with '$buffer_fix'"
      echo
    ) >> $tmp_buffer_file # }}} # }}}
    vim $tmp_buffer_file || return 0
    local b_cmd=, b_name= b_buf= line= b_new_name=
    local lines=()
    i=0
    while read line; do
      lines[$i]="$line"
      i=$(($i+1))
    done < <(cat $tmp_buffer_file | sed -e '/^\s*$/ d' -e '/^#.*/ d')
    i=0
    while [[ $i -lt ${#lines[*]} ]]; do # {{{
      line=${lines[$i]}
      i=$(($i+1))
      [[ -z $line ]] && continue
      b_cmd=$line b_name=$line b_buf=$line
      b_cmd=${b_cmd%% *}
      b_name=${b_name#$b_cmd} b_name=${b_name# } b_name=${b_name%%:*}
      b_buf=${b_buf#$b_cmd} b_buf=${b_buf# } b_buf=${b_buf#$b_name} b_buf=${b_buf#: }
      to_remove="${to_remove/ $b_name / }"
      case $b_cmd in # {{{
      p | pick) # {{{
        ;; # }}}
      d | drop) # {{{
        to_remove+="$b_name "
        ;; # }}}
      h | hide) # {{{
        to_remove+="@@$b_name "
        ;; # }}}
      u | unhide) # {{{
        mv $buffers_path/.$b_name.$buffer_fix $buffers_path/$b_name.$buffer_fix
        tmux load-buffer -b $b_name $buffers_path/$b_name.$buffer_fix
        ;; # }}}
      # Common: edit/rename/add: Make file header # {{{
      e | edit   | \
      r | rename | \
      a | add    )
        local function=
        case $b_cmd in
          e | edit   ) function='edit';;
          r | rename ) function='rename';;
          a | add    ) function='add';;
        esac
        (
          echo "${b_name:-$buffer_fix-$(date +"$DATE_FMT")}"
          echo
          echo "# Buffer to $function:"
        ) >$tmp_buffer_file
        ;;& # }}}
      # Common: edit/rename: Do job # {{{
      e | edit   | \
      r | rename )
        local function=
        case $b_cmd in
          e | edit   ) function='edit';;
          r | rename ) function='rename';;
        esac
        tmux show-buffer -b $b_name >>$tmp_buffer_file
        vim $tmp_buffer_file || continue
        b_new_name="$(head -n 1 $tmp_buffer_file)"
        [[ -z $b_new_name || $b_new_name == \#* ]] && continue
        [[ $function == 'rename' && $b_new_name == $b_name ]] && continue
        if [[ $b_new_name != $b_name ]]; then
          tmux show-buffer -b $b_new_name >/dev/null 2>&1 && continue
          tmux set-buffer -b $b_name -n $b_new_name
          rm -f $buffers_path/$b_name.$buffer_fix
          b_name=$b_new_name
        fi
        ;;& # }}}
      a | add) # {{{
        if [[ ! -z $b_buf ]]; then
          echo -en "$b_buf" >> $tmp_buffer_file
        else
          vim $tmp_buffer_file || continue
        fi
        b_name="$(head -n 1 $tmp_buffer_file)"
        [[ -z $b_name || $b_name == \#* ]] && continue
        ;;& # }}}
      # Common: edit/add: Load buffer from file # {{{
      e | edit | \
      a | add  )
        tail -n +4 $tmp_buffer_file >$tmp_buffer_file.tmp
        mv $tmp_buffer_file.tmp $tmp_buffer_file
        if [[ $(wc -l $tmp_buffer_file | cut -d\  -f1) -le 3 ]]; then
          tmux set-buffer -b $b_name "$(echo -n "$(cat $tmp_buffer_file)")"
        else
          tmux load-buffer -b $b_name $tmp_buffer_file
        fi
        ;;& # }}}
      # Common: save/edit/rename/add: Save buffer # {{{
      s | save   | \
      e | edit   | \
      r | rename | \
      a | add    )
        [[ $b_name != $buffer_fix* ]] && tmux save-buffer -b $b_name $buffers_path/$b_name.$buffer_fix
        ;; # }}}
      esac # }}}
    done # }}}
    for b_name in $to_remove; do # {{{
      tmux delete-buffer -b ${b_name#@@} >/dev/null 2>&1
      if [[ $b_name != @@* ]]; then
        rm -f $buffers_path/$b_name.$buffer_fix
      else
        mv $buffers_path/${b_name#@@}.$buffer_fix $buffers_path/.${b_name#@@}.$buffer_fix
      fi
    done # }}}
    return 0
    ;; # }}}
  attach) # {{{
    var=${1^^}
    if [[ -z $var ]] || ! tmux has-session -t $var 1>/dev/null 2>&1; then
      [[ -e $TMP_PATH/.tmux_last_session.$USER ]] && var="$(cat $TMP_PATH/.tmux_last_session.$USER)"
      if [[ -z $var ]] || ! tmux has-session -t $var 1>/dev/null 2>&1; then
        var=${TMUX_SESSION_DEFAULT:-'MAIN'}
      fi
    fi
    ! tmux has-session -t $var >/dev/null 2>&1 && echor -cn $silent "Session [$var] not found" && return 1
    if [[ -n $TMUX ]]; then
      [[ -z $var ]] && return 1
      if $nest; then
        tmux set-option -t "$var" -q @master_pane $TMUX_SESSION
        tmux set-option -t "$(tmux display-message -p -t $TMUX_PANE -F '#S:#I')" -qw @marked_pane $(tmux display-message -p -t $TMUX_PANE -F '#P')
        set-title --from-tmux "$(tmux display-message -p -t $TMUX_PANE -F '#S:#I')" "$var"
        cmd="TMUX= tmux attach-session -t \"$var\""
      else
        cmd="tmux switch-client -t \"$var\""
      fi
    else
      cmd='tmux attach'
      [[ ! -z $var ]] && cmd+=" -t \"$var\""
    fi
    ;; # }}}
  path) # {{{
    [[ -n $TMUX ]] || return 1
    var=${1:-$PWD}
    [[ -d $var ]] || return 1
    cmd="tmux set -q @tmux_path \"$var\""
    ;; # }}}
  install) # {{{
    [[ -n $TMUX ]] || return 1
    cmd="tmux run-shell \"~/.tmux/plugins/tpm/scripts/update_plugin_prompt.sh\""
    ;; # }}}
  exec) # {{{
    [[ -n $TMUX ]] || return 1
    [[ ! -z $1 ]] || return 1
    local message="$@"
    var="$TMUX_SESSION"
    local w= p=
    for w in $(tmux list-windows -t $var | cut -d: -f1 ); do
      for p in $(tmux list-panes -t $var:$w | cut -d: -f1 ); do
        tmux send-keys -t $var:$w.$p -l "$message"
      done
    done
    ;; # }}}
  new) # {{{
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      *) title="$1";;
      esac; shift
    done # }}}
    if [[ -z $title ]]; then # {{{
      title=${PWD//\/*\//}
      [[ "$PWD" == "$HOME" ]] && title="\"~\""
    fi # }}}
    title="${title^^}"
    local params='new-session'
    local params_set=
    local fix_for_v16=
    case $(tmux -V) in # {{{
    *1.6) if tmux has-session -t $title 2>/dev/null; then
            params="attach-session -t $title"
          else
            params+=" -s $title"
            fix_for_v16="&& tmux attach-session -t $title"
          fi
          ;;
    *)    params+=' -A'
          params+=" -s $title"
          params_set+=' -q'
          ;;
    esac # }}}
    local switchTo=false
    if $inBackground; then # {{{
      params+=' -d'
    elif [[ -n $TMUX ]]; then
      switchTo=true
      params+=' -d'
    fi # }}}
    cmd+=" tmux $params \; set -t $title $params_set @tmux_path \"$PWD\""
    cmd+=" $fix_for_v16"
    echormf "$cmd"
    local pid=$$
    [[ $(ps | grep $pid) == *aliases* ]] && pid=$PPID
    trap "kill -SIGHUP $pid" SIGHUP
    ( unset TMUX; eval $cmd; )
    if $switchTo; then # {{{
      cmd="tmux switch-client -t $title"
      echormf "$cmd"
      eval $cmd
    fi # }}}
    return 0
    ;; # }}}
  pane) # {{{
    [[ -z $1 || -z $2 ]] && return 1
    local p= i=
    case $1 in
    \?\?) p=$(tmux list-panes -a      -F '#S:#I.#P #T' | grep -P "^.*:\d+\.\d+ $2$" | head -n1 | awk '{print $1}');;
    \?)   p=$(tmux list-panes -s      -F '#S:#I.#P #T' | grep -P "^.*:\d+\.\d+ $2$" | head -n1 | awk '{print $1}');;
    *)    p=$(tmux list-panes -t "$1" -F '#S:#I.#P #T' | grep -P "^.*:\d+\.\d+ $2$" | head -n1 | awk '{print $1}');;
    esac
    [[ -z $p ]] && return 1
    shift 2
    [[ -z $1 ]] && echo "$p" && return 0
    for i; do
      [[ $i == '-' || ${i,,} == 'nl' ]] && i=""
      tmux send-keys -t $p "$(echo -e "${i//\\n/}")"
    done
    ;; # }}}
  switch) # {{{
    local getCurrent=false dstId=
    while [[ ! -z $1 ]]; do
      case $1 in
      --get) getCurrent=true;;
      *)     dstId="$1"; break
      esac; shift
    done
    [[ ! -z $dstId ]] || return 1
    local currS= currW= currP= currId=
    if $getCurrent; then
      local  currTty=$(tty)
      if [[ $currTty == /dev/* ]]; then
        currId=$(tmux list-panes -a -F '#{pane_tty} #{pane_id}' | awk '/^'"${currTty//\//\\/}"' / {print $2}')
      else
        currS=$(tmux display-message -pF '#{client_session}')
        currW=$(tmux display-message -t $currS -pF '#{active_window_index}')
        currP=$(tmux list-panes -t $currS:$curW -F '#{pane_active} #P' | awk '/^1 / {print $2}')
        currId=$(tmux list-panes -a -F '#S:#I.#P: :: #{pane_id}' | sed -n '/^'"$currS:$currW.$currP"':/s/.* :: //p')
      fi
      echo "$currId"
    fi
    case $dstId in
    %*) ;;
    *)  dstId="$(tmux list-panes -a -F '#S:#I.#P :: #{pane_id}' | sed -n '/^'"$dstId"' ::  /s/.*:: //p' | head -n1)"
    esac
    [[ ! -z $dstId ]] && tmux switch-client -t "$dstId"
    return 0;; # }}}
  pids) # {{{
    local pane= tmuxParams= paneId="#P" pidParam="pid=,cmd=" full=false sortParams="-k2,2n"
    $IS_MAC && pidParam="pid=,command="
    while [[ ! -z $1 ]]; do
      case $1 in
      -f) full=true;;
      -a) tmuxParams="-a"; sortParams="-k2,2"; paneId="#S:#I.#P";;
      -s) tmuxParams="-s"; sortParams="-k2,2"; paneId="#I.#P";;
      esac; shift
    done
    pane=$(
      i= pPid= pId= pTitle= pTty= pPath= pidInfo=
      tmux list-panes $tmuxParams -F 'pPid="#{pane_pid}"; pId="'"$paneId"'"; pTitle="#{=15:pane_title}"; pTty="#{s|/dev/||:pane_tty}"; pPath="#{pane_current_path}"' \
      | while read i; do
          eval $i
          pidInfo=$(ps -g $pPid -o $pidParam | sed -n 2p | awk '{print $1,$3}')
          if [[ ! -z $pidInfo ]]; then
            lPid=${pidInfo%% *}
            pidInfo=${pidInfo#* }
            [[ -z $pidInfo ]] && pidInfo='cli'
            if ! $full; then
              pPid=$lPid
              pidInfo=${pidInfo##*/}
            else
              pidInfo="$pidInfo@$lPid"
            fi
          fi
          if ! $full; then
            echo "$pPid $pId ${pidInfo:--} $pPath"
          else
            echo "$pPid $pId ${pidInfo:--} ${pTitle// /-} $pTty $pPath"
          fi
        done \
      | sort $sortParams \
      | sed -e 's|'"$HOME"'|~|g' \
      | column -t | fzf)
    [[ $? != 0 || -z $pane ]] && return 0
    if ! $full; then
      echo "$pane" | awk '{print $1}' | tr '\n' ' '
    else
      local tmp= pPid pidInfo=
      echo "$pane" | while read pPid tmp pidInfo tmp; do
        [[ $pidInfo == *@* ]] && pPid=${pidInfo##*@}
        echo "$pPid"
      done | tr '\n' ' '
    fi
    return 0;; # }}}
  esac # }}}
  if [[ ! -z $cmd ]]; then # {{{
    echo $cmd
    eval $cmd
  fi # }}}
} # }}}
_tm "$@"

