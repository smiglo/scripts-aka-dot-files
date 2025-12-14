#!/usr/bin/env bash

python="${PYTHON:-python}"
vExp="3.9.0"
vEnv="./${AI_VENV_PATH:-.venv}"

v="$($python --version)"
v="${v##* }"

echoe -m prepare-ai "Python: $v"

if [[ $v != $vExp && "$v" != "$(echo -en "$v\n$vExp" | sort -Vr | head -n1)" ]]; then
  echoe -m prepare-ai "Python needs to be $vExp+"
fi

echoe -m prepare-ai "Setting venv in $vEnv"
$python -m venv $vEnv
source $vEnv/bin/activate || exit $?

echoe -m prepare-ai "Installing packages"
pip install -r requirements.txt || exit $?
echoe -m prepare-ai "source $vEnv/bin/activate"

