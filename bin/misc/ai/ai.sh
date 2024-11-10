#!/usr/bin/env bash

if [[ $1 == '@@' ]]; then
  case $3 in
  --prompt) echo "PROMPT-FILE";;
  --id) echo "MSG-FILE-ID";;
  -f | --file) echo "MSG-FILE";;
  *)
    echo "-h --help"
    echo "-i --improve"
    echo "-t --translate"
    echo "--promp"
    echo "--chat"
    echo "--id -f --file -n --new"
    echo "--vim"
    echo "--usage"
    ;;
  esac
  exit 0
fi

aiPwd="${AI_PATH:-$SCRIPT_PATH/bin/misc/ai}"
vEnv="${AI_VENV_PATH:-.venv}"

[[ -e "$aiPwd/$vEnv/bin/activate" ]] || die "venv not created"
source "$aiPwd/$vEnv/bin/activate"

[[ -z $GEMINI_API_KEY ]] && isInstalled keep-pass.sh && keep-pass.sh --has-key 'gemini_api' && export GEMINI_API_KEY="$(keep-pass.sh --get --key 'gemini_api')"
[[ ! -z $GEMINI_API_KEY ]] || die "No API key"

python $aiPwd/ai-assistant.py "$@"

