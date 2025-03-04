#!/usr/bin/env bash

python="${PYTHON:-python}"
vExp="3.9.0"
vEnv="./${AI_VENV_PATH:-.venv}"

v="$($python --version)"
v="${v##* }"

echor "Python: $v"

if [[ $v != $vExp && "$v" != "$(echo -en "$v\n$vExp" | sort -Vr | head -n1)" ]]; then
  echor "Python needs to be $vExp+"
fi

echor "Setting venv in $vEnv"
$python -m venv $vEnv
source $vEnv/bin/activate || exit $?

echor "Installing packages"
pip install -r requirements.txt || exit $?
echor "source $vEnv/bin/activate"

