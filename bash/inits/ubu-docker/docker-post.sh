#!/usr/bin/env bash
# vim: fdl=0

installInfoDir=$HOME/.config/docker-post
scriptsPath="$(realpath "$(dirname "$(readlink -f "$0")")/../../..")"
toolsDocker="$HOME/tools.docker"
source /etc/docker-ubu.conf
export PATH="$HOME/.local/bin:$PATH"
mkdir -p $installInfoDir >/dev/null
allYes=false
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -c | --clean) rm -f $installInfoDir/*;;
  -y | --yes)   allYes=true;;
  *) for i in $@; do rm -f $installInfoDir/$i; done; shift $#;;
  esac; shift
done # }}}
[[ -e $installInfoDir/all-installed ]] && exit 0
doInstall() { # {{{
  local ret=0 file=$installInfoDir/$1
  [[ -e $file ]] && ret=1
  touch $file
  return $ret
} # }}}
export -f doInstall
if doInstall 'pwd'; then # {{{
  echo "Installing: pwd" >/dev/stderr
  [[ ! -z $DOCKER_CONF_PWD_USER ]] && echo "$USER:$DOCKER_CONF_PWD_USER" | sudo chpasswd -e
  [[ ! -z $DOCKER_CONF_PWD_ROOT ]] && echo "root:$DOCKER_CONF_PWD_ROOT" | sudo chpasswd -e
fi # }}}
if doInstall 'basic'; then # {{{
  echo "Installing: basic" >/dev/stderr
  $scriptsPath/bin/mk_install_scripts.sh -p - --all-yes --no-exec || { rm -f $installInfoDir/basic; echo "basic: installation failed" >/dev/stderr; exit 1; }
  ln -sf $scriptsPath/bash/inits/ubu-docker/runtime-docker.bash $HOME/.runtime/
fi # }}}
if doInstall 'tools'; then # {{{
  echo "Installing: tools" >/dev/stderr
  clone() { # {{{
    local url="$1" key=
    local name=${url##*/} && name=${name%.git}
    while [[ ! -e $name ]] && ! git clone $url; do # {{{
      read -p "$name: clone failed, press a key to continue or Q > " key
      case ${key,,} in
      q) rm -rf $name; return 1;;
      esac
    done # }}}
    return 0
  } # }}}
  if ${DOCKER_CONF_TOOLS_FZF:-true}; then # {{{
    echo "Installing: tools: fzf" >/dev/stderr
    pushd $toolsDocker
    if clone "https://github.com/junegunn/fzf.git"; then
      pushd fzf
      git checkout v0.55.0
      ( export PATH="/usr/local/bin:/usr/bin:/bin"
        ./install --bin
      )
      popd
    fi
    popd
  fi # }}}
  if ${DOCKER_CONF_TOOLS_PWNTOOLS:-true}; then # {{{
    echo "Installing: tools: pwntools" >/dev/stderr
    python3 -m pip install --break-system-packages pwntools
  fi # }}}
  if ${DOCKER_CONF_TOOLS_FRIDA:-true}; then # {{{
    echo "Installing: tools: frida" >/dev/stderr
    python3 -m pip install --break-system-packages frida-tools
  fi # }}}
  mv $HOME/.gitconfig $HOME/.gitconfig_
  if ${DOCKER_CONF_TOOLS_PWNDBG:-true}; then # {{{
    echo "Installing: tools: pwndbg" >/dev/stderr
    pushd $toolsDocker
    if clone "https://github.com/pwndbg/pwndbg"; then
      pushd pwndbg
      ./setup.sh --update
      sed -i -e 's/gdb.execute(f"set prompt {prompt}")/# \0/' pwndbg/gdblib/prompt.py
      popd
    fi
    popd
  fi # }}}
  if ${DOCKER_CONF_TOOLS_RADARE2:-true}; then # {{{
    echo "Installing: tools: radare2" >/dev/stderr
    pushd $toolsDocker
    git config --global http.version HTTP/1.1
    if clone "https://github.com/radareorg/radare2.git"; then
      pushd radare2
      tag=$(git tag | grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" | tail -n1)
      [[ $tag == "5.9.6" ]] && tag="5.9.4"
      echo "radare2: building on tag: $tag"
      git checkout $tag
      ./sys/install.sh
      if [[ $? == 0 ]] && which r2pm >/dev/null 2>&1; then
        lvl=${DOCKER_CONF_TOOLS_RADARE2_PM_LVL:-1}
        echo "Installing: tools: r2-plugins: l$lvl" >/dev/stderr
        python3 -m pip install --break-system-packages meson
        [[ $lvl -ge 1 ]] && r2pm -c -i r2dec r2pipe
        [[ $lvl -ge 2 ]] && r2pm -c -i r2frida r2ghidra r2diaphora
        [[ $lvl -ge 3 ]] && r2pm -c -i r2ai
      fi
      popd
    fi
    popd
  fi # }}}
  rm -f $HOME/.gitconfig
  mv $HOME/.gitconfig_ $HOME/.gitconfig
fi # }}}
if doInstall 'crystal'; then # {{{
  echo "Installing: crystal" >/dev/stderr
  sudo apt-get update
  which gpg >/dev/null 2>&1 || sudo apt-get install -y gpg
  curl -fsSL https://packagecloud.io/84codes/crystal/gpgkey | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/84codes_crystal.gpg > /dev/null
  . /etc/os-release
  echo "deb https://packagecloud.io/84codes/crystal/$ID $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/84codes_crystal.list
  sudo apt-get update
  sudo apt-get install -y crystal
  sudo rm -f /etc/apt/sources.list.d/84codes_crystal.list
fi # }}}
if doInstall 'ext'; then # {{{
  echo "Installing: ext" >/dev/stderr
  if [[ -e $DOCKER_CONF_EXT ]]; then
    $DOCKER_CONF_EXT
  fi
fi # }}}
if doInstall 'snapshot'; then # {{{
  echo "Installing: snapshot" >/dev/stderr
  if type snapshot >/dev/null 2>&1; then
    snapshot --restore
  elif $allYes; then
    echo "Restore from snaphot: snapshot --restore" >/dev/stderr
  else
    read -p "Restore from snaphot: snapshot --restore" >/dev/stderr
  fi
fi # }}}
if doInstall 'clean-after'; then # {{{
  echo "Installing: cleaning-after" >/dev/stderr
  sudo apt-get -y autoremove
  sudo apt-get -y clean
  sudo rm -rf /var/lib/apt/lists/*
fi # }}}
touch $installInfoDir/all-installed

