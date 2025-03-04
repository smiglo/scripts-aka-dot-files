#!/usr/bin/env bash
# vim: fdl=0

installInfoDir=$HOME/.config/docker-post
scriptsPath="$(realpath "$(dirname "$(readlink -f "$0")")/../../..")"
source /etc/docker-ubu.conf
export PATH="$HOME/.local/bin:$PATH"
mkdir -p $installInfoDir >/dev/null
export DEBIAN_FRONTEND=noninteractive
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
if doInstall 'tmux-fingers'; then # {{{
  mkdir -p $HOME/.tmux/plugins
  pushd $HOME/.tmux/plugins
  git clone https://git::@github.com/morantron/tmux-fingers
  pushd tmux-fingers
  if [[ $(uname -m) == 'aarch64' ]]; then
    echo "Installing: tmux-fingers & crystal" >/dev/stderr
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
    echo "Installing: tmux-fingers"
    ./install-wizard.sh download-binary
  fi
  popd
  popd
fi # }}}
if doInstall 'ext'; then # {{{
  echo "Installing: ext" >/dev/stderr
  if [[ -e $(dirname "$0")/docker-post-ext.sh ]]; then
    $(dirname "$0")/docker-post-ext.sh
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

