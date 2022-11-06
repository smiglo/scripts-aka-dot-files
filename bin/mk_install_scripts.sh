#!/usr/bin/env bash
# vim: fdl=0

set -e

if [[ $1 == @@ ]]; then # {{{
  case $3 in
  -i) # {{{
    {
      sed -n '/if\s\+install/s/.*install\s\+'"'"'\([^'"'"']*\)'"'"'.*/\1/p' $0
      for i in $PROFILES_PATH/*; do
        [[ -e $i/mk_install_scripts.sh ]] && sed -n '/if\s\+install/s/.*install\s\+'"'"'\([^'"'"']*\)'"'"'.*/\1/p' $i/mk_install_scripts.sh
      done
    } | sort;; # }}}
  *) echo -i --all-{yes,no} --selent --no-exit ? --{no-}sudo;;
  esac
  exit 0
fi # }}}
# Functions {{{
dbg() { # {{{
  local silent=$IS_SILENT
  if [[ $1 == '--force' ]]; then
    shift
    silent=false
  fi
  $silent && return
  echo "$@"
} # }}}
cleanUp() { # {{{
  [[ $? == 0 ]] && return 0
  dbg -n "Cleaning after error ($?)... "
  dbg "[DONE]"
} # }}}
get_app_name() { # {{{
  local IFS=':'
  read prg inst ppa <<<"$1"
  [[ -z $inst ]] && inst=$prg
  return 0
} # }}}
install() { # {{{
  echo "$TO_INSTALL" | command grep -q " $1\(:[^ ]*\)\{0,1\} " && return 0
  if [[ ! -z $INSTALL_FROM_ARGS ]]; then
    local i=
    for i in $TO_INSTALL; do
      [[ $i != '@' ]] || continue
      [[ $i == *\* ]] || continue
      echo "$1" | command grep -q "${i/\*/.\*}" && return 0
    done
  fi
  return 1
} # }}}
install_ext() { # {{{
  install "$1" && return 0
  [[ ! -z $INSTALL_FROM_ARGS ]] && return 1
  [[ -z $INSTALL_EXT_SUFFIX ]] && return 1
  [[ $1 == *-${INSTALL_EXT_SUFFIX} ]] && return 0
  [[ -z $INSTALL_EXT_PROFILES ]] && return 1
  local i=
  for i in $INSTALL_EXT_PROFILES; do
    [[ $1 == *-${INSTALL_EXT_SUFFIX}-$i ]] && return 0
  done
  return 1
} # }}}
do_install() { # {{{
  [[ $AUTO_INSTALL_TOOLS == false ]] && dbg "[SKIPPED]" && return 0
  if [[ $AUTO_INSTALL_TOOLS == true ]]; then
    dbg "[AUTO-INSTALL]"
  else
    dbg "[NOT INSTALLED]"
    while true; do
      read -p "Install $prg:$inst [Y/y/N/n] ? " key
      case $key in
      ""|y) break;;
      Y) AUTO_INSTALL_TOOLS=true; break;;
      N) AUTO_INSTALL_TOOLS=false; return 0;;
      n) return 0;;
      esac
    done
  fi
  if $IS_MAC; then
    brew install $inst || INSTALL_FAILED+="$inst "
  elif type apt-get >/dev/null 2>&1; then
    if $INSTALL_SUDO_ALLOWED; then
      if [[ ! -z $ppa ]] && ! sudo add-apt-repository -y ppa:$ppa; then
        INSTALL_FAILED+="$inst "
      else
        sudo apt-get -y install $inst || INSTALL_FAILED+="$inst "
      fi
    else
      echo "Installation of '$inst' skipped due to disallowed sudo" >/dev/stderr
    fi
  elif type yum >/dev/null 2>&1; then
    sudo yum install -y $inst || INSTALL_FAILED+="$inst "
  else
    dbg "apt-get/yum not available, install ($prg) manually."
  fi
} # }}}
do_dconf() { #{{{
  dbg -n "Configuring (dconf)... "
  if ! type dconf >/dev/null 2>&1; then
    dbg "[ERR: dconf not installed]"
    return 1
  fi
  local dconf_file_templ="$script_path/bash/inits/dconf/dconf.dump"
  local dconf_file_local="$dconf_file_templ.$HOSTNAME"
  local ver_current="$(git log -1 -- $dconf_file_templ | cut -d' ' -f1)"
  local ver_last=
  [[ -e ${dconf_file_templ%/*}/status.txt ]] && ver_last="$(command grep $HOSTNAME ${dconf_file_templ%/*}/status.txt | cut -d' ' -f1 || 0)"
  if [[ $ver_current == $ver_last ]]; then
    dbg "[UP-TO-DATE]"
    return 0
  fi
  if ! dconf dump / >$dconf_file_local; then
    dbg "[ERR: on dump]"
    return 1
  fi
  if diff $dconf_file_templ $dconf_file_local >/dev/null 2>&1; then
    dbg "[THE-SAME]"
    rm $dconf_file_local
    return 0
  fi
  dbg "[DIFFERS]"
  dbg --force "[DCONF] Review changes and do \"cat $dconf_file_local | dconf load /\""
  local key
  read key
  return 0
} #}}}
appender() { # {{{
  local dst=$1; shift
  local srcs=$@ src=
  [[ -e $dst ]] || touch $dst
  for src in $srcs; do
    src="$(echo "$src" | sed -e 's/[{}]//g')"
    [[ -e $src ]] || continue
    ! command grep -q "$(head -n1 $src)" $dst || continue
    cat $src >> $dst
  done
} # }}}
# }}}
# Setup {{{
# INIT {{{

# trap cleanUp EXIT
if [[ -z $MY_PROJ_PATH ]]; then # {{{
  export MY_PROJ_PATH=$HOME/projects/my
  [[ ! -e $MY_PROJ_PATH ]] && export MY_PROJ_PATH=$HOME/projects
  [[ ! -e $MY_PROJ_PATH ]] && dbg 'MY_PROJ_PATH cannot be evaluated. Export correct value from a shell' && exit 1
fi # }}}
script_path=$MY_PROJ_PATH/scripts
bin_path=$HOME/.bin
TMP_PATH=${TMP_PATH:-$HOME/.tmp}
RUNTIME_PATH=${RUNTIME_PATH:-$HOME/.runtime}
APPS_CFG_PATH=${APPS_CFG_PATH:-$RUNTIME_PATH/apps}
[[ ! -e $APPS_CFG_PATH ]] && command mkdir -p $APPS_CFG_PATH

SETUP_PROFILES=$MK_INSTALL_SETUP_PROFILES
AUTO_INSTALL_TOOLS=${MK_INSTALL_AUTO_INSTALL_TOOLS}
INSTALL_FAILED=
IS_SILENT=false
DO_EXEC=true
INSTALL_FEATURES_BASIC='bashrc bin-path bash-path bin-misc vim git tmux mc htop agignore alacritty fzf fonts colors rlwrap quilt my-proj-path-as-kb'
INSTALL_FEATURES_EXT='grc atom ap-calc tig install-tools ack ssh-config gitsh gdb gdb-multiarch speedtest-net'
INSTALL_FEATURES_EXT_UBU='abcde autostart notify-log marblemouse pulse-audio x-opengl vrapper-eclipse less-highlight'
INSTALL_FEATURES_EXT_MAC='mac-tools mac-grep'
TO_INSTALL_TOOLS_BASIC="git tig pv at tmux w3m cmatrix mc cscope grc vlock jq expect colordiff column htop curl \
    cowsay figlet lolcat fortune:fortune-mod"
TO_INSTALL_TOOLS_UBU="calc:apcalc vim.gtk3:vim-gtk xclip ack-grep:ack cryptsetup ctags:exuberant-ctags clang valgrind openvpn unclutter dconf-cli \
    vipe:moreutils gnuplot-x11 pstree ag:silversearcher-ag \
    libnotify-bin notify-osd \
    ccsm:compizconfig-settings-manager unity-tweak-tool gnome-tweak-tool \
    ifconfig:net-tools synaptic dconf-editor gawk gparted fdfind:fd-find \
    bfs gucharmap git-lfs psmisc kcharselect build-essential psmisc rr cpufrequtils \
    "
TO_INSTALL_TOOLS_MAC="calc ack pbcopy:tmux-pasteboard ctags ag:the_silver_searcher \
    bfs:tavianator/tap/bfs fd pidof pstree \
    "
INSTALL_BIN_MISC_BASIC='cht.sh keep-pass.sh'
INSTALL_FROM_ARGS=
INSTALL_SUDO_ALLOWED=${INSTALL_SUDO_ALLOWED:-true}
# Other features: dconf
# }}}
# Check parameters {{{
while [[ ! -z $1 ]]; do
  case $1 in
    --no-sudo) INSTALL_SUDO_ALLOWED=false;;
    --sudo)    INSTALL_SUDO_ALLOWED=true;;
    --all-yes) AUTO_INSTALL_TOOLS=true;;
    --all-no)  AUTO_INSTALL_TOOLS=false;;
    --silent)  IS_SILENT=true;;
    --no-exec) DO_EXEC=false;;
    -i)        DO_EXEC=false; shift; INSTALL_YES=true
               INSTALL_FROM_ARGS+=" ${1//,/ }"
               ;;
    --tools | \?\?) # {{{
      sed -n -e "/^\s*if install.*/s/[^\"']*[\"']\([^\"']*\)[\"'].*/\1/p" $0 | sort -u
      for i in $bin_path/bash/profiles/*; do # {{{
        [[ -e $i/mk_install_scripts.sh ]] && sed -n -e "/^\s*if install.*/s/[^\"']*[\"']\([^\"']*\)[\"'].*/${i##*/}:\1/p" $i/mk_install_scripts.sh
      done | sort -u # }}}
      exit 0;; # }}}
    \?)
      echo "$0" [--all-{yes,no}] "--silent --no-exec [-i TOOL,...] [--tools|??] [?] PROFILE ..."
      echo
      echo "Basic:     $INSTALL_FEATURES_BASIC"
      echo "Ext:       $INSTALL_FEATURES_EXT $( ! $IS_MAC && echo "$INSTALL_FEATURES_EXT_UBU" || echo "$INSTALL_FEATURES_EXT_MAC")"
      echo "Bin-Basic: $INSTALL_BIN_MISC_BASIC"
      exit 0;;
    *)         SETUP_PROFILES+=" $1";;
  esac
  shift
done
# }}}
# Select profiles to install {{{
PROFILES_FILE=$APPS_CFG_PATH/setup_profiles
[[ -z $SETUP_PROFILES && -e $PROFILES_FILE ]] && SETUP_PROFILES="$(cat $PROFILES_FILE)"
[[ -z $SETUP_PROFILES ]] && echo "WARNING: Profiles not specifed" >/dev/stderr
# }}}
# Cleaning {{{
[[ -z $INSTALL_FROM_ARGS ]] && rm -rf $bin_path
# }}}
# Load configuration {{{
dbg -n "Loading cfg file... "
set +e
[[ -e $script_path/bash/runtime ]] && dbg "  Loading $script_path/bash/runtime" && source $script_path/bash/runtime >/dev/null
for p in $SETUP_PROFILES; do
  [[ -e $script_path/bash/profiles/$p/runtime ]] && dbg "  Loading $script_path/bash/profiles/$p/runtime" && source $script_path/bash/profiles/$p/runtime >/dev/null
done
[[ -e $script_path/bash/cfg ]] && dbg "  Loading $script_path/bash/cfg" && source $script_path/bash/cfg >/dev/null
for p in $SETUP_PROFILES; do
  [[ -e $script_path/bash/profiles/$p/cfg ]] && dbg "  Loading $script_path/bash/profiles/$p/cfg" && source $script_path/bash/profiles/$p/cfg >/dev/null
done
set -e
dbg "[DONE]"
# }}}
# Initialiaze profiles {{{
for p in $SETUP_PROFILES; do
  dbg "Initialize profile ($p)... "
  INSTALL_EXT_SUFFIX=
  INSTALL_EXT_PROFILES=
  [[ -e $script_path/bash/profiles/$p/mk_install_scripts.sh ]] && source $script_path/bash/profiles/$p/mk_install_scripts.sh prepare_installation
done
# }}}
# Configure TMP_PATH {{{
dbg -n "Configuring tmp ($TMP_PATH)... "
[[ ! -d $TMP_PATH ]] && command mkdir -p $TMP_PATH
dbg "[DONE]"
# }}}
# Store selected profiles in a file {{{
echo $SETUP_PROFILES > $PROFILES_FILE
# }}}
# Check INSTALL_FEATURES {{{
if [[ -z $INSTALL_FROM_ARGS ]]; then # {{{
  [[ $INSTALL_FEATURES == 'NONE' ]] && exit 0
  TO_INSTALL="$INSTALL_FEATURES_BASIC $INSTALL_FEATURES_EXT"
  if ! ${IS_MAC:-false}; then
    TO_INSTALL+=" $INSTALL_FEATURES_EXT_UBU"
  else
    TO_INSTALL+=" $INSTALL_FEATURES_EXT_MAC"
  fi
  if [[ ! -z $INSTALL_FEATURES ]]; then
    INSTALL_FEATURES=" $INSTALL_FEATURES "
    if [[ $INSTALL_FEATURES == *\ BASIC\ * ]]; then
      INSTALL_FEATURES="${INSTALL_FEATURES//' BASIC '/ }"
      TO_INSTALL="$INSTALL_FEATURES_BASIC"
    fi
    for i in $INSTALL_FEATURES; do
      case $i in
      -*)   TO_INSTALL="${TO_INSTALL// ${i#-} / }";;
      +*)   TO_INSTALL+=" ${i/+} ";;
      *)    TO_INSTALL+=" $i ";;
      esac
    done
  fi
else
  INSTALL_FROM_ARGS="$(echo "$INSTALL_FROM_ARGS" | sed -e 's/\s*\w*:\(\w*\)/ \1/g')"
  TO_INSTALL="$INSTALL_FROM_ARGS"
fi # }}}
dbg "To install: [$TO_INSTALL]"
TO_INSTALL="@ $TO_INSTALL @"
# }}}
# }}}
# Installation {{{
# Configurations, etc. {{{
if type lsb_release >/dev/null 2>&1 && lsb_release -a 2>/dev/null | command grep -q 'Description.*Ubuntu' && $INSTALL_SUDO_ALLOWED; then # {{{
  dbg "Configuring (apt repositories)... "
  sudo add-apt-repository main
  sudo add-apt-repository universe
  sudo add-apt-repository restricted
  sudo add-apt-repository multiverse
  dbg "[DONE]"
fi # }}}
if install 'bashrc'; then # {{{
  dbg -n "Configuring (bashrc)... "
  ln -sf $script_path/bash/bashrc ~/.bashrc
  ln -sf $script_path/bash/bash_profile ~/.bash_profile
  ln -sf $script_path/bash/bash_login ~/.bash_login
  ln -sf $script_path/bash/profile ~/.profile
  ln -sf $script_path/bash/inputrc ~/.inputrc
  dbg "[DONE]"
fi # }}}
if install 'bin-path'; then # {{{
  dbg -n "Configuring ($bin_path)... "
  command mkdir -p $bin_path
  for i in $script_path/bin/*; do
    [[ -f $i ]] && ln -s $i $bin_path/
  done
  [[ -e $script_path/bin/ticket-tool ]] && ln -s $script_path/bin/ticket-tool $bin_path/
  dbg "[DONE]"
fi # }}}
if install 'bin-misc'; then # {{{
  dbg    "Configuring (bin-misc)... "
  TO_INSTALL_BIN_MISC="${TO_INSTALL_BIN_MISC/BASIC/$INSTALL_BIN_MISC_BASIC}"
  dbg    "  List: [$(echo $TO_INSTALL_BIN_MISC)]"
  command mkdir -p $bin_path/misc
  paths="$script_path/bin/misc"
  for i in $SETUP_PROFILES; do
    paths+=" $script_path/bash/profiles/$i/bin/misc"
  done
  for i in $TO_INSTALL_BIN_MISC; do
    found=false
    for p in $paths; do
      if [[ -e "$p/$i" ]]; then
        found=true
        if [[ -d "$p/$i" ]]; then
          for j in $(cd $p/$i; echo *); do
            ln -sf $p/$i/$j $bin_path/misc/
          done
        else
          ln -sf $p/$i $bin_path/misc/
        fi
      fi
    done
    $found || dbg "  Not found [$i]"
  done
  dbg "[DONE]"
fi # }}}
if install 'bash-path'; then # {{{
  dbg -n "Configuring ($bin_path/bash)... "
  command mkdir -p $bin_path/bash
  for i in $script_path/bash/*; do
    [[ -f $i ]] && ln -s $i $bin_path/bash/
  done
  ln -s $script_path/bash/completion.d $bin_path/bash/
  ln -s $script_path/bash/personalities $bin_path/bash/
  command mkdir $bin_path/bash/profiles
  for i in $SETUP_PROFILES; do
    [[ ! -e $bin_path/bash/profiles/$i ]] && ln -s $script_path/bash/profiles/$i $bin_path/bash/profiles/$i
  done
  for i in $bin_path/bash/profiles/*/bin/*; do
    [[ -f $i ]] && ln -s $i $bin_path/
  done
  dbg "[DONE]"
fi # }}}
if install 'my-proj-path-as-kb'; then # {{{
  ln -sf $bin_path/ticket-tool/ticket-data.sh $MY_PROJ_PATH/.ticket-data.sh
  if [[ ! -e $MY_PROJ_PATH/.env ]]; then
    cat >$MY_PROJ_PATH/.env <<-'EOF'
			#!/bin/bash
			if [[ -n $TICKET_TOOL_PATH && -e $TICKET_TOOL_PATH/session-init.sh ]]; then
			  source $TICKET_TOOL_PATH/session-init.sh "$MY_PROJ_PATH" "ENV"
			fi
		EOF
  fi
fi # }}}
if install 'fonts' && [[ -e $SHARABLE_PATH && -e $HOME/.local/share/fonts ]]; then # {{{
  dbg -n "Configuring (fonts)... "
  fonts="FiraMono Inconsolata" dst="$HOME/.local/share/fonts"
  $IS_MAC && dst="$HOME/Library/Fonts"
  for f in $fonts; do
    [[ "$(command cd $dst; echo $f*)" == "$f"'*' ]] || continue
    unzip -q -d "$dst" "$SHARABLE_PATH/sharable/fonts/${f}.zip" \*.ttf
  done
  dbg "[DONE]"
fi # }}}
if install 'colors'; then # {{{
  dbg "Pleasant colours:"
  dbg "  black      : #121212"
  dbg "  red        : #ED655C"
  dbg "  green      : #98971A"
  dbg "  yellow     : #D79921"
  dbg "  blue       : #458588"
  dbg "  magenta    : #B16286"
  dbg "  cyan       : #689D6A"
  dbg "  white      : #FBF1C7"
  dbg "  br.black   : #928374"
  dbg "  br.red     : #FB4934"
  dbg "  br.green   : #B8BB26"
  dbg "  br.yellow  : #FABD2F"
  dbg "  br.blue    : #83A598"
  dbg "  br.magenta : #D3869B"
  dbg "  br.cyan    : #8EC07C"
  dbg "  br.white   : #EBDBB2"
  dbg "  -- From: https://github.com/morhetz/gruvbox"
  if ! ${IS_MAC:-false}; then
    if [[ -z $TERMINAL_PROFILE ]]; then
      TERMINAL_PROFILE="$(dconf list "/org/gnome/terminal/legacy/profiles:/" | command grep "^:" |  head -n1)"
      TERMINAL_PROFILE="${TERMINAL_PROFILE#:}"
      TERMINAL_PROFILE="${TERMINAL_PROFILE%/}"
    fi
    if [[ ! -z $TERMINAL_PROFILE ]]; then
      dconf write "/org/gnome/terminal/legacy/profiles:/:$TERMINAL_PROFILE/palette" \
          "[ \
              'rgb(18,18,18)',    'rgb(237,101,92)', 'rgb(152,151,26)', 'rgb(215,153,33)', 'rgb(69,133,136)',  'rgb(177,98,134)',  'rgb(104,157,106)', 'rgb(251,241,199)', \
              'rgb(146,131,116)', 'rgb(251,73,52)',  'rgb(184,187,38)', 'rgb(250,189,47)', 'rgb(131,165,152)', 'rgb(211,134,155)', 'rgb(142,192,124)', 'rgb(235,219,178)'  \
           ]"
      dconf write "/org/gnome/terminal/legacy/profiles:/:$TERMINAL_PROFILE/background-color"   "'rgb(18,18,18)'"
      dconf write "/org/gnome/terminal/legacy/profiles:/:$TERMINAL_PROFILE/bold-color"         "'rgb(168,153,132)'"
      dconf write "/org/gnome/terminal/legacy/profiles:/:$TERMINAL_PROFILE/foreground-color"   "'rgb(235,219,178)'"
      dconf write "/org/gnome/terminal/legacy/profiles:/:$TERMINAL_PROFILE/font"               "'Fira Mono 13'"
    else
      dbg "  dconf write"
      dbg "    '/org/gnome/terminal/legacy/profiles:/:\$TERMINAL_PROFILE/palette'"
      dbg "    \"["
      dbg "        'rgb(18,18,18)',    'rgb(237,101,92)', 'rgb(152,151,26)', 'rgb(215,153,33)', 'rgb(69,133,136)',  'rgb(177,98,134)',  'rgb(104,157,106)', 'rgb(251,241,199)',"
      dbg "        'rgb(146,131,116)', 'rgb(251,73,52)',  'rgb(184,187,38)', 'rgb(250,189,47)', 'rgb(131,165,152)', 'rgb(211,134,155)', 'rgb(142,192,124)', 'rgb(235,219,178)'"
      dbg "     ]\""
      dbg " dconf write '/org/gnome/terminal/legacy/profiles:/:\$TERMINAL_PROFILE/background-color'   \"'rgb(18,18,18)'\""
      dbg " dconf write '/org/gnome/terminal/legacy/profiles:/:\$TERMINAL_PROFILE/bold-color'         \"'rgb(168,153,132)'\""
      dbg " dconf write '/org/gnome/terminal/legacy/profiles:/:\$TERMINAL_PROFILE/foreground-color'   \"'rgb(235,219,178)'\""
      dbg " dconf write '/org/gnome/terminal/legacy/profiles:/:\$TERMINAL_PROFILE/font'               \"'Fira Mono 13'\""
    fi
  fi
  dbg "[DONE]"
fi # }}}
if install 'vim'; then # {{{
  dbg -n "Configuring (vim)... "
  vim_repo_path=$(cd $script_path/../vim; pwd)
  ln -sf $vim_repo_path/vimrc ~/.vimrc
  rm -rf ~/.vim
  ln -sf $vim_repo_path/vim ~/.vim

  vim_specific=$HOME/.vimrc.specific
  [[ ! -z $SETUP_PROFILES ]] && appender $vim_specific $(eval echo $script_path/bash/profiles/{${SETUP_PROFILES// /,}}/inits/vim/vim-specific)

  vim_path=$bin_path/vims
  command mkdir -p $vim_path
  ln -s $vim_repo_path/mvim $vim_path/
  pushd $vim_path >/dev/null
  for i in {,_}{,g,m,r}{vi,view,vim,vimdiff} vimdiffgit; do
    [[ "$i" == 'mvim' ]] && continue
    ln -s mvim $i
  done
  ln -s mvim vim-session
  popd >/dev/null
  chmod +x $vim_path/*
  dbg "[DONE]"
fi # }}}
if install 'git'; then # {{{
  dbg -n "Configuring (git)... "
  ln -sf $script_path/git/gitconfig ~/.gitconfig
  ln -sf $script_path/git/gitignore ~/.gitignore
  rm -f ~/.git_template
  ln -sf $script_path/git/template ~/.git_template
  ln -sf $script_path/git/git-cmds.sh $bin_path/
  if [[ ! -e $RUNTIME_PATH/gitconfig ]]; then
    echo "[include] # {{{" >$RUNTIME_PATH/gitconfig
    for p in $SETUP_PROFILES; do
      echo "  path = $HOME/.bin/bash/profiles/$p/gitconfig" >>$RUNTIME_PATH/gitconfig
    done
    echo "# }}}" >>$RUNTIME_PATH/gitconfig
  fi
  dbg "[DONE]"
fi # }}}
if install 'tmux'; then # {{{
  dbg -n "Configuring (tmux)... "
  # rm -rf ~/.tmux
  [[ ! -e ~/.tmux/plugins ]] && command mkdir -p ~/.tmux/plugins
  ln -sf $script_path/bash/inits/tmux/plugins/tpm   ~/.tmux/plugins
  ln -sf $script_path/bash/inits/tmux/tmux-chain.sh ~/.tmux/
  ln -sf $script_path/bash/inits/tmux/tmux.conf     ~/.tmux.conf
  ln -sf $script_path/bash/inits/tmux/tmux.bash     ~/.tmux.bash
  dbg "[DONE]"
fi # }}}
if install 'mc'; then # {{{
  dbg -n "Configuring (mc)... "
  [[ ! -e ~/.config ]] && command mkdir -p ~/.config
  rm -rf ~/.config/mc
  cp -rf $script_path/bash/inits/mc ~/.config/
  command mkdir -p ~/.local/share
  rm -rf ~/.local/share/mc
  ln -sf $script_path/bash/inits/mc/share ~/.local/share/mc
  ln -sf ~/.config/mc.menu ~/.mc.menu
  dbg "[DONE]"
fi # }}}
if install 'htop'; then # {{{
  dbg -n "Configuring (htop)... "
  [[ ! -e ~/.config ]] && command mkdir -p ~/.config
  ln -sf $script_path/bash/inits/htop ~/.config/
  dbg "[DONE]"
fi # }}}
if install 'alacritty'; then # {{{
  dbg -n "Configuring (alacritty)... "
  [[ ! -e ~/.config/alacritty ]] && command mkdir -p ~/.config/alacritty
  src="$script_path/bash/inits/alacritty/alacritty$($IS_MAC && echo "-os" || echo "").yml"
  ln -sf $src ~/.config/alacritty.yml
  dbg "[DONE]"
fi # }}}
if install 'fzf'; then # {{{
  if [[ ! -e $HOME/.fzf.bash ]]; then
    dbg -n "Configuring (fzf)... "
    (
      cd $script_path/bash/inits/fzf
      if [[ -e 'install' ]]; then
        ./install --completion --key-bindings --no-update-rc --no-zsh --no-fish
        dbg "[DONE]"
      else
        dbg "[NO FZF]"
      fi
    )
  fi
fi # }}}
if install 'grc'; then # {{{
  dbg -n "Configuring (grc)... "
  rm -rf ~/.grc
  ln -sf $script_path/bash/inits/grc ~/.grc
  dbg "[DONE]"
fi # }}}
if install 'atom'; then # {{{
  dbg -n "Configuring (atom)... "
  [[ ! -e ~/.atom ]] && command mkdir -p ~/.atom
  for i in $(ls $script_path/bash/inits/atom/); do
    [[ -e ~/.atom/$i ]] && rm -rf ~/.atom/$i
    ln -sf $script_path/bash/inits/atom/$i ~/.atom/
  done
  dbg "[DONE]"
fi # }}}
if install 'less-highlight' && $INSTALL_SUDO_ALLOWED; then # {{{
  if which dpkg >/dev/null 2>&1 && ! dpkg -L libsource-highlight-common >/dev/null 2>&1; then
    dbg "Configuring (less-highlight)... "
    sudo apt install libsource-highlight-common source-highlight
    dbg "[DONE]"
  fi
fi # }}}
if install 'ap-calc'; then # {{{
  dbg -n "Configuring (ap-calc)... "
  ln -sf $script_path/bash/inits/calcrc ~/.calcrc
  dbg "[DONE]"
fi # }}}
if install 'tig'; then # {{{
  dbg -n "Configuring (tig)... "
  ln -sf $script_path/bash/inits/tigrc ~/.tigrc
  dbg "[DONE]"
fi # }}}
if install 'dconf'; then # {{{
  do_dconf
fi # }}}
if install 'abcde'; then # {{{
  dbg -n "Configuring (abcde)... "
  ln -sf $script_path/bash/inits/abcde.conf ~/.abcde.conf
  dbg "[DONE]"
fi # }}}
if install 'autostart'; then # {{{
  dbg -n "Configuring (autostart)... "
  [[ ! -e ~/.config/autostart ]] && command mkdir -p ~/.config/autostart
  for i in $(ls $script_path/bash/inits/autostart); do
    rm -rf ~/.config/autostart/$i
    ln -sf $script_path/bash/inits/autostart/$i ~/.config/autostart/$i
  done
  dbg "[DONE]"
fi # }}}
if install 'notify-log' && $INSTALL_SUDO_ALLOWED; then # {{{
  dbg -n "Configuring (notify-log)... "
  [[ ! -e /etc/profile.d/notify_log.sh ]] && sudo ln -s $script_path/bash/inits/profile.d/notify_log.sh /etc/profile.d/notify_log.sh
  dbg "[DONE]"
fi # }}}
if install 'marblemouse' && [[ $AUTO_INSTALL_TOOLS != false ]] && $INSTALL_SUDO_ALLOWED; then # {{{
  dbg -n "Configuring (X11 Marble Mouse)... "
  if [[ ! -e /usr/share/X11/xorg.conf.d/50-marblemouse.conf ]]; then
    f=
    v="$(lsb_release -a 2>/dev/null | awk '/^Release:/ {print $2}')"
    if [[ -e "$script_path/bash/inits/x11/50-marblemouse-$v.conf" ]]; then
      f="$script_path/bash/inits/x11/50-marblemouse-$v.conf"
    else
      f="$script_path/bash/inits/x11/50-marblemouse.conf"
    fi
    while true; do
      dbg
      read -p "Install support for Marble Mouse [y/n] ? " key
      case $key in
      y|Y)
        sudo ln -sf $f /usr/share/X11/xorg.conf.d/
        ;&
      n|N) break;;
      esac
    done
  fi
  dbg "[DONE]"
fi # }}}
if install 'pulse-audio'; then # {{{
  dbg -n "Configuring (pulse-audio)... "
  command mkdir -p ~/.config/pulse
  ln -sf $script_path/bash/inits/pulse-audio/default.pa ~/.config/pulse/
  dbg "[DONE]"
fi # }}}
if install 'x-opengl' && $INSTALL_SUDO_ALLOWED; then # {{{
  dbg -n "Configuring (support for OpenGL in X)... "
  if ! command grep -q "^export MOZ_USE_OMTC=1" /etc/X11/Xsession.d/90environment; then
    sudo bash -c "echo export MOZ_USE_OMTC=1 >> /etc/X11/Xsession.d/90environment"
  fi
  dbg "[DONE]"
fi # }}}
if install 'vrapper-eclipse'; then # {{{
  dbg -n "Configuring (vrapper-eclipse)... "
  ln -sf $script_path/bash/inits/eclipse/vrapperrc ~/.vrapperrc
  dbg "[DONE]"
fi # }}}
if install 'agignore'; then # {{{
  dbg -n "Configuring (agignore)... "
  cfg_file=$HOME/.agignore
  files="$script_path/bash/inits/agignore"
  [[ ! -z $SETUP_PROFILES ]] && files+=" $(eval echo $script_path/bash/profiles/{${SETUP_PROFILES// /,}}/inits/agignore)"
  appender $cfg_file $files
  ln -sf $HOME/.agignore $HOME/.fdignore
  dbg "[DONE]"
fi # }}}
if install 'gdb'; then # {{{
  dbg -n "Configuring (gdb)... "
  p="$HOME/.config/gdb"
  [[ -e $p ]] || command mkdir -p $p
  rm -rf $HOME/.gdbinit
  ln -sf $script_path/bash/inits/gdb/gdbinit "$HOME/.gdbinit"
  nr=1
  for i in $(ls $script_path/bash/inits/gdb/*.gdb 2>/dev/null); do
    fname=${i##*/}
    if ! ls $p/*${fname}* >/dev/null 2>&1; then
      [[ $fname =~ ^[0-9]{3}-* ]] \
        && ln -sf $i $p/$fname \
        || ln -sf $i $p/$(printf "%03d-%s" "$nr" "$fname")
    fi
    nr=$(($nr+1))
  done
  nrj=10
  for j in $SETUP_PROFILES; do
    nr=$nrj
    for i in $(ls $script_path/bash/profiles/$j/inits/gdb/*.gdb 2>/dev/null); do
      fname=${i##*/}
      if ! ls $p/*${fname}* >/dev/null 2>&1; then
        [[ $fname =~ ^[0-9]{3}-* ]] \
          && ln -sf $i $p/$fname \
          || ln -sf $i $p/$(printf "%03d-%s" "$nr" "$fname")
      fi
      nr=$(($nr+1))
    done
    nrj=$(($nrj+10))
  done
  nr="050"
  ls $p/*gdb-dashboard.gdb* >/dev/null 2>&1 || echo "https://github.com/cyrus-and/gdb-dashboard.git" >$p/${nr}-gdb-dashboard.gdb.ign
  nr="060"
  ls $p/*peda.py* >/dev/null 2>&1 || echo "https://github.com/longld/peda.git" >$p/${nr}-peda.py.ign
  dbg "[DONE]"
fi # }}}
if install 'ssh-config'; then # {{{
  dbg -n "Configuring (ssh-config)... "
  cfg_file=$HOME/.ssh/config
  [[ -e $cfg_file ]] || touch $cfg_file
  files="$script_path/bash/inits/ssh/config"
  [[ ! -z $SETUP_PROFILES ]] && files+=" $(eval echo $script_path/bash/profiles/{${SETUP_PROFILES// /,}}/inits/ssh/config)"
  appender $cfg_file $files
  dbg "[DONE]"
fi # }}}
if install 'tmux-tarball'; then # {{{
  v="$(echo "$TO_INSTALL" | sed 's/ tmux-tarball\(:\([^ ]*\)\)\{0,1\} /\2/')"
  if ! type tmux >/dev/null 2>&1 || [[ -z $v || $(tmux -V) != "tmux $v" ]]; then
    dbg -n "  Configuring (tmux-tarball [${v:-Ver not specified}])... "
    command mkdir -p $HOME/.config
    cd $HOME/.config
    [[ -e tmux-local ]] && mv tmux-local $TMP_PATH/tmux-local.$(command date +"$DATE_FMT")
    suffix=
    if type apt-get 1>/dev/null 2>&1; then
      suffix='-ubu'
    elif $IS_MAC; then
      suffix='-osx'
    elif type yum 1>/dev/null 2>&1; then
      suffix='-centos'
    fi
    [[ ! -z $v ]] && v="-$v"
    file=$script_path/bash/inits/tmux/src/tmux-local${v}${suffix}.tar.gz
    [[ ! -e $file ]] && file=$script_path/bash/inits/tmux/src/tmux-local${suffix}.tar.gz
    if [[ -e $file ]]; then
      tar xzf $file
      [[ ! -e $bin_path/tmux-local-bin ]] && ln -sf $HOME/.config/tmux-local/local/bin $bin_path/tmux-local-bin
      dbg "[DONE]"
    else
      dbg "[FILE NOT FOUND]"
    fi
    cd - >/dev/null 2>&1
  fi
fi # }}}
if install 'radare2'; then # {{{
  if ! type radare2 >/dev/null 2>&1; then
    dbg "Configuring [radare2]... "
    [[ ! -e $MY_PROJ_PATH/oth ]] && command mkdir -p $MY_PROJ_PATH/oth
    pushd $MY_PROJ_PATH/oth >/dev/null 2>&1
    [[ ! -e radare2 ]] && git clone https://github.com/radare/radare2
    cd radare2
    if $INSTALL_SUDO_ALLOWED; then
      sudo sys/install.sh
    else
      sys/install.sh
    fi
    ln -sf $script_path/bash/inits/radare2rc $HOME/.radare2rc
    popd >/dev/null 2>&1
    dbg "[DONE]"
  fi
fi # }}}
if install 'gdb-peda'; then # {{{
  [[ ! -e $MY_PROJ_PATH/oth ]] && command mkdir -p $MY_PROJ_PATH/oth
  if [[ ! -e $MY_PROJ_PATH/oth/gdb-peda ]]; then
    dbg "Configuring [gdb-peda]... "
    git clone https://github.com/longld/peda.git $MY_PROJ_PATH/oth/gdb-peda
    echo "source $MY_PROJ_PATH/oth/gdb-peda/peda.py" >> ~/.gdbinit
    dbg "[DONE]"
  fi
fi # }}}
if install 'ack'; then # {{{
  dbg -n "Configuring [ack]... "
  msg="DONE"
  if ! type ack >/dev/null 2>&1; then
    if ! type ack-grep >/dev/null 2>&1; then
      msg="NOT INSTALLED"
    else
      ln -sf $(which ack-grep) $bin_path/ack
    fi
  fi
  ln -sf $script_path/bash/inits/ack/ackrc ~/.ackrc
  dbg "[$msg]"
fi # }}}
if install 'gitsh'; then # {{{
  :
  # sudo apt update
  # sudo apt install ruby2.3 ruby2.3-dev
  # sudo apt install libreadline6 libreadline6-dev
  # wget https://github.com/thoughtbot/gitsh/releases/download/v0.12/gitsh-0.12.tar.gz
  # tar -zxvf gitsh-0.12.tar.gz
  # ./configure
  # make
  # sudo make install
fi # }}}
if install 'speedtest-net' && $INSTALL_SUDO_ALLOWED; then # {{{
  dbg "Configuring (speedtest-net)... "
  if ! $IS_MAC; then
    sudo apt-get install curl
    curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash
    sudo apt-get install speedtest
  else
    brew tap teamookla/speedtest
    brew update
    brew install speedtest --force
  fi
  dbg "[DONE]"
fi # }}}
# }}}
# Install tools {{{
if install 'install-tools'; then
  tools="$TO_INSTALL_TOOLS"
  to_remove=
  for i in $tools; do
    [[ $i == -* ]] && to_remove+=" $i"
  done
  tools="$(echo " $tools " | sed -e 's/ -[^ ]*//g')"
  tools="$(echo $tools)"
  if [[ -z $tools ]]; then
    tools="$TO_INSTALL_TOOLS_BASIC"
    if ! $IS_MAC; then
      tools+=" $TO_INSTALL_TOOLS_UBU"
    else
      tools+=" $TO_INSTALL_TOOLS_MAC"
    fi
    install_full=true
  fi
  ! $IS_MAC && type apt-get >/dev/null 2>&1 && $INSTALL_SUDO_ALLOWED && sudo apt-get update || true
  tools+=" $TO_INSTALL_TOOLS_EXTRA $to_remove"
  dbg "Tools: To install: [$tools]"
  for i in $tools; do
    [[ $i == -* ]] && continue
    echo " $to_remove " | command grep -q " -${i} " && continue
    inst= prg= ppa=
    get_app_name $i
    dbg -n "Checking [$prg:$inst$([[ ! -z $ppa ]] && echo " from $ppa")]... "
    if ! which $prg >/dev/null 2>&1; then
      do_install
    else
      dbg "[DONE]"
    fi
  done

  if ${install_full:-false} && ! $IS_MAC; then
    tools="autofs nfs-kernel-server"
    for i in $tools; do
      get_app_name $i
      dbg -n "Checking [$prg]... "
      if ! ls /etc/init.d | command grep $prg 1>/dev/null; then
        do_install
      else
        dbg "[DONE]"
      fi
    done
  fi
fi
# }}}
for i in $bin_path/bash/profiles/*; do # {{{
  dbg "Configuring profile (${i/*\/})... "
  [[ -e $i/mk_install_scripts.sh ]] && source $i/mk_install_scripts.sh || true
done # }}}
# }}}
# Finish {{{
[[ ! -z $INSTALL_FAILED ]] && echo -en "Some of installations have failed: [$INSTALL_FAILED]\nPress any key to proceed..." >/dev/stderr && read
$DO_EXEC && exec bash || true
# }}}

