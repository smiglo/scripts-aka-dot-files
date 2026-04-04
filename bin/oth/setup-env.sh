#!/usr/bin/env bash
# vim: fdl=0

thisFile=$(readlink -f $0)
get-steps() { # {{{
  sed -n '/^\s*install-.*()/ s/install-\(.*\)().*/\1/p' $1
} # }}}

if [[ $1 == "@@" ]]; then # @@:new # {{{
  ENV_PATH="${thisFile%%/scripts/*}"
  SCRIPT_PATH=$ENV_PATH/scripts
  [[ -n $APPS_CFG_PATH ]] || APPS_CFG_PATH=${RUNTIME_PATH:-$HOME/.runtime}/apps
  appPath="$APPS_CFG_PATH/setup-env"
  case $2 in
  -p)
    ret=
    for p in $SCRIPT_PATH/bash/profiles/*; do
      [[ -e $p/cfg ]] && ret+=" ${p##*/}"
    done
    echo "${ret:----}";;
  *)
    echo "--clean -p --no-sudo --gui --no-gui -v --verbose -f --force --easy"
    get-steps $thisFile
    for p in $SCRIPT_PATH/bash/profiles/*; do # {{{
      f="$p/bash/inits/setup-env.conf"
      [[ -e $f ]] && get-steps $f
    done # }}}
    [[ -e $appPath/setup-env.conf ]] && get-steps $appPath/setup-env.conf;;
  esac
  exit 0
fi # }}}

# functions # {{{
log() { # {{{
  local module=${FUNCNAME[1]}
  case $module in
  source | main | '') module=;;
  *) module="${module#install-}: "
  esac
  case $1 in
  false) return;;
  true)  shift;;
  esac
  echo "$module$@" | tee -a $logFile >&2
} # }}}
is-os-allowed() { # {{{
  local i= ret=0 caller=${FUNCNAME[1]} doLog=true
  declare -A hosts=()
  case $caller in
  source | '' | main) caller="?"; doLog=false;;
  esac
  log $doLog "$caller - checking range: $@"
  for i; do
    case $i in
    +docker) $IS_DOCKER || ret=1;;
    -docker) ! $IS_DOCKER || ret=1;;
    +virt-os) $IS_VIRTUAL_OS || ret=1;;
    -virt-os) ! $IS_VIRTUAL_OS || ret=1;;
    +wsl) $IS_WSL || ret=1;;
    -wsl) ! $IS_WSL || ret=1;;
    +gui) $hasGUI || ret=1;;
    -gui) ! $hasGUI || ret=1;;
    +sudo) $useSudo || ret=1;;
    -sudo) ! $useSudo || ret=1;;
    +linux) $isLinux || ret=1;;
    -linux) ! $isLinux || ret=1;;
    *) hosts[$1]=;;
    esac
    (( ret == 0 )) || { log $doLog "$caller - not allowed due to $i"; return 1; }
  done
  [[ -z $hosts ]] || [[ -v hosts[$OS_KIND] ]] || { log $doLog "$caller - not allowed due to OS: '$OS_KIND' not in '$hosts'"; return 1; }
  return 0
} # }}}
is-enabled() { # {{{
  local step=$1
  (
    [[ -v stepsList[$step] ]] || return 1
    for i in arch ubuntu mac; do
      [[ ! $step =~ "$i-" ]] || [[ $OS_KIND == "$i" ]] || return 1
    done
    [[ ! $step =~ "sudo-" ]] || $useSudo || return 1
    [[ ! $step =~ "gui-" ]] || $hasGui || return 1
    [[ ! $step =~ "linux-" ]] || $isLinux || return 1
    [[ ! $step =~ "docker-" ]] || $IS_DOCKER || return 1
    [[ ! $step =~ "virtos-" ]] || $IS_VIRTUAL_OS || return 1
    [[ ! $step =~ "wsl-" ]] || $IS_WSL || return 1
    return 0
  ) || { log "step $step disabled"; return 1; }
} # }}}
bck() { # {{{
  local i=
  for i; do
    [[ -h $i ]] && rm $i
    [[ -e $i ]] || continue
    if [[ ! -h $i && -s $i ]]; then
      log "$i -> $i-$installTS.bak"
      mv $i $i-$installTS.bak
    else
      rm $i
    fi
  done
} # }}}
appender() { # {{{
  local src=$1 dst=$2 p= foundCount=0 lastFound= subPath="bash/inits/dot-files"
  bck $dst
  if [[ -e $SCRIPT_PATH/$subPath/$src ]]; then
    log "$src - in root"
    if [[ -f $SCRIPT_PATH/$subPath/$src ]]; then
      (
        echo "### MAIN ### # {{{"
        cat $SCRIPT_PATH/$subPath/$src
        echo "# }}}"
      ) >>$dst
    else
      log "$src - not a file"
    fi
    ((++foundCount))
    lastFound="$SCRIPT_PATH/$subPath/$src"
    onlyRoot=true
  fi
  for p in $profiles; do
    [[ -e $PROFILES_PATH/$p/$subPath/$src ]] || continue
    log "$src - in $p"
    (
      echo "### $p ### # {{{"
      cat $PROFILES_PATH/$p/$subPath/$src
      echo "# }}}"
    ) >>$dst
    ((++foundCount))
    lastFound="$PROFILES_PATH/$p/$subPath/$src"
  done
  if [[ -e $appPath/dot-files/$src ]]; then
    log "$src - in runtime"
    (
      echo "### runtime ### # {{{"
      cat $appPath/dot-files/$src
      echo "# }}}"
    ) >>$dst
    ((++foundCount))
    lastFound="$appPath/dot-files/$src"
  fi
  [[ ! -e $dst ]] || [[ -s $dst ]] || { log "$src - not created or empty, ignoring"; return 1; }
  if (( foundCount == 1 )); then
    log "$src - just one found in $lastFound, linking"
    rm -f $dst
    ln -sf $lastFound $dst
  fi
} # }}}
find-file() { # {{{
  local file=$1 subPath="$2" i=
  local paths="$SCRIPT_PATH/$subPath"
  for i in $profiles; do
    paths+=" $PROFILES_PATH/$i/$subPath"
  done
  for i in $paths; do
    [[ -e $i/$file ]] && echo "$i/$file" && { log "$file - found in $i ($subPath)"; return 0; }
  done
  log "$file - NOT found"
  return 1
} # }}}
# }}}
# install steps, order matters # {{{
install-packages() { # {{{
  (( ${#packages[*]} )) || { log "no packages to install"; return 1; }
  local list= i=
  for i in ${!packages[*]}; do
    list+=" ${packages[$i]}"
  done
  case $OS_KIND in
  ubuntu) # {{{
    is-os-allowed +sudo || { log "no sudo"; return 1; }
    if ! is-installed -w add-apt-repository; then
      log "no add-apt-repository, installing it first"
      sudo apt-get update
      sudo apt-get install -y --no-install-recommends --fix-missing software-properties-common
    fi
    apts[main]="-c"
    apts[universe]="-c"
    apts[restricted]="-c"
    apts[multiverse]="-c"
    local newList=; declare -A apts=
    for i in $list; do
      if [[ $i == *@* ]]; then
        apts[${i#*@}]="-P"
        i="${i%%@*}"
      fi
      newList+=" $i"
    done
    log "apts: ${!apts[*]}"
    log "list: $newList"
    for i in ${!apts[*]}; do
      sudo add-apt-repository -y ${apts[$i]} $i || { log "cannot add apt-repo: $i (${apts[$i]})"; return 1; }
    done
    sudo apt-get install -y --no-install-recommends --fix-missing $newList || { log "apt failed"; return 1; }
    ;; # }}}
  arch) # {{{
    is-os-allowed +sudo || { log "no sudo"; return 1; }
    log "$list"
    sudo pacman -Sy --needed $list || { log "pacman failed"; return 1; }
    ;; # }}}
  mac) # {{{
    is-installed brew || { log "no brew"; return 1; }
    log "$list"
    if ${SETUP_ENV_BREW_SUDO:-false}; then
      brew install -y $list || { log "brew failed"; return 1; }
    else
      sudo brew install -y $list || { log "brew failed"; return 1; }
    fi;; # }}}
  esac
} # }}}
install-basics() { # {{{
  ln -sf $SCRIPT_PATH/bash/bashrc $HOME/.bashrc
  ln -sf $SCRIPT_PATH/bash/bash_login $HOME/.bash_login
  ln -sf $SCRIPT_PATH/bash/bash_profile $HOME/.bash_profile
  ln -sf $SCRIPT_PATH/bash/inputrc $HOME/.inputrc
  ln -sf $SCRIPT_PATH/bash/profile $HOME/.profile
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
    [[ -e $PROFILES_PATH/$i ]] || ln -sf $SCRIPT_PATH/bash/profiles/$i $PROFILES_PATH/$i
  done
  mkdir -p $HOME/.config/setup-env
  mkdir -p $BIN_PATH
} # }}}
install-bin-misc() { # {{{
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
  )
  appender "vim-specific" $HOME/.vimrc.specific || true
} # }}}
install-git() { # {{{
  ln -sf $SCRIPT_PATH/git/gitconfig $HOME/.gitconfig
  ln -sf $SCRIPT_PATH/git/gitignore $HOME/.gitignore
  rm -f $HOME/.git_template
  ln -sf $SCRIPT_PATH/git/template $HOME/.git_template
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
  [[ ! -e $HOME/.tmux/plugins ]] && mkdir -p $HOME/.tmux/plugins
  ln -sf $SCRIPT_PATH/bash/inits/tmux/plugins/tpm   $HOME/.tmux/plugins
  ln -sf $SCRIPT_PATH/bash/inits/tmux/tmux.conf     $HOME/.tmux.conf
  ln -sf $SCRIPT_PATH/bash/inits/tmux/tmux.bash     $HOME/.tmux.bash
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
install-alacritty() { # {{{
  $SCRIPT_PATH/bash/inits/alacritty/install.sh
} # }}}
install-ack() { # {{{
  $force || ! is-installed -w ack || return 0
  is-installed -w ack-grep || { log "not installed"; return 1; }
  ln -sf $(which ack-grep) $BIN_PATH/ack
} # }}}
install-gdb() { # {{{
  local p="$HOME/.config/gdb"
  mkdir -p $p
  rm -rf $HOME/.gdbinit
  ln -sf $SCRIPT_PATH/bash/inits/gdb/gdbinit "$HOME/.gdbinit"
  nr=1
  for i in $(ls $SCRIPT_PATH/bash/inits/gdb/*.{gdb,py} 2>/dev/null); do
    fname=${i##*/}
    if ! ls $p/*${fname}* >/dev/null 2>&1; then
      [[ $fname =~ ^[0-9]{3}-* ]] \
        && ln -sf $i $p/$fname \
        || ln -sf $i $p/$(printf "%03d-%s" "$nr" "$fname")
    fi
    ((++nr))
  done
  nrj=10
  for j in $profiles; do
    nr=$nrj
    for i in $(ls $SCRIPT_PATH/bash/profiles/$j/inits/gdb/*.{gdb,py} 2>/dev/null); do
      fname=${i##*/}
      if ! ls $p/*${fname}* >/dev/null 2>&1; then
        [[ $fname =~ ^[0-9]{3}-* ]] \
          && ln -sf $i $p/$fname \
          || ln -sf $i $p/$(printf "%03d-%s" "$nr" "$fname")
      fi
      ((++nr))
    done
    ((nrj+=10))
  done
  nr="050"
  ls $p/*gdb-dashboard.gdb* >/dev/null 2>&1 || echo "https://github.com/cyrus-and/gdb-dashboard.git" >$p/${nr}-gdb-dashboard.gdb.ign
  if [[ $OS_KIND == "ubuntu" ]]; then
    is-installed -w gdb-multiarch && ln -sf $(which gdb-multiarch) $BIN_PATH/gdb
  fi
} # }}}
install-mc() { # {{{
  mkdir -p $HOME/.config $HOME/.local/share
  bck $HOME/.config/mc
  cp -rf $SCRIPT_PATH/bash/inits/mc/config $HOME/.config/mc
  rm -rf $HOME/.local/share/mc
  ln -sf $SCRIPT_PATH/bash/inits/mc/share $HOME/.local/share/mc
  ln -sf $HOME/.config/mc/mc.menu $HOME/.mc.menu
} # }}}
install-cht-sh() { # {{{
  $force || ! is-installed -w cht.sh || return 0
  curl -sL https://cht.sh/:cht.sh >$BIN_PATH/cht.sh
  chmod +x $BIN_PATH/cht.sh
  mkdir -p $RUNTIME_PATH/completion.d
  curl -sL https://cheat.sh/:bash_completion >$RUNTIME_PATH/completion.d/cht-compl.sh
} # }}}
install-docker() { # {{{
  is-os-allowed -virt-os || return 0
  dockerFile="$HOME/.docker/config.json"
  if [[ -e $dockerFile ]]; then
    sed -i '/detachKeys/s/: ".*"/: "ctrl-x,ctrl-y"/' $dockerFile
  else
    mkdir -p ${dockerFile%/*}
    cat >$dockerFile <<-EOF
			{
			  "detachKeys": "ctrl-x,ctrl-y"
			}
		EOF
  fi
} # }}}
install-dot-files() { # {{{
  local i=
  for i in ${!dotFilesList[*]}; do
    local dst="${dotFilesList[$i]:-.$i}" dstForSudo=
    [[ $dst == */ ]] && dst="$dst${i##*/}"
    if [[ $dst == /* ]]; then
      is-os-allowed +sudo || { log "$i - skipping due to missing sudo perms"; return 1; }
      sudo mkdir -p ${dst%/*}
      dstForSudo=$dst
      dst=$TMP_MEM_PATH/${dst##*/}
    else
      [[ $dst == */* ]] && mkdir -p $HOME/${dst%/*}
      dst="$HOME/$dst"
    fi
    case $i in
    /*) bck $dst; ln -sf $i $dst;;
    *) appender $i $dst || { log "$i - file not found"; return 1; }
    esac
    [[ -z $dstForSudo ]] || sudo mv $dst $dstForSudo
  done
} # }}}
install-gui-fonts() { # {{{
  if is-os-allowed ubuntu mac; then
    [[ -e $SHARABLE_PATH ]] || return 0
    local fonts="FiraMono Inconsolata" dst="$HOME/.local/share/fonts" f=
    $IS_MAC && dst="$HOME/Library/Fonts"
    mkdir -p $dst
    for f in $fonts; do
      [[ "$(cd $dst; echo $f*)" == "$f"'*' ]] || continue
      [[ -e "$SHARABLE_PATH/sharable/fonts/$f.zip" ]] || continue
      unzip -q -d "$dst" "$SHARABLE_PATH/sharable/fonts/$f.zip" '*.ttf'
    done
  fi
  fc-cache -fv
} # }}}
install-cargo() { # {{{
  is-os-allowed ubuntu mac || return 0
  is-installed rustup && { log "rustup already installed; ignoring"; return 0; }
  curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path
  export PATH=$HOME/.cargo/bin:$PATH
} # }}}
install-nodejs() { # {{{
  $force || ! is-installed -w node || return 0
  if ${NODE_USE_NVM:-true}; then
    if ! is-installed -w nvm; then
      export NVM_DIR="$HOME/.nvm"
      [[ -e $NVM_DIR ]] || curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
      source $NVM_DIR/nvm.sh
    fi
    nvm install ${NODE_VERSION:---lts}
  elif is-os-allowed +sudo ubuntu; then
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION:-24.x} | sudo -E bash - && sudo apt-get install -y nodejs
  fi
} # }}}
# spec: linux # {{{
install-linux-sudo-locale() { # {{{
  sudo locale-gen C.UTF-8 en_US.UTF-8 en_GB.UTF-8 pl_PL.UTF-8
  case $OS_KIND in
  ubuntu)
    local locList="$(cat <<-EOF
		LANG="en_US.UTF-8" LC_CTYPE="en_US.UTF-8" LC_MESSAGES="en_US.UTF-8" \
		LC_TIME="en_GB.UTF-8" \
		LC_ADDRESS="pl_PL.UTF-8" LC_IDENTIFICATION="pl_PL.UTF-8" LC_MEASUREMENT="pl_PL.UTF-8" LC_MONETARY="pl_PL.UTF-8" LC_NAME="pl_PL.UTF-8" LC_NUMERIC="pl_PL.UTF-8" LC_PAPER="pl_PL.UTF-8" LC_TELEPHONE="pl_PL.UTF-8" \
		LC_COLLATE="C" \
		LC_ALL="
	EOF
    )"
    sudo update-locale $locList;;
  arch)
    cat <<EOF | sudo tee /etc/locale.conf >/dev/null
LANG=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
LC_MESSAGES=en_US.UTF-8
# 24h clock and Monday start usually come from GB or PL
LC_TIME=en_GB.UTF-8
# Polish specifics
LC_ADDRESS=pl_PL.UTF-8
LC_IDENTIFICATION=pl_PL.UTF-8
LC_MEASUREMENT=pl_PL.UTF-8
LC_MONETARY=pl_PL.UTF-8
LC_NAME=pl_PL.UTF-8
LC_NUMERIC=pl_PL.UTF-8
LC_PAPER=pl_PL.UTF-8
LC_TELEPHONE=pl_PL.UTF-8
# Standard sorting/collating
LC_COLLATE=C
EOF
    locale;;
  esac
} # }}}
install-linux-sudo-user-groups() { # {{{
  local groupList="adm admin sudo dialout video plugdev input ssh docker wireshark pcap git tty"
  local groupUser="$(groups | tr ' ' '\n')" groupSystem="$(cat /etc/group | cut -d: -f1)"
  local list= i=
  for i in $groupList; do
    echo "$groupSystem" | grep -q "^$i$" || sudo groupadd $i
    echo "$groupUser"   | grep -q "^$i$" || list+="$i,"
  done
  sudo groupadd -g $(id -u) $USER && list+="$USER,"
  [[ -n $list ]] || return 0
  sudo usermod -aG "${list%,}" $USER
} # }}}
install-linux-sudo-root-utils() { # {{{
  sudo mkdir -p /root/bin
  sudo cp $SCRIPT_PATH/bin/oth/utils-root.sh /root/bin/utils.sh
  sudo chmod 755 /root/bin/utils.sh
} # }}}
install-linux-sudo-sudoers() { # {{{
  declare -A prgList=( [ip]= [rtcwake]=)
  prgList+=( [mount]= [umount]= )
  prgList+=( [shutdown]= [systemctl@1]="suspend" )
  prgList+=( [reboot]= [reboot.ask]= )
  prgList+=( [nice]= [renice]= [dbus-monitor]= )
  prgList+=( [tcpdump]= )
  prgList+=( [/usr/local/bin/power-manager.sh]= [/root/bin/utils.sh]= )
  is-os-allowed +virt-os && prgList+=( [service]= [tee]= [ufw]= )
  (
    echo "# vim: ft=sudoers"
    echo
    echo "$USER ALL=(ALL:ALL) ALL"
    echo "$USER ALL=(ALL) NOPASSWD: \\"
    for i in ${!prgList[*]}; do
      case $i in
      /*) cmd=${i%@*};;
      *)
        cmd=$(which ${i%@*} 2>/dev/null)
        [[ -n $cmd ]] || { log "skipping $i"; continue; }
      esac
      [[ -n ${prgList[$i]} ]] && cmd+=" ${prgList[$i]}"
      echo "        $cmd, \\"
    done | sort
  ) \
  | sed -z 's/, \\\n$/\n/' \
  | sudo tee /etc/sudoers.d/user-${USER,,} >/dev/null
  sudo chmod 440 /etc/sudoers.d/user-${USER,,}
  sudo sed -i '/^'"$USER"'/s/^/# /' /etc/sudoers
} # }}}
install-linux-sudo-tcpdump-permissions() { # {{{
  tcpdump="$(which tcpdump 2>/dev/null)" || { log "ignoring due to missing tcpdump"; return 0; }
  sudo chgrp pcap $tcpdump
  sudo setcap cap_net_raw,cap_net_admin=eip $tcpdump
} # }}}
install-linux-sudo-ssh-inhibitor() { # {{{
  is-os-allowed -virt-os || return 0
  $force || [[ ! -e /etc/systemd/system/ssh-sleep-inhibitor@.service ]] || return 0

  local sshSrv="ssh"
  case $OS_KIND in
  arch) sshSrv="sshd";;
  esac

  if [[ ! -e /etc/systemd/system/sshd.socket ]]; then
    cat <<"EOF" | sudo tee /etc/systemd/system/sshd.socket > /dev/null
[Unit]
Description=OpenSSH Server Socket
Conflicts=sshd.service

[Socket]
ListenStream=22
Accept=yes

[Install]
WantedBy=sockets.target
EOF
  fi

  cat <<EOF | sudo tee /etc/systemd/system/ssh-sleep-inhibitor@.service > /dev/null
[Unit]
Description=SSH Sleep Inhibitor for session %I
StopWhenUnneeded=yes
BindsTo=$sshSrv@%i.service

[Service]
Type=simple
ExecStart=/usr/bin/systemd-inhibit --mode block --what sleep --who "ssh session %I" --why "session still active" /usr/bin/sleep infinity
Restart=no
TimeoutStopSec=5

[Install]
WantedBy=$sshSrv@.service
EOF

  sudo systemctl daemon-reload || { log "daemon-reload failed"; return 1; }
  sudo systemctl enable ssh-sleep-inhibitor@.service || { log "ssh-sleep-inhibitor not enabled"; return 1; }

  sudo systemctl disable --now $sshSrv.service || { log "$sshSrv.service not disabled"; return 1; }
  sudo systemctl enable --now $sshSrv.socket || { log "$sshSrv.socket not enabled"; return 1; }

  systemd-inhibit --list
  systemctl status ssh-sleep-inhibitor@*.service
} # }}}
install-linux-sudo-ufw-conf() { # {{{
  is-installed ufw || { log "ufw not installed"; return 1; }
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw logging off
  sudo systemctl enable ufw.service
  sudo ufw enable
} # }}}
# # }}}
# spec: ubuntu # {{{
install-ubuntu-gui-sudo-marble-mouse() { # {{{
  local dst="/usr/share/X11/xorg.conf.d/50-marblemouse.conf"
  $force || [[ ! -e $dst ]] || return 0
  local f= v="$(lsb_release -a 2>/dev/null | awk '/^Release:/ {print $2}')" k=
  if [[ -e "$SCRIPT_PATH/bash/inits/x11/50-marblemouse-$v.conf" ]]; then
    f="$SCRIPT_PATH/bash/inits/x11/50-marblemouse-$v.conf"
  else
    f="$SCRIPT_PATH/bash/inits/x11/50-marblemouse.conf"
  fi
  while read -p "Install support for Marble Mouse [y/n] ? " -t 15 k; do
    case ${k,,} in
    y) sudo ln -sf $f $dst; break;;
    n) break;;
    esac
  done
} # }}}
install-ubuntu-gui-dconf() { # {{{
  is-installed -w dconf || { log "dconf not installed"; return 1; }
  is-installed -w gsettings || { log "gsettings not installed"; return 1; }
  if ${SETUP_ENV_DCONF_KEYS:-true}; then # {{{
    gsettings set org.gnome.mutter overlay-key ''
    gsettings set org.gnome.shell.keybindings toggle-overview "['<Super>s', '<Super>Space']"
    f=$SCRIPT_PATH/bash/inits/dconf.keys
    for i in $(grep "^\[.*\]$" $f); do
      i="${i//[\[\]]}"
      range="[/]\n$(sed -n '/^\['"${i//\//\\\/}"'\]/,/^$/p' $f | tail -n+2)"
      range="${range//@HOME/$HOME}"
      echo -e "$range" | dconf load "/$i/"
    done
  fi # }}}
  if ${SETUP_ENV_DCONF_COLORS:-true}; then # {{{
    local terminalProfile=$SETUP_ENV_DCONF_TERMINAL_PROFILE
    if [[ -z $terminalProfile ]]; then
      terminalProfile="$(dconf list "/org/gnome/terminal/legacy/profiles:/" | grep "^:" |  head -n1)"
      terminalProfile="${terminalProfile#:}"
      terminalProfile="${terminalProfile%/}"
    fi
    if [[ -n $terminalProfile ]]; then
      dconf write "/org/gnome/terminal/legacy/profiles:/:$terminalProfile/palette" \
          "[ \
              'rgb(18,18,18)',    'rgb(237,101,92)', 'rgb(152,151,26)', 'rgb(215,153,33)', 'rgb(69,133,136)',  'rgb(177,98,134)',  'rgb(104,157,106)', 'rgb(251,241,199)', \
              'rgb(146,131,116)', 'rgb(251,73,52)',  'rgb(184,187,38)', 'rgb(250,189,47)', 'rgb(131,165,152)', 'rgb(211,134,155)', 'rgb(142,192,124)', 'rgb(235,219,178)'  \
          ]"
      dconf write "/org/gnome/terminal/legacy/profiles:/:$terminalProfile/background-color"   "'rgb(18,18,18)'"
      dconf write "/org/gnome/terminal/legacy/profiles:/:$terminalProfile/bold-color"         "'rgb(168,153,132)'"
      dconf write "/org/gnome/terminal/legacy/profiles:/:$terminalProfile/foreground-color"   "'rgb(235,219,178)'"
      dconf write "/org/gnome/terminal/legacy/profiles:/:$terminalProfile/font"               "'Fira Mono 13'"
    else
     log "terminal profile not found"
    fi
  fi # }}}
} # }}}
# }}}
# spec: arch # {{{
install-arch-sudo-paru() { # {{{
  $force || ! is-installed -w paru || return 0
  (
    cd $TOOLS_PATH
    git clone https://aur.archlinux.org/paru.git || { log "clone failed"; return 1; }
    cd paru
    makepkg -si || { log "makepkg failed"; return 1; }
  )
  (( $? == 0 )) || return 1
  rm -rf $TOOLS_PATH/paru
} # }}}
install-arch-paru-tools() { # {{{
  (( ${#paruTools[*]} )) || { log "nothing to install via paru"; return 0; }
  is-installed -w paru || { log "paru not installed"; return 1; }
  log "paru-tools: ${!paruTools[*]}"
  paru -S --needed ${!paruTools[*]}
} # }}}
install-arch-sudo-keyboard() { # {{{
  $force || [[ ! -e /usr/local/share/kbd/keymaps/pl-nocaps.map ]] || return 0
  sudo mkdir -p /usr/local/share/kbd/keymaps
  sudo cp $SCRIPT_PATH/bash/inits/dot-files/arch/kbd/vconsole.conf /etc/
  sudo cp $SCRIPT_PATH/bash/inits/dot-files/arch/kbd/pl-nocaps.map /usr/local/share/kbd/keymaps/
} # }}}
install-arch-sudo-hyprland() { # {{{
  local f="/etc/environment"
  (
    grep -q "XDG_SESSION_TYPE=\"wayland\"" $f || echo "XDG_SESSION_TYPE=\"wayland\""
    grep -q "QT_QPA_PLATFORM=\"wayland;xcb\"" $f || echo "QT_QPA_PLATFORM=\"wayland;xcb\""
    grep -q "MOZ_ENABLE_WAYLAND=1" $f || echo "MOZ_ENABLE_WAYLAND=1"
  ) | sudo tee -a $f >/dev/null
} # }}}
install-arch-sudo-misc() { # {{{
  # sddm # {{{
  paru -S sddm-silent-theme
  sudo systemctl enable sddm
  f="/etc/sddm.conf"
  [[ ! -e $f ]] && cp $BASH_PATH/inits/dot-files/arch/sddm.conf /etc/ # }}}
} # }}}
# }}}
# spec: mac # {{{
install-mac-copy-paste() { # {{{
  $force || [[ ! -e $HOME/Library/KeyBindings/DefaultKeyBinding.Dict ]] || return 0
  mkdir -p $HOME/Library/KeyBindings
  # via: https://blog.victormendonca.com/2020/04/27/how-to-change-macos-key-bindings/
  cat >$HOME/Library/KeyBindings/DefaultKeyBinding.Dict <<-'EOF'
		{
		    "^x" = "cut:";
		    "^c" = "copy:";
		    "^v" = "paste:";
		    "^a" = "selectAll:";
		    "^z" = "undo:";
		    "^Z" = "redo:";
		    "^s" = "save:"; /* not work, probably */
		    "^f" = "find:"; /* not work, probably */
		    /* <C+Left/Right> */
		    "^\UF702"  = "moveWordLeft:";
		    "^\UF703"  = "moveWordRight:";
		    /* <C+S+Left/Right> */
		    "^$\UF702" = "moveWordLeftAndModifySelection:";
		    "^$\UF703" = "moveWordRightAndModifySelection:";
		    /* <Home/End> */
		    "\UF729" = "moveToBeginningOfLine:";
		    "\UF72B" = "moveToEndOfLine:";
		    /* <S+Home/End> */
		    "$\UF729" = "moveToBeginningOfLineAndModifySelection:";
		    "$\UF72B" = "moveToEndOfLineAndModifySelection:";
		    /* <C+Home/End> */
		    "^\UF729" = "moveToBeginningOfDocument:";
		    "^\UF72B" = "moveToEndOfDocument:";
		    /* <C+S+Home/End> */
		    "^$\UF729" = "moveToBeginningOfDocumentAndModifySelection:";
		    "^$\UF72B" = "moveToEndOfDocumentAndModifySelection:";
		}
	EOF
} # }}}
# }}}
# tools # {{{
install-tool-gemini() { # {{{
  [[ -v tools[gemini] ]] || return 0
  $force || ! is-installed -w gemini || return 0
  npm install -g @google/gemini-cli
} # }}}
install-tool-dedoc() { # {{{
  [[ -v tools[decoc] ]] || return 0
  $force || ! is-installed -w dedoc || return 0
  cargo install dedoc || return
  $force || [[ ! -e $HOME/.dedoc ]] || return 0
  mkdir -p $HOME/.dedoc
  if dedoc fetch; then
    dedoc download c cpp cmake bash python~3.13
  else
    (
      cd $HOME/.dedoc
      rm -rf *
      tar xzf $SCRIPT_PATH/bash/inits/dedoc.tgz
    )
  fi
} # }}}
install-tool-pwndbg() { # {{{
  [[ -v tools[pwndbg] ]] || return 0
  $force || [[ ! -e $TOOLS_PATH/pwndbg ]] || return 0
  local err=0
  mv $HOME/.gitconfig $HOME/.gitconfig_
  git config --global http.version HTTP/1.1
  (
    cd $TOOLS_PATH
    git clone --single-branch --depth 2 https://github.com/pwndbg/pwndbg || { log "cannot clone"; return 1; }
    cd pwndbg
    ./setup.sh --update || { log "cannot build"; return 1; }
    sed -i -e 's/gdb.execute(f"set prompt {prompt}")/# \0/' pwndbg/gdblib/prompt.py
  )
  err=$?
  mv $HOME/.gitconfig_ $HOME/.gitconfig
  return $err
} # }}}
install-tool-sudo-gh-cli() { # {{{
  [[ -v tools[gh-cli] ]] || return 0
  $force || ! is-installed gh || return 0
  sudo mkdir -p -m 755 /etc/apt/keyrings
  local out=$(mktemp)
  wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg
  cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y gh
  gh extension install github/gh-copilot
} # }}}
# }}}
# extensions # {{{
install-ext-fzf-local() { # {{{
  if ${SETUP_ENV_FZF_USE_SUBMODULE:-false} && [[ -e $SCRIPT_PATH/bash/inits/fzf/install ]]; then
    (
      cd $SCRIPT_PATH/bash/inits/fzf
      ./install --no-completion --key-bindings --no-update-rc --no-zsh --no-fish || { log "installation failed"; return 1; }
    )
  else
    (
      if [[ ! -e fzf ]]; then
        v="${SETUP_ENV_FZF_VERSION:-0.70.0}"
        cd $TOOLS_PATH
        [[ -e fzf ]] || curl -sL https://github.com/junegunn/fzf/archive/refs/tags/v$v.tar.gz | tar xzf - || { log "cannot fetch"; return 1; }
        mv fzf-$v fzf
      fi
      cd fzf
      ./install --no-completion --key-bindings --no-update-rc --no-zsh --no-fish --no-bash || { log "installation failed"; return 1; }
    )
  fi
} # }}}
install-ext-docker-snapshot-restore() { # {{{
  $force || [[ ! -e $HOME/.config/setup-env/snapshot-restore ]] || return 0
  is-installed snapshot || { log "snapshot is missing"; return 1; }
  snapshot --restore
  touch $HOME/.config/setup-env/snapshot-restore
} # }}}
install-ext-ubunt-sudo-clean-after() { # {{{
  sudo apt-get -y autoremove
  sudo apt-get -y clean
  sudo rm -rf /var/lib/apt/lists/*
} # }}}
install-ext-arch-sudo-nvidia-old() { # {{{
  [[ $HOSTNAME == $HOST_HOME_WOSTA ]] || { log "wrong host"; return 1; }
  if ! is-installed nvidia-smi; then # {{{
    (
      cd $TOOLS_PATH
      git clone https://aur.archlinux.org/nvidia-580xx-utils.git || return 1
      cd nvidia-580xx-utils
      makepkg -si
    )
    (( $? == 0 )) || { log "nvidia installation failed"; return 1; }
    rm -rf $TOOLS_PATH/nvidia-580xx-utils
  fi # }}}

  local rootDev="$(mount | grep "\s\+on\s\+/\s\+" | head -n1 | awk '{print $1}')"
  local rID="$(sudo blkid -s UUID -o value $rootDev)"
  local params="rw quiet nvidia-drm.modeset=1" f=

  [[ -n $rootDev && -n $rID ]] || { log "cannot obtain UUID of /"; return 1; }

  if false; then # {{{
    sudo efibootmgr --create --disk /dev/sda --part 1 \
      --label "Arch Linux" \
      --loader /vmlinuz-linux \
      --unicode "root=UUID=$rID initrd=\intel-ucode.img initrd=\initramfs-linux.img $params" \
      --verbose
  fi # }}}

  f="/etc/kernel/cmdline"
  $force || [[ ! -e $f ]] || { log "file $f alredy exists"; return 1; }
  echo "root=UUID=$rID $params" | sudo tee $f >/dev/null

  if [[ $params =~ nvidia ]]; then # {{{
    f="/etc/mkinitcpio.conf"
    [[ -e $f ]] || exit 1
    log "WARNING: in $f MODULES were replaced with new values: $(sed -n '/^MODULES/p' $f)"
    sed -i '/^MODULES/s/^/# /' $f
    echo "MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)" | sudo tee -a $f >/dev/null
  fi # }}}

  f="/etc/pacman.d/hooks/90-uki-fallback.hook"
  $force || [[ ! -e $f ]] || { log "hook file $f exists"; return 1; }

  sudo mkdir -p /etc/pacman.d/hooks
  cat <<EOF | sudo tee /etc/pacman.d/hooks/90-uki-fallback.hook >/dev/null
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = linux
Target = intel-ucode
Target = nvidia-580xx-dkms

[Action]
Description = Updating UKI Fallback in /EFI/BOOT/BOOTX64.EFI...
When = PostTransaction
Exec = /usr/bin/ukify build --linux=/boot/vmlinuz-linux --initrd=/boot/intel-ucode.img --initrd=/boot/initramfs-linux.img --cmdline=@/etc/kernel/cmdline --output=/boot/EFI/BOOT/BOOTX64.EFI
EOF

  sudo mkinitcpio -P
} # }}}
install-ext-arch-sudo-pacman-keys-reset() { # {{{
  sudo pacman-key --init
  sudo pacman-key --populate archlinux
  sudo pacman -Sy archlinux-keyring
  sudo pacman-key --refresh-keys
  sudo pacman -Scc
  sudo pacman -Syu
} # }}}
install-ext-arch-sudo-dns-resolver() { # {{{
  dns-checker() { # {{{
    is-installed tcpdump dig || { log "tcpdump, dig not installed"; return 1; }
    echo "--- Local Resolver Check ---"
    grep "nameserver" /etc/resolv.conf
    echo -e "--- Testing resolution through $gatewayIp ---"
    dig google.com | grep -A 1 "SERVER:"
    if sudo timeout 10s tcpdump -i any port 53 -n 2>/dev/null | grep "IP .* >"; then
      log "Bad!!! Plain DNS traffic detected"
      return 1
    fi
    log "Maybe good, no plain DNS traffic detected"
    return 0
  } # }}}

  local connectionName=$CONNECTION_NAME
  [[ -n $connectionName ]] || { log "connection name not provided"; return 1; }
  local gatewayIp=$(ip route | grep default | awk '{print $3}')
  [[ -n $gatewayIp ]] || { log "no gateway ip address"; return 1; }
  if ${DNS_CHECK:-false}; then
    dns-checker
    return
  fi

  ( # {{{
    set -e
    sudo nmcli connection modify "$connectionName" ipv4.dns "$gatewayIp"
    sudo nmcli connection modify "$connectionName" ipv4.ignore-auto-dns yes
    sudo nmcli connection modify "$connectionName" ipv6.ignore-auto-dns yes
    sudo nmcli connection up "$connectionName"
  )
  (( $? == 0 )) || { log "nmcli failed, check connection name"; return 1; } # }}}

  cat <<EOF | sudo tee /etc/systemd/resolved.conf >/dev/null
[Resolve]
DNS=1.1.1.1 9.9.9.9
DNSOverHTTPS=yes
DNSSEC=yes
Domains=~.
EOF

  cat <<"EOF" | sudo tee /etc/NetworkManager/dispatcher.d/99-doh-dns >/dev/null
#!/bin/bash

INTERFACE=$1
ACTION=$2

HOME_GW_IP="192.168.92.1"

if [[ "$ACTION" = "up" ]]; then
    CURRENT_GW=$(ip route show dev "$INTERFACE" | grep default | awk '{print $3}')
    if [[ "$CURRENT_GW" == "$HOME_GW_IP" ]]; then
        echo "Home detected. Using Gateway DNS."
        resolvectl dns "$INTERFACE" "$HOME_GW_IP"
        resolvectl default-route "$INTERFACE" yes
    else
        echo "Roaming detected. Using System DoH (Cloudflare/Quad9)."
        resolvectl revert "$INTERFACE"
    fi
fi
EOF
  sudo chmod +x /etc/NetworkManager/dispatcher.d/99-doh-dns
  sudo systemctl enable --now systemd-resolved
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  dns-checker || true
} # }}}
# }}}
# }}}

# init # {{{
trackFile=$HOME/setup-env.track
logFile=${TMP_PATH:-$HOME}/setup-env.log
force=false
hasGui=
isLinux=true
profiles=
stepsCLI=
useSudo=
verbose=false
installTS=$EPOCHSECONDS
boldOnError=false
log "--------------------------------------------------" # {{{
log "started      : $(date +%Y%m%d-%H%M%S -d@$installTS)"
log "args         : ${@:-no args}"
log "log-file     : $logFile"
log "track-file   : $trackFile" # }}}
while [[ -n $1 ]]; do # {{{
  case $1 in
  --clean) rm -f $trackFile $logFile;;
  --no-sudo) useSudo=false;;
  --gui) hasGui=true;;
  --no-gui) hasGui=false;;
  --easy) boldOnError=false;;
  -f | --force) force=true;;
  -p | --profiles) profiles+=" $2"; shift;;
  -v | --verbose) verbose=true;;
  *) stepsCLI="$@"; shift $#;;
  esac; shift
done # }}}
# }}}
# env-load # {{{
touch $trackFile
if [[ -z $profiles ]]; then # {{{
  [[ -e $RUNTIME_PATH/profiles ]] && profiles="$(ls $RUNTIME_PATH/profiles)"
elif [[ $profiles == '-' ]]; then
  profiles=
fi
log "profiles     : '$profiles'" # }}}
BASHRC_FULL_START=true
ENV_PATH="${thisFile%%/scripts/*}"
SCRIPT_PATH=$ENV_PATH/scripts
if $boldOnError; then
  set -e
fi
log "[    ]         sourcing environment basics"
source $SCRIPT_PATH/bash/aliases.d/0.essentials
source $SCRIPT_PATH/bash/runtime.basic
source $SCRIPT_PATH/bash/runtime
source $SCRIPT_PATH/bash/completion.basic
profilesPath="$SCRIPT_PATH/bash/profiles"
for p in $profiles; do
  [[ -e $profilesPath/$p/runtime ]] && source $profilesPath/$p/runtime
done
[[ -e $SCRIPT_PATH/bash/cfg ]] && source $SCRIPT_PATH/bash/cfg
for p in $profiles; do
  [[ -e $profilesPath/$p/cfg ]] && source $profilesPath/$p/cfg
done
log "[done]         sourcing environment basics"
# }}}
# setup # {{{
stepsAll="$(get-steps $thisFile)"
declare -A stepsList=()
declare -A packages=()
declare -A binMiscList=()
declare -A dotFilesList=()
declare -A tools=()
for si in ${stepsCLI:-$stepsAll}; do
  [[ $si =~ ^ext- ]] && continue
  stepsList[$si]=
done
appPath="$APPS_CFG_PATH/setup-env"
source $SCRIPT_PATH/bash/inits/setup-env.conf
for p in $profiles; do # {{{
  f="$profilesPath/$p/bash/inits/setup-env.conf"
  [[ -e $f  ]] || continue
  source $f
  stepsAll+=" $(get-steps $f)"
done # }}}
if [[ -e $appPath/setup-env.conf ]]; then
  source $appPath/setup-env.conf
  stepsAll+=" $(get-steps $appPath/setup-env.conf)"
fi
if [[ $OS_KIND == "ubuntu" || $OS_KIND == "arch" ]]; then # {{{
  isLinux=true
else
  isLinux=false
fi # }}}
if [[ -z $useSudo ]]; then # {{{
  useSudo=${SETUP_ENV_USE_SUDO:-true}
fi # }}}
if [[ -z $hasGUI ]]; then # {{{
  hasGUI=${SETUP_ENV_HAS_GUI:-true}
  case $OS_KIND,$IS_VIRTUAL_OS in
  *,true) hasGUI=false;;
  ubuntu,*) dpkg -l | grep -q "ubuntu-desktop" || hasGUI=false;;
  *)
  esac
fi # }}}
# }}}
# log # {{{
log "state        : os: $OS_KIND, gui: $hasGUI, sudo: $useSudo"
log "             : linux: $isLinux, arch: $IS_ARCH, mac: $IS_MAC"
log "             : virt: $IS_VIRTUAL_OS, docker: $IS_DOCKER, wsl: $IS_WSL"
log "force        : $force"
log "backupTS     : $installTS"
log "steps-cli    : $(declare -p stepsCLI)"
log "stepsList    : $(declare -p stepsList)"
(
  log "packages     : $(declare -p packages)"
  log "binMiscList  : $(declare -p binMiscList)"
  log "dotFilesList : $(declare -p dotFilesList)"
  log "tools        : $(declare -p tools)"
) |& { if $verbose; then cat - >&2; else cat ->/dev/null; fi; }
# }}}

for si in $stepsAll; do # {{{
  grep -q "^$si$" $trackFile && { log "step: $si - already done, skipping"; continue; }
  if [[ -n $stepsCLI ]]; then
    [[ " $stepsCLI " =~ " $si " ]] || continue
    log "step: $si - from CLI, executing"
  else
    is-enabled $si || continue
  fi
  log "step: $si - installing"
  install-$si; err=$?; set +xv
  if (( err )); then
    log "step: $si - failed, exiting"
    exit 1
  fi
  log "step: $si - succeed"
  echo "$si" >>$trackFile
done # }}}
rm -f $trackFile
