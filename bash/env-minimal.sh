#!/usr/bin/env bash
# vim: fdl=0

# curl -sfSL https://raw.githubusercontent.com/smiglo/scripts-aka-dot-files/refs/heads/next/bash/env-minimal.sh | bash

repo="https://raw.githubusercontent.com/smiglo/scripts-aka-dot-files"
br="${ENV_BRANCH:-next}"

mkBackup() { # {{{
  local i=
  for i; do
    [[ -e $i ]] || continue
    cp "$i" "$i.$ts"
  done
} # }}}
getFile() { # {{{
  echo "GET: $1 -> $2" >&2
  curl -sfSL $repo/refs/heads/$br/$1 >"$2" 2>/dev/null && return 0
  echo "ERR: $2 not downloaded ($1)" >&2
  return 1
} # }}}

printf -v ts "%(%Y%m%d-%H%M%S)T\n" $EPOCHSECONDS
dir="${ENV_DIR:-$HOME}"

while [[ -n $1 ]]; do # {{{
  case $1 in
  -d | --dir) dir="$2"; shift;;
  -b | --branch) br="$2"; shift;;
  esac; shift
done # }}}

mkdir -p $dir
bashrcF="$dir/.bashrc-minimal"
inputrcF="$dir/.inputrc"
tmuxF="$dir/.tmux.conf"
vimrcF="$dir/.vimrc"

mkBackup $bashrcF $inputrcF $tmuxF $vimrcF

if getFile dot-files/bashrc-minimal $bashrcF; then
  if [[ $dir == $HOME ]] && ( [[ ! -e $HOME/.bashrc ]] || ! grep -q "source $bashrcF" $HOME/.bashrc ); then
    echo "source $bashrcF" >>$HOME/.bashrc
    echo "INF: source ~/.bashrc" >&2
  else
    echo "INF: source $bashrcF" >&2
  fi
fi
getFile dot-files/inputrc $inputrcF
getFile dot-files/root-vimrc $vimrcF
if getFile dot-files/tmux/tmux.conf $tmuxF; then
  sed -i \
    -e 's/^# \(.* # ENA-IN-MIN.*\)/\1/' \
    -e 's/\(.* # DIS-IN-MIN.*\)/# \1/' \
    $tmuxF
  if [[ $dir == $HOME ]]; then
    touch $HOME/.tmux.bash
    chmod +x $HOME/.tmux.bash
    pgrep tmux >/dev/null 2>&1 && tmux source-file $tmuxF
  fi
fi
