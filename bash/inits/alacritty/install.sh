d=$HOME/.config/alacritty

[[ -e $d ]] || mkdir -p $d

src=linux
$IS_MAC && src=mac
sp=$SCRIPT_PATH/bash/inits/alacritty

for i in $src-alacritty.toml common.toml common-bindings.toml $src-specific.toml $src-bindings.toml; do
  df=$d/$i
  [[ $i == $src-alacritty.toml ]] && df=$d/alacritty.toml
  [[ -e $df ]] && mv $df $df.bak
  ln -sf $sp/$i $df
done

if [[ ! -e $d/local-conf.toml ]]; then
  touch $d/local-conf.toml
fi

