#!/usr/bin/env bash
# vim: fdl=0

thisFile=$(readlink -f $0)
get-steps() { # {{{
  local prefix="${2:-install}"
  sed -n '/^\s*'"$prefix"'-.*()/ s/'"$prefix"'-\(.*\)().*/\1/p' $1
} # }}}
is-enabled() { # {{{
  local step=$1 list= checkList=false
  if (( $# == 2 )); then
    local -n list=$2
    checkList=true
  fi
  (
    ! $checkList || [[ -v list[$step] ]] || return 1
    for i in arch ubuntu mac; do
      [[ ! $step =~ "$i-" ]] || [[ $OS_KIND == "$i" ]] || return 1
    done
    [[ ! "-$step" =~ "-sudo" ]] || $useSudo || return 1
    [[ ! "-$step" =~ "-Nsudo" ]] || ! $useSudo || return 1
    [[ ! "-$step" =~ "-gui" ]] || $hasGui || return 1
    [[ ! "-$step" =~ "-Ngui" ]] || ! $hasGui || return 1
    [[ ! "-$step" =~ "-linux" ]] || $isLinux || return 1
    [[ ! "-$step" =~ "-Nlinux" ]] || ! $isLinux || return 1
    [[ ! "-$step" =~ "-docker" ]] || $IS_DOCKER || return 1
    [[ ! "-$step" =~ "-Ndocker" ]] || ! $IS_DOCKER || return 1
    [[ ! "-$step" =~ "-virtos" ]] || $IS_VIRTUAL_OS || return 1
    [[ ! "-$step" =~ "-Nvirtos" ]] || ! $IS_VIRTUAL_OS || return 1
    [[ ! "-$step" =~ "-wsl" ]] || $IS_WSL || return 1
    [[ ! "-$step" =~ "-Nwsl" ]] || ! $IS_WSL || return 1
    return 0
  ) || { log -s=$verbose "step $step disabled"; return 1; }
  return 0
} # }}}

if [[ $1 == "@@" ]]; then # @@:new # {{{
  [[ -n $APPS_CFG_PATH ]] || APPS_CFG_PATH=${RUNTIME_PATH:-$HOME/.runtime}/apps
  appPath="$APPS_CFG_PATH/setup-env"
  case " $@ " in
  *" --add-note "* | *" --add-update "*) # {{{
    case $2 in
    -p)
      echo "main app"
      [[ -e $RUNTIME_PATH/profiles ]] && ls $RUNTIME_PATH/profiles;;
    *)
      echo "-p"
      if [[ " $@ " == *" --add-note "* ]]; then
        echo "--edit NOTE"
      elif [[ " $@ " == *" --add-update "* ]]; then
        echo "NAME"
      fi
      ;;
    esac;; # }}}
  *) # {{{
    case $2 in
    -p) # {{{
      ret=
      for p in $SCRIPT_PATH/bash/profiles/*; do
        [[ -e $p/cfg ]] && ret+=" ${p##*/}"
      done
      echo "${ret:----}";; # }}}
    *) # {{{
      useSudo=${SETUP_ENV_USE_SUDO:-true}
      hasGui=${SETUP_ENV_HAS_GUI:-true}
      case $OS_KIND,$IS_VIRTUAL_OS in
      *,true) hasGui=false;;
      ubuntu,*) dpkg -l | grep -q "ubuntu-desktop" || hasGui=false;;
      *)
      esac
      case $OS_KIND in
      ubuntu | arch) isLinux=true;;
      *) isLinux=false;;
      esac
      log() { : ; }
      list=
      declare -A stepsList=()
      if [[ " $@ " == *" --update "* ]]; then
        steps=
        [[ -f $SCRIPT_PATH/inits/setup-env.to-apply ]] && steps+=" $(get-steps $SCRIPT_PATH/inits/setup-env.to-apply "update")"
        for p in $PROFILES_PATH/*; do # {{{
          f="$p/inits/setup-env.to-apply"
          [[ -f $f ]] && steps+=" $(get-steps $f "update")"
        done # }}}
        [[ -f $appPath/setup-env.to-apply ]] && steps+=" $(get-steps $appPath/setup-env.to-apply "update")"
        for s in $steps; do
          stepsList[$s]=
          is-enabled $s "stepsList" && list+=" $s"
        done
      else
        steps="$(get-steps $thisFile)"
        steps+=" $(get-steps $SCRIPT_PATH/inits/setup-env.conf)"
        for p in $PROFILES_PATH/*; do # {{{
          f="$p/inits/setup-env.conf"
          [[ -e $f ]] && steps+=" $(get-steps $f)"
        done # }}}
        [[ -e $appPath/setup-env.conf ]] && steps+=" $(get-steps $appPath/setup-env.conf)"
        if [[ " $@ " == *" -- "* ]]; then
          echo "$steps"
          exit 0
        fi
        compl-get-args "@@:main" < "$0"
        for s in $steps; do
          stepsList[$s]=
          is-enabled $s "stepsList" && list+=" $s"
        done
      fi
      echo "$list";; # }}}
    esac;; # }}}
  esac
  exit 0
fi # }}}

# functions # {{{
wide-print() { # {{{
  local w=$wideLen msg="$1"
  (( $# == 2 )) && { w=$1; msg="$2"; }
  printf "[ %-${w}s ]" "$msg"
} # }}}
log() { # {{{
  local module=${FUNCNAME[1]} onStderr=true
  case $module in
  source | main | '') module=;;
  *) module="${module#install-}: "
  esac
  while (( $# )); do
    case $1 in
    false) return;;
    true) ;;
    -s=false | -s=!true  | -s=0) onStderr=false;;
    -s=true  | -s=!false | -s=1) ;;
    -) module=;;
    *) break
    esac; shift
  done
  echo "$module$@" | tee -a $logFile | { if $onStderr; then cat - >&2; else cat - >/dev/null; fi; }
} # }}}
is-os-allowed() { # {{{
  local i= ret=0 caller=${FUNCNAME[1]} doLog=true
  declare -A hosts=()
  case $caller in
  source | '' | main) caller="?"; doLog=false;;
  esac
  log $doLog -s=$verbose "$caller - checking range: $@"
  for i; do
    case $i in
    +docker) $IS_DOCKER || ret=1;;
    -docker) ! $IS_DOCKER || ret=1;;
    +virt-os) $IS_VIRTUAL_OS || ret=1;;
    -virt-os) ! $IS_VIRTUAL_OS || ret=1;;
    +wsl) $IS_WSL || ret=1;;
    -wsl) ! $IS_WSL || ret=1;;
    +gui) $hasGui || ret=1;;
    -gui) ! $hasGui || ret=1;;
    +sudo) $useSudo || ret=1;;
    -sudo) ! $useSudo || ret=1;;
    +linux) $isLinux || ret=1;;
    -linux) ! $isLinux || ret=1;;
    +p=*) [[ " $profiles " == *" ${i#-p=} *" ]] || ret=1;;
    -p=*) ! [[ " $profiles " == *" ${i#-p=} *" ]] || ret=1;;
    *) hosts[$1]=;;
    esac
    (( ret == 0 )) || { log $doLog -s=$verbose "$caller - not allowed due to $i"; return 1; }
  done
  [[ -z $hosts ]] || [[ -v hosts[$OS_KIND] ]] || { log $doLog -s=$verbose "$caller - not allowed due to OS: '$OS_KIND' not in '$hosts'"; return 1; }
  return 0
} # }}}
get-fingerprint() { # {{{
  sha1sum | cut -d' ' -f1
} # }}}
done-checker() { # {{{
  local mode=$1; shift
  local varName="stepsDone" prefix="install" file="$stepsDoneF" IFS=$IFS checkStepFile=true
  if [[ -n $DONE_PROPERTIES ]]; then
    IFS=$':' read -r varName prefix file <<<"$DONE_PROPERTIES"
    checkStepFile=false
  fi
  local -n ref=$varName
  local s=$(type $prefix-$1 | tail -n+2 | get-fingerprint)
  case $mode in
  mark-done)
    ref[$1]="$s"
    ref[zzz:$s]=
    (
      echo "declare -A $varName=()"
      for i in $(echo ${!ref[*]} | tr ' ' '\n' | sort); do
        echo "$varName[$i]=\"${ref[$i]}\""
      done
    ) >$file;;
  is-done)
    $checkStepFile && [[ -e $confDir/step-$1.done ]] && return 0
    [[ -v ref[zzz:$s] || ${ref[$1]} == $s ]];;
  esac
} # }}}
check-fingerprint() { # {{{
  local sumNew="$(echo "$1" | get-fingerprint)" sumF="$confDir/step-$2.done" sumOld=0
  [[ -e $sumF ]] && sumOld=$(< $sumF)
  $force || [[ $sumNew != $sumOld ]] || return 1
  echo "$sumNew" >$sumF
  $justMark && return 1
  return 0
} # }}}
bck() { # {{{
  local mode="backup" message=false
  while [[ -n $1 ]]; do
    case $1 in
    --clean) mode="cleaning";;
    --msg) message=true;;
    *) break;;
    esac; shift
  done
  local i=$1 iBak="$1-$installTS.bak"
  [[ -e $i ]] || return 0
  case $mode in
  backup)
    rm -f $i-*.bak
    if [[ ! -h $i && -s $i ]]; then
      iBak="$i-$installTS.bak"
      $message && log -s=$verbose "$i -> $iBak"
      mv $i $iBak
    else
      rm -f $i
    fi;;
  cleaning)
    if [[ -f $iBak ]]; then
      if [[ $(sha1sum $iBak | cut -d' ' -f1) == $(sha1sum $i | cut -d' ' -f1) ]]; then
        log -s=$verbose "cleaning backup: $iBak"
        rm -f $iBak
      else
        log "$i -> $iBak"
      fi
    fi;;
  esac
} # }}}
appender() { # {{{
  local src=$1 dst=$2 doLink=${3:-true} p= foundCount=0 lastFound= subPath="dot-files"
  bck $dst
  if [[ -e $SCRIPT_PATH/$subPath/$src ]]; then
    log -s=$verbose "$src - in root"
    if [[ -f $SCRIPT_PATH/$subPath/$src ]]; then
      (
        echo "### MAIN ### # {{{"
        cat $SCRIPT_PATH/$subPath/$src
        echo "# }}}"
      ) >>$dst
    else
      log -s=$verbose "$src - not a file"
    fi
    ((++foundCount))
    lastFound="$SCRIPT_PATH/$subPath/$src"
    onlyRoot=true
  fi
  for p in $profiles; do
    [[ -e $PROFILES_PATH/$p/$subPath/$src ]] || continue
    log -s=$verbose "$src - in $p"
    (
      echo "### $p ### # {{{"
      cat $PROFILES_PATH/$p/$subPath/$src
      echo "# }}}"
    ) >>$dst
    ((++foundCount))
    lastFound="$PROFILES_PATH/$p/$subPath/$src"
  done
  if [[ -e $appPath/dot-files/$src ]]; then
    log -s=$verbose "$src - in runtime"
    (
      echo "### runtime ### # {{{"
      cat $appPath/dot-files/$src
      echo "# }}}"
    ) >>$dst
    ((++foundCount))
    lastFound="$appPath/dot-files/$src"
  fi
  [[ ! -e $dst ]] || [[ -s $dst ]] || { log -s=$verbose "$src - not created or empty, ignoring"; return 1; }
  if (( foundCount == 1 )); then
    if $doLink; then
      log -s=$verbose "$src - just one found in $lastFound, linking"
      rm -f $dst
      ln -sf $lastFound $dst
    else
      ln -sf $lastFound $dst.lnk
    fi
  fi
  bck --clean $dst
} # }}}
find-file() { # {{{
  local file=$1 subPath="$2" i=
  local paths="$SCRIPT_PATH/$subPath"
  for i in $profiles; do
    paths+=" $PROFILES_PATH/$i/$subPath"
  done
  for i in $paths; do
    [[ -e $i/$file ]] && echo "$i/$file" && { log -s=$verbose "$file - found in $i ($subPath)"; return 0; }
  done
  log "$file - NOT found"
  return 1
} # }}}
include-config() { # {{{
  [[ -e $1 ]] || return
  source $1
  local -n ref=${3:-stepsAll}
  ref+=" $( get-steps $1 $2)"
} # }}}
os-install() { # {{{
  case $OS_KIND in
  ubuntu) sudo apt-get install -y --no-install-recommends --fix-missing "$@" || { log "apt failed"; return 1; };;
  arch) sudo pacman -Sy --needed "$@" || { log "pacman failed"; return 1; };;
  mac)
    if ${SETUP_ENV_BREW_SUDO:-false}; then
      brew install -y "$@" || { log "brew failed"; return 1; }
    else
      sudo brew install -y "$@" || { log "brew failed"; return 1; }
    fi;;
  *) log "undefined OS"; return 1;
  esac
} # }}}
check-list() { # {{{
  local name=$1 i= list=
  shift
  local -n refList=$name
  (( ${#refList[*]} )) || { log -s=$verbose - "nothing to install"; return 0; }
  for i in ${!refList[@]}; do
    list+=" ${refList[$i]:-$i}"
  done
  list="${list# }"
  check-fingerprint "$list" $name || { log -s=$verbose - "nothing new to install"; return 0; }
  echo "$list"
} # }}}
# }}}
# install steps: core & packages, order matters # {{{
install-packages() { # {{{
  local list=$(check-list packages)
  [[ -n $list ]] || return 0
  case $OS_KIND in
  ubuntu) # {{{
    is-os-allowed +sudo || { log "no sudo"; return 1; }
    if ! is-installed -w add-apt-repository; then
      log "no add-apt-repository, installing it first"
      sudo apt-get update
      sudo apt-get install -y --no-install-recommends --fix-missing software-properties-common
    fi
    declare -A apts=()
    apts[main]="-c"
    apts[universe]="-c"
    apts[restricted]="-c"
    apts[multiverse]="-c"
    local newList=
    for i in $list; do
      if [[ $i == *@* ]]; then
        apts[${i#*@}]="-P"
        i="${i%%@*}"
      fi
      newList+=" $i"
    done
    log "apts: ${!apts[*]}"
    for i in ${!apts[*]}; do
      sudo add-apt-repository -y ${apts[$i]} $i || { log "cannot add apt-repo: $i (${apts[$i]})"; return 1; }
    done
    list="$newList";; # }}}
  arch) # {{{
    is-os-allowed +sudo || { log "no sudo"; return 1; };; # }}}
  mac) # {{{
    is-installed brew || { log "no brew"; return 1; };; # }}}
  esac
  log -s=$verbose "$list"
  os-install $list || return 1
} # }}}
install-basics() { # {{{
  check-fingerprint "$(declare -p dotFilesBasicList)" basics || { log -s=$verbose "nothing new to install"; return 0; }
  install-dot-files "dotFilesBasicList"
  touch $HOME/.hushlogin
  local i=
  for i in $RUNTIME_PATH/*; do
    [[ -h $i && ! -e $i ]] && rm $i
  done
  [[ -e $RUNTIME_PATH/runtime-pre.mount ]] || ln -sf $SCRIPT_PATH/bash/runtime-pre.mount $RUNTIME_PATH/
  [[ -e $RUNTIME_PATH/runtime-pre.cfg ]] || cp $SCRIPT_PATH/bash/runtime-pre.cfg $RUNTIME_PATH/
  [[ -e $RUNTIME_PATH/runtime-pre.bash ]] || touch $RUNTIME_PATH/runtime-pre.bash
  rm -rf $PROFILES_PATH/*; mkdir -p $PROFILES_PATH
  for i in $profiles; do
    [[ ! -e $PROFILES_PATH/$i ]] || continue
    [[ -d $SCRIPT_PATH/bash/profiles/$i ]] || { log "profile '$i' does not exists"; return 1; }
    ln -sf $SCRIPT_PATH/bash/profiles/$i $PROFILES_PATH/$i
  done
} # }}}
install-bin-misc() { # {{{
  check-fingerprint "$(declare -p binMiscList)" bin-misc || { log -s=$verbose "nothing new to install"; return 0; }
  mkdir -p $BIN_PATH
  [[ -e $BIN_PATH/ticket-tool ]] || ln -sf $SCRIPT_PATH/bin/ticket-tool $BIN_PATH/
  for i in $BIN_PATH/*; do
    [[ -e $i ]] || rm $i
  done
  local f= j=
  for i in ${!binMiscList[*]}; do for j in ${binMiscList[$i]:-$i}; do
    [[ ! -e $BIN_PATH/$j ]] || continue
    f="$(find-file $j "bin/misc")" || { log "bin-misc $i/$j - not found"; return 1; }
    ln -sf $f $BIN_PATH/$j
  done; done
} # }}}
install-vim() { # {{{
  local vimPath=$ENV_PATH/vim
  ln -sf $vimPath/vimrc $HOME/.vimrc
  rm -rf $HOME/.vim
  ln -sf $vimPath/vim $HOME/.vim
  local binVimPath=$BIN_PATH/vims
  mkdir -p $binVimPath
  (
    cd $binVimPath
    ln -sf $vimPath/mvim ./
    for i in {,g,m,r}{vi,view,vim,vimdiff} vimdiffgit; do
      [[ "$i" == 'mvim' ]] && continue
      ln -sf mvim $i
    done
    ln -sf mvim vim-session
    ln -sf mvim vimS
    chmod +x $binVimPath/*
    (
      echo '#!/bin/bash'
      echo 'vim --editor "$@"'
    ) >vim-editor
    chmod +x vim-editor
  )
  appender "vim-specific" $HOME/.vimrc.specific || true
} # }}}
install-git() { # {{{
  if [[ ! -e $RUNTIME_PATH/gitconfig ]]; then
    (
      echo "[include]"
      for p in $profiles; do
        echo "  path = $PROFILES_PATH/$p/gitconfig"
      done
    ) >$RUNTIME_PATH/gitconfig
  fi
} # }}}
install-tmux() { # {{{
  [[ -e $HOME/.tmux/plugins/tpm ]] && return 0
  mkdir -p $HOME/.tmux/plugins
  tar xzf $SCRIPT_PATH/dot-files/tmux/tpm.tgz -C $HOME/.tmux/plugins
  # $HOME/.tmux/plugins/tpm/scripts/install_plugins.sh || return 1
} # }}}
install-tmux-fingers() { # {{{
  $force || [[ ! -e $HOME/.tmux/plugins/tmux-fingers ]] || return 0
  (
    cd $HOME/.tmux/plugins
    git clone https://git::@github.com/morantron/tmux-fingers || { log "cannot clone"; return 1; }
    set -e
    cd tmux-fingers
    if $IS_DOCKER && [[ $(uname -m) == 'aarch64' ]]; then
      is-os-allowed +sudo || return 1
      log "installing with crystal"
      sudo apt-get update
      which gpg >/dev/null 2>&1 || sudo apt-get install -y gpg
      curl -fsSL https://packagecloud.io/84codes/crystal/gpgkey | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/84codes_crystal.gpg > /dev/null
      . /etc/os-release
      echo "deb https://packagecloud.io/84codes/crystal/$ID $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/84codes_crystal.list
      sudo apt-get update
      sudo apt-get install -y crystal
      sudo rm -f /etc/apt/sources.list.d/84codes_crystal.list
      ./install-wizard.sh install-from-source
    else
      ./install-wizard.sh download-binary
    fi
  )
  (( $? == 0 )) || { "tmux-fingers: installation failed"; return 1; }
} # }}}
install-dot-files() { # {{{
  local -n list=${1:-dotFilesList}
  (( ${#list[*]} )) || { log -s=$verbose "nothing to install"; return 0; }
  if [[ -z $1 ]]; then
    check-fingerprint "$(declare -p dotFilesList)" dot-files || { log -s=$verbose "nothing new to install"; return 0; }
  fi
  local i=
  log -s=$verbose "list: $(declare -p list)"
  for i in ${!list[*]}; do
    local dst="${list[$i]:-.${i##*/}}" dstForSudo= src="$i" doLink=true
    [[ $dst == @* ]] && doLink=false && dst="${dst#@}"
    [[ $dst == *:* ]] && src=${dst%%:*} && dst=${dst#*:}
    if [[ $dst == /* && $dst != $HOME/* ]]; then
      is-os-allowed +sudo || { log "$i - missing sudo perms"; return 1; }
      sudo mkdir -p ${dst%/*} || { log "$i - cannot mkdir '${dst%/*}'"; return 1; }
      dstForSudo=$dst
      dst=$TMP_MEM_PATH/${dst##*/}
    else
      [[ $dst == */* && $dst != /* ]] && mkdir -p $HOME/${dst%/*}
      if [[ $dst == */ ]]; then
        dst=${dst%/}
        local bi=$(basename $i) bdst=$(basename $dst)
        if [[ $bi =~ ${bdst#.}-* ]]; then
          dst="$dst/${bi#${bdst#.}-}"
        else
          dst="$dst/${i##*/}"
        fi
      fi
      dst="$HOME/$dst"
    fi
    case $src in
    /*)
      bck $dst
      if $doLink; then
        ln -sf $src $dst
      else
        cp $src $dst
      fi
      bck --clean $dst;;
    *)
      appender $src $dst $doLink || { log "$i - file not found ($src)"; return 1; }
    esac
    [[ -z $dstForSudo ]] || sudo mv $dst $dstForSudo
  done
} # }}}
# }}}
update-env() { # {{{
  touch "$confDir/step-update-env.done"
  if $updateAll; then # {{{
    declare -A updateApplied=()
    local updateAppliedF="$confDir/step-update-env.applied"
    [[ -e $updateAppliedF ]] && source $updateAppliedF
    local force=$force
    if [[ -z $updateList ]]; then
      updateList="$(get-steps $SCRIPT_PATH/inits/setup-env.to-apply "update")" i= name=
      for i in $profiles; do # {{{
        include-config "$profilesPath/$i/inits/setup-env.to-apply" "update" updateList
      done # }}}
      include-config $appPath/setup-env.to-apply "update" updateList
      updateList="$(echo "$updateList" | tr '\n' ' ')"
    else
      force=true
    fi
    log -s=$verbose "updateList: $updateList"
    local DONE_PROPERTIES="updateApplied:update:$updateAppliedF"
    for i in $updateList; do # {{{
      is-enabled $i || continue
      name="$(wide-print $i)"
      $justMark && { done-checker mark-done $i; continue; }
      $force || ! done-checker is-done $i "updateApplied" "update" || continue
      log "$name updating"
      update-$i || { log "$name failed, exiting"; return 1; }
      done-checker mark-done $i
      log -s=$verbose "$name done"
    done # }}}
  fi # }}}
  # notes # {{{
  declare -A noteFiles=()
  local files="main $profiles app" line=
  [[ -e $SCRIPT_PATH/inits/setup-env.notes ]] && noteFiles[main]="$SCRIPT_PATH/inits/setup-env.notes"
  for i in $profiles; do # {{{
    [[ -e $profilesPath/$i/inits/setup-env.notes ]] && noteFiles[$i]=" $profilesPath/$i/inits/setup-env.notes"
  done # }}}
  [[ -e $appPath/setup-env.notes ]] && noteFiles[app]=" $appPath/setup-env.notes"
  if [[ ${#noteFiles[*]} ]]; then # {{{
    declare -A notesApplied=()
    local notesAppliedF="$confDir/step-update-env-notes.applied"
    [[ -e $notesAppliedF ]] && source $notesAppliedF
    local line= s=
    log -s=$verbose "notes: ${noteFiles[*]}"
    for i in $files; do # {{{
      [[ -v noteFiles[$i] && -s ${noteFiles[$i]} ]] || continue
      ! $justMark && echo "Todo :: $i:"
      while read -r line; do
        local s=$(echo "$line" | get-fingerprint)
        $force || [[ ! -v notesApplied[$s] ]] || continue
        notesApplied[$s]=
        $justMark && continue
        echo "[ ] $line"
      done <${noteFiles[$i]}
    done # }}}
    (
      echo "declare -A notesApplied=()"
      for i in $(echo ${!notesApplied[*]} | tr ' ' '\n' | sort); do
        echo "notesApplied[$i]=\"${notesApplied[$i]}\""
      done
    ) >$notesAppliedF
  fi # }}} # }}}
} # }}}

# init # {{{
verbose=false
verboseLvl=0
confDir="$HOME/.config/setup-env"
[[ -e $confDir ]] || mkdir -p $confDir
stepsDoneF="$confDir/steps.done"
logFile=$confDir/setup-env.log
force=false
hasGui=
useSudo=
isLinux=true
profiles=
installTS=$EPOCHSECONDS
boldOnError=false
initCoreEnv=
stepsFromCLI=false
justMark=false
update=false
updateAll=true
updateList=
wideLen=12
[[ -z $1 ]] && { update=true; initCoreEnv=false; stepsFromCLI=false; }
declare -A stepsDone=()
declare -A stepsCLI=()
[[ -e $stepsDoneF ]] && source $stepsDoneF
args="${@:-no args}"
while [[ -n $1 ]]; do # @@:main # {{{
  case $1 in
  --whats-new) # {{{
    shift
    ref= p=
    case $1 in
    l | last) ref="tmp/sync/last";;
    '') ref="origin/devel"; p="-R";;
    *)
      if [[ $1 =~ ^[0-9]+$ ]]; then
        ref="HEAD~$1"
      else
        ref="$1"
      fi;;
    esac
    git diff $p $ref..HEAD -- ./inits/setup-env.conf ./inits/setup-env.to-apply ./bin/setup-env.sh
    exit 0;; # }}}
  --add-note | --add-update) # {{{
    cmd="${1#--add-}"; shift
    [[ -e $RUNTIME_PATH/profiles ]] && profiles="$(ls $RUNTIME_PATH/profiles)"
    appPath="$APPS_CFG_PATH/setup-env"
    value= mode="default"
    where="main"
    while [[ -n $1 ]]; do # {{{
      case $cmd::$1 in
      -p) where="$2"; shift;;
      note::--edit) mode="edit";;
      note::*) value="$@"; shift $#;;
      update:*)  value="$@"; shift $#;;
      esac; shift
    done # }}}
    case $where in # {{{
    main) where="$SCRIPT_PATH/inits/setup-env";;
    app)  where="$appPath/setup-env";;
    *)
      [[ " $profiles " == *" $where "* ]] || die "wrong target: $where"
      where="$PROFILES_PATH/$where/inits/setup-env";;
    esac # }}}
    case $cmd::$mode in # {{{
    note::default)
      [[ -n $value ]] || die "nothing to add"
      echo "$value" >>$where.notes;;
    note::edit)
      vim $where.notes;;
    update::default)
      lines=
      [[ -n $value ]] || value="misc-$(date +$DATE_FMT -d @$installTS)"
      if [[ -n $value ]]; then
        cat <<EOF >>$where.to-apply
update-$value() { # {{{
  local _ts="$(date +%y%m%d%H%M%S -d @$installTS)"
} # }}}
EOF
        lines="+$(( $(wc -l $where.to-apply | cut -d' ' -f1) - 2 ))"
      fi
      vim $lines $where.to-apply $HISTFILE;;
    esac # }}}
    exit 0;; # }}}
  --just-mark) # {{{
    shift
    case $1 in
    '' | skip-update)
      skipUpdate=false
      [[ $1 == skip-update ]] && skipUpdate=true
      $0 --just-mark-worker --all
      list="packages basics bin-misc dot-files tools cargo-tools pip-tools"
      case $OS_KIND in
      arch) is-os-allowed +sudo && list+=" arch-sudo-paru-tools"
      esac
      $0 --just-mark-worker $list
      if ! $skipUpdate; then
        $0 --just-mark-worker --update
      fi;;
    *)
      [[ $1 == '-' ]] && shift
      $0 --just-mark-worker "$@";;
    esac
    exit 0;; # }}}
  --clean) # {{{
    rm -f $logFile $stepsDoneF $confDir/step-*.done $confDir/step-*.applied
    stepsDone=();; # }}}
  --no-sudo) useSudo=false;;
  --gui) hasGui=true;;
  --no-gui) hasGui=false;;
  --easy) boldOnError=false;;
  --core-env) initCoreEnv=true;;
  --update) update=true; initCoreEnv=false; shift; updateList="$@"; shift $#;;
  --notes) update=true; updateAll=false; initCoreEnv=false;;
  --all) initCoreEnv=false;;
  --just-mark-worker) justMark=true;; # @@:ign
  -f | --force) force=true;;
  -p | --profiles) profiles+=" $2"; shift;;
  -v  | --verbose) verbose=true; verboseLvl=1;;
  -vv | --verbose2) verbose=true; verboseLvl=2;;
  *) # {{{
    [[ $1 == "--" ]] && shift
    while [[ -n $1 ]]; do
      stepsCLI[$1]=
      shift
    done
    stepsFromCLI=true
    force=true
    [[ -z $initCoreEnv ]] && initCoreEnv=false;; # }}}
  esac; shift
done # }}}
log -s=$verbose "--------------------------------------------------" # {{{
log -s=$verbose "started      : $(date +%Y%m%d-%H%M%S -d@$installTS)"
log -s=$verbose "args         : $args"
log -s=$verbose "log-file     : $logFile"
# }}}
# env-load # {{{
if [[ -z $profiles ]]; then # {{{
  [[ -e $RUNTIME_PATH/profiles ]] && profiles="$(ls $RUNTIME_PATH/profiles)"
elif [[ $profiles == ' -' ]]; then
  profiles=
fi
log -s=$verbose "profiles     : '$profiles'" # }}}
BASHRC_FULL_START=true
ENV_PATH="${thisFile%%/scripts/*}"
SCRIPT_PATH=$ENV_PATH/scripts
if $boldOnError; then
  set -e
fi
log -s=$verbose "[    ]         sourcing environment basics"
source $SCRIPT_PATH/bash/runtime.basic
source $SCRIPT_PATH/bash/completion.basic
source $SCRIPT_PATH/bash/essentials
source $SCRIPT_PATH/bash/runtime
profilesPath="$SCRIPT_PATH/bash/profiles"
for p in $profiles; do
  [[ -e $profilesPath/$p/runtime ]] && source $profilesPath/$p/runtime
done
[[ -e $SCRIPT_PATH/bash/cfg ]] && source $SCRIPT_PATH/bash/cfg
for p in $profiles; do
  [[ -e $profilesPath/$p/cfg ]] && source $profilesPath/$p/cfg
done
log -s=$verbose "[done]         sourcing environment basics"
# }}}
# setup # {{{
case $OS_KIND in # {{{
ubuntu | arch) isLinux=true;;
*) isLinux=false
esac # }}}
if [[ -z $useSudo ]]; then # {{{
  useSudo=${SETUP_ENV_USE_SUDO:-true}
fi # }}}
if [[ -z $hasGui ]]; then # {{{
  hasGui=${SETUP_ENV_HAS_GUI:-true}
  case $OS_KIND,$IS_VIRTUAL_OS in
  *,true) hasGui=false;;
  ubuntu,*) dpkg -l | grep -q "ubuntu-desktop" || hasGui=false;;
  esac
fi # }}}
declare -A packages=()
declare -A binMiscList=()
declare -A dotFilesBasicList=()
declare -A dotFilesList=()
declare -A tools=()
declare -A paruTools=()
declare -A coreEnv=()
declare -A stepsList=()
declare -A cargoTools=()
declare -A pipTools=()
appPath="$APPS_CFG_PATH/setup-env"
stepsAll="$(get-steps $thisFile)"
for si in $stepsAll; do coreEnv[$si]=; done
unset coreEnv[packages]
include-config $SCRIPT_PATH/inits/setup-env.conf
for si in ${stepsCLI:-$stepsAll}; do
  [[ $si =~ ^ext- ]] && continue
  stepsList[$si]=
done
for p in $profiles; do # {{{
  include-config "$profilesPath/$p/inits/setup-env.conf"
done # }}}
include-config $appPath/setup-env.conf
[[ -n $initCoreEnv ]] || initCoreEnv=true
$initCoreEnv && updateAll=false
# }}}
# log # {{{
log -s=$verbose "state        : os: $OS_KIND, gui: $hasGui, sudo: $useSudo"
log -s=$verbose "             : linux: $isLinux, arch: $IS_ARCH, mac: $IS_MAC"
log -s=$verbose "             : virt: $IS_VIRTUAL_OS, docker: $IS_DOCKER, wsl: $IS_WSL"
log -s=$verbose "force        : $force"
log -s=$verbose "backupTS     : $installTS"
log -s=$verbose "init-core    : $initCoreEnv"
log -s=$verbose "update       : $update"
log -s=$verbose "conf-dir     : $confDir"
printEnv=$(( verboseLvl >= 2 ))
log -s=$printEnv "stepsCLI     : $(declare -p stepsCLI)"
log -s=$printEnv "stepsList    : $(declare -p stepsList)"
log -s=$printEnv "coreEnv      : $(declare -p coreEnv)"
log -s=$printEnv "packages     : $(declare -p packages)"
log -s=$printEnv "binMiscList  : $(declare -p binMiscList)"
log -s=$printEnv "dotBasicList : $(declare -p dotFilesBasicList)"
log -s=$printEnv "dotFilesList : $(declare -p dotFilesList)"
log -s=$printEnv "tools        : $(declare -p tools)"
log -s=$printEnv "paruTools    : $(declare -p paruTools)"
log -s=$printEnv "cargoTools   : $(declare -p cargoTools)"
log -s=$printEnv "pipTools     : $(declare -p pipTools)"
log -s=$printEnv "upadteList   : $(declare -p updateList)"
log -s=$verbose # }}}
# }}}

if $update; then # {{{
  [[ -e $SCRIPT_PATH/inits/setup-env.to-apply ]] || { log "nothing to update"; exit 0; }
  source $SCRIPT_PATH/inits/setup-env.to-apply
  name="$(wide-print "update")"
  if $justMark; then
    log "$name marking"
  else
    log "$name installing"
  fi
  update-env || { log "$name update failed, exiting"; exit 1; }
  log -s=$verbose "$name done"
  if ! $justMark; then
    log "marking all as done"
    $0 --just-mark skip-update
  fi # }}}
else # {{{
  for si in $stepsAll; do
    name="$si" nameFull=
    if (( ${#name} > $wideLen )); then
      nameFull=" ($name)"
      name="$(sed -e 's/\(arch\|ubuntu\|mac\|N\?linux\|N\?docker\|N\?virtos\|N\?sudo\|\N\?wsl\|\N\?gui\|ext\)-//g' <<<"$name")"
      (( ${#name} <= $wideLen )) || name="${name:0:11}."
    fi
    name="$(wide-print $name)"
    type install-$si >/dev/null 2>&1 || { log "$name not defined"; exit 1; }
    if $stepsFromCLI; then
      [[ -v stepsCLI[$si] ]] || continue
    else
      ! $initCoreEnv || [[ -v coreEnv[$si] ]] || continue
      $justMark && { done-checker mark-done $si; continue; }
      $force || ! done-checker is-done $si || { log -s=$verbose "$name already done, skipping"; continue; }
      if $initCoreEnv; then
        log -s=$verbose "$name from core, executing"
      else
        is-enabled $si "stepsList" || continue
      fi
    fi
    if $justMark; then
      log "$name marking$nameFull"
    else
      log "$name installing$nameFull"
    fi
    install-$si || { log "$name failed$nameFull, exiting"; exit 1; }
    done-checker mark-done $si
    log -s=$verbose "$name done"
  done
fi # }}}
