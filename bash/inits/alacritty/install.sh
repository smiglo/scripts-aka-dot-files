#!/usr/bin/env bash
# vim: fdl=0

d=$HOME/.config/alacritty
src="linux"
if $IS_MAC; then src="mac"
elif $IS_ARCH; then src="arch"
fi

sp=$SCRIPT_PATH/bash/inits/alacritty
cd $sp
[[ -e $d ]] || mkdir -p $d

for i in alacritty common colors bindings specific; do
  df="$d/$i.toml"
  [[ -e $i-$src.toml ]] && i="$i-$src"
  [[ -e $i.toml ]] || continue
  [[ -e $df ]] && mv $df $df.bak
  ln -sf $sp/$i.toml $df
done

if [[ ! -e $d/local-conf.toml ]]; then
  touch $d/local-conf.toml
fi
