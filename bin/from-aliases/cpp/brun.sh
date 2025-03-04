#!/usr/bin/env bash
# vim: fdl=0

_brun() { # @@ # {{{
  if [[ $1 == '@@' ]]; then # {{{
    if [[ $2 == --shorts ]]; then # {{{
      local f=$(get-file-list -t -1 '*.cpp')
      [[ -z $f ]] && f=$(get-file-list -t -1 '*.c')
      [[ ! -z $f ]] && echo "lo --loop -lpthread $f"
      return 0
    fi # }}}
    case $3 in
    --conf) echo "${!BRUN_CONF_*}" | sed 's/BRUN_CONF_//g' | tr 'A-Z' 'a-z' ;;
    --check-files) echo "@@-f";;
    *)
      echo "-- -V -G -R -r -l --conf -c --run --no-run --loop --check-files -s -v --clang --no-clear"
      echo "-lpthread"
      echo "$(get-file-list '*.c') $(get-file-list '*.cpp') $(get-file-list '*.sh')"
      [[ $2 != -- ]] && compl-short --shorts
      ;;
    esac
    return 0
  fi # }}}
  local f= p= o= clangCmd="clang++ $CLANGPP_PARAMS $CLANG_PARAMS_COMMON $CLANG_PARAMS_W" run=true compile=true new_params= args= s= loop=false loop_delay=${BRUN_LOOP_DELAY:-2} key= modTime= sum= err= autoClear=true
  local valgrind=false gdb=false
  local filesToCheck="$BRUN_CHECK_FILES"
  eval set -- $(compl-short --shorts --args "$@")
  case $@ in # {{{
  --\ *) set -- --run ${BRUN_PARAMS%% -- *} $@;;
  -c | --no-run) set -- -c ${BRUN_PARAMS%% -- *};;
  -r | --run | -q | -v) # {{{
    set -- $@ $BRUN_PARAMS;; # }}}
  esac # }}}
  [[ -z $1 ]] && set -- $BRUN_PARAMS ## Required to capture file
  [[ -z $1 ]] && set -- $BRUN_PARAMS_DEFAULT
  while [[ ! -z $1 ]]; do # {{{
    case $1 in # {{{
    # Internal switches # {{{
    -q) echormf -M -;;&
    -v) echormf -M +;;&
    -V) valgrind=true;;&
    -G) gdb=true;;&
    -R) BRUN_PARAMS=""; [[ -z $2 ]] && return 0;;&
    -c | --no-run) run=false;;&
    -r | --run)    compile=false; run=true;;&
    -l | --loop)   loop=true;;&
    --check-files) filesToCheck="$2"; shift;;&
    --no-clear)    autoClear=false;;&
    -lpthread)     clangCmd+=" -lpthread";;
    -q | -v | -V | -G | -R | -c | --no-run | -r | --run | -lpthread) # {{{
      s+=" $1";& # }}}
    -l | --loop | --check-files | --no-clear) # {{{
      shift; continue;; # }}}
    --conf) # {{{
      local conf="$(eval echo "\$BRUN_CONF_${2^^}")"
      [[ -z "$conf" ]] && echor "Configuration not found" && return 1
      shift 2
      [[ ! -z "$1" ]] && conf="${conf%% -- *} --no-run"
      brun $s $conf $p
      [[ $? != 0 ]] && return 1
      [[ -z $1 ]] && return 0
      brun $@
      return $?
      ;; # }}}
    --clang) clangCmd="clang $CLANG_PARAMS $CLANG_PARAMS_COMMON $CLANG_PARAMS_W";;
    # }}}
    *.c | *.cpp | *.sh) # {{{
      if [[ -z $f ]]; then
        f="$1"
        if [[ -d ${f%.*} ]]; then
          p+=" $(find ${f%.*} -name \*.${f##*.} | tr '\n' ' ')"
        else
          filesToCheck+=" $1"
        fi
      else
        p+=" $1"
        filesToCheck+=" $1"
      fi;; # }}}
    --);;
    --*) p+=" ${1#-}";;
    *)   p+=" $1";;
    esac # }}}
    case $1 in # {{{
    --)  new_params+=" $@"; shift; args="$@"; shift $#;;
    --*) new_params+=" ${1#-}";;
    *)   new_params+=" $1";;
    esac # }}}
    shift
  done # }}}
  if [[ -z $f ]]; then # {{{
    local f="$(get-file-list -t -1 '*.cpp')"
    local fC="$(get-file-list -t -1 '*.c')"
    if [[ ! -z $fC ]]; then
      [[ -z $f || $(file-stat $fC) -gt $(file-stat $f) ]] && f=$fC
    fi
    [[ -z $f ]] && echor "No file was found" && return 1
    progress --msg "Auto chosen file [$f] proceed?" --key --dots --cnt 40 || return 0
    new_params+=" $f"
  fi # }}}
  [[ ! -e $f ]] && echor "File [$f] does not exist" && return 1
  [[ ! -z $new_params ]] && export BRUN_PARAMS="$new_params"
  [[ -z $filesToCheck ]] && filesToCheck="$f"
  local pushed=false
  case $(echormf -f?; echo $?) in
  10)
    pushed=true
    echormf --push
    $loop && echormf -M - || echormf -M +
    ;;
  esac
  $loop && compile=true && run=true && modTime="$(stat -c %Y $filesToCheck 2>/dev/null)" && sum="$(sha1sum $filesToCheck 2>/dev/null)"
  [[ -z "$COff" ]] && source $BASH_PATH/colors
  if [[ "$f" == *".sh" ]]; then
    o="${f/.\/}"
    clangCmd="$SHELL"
    compile=false
    run=true
    loop=true
  else
    if $gdb; then
      local gdb_params="${BRUN_GDB_PARAMS}"
      [[ -z $gdb_params ]] && gdb_params="-O0 -g -ggdb3 -gdwarf-5"
      clangCmd+=" $gdb_params"
    fi
    if [[ ! " $p " =~ \ -o\ +([^ ]+)\  ]]; then # {{{
      o="${f%.*}.out"
      p+=" -o $o"
    else
      o="${BASH_REMATCH[1]}"
      case $o in
      *.a | *.so | *.so.*)
        [[ " $p " != *" -c "* ]] && p="-c $p"
        run=false;;
      esac
    fi # }}}
    [[ $f == *.c && $clangCmd == *clang++* ]] && clangCmd+=" -Wno-deprecated"
  fi
  set-title "$(echo "${clangCmd/command }" | sed -e 's/-W[^ ]*//g' -e 's/  \+/ /g' -e 's/ $//') ${f# } ${p# }"
  local progr_colors=($CYellow $CPurple $CBlue   $CGreen ) progr_i=0 doClear=false first=true
  local   msg_colors=($CBlue   $CGreen  $CYellow $CPurple)
  while true; do # {{{
    err=0 err_run=0
    local c="${progr_colors[progr_i]}" force=false
    if $loop; then
      ( $doClear || $autoClear ) && clear
      doClear=false
      echor -e -nh "${c}---------------${COff}\n${msg_colors[progr_i]}$(date +"$TIME_FMT"): Start${COff}\n${c}---------------${COff}"
    fi
    ! $run && ! ${compile:-false} && compile=true
    $run && [[ ! -e $o ]] && compile=true
    if ${compile:-false} && [[ "$f" != *".sh" ]]; then # {{{
      echormf "# Compiling as"
      echormf "\$ $(echo "${clangCmd/command }" | sed -e 's/  \+/ /g' -e 's/ $//') ${f# } ${p# }"
      rm -f $o
      $clangCmd $f $p
      err=$?
    fi # }}}
    if $run && [[ $err == 0 ]]; then # {{{
      cmd="./${o#./}"
      if $valgrind; then
        cmd="valgrind $cmd"
      elif $gdb; then
        confFileF="${f%.*}.gdb"
        confFileM="gdb.conf"
        cmd="gdb$([[ -e $confFileF ]] && echo " -x $confFileF")$([[ -e $confFileM ]] && echo " -x $confFileM") --args $cmd"
      fi
      echormf "# Running as"
      echormf "\$ $cmd ${args:-\b}"
      $cmd $args
      err_run=$?
      err=$err_run
    fi # }}}
    ! $loop && break
    $first && first=false && echormf --push && echormf -M -
    compile=
    [[ $err != 0 ]] && c="$CRed"
    echor -n -nh "${c}---------------$([[ $err_run != 0 ]] && echor -nh " [$err_run]")${COff} "
    progress --mark --color "${progr_colors[progr_i]}" --dots --delay 0.5
    progr_i="$(((progr_i+1)%${#progr_colors[*]}))"
    while true; do # {{{
      if read -s -n1 -t $loop_delay key; then # {{{
        case ${key^^} in
        Q)       progress --unmark; break 2;;
        C)       compile=true;;
        R | '')  ;;
        *)       continue;;
        esac
        force=true
        doClear=true
      fi # }}}
      local modTime2="$(stat -c %Y $filesToCheck 2>/dev/null)" sum2="$(sha1sum $filesToCheck 2>/dev/null)"
      [[ "$modTime2" == "$modTime" ]] && ! $force && continue
      modTime="$modTime2"
      [[ -z $compile ]] && compile=false
      [[ "$sum2" != "$sum" ]] && sum="$sum2" && compile=true
      break
    done # }}}
    progress --unmark
  done # }}}
  $loop && ! $first && echormf --pop
  $pushed && echormf --pop
  [[ ! -z $state ]] && eval $(echo export $state)
  return $err
} # }}}
_brun "$@"

