if [[ $(cd $SCRIPT_PATH/bash/inits/fzf; echo *) != '*' ]]; then
  if ! ${FZF_USE_SYSTEM:-false} && [[ -z $FZF_PATH ]] && [[ ! ":$PATH:" == *:$SCRIPT_PATH/bash/inits/fzf/bin:* ]]; then
    export PATH="$SCRIPT_PATH/bash/inits/fzf/bin:$PATH"
  fi
  [[ $- == *i* ]] && source "$SCRIPT_PATH/bash/inits/fzf/shell/completion.bash" 2>/dev/null
  source "$SCRIPT_PATH/bash/inits/fzf/shell/key-bindings.bash"
else
  echor "no fzf submodule"
fi
