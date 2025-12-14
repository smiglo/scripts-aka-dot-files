# Setup fzf
# ---------
if ! ${FZF_USE_SYSTEM:-false} && [[ -z $FZF_PATH ]]; then
  if [[ $(cd $SCRIPT_PATH/bash/inits/fzf; echo *) != '*' ]]; then
    [[ ":$PATH:" == *:$SCRIPT_PATH/bash/inits/fzf/bin:* ]] || export PATH="$SCRIPT_PATH/bash/inits/fzf/bin:$PATH"
  else
    echoe -m fzf "no fzf submodule"
  fi
fi
if type fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
  if ! type __fzf_default_completion >/dev/null 2>&1 && [[ -e $FZF_PATH/../shell/completion.bash ]]; then
    source $FZF_PATH/../shell/completion.bash
  fi
else
  echoe -m fzf "no fzf installation"
fi

