#!/usr/bin/env bash
# vim: fdl=0

c=$1
shift
ask() { # {{{
  case ${1,,} in
  y | -y) return 0
  esac
  local k=
  if ! read -t5 -p "$1 [NY] ? " k; then
    echo; return 2
  fi
  [[ $k == 'Y' ]] || return 1
} # }}}
IS_DOCKER=false
IS_WSL=false
if [[ -e /.dockerenv ]]; then
  IS_DOCKER=true
elif [[ -e /mnt/wsl ]]; then
  IS_WSL=true
fi
ret=
case $c in
-H | --help | help) # {{{
  ret+=" $(awk -F ')' '/^-.*).*#\s*\{{3}$/{print $1}' "$0" | sed -e '/($/d' -e 's/|//g' -e "s/''//g")" ;& # }}}
-h | '') # {{{
  ret+=" $(grep -v "# IGN" "$0" | awk -F ')' '/^[a-z].*).*#\s*\{{3}$/{print $1}' | sed -e '/(/d')"
  echo $ret | tr ' ' '\n' | sort | tr '\n' ' '; echo;; # }}}
-i | --install) # {{{
  sudo cp $0 /root/bin/utils.sh
  for i in $(find ./ -type f -executable -path './bin/oth/root--*.sh'); do
    sudo cp $i /root/bin/${i##*/root--}
  done
  for i in $(find -L $PROFILES_PATH -type f -executable -path '*/bin/oth/root--*.sh'); do
    sudo cp $i /root/bin/${i##*/root--}
  done
  if [[ -e $APPS_CFG_PATH/root-utils ]]; then
    for i in $(find -L $APPS_CFG_PATH/root-utils -type f -executable -name '*.sh'); do
      sudo cp $i /root/bin/${i##*/}
    done
  fi;; # }}}
reboot) # @@: -y # {{{
  if ask $1 'Reboot'; then
    if $IS_WSL; then
      /mnt/c/Windows/System32/shutdown.exe /r /t 0 /f
    elif [[ -e /usr/sbin/reboot.ask ]]; then
      /usr/sbin/reboot.ask
    elif [[ -e /usr/sbin/reboot ]]; then
      /usr/sbin/reboot
    elif which reboot >/dev/null 2>&1; then
      reboot
    else
      echo "Reboot command not found" >&2
      exit 1
    fi
  fi;; # }}}
suspend) # {{{
  if $IS_WSL; then
    /mnt/c/Windows/System32/shutdown.exe /h /f
  elif ${UTILS_SUSPEND_USE_PWR_MGR:-false} && [[ -e /usr/local/bin/power-manager.sh ]]; then
    sudo /usr/local/bin/power-manager.sh --now
  else
    systemctl suspend
  fi ;; # }}}
shutdown) # @@: -y # {{{
  if ask $1 'Shutdown'; then
    if $IS_WSL; then
      /mnt/c/Windows/System32/shutdown.exe /s /hybrid /t 0 /f
    elif [[ -e /usr/sbin/shutdown.ask ]]; then
      /usr/sbin/shutdown.ask now
    elif [[ -e /usr/sbin/shutdown ]]; then
      /usr/sbin/shutdown now
    elif which shutdown >/dev/null 2>&1; then
      shutdown now
    else
      echo "Reboot command not found" >&2
    fi
  fi;; # }}}
*) # {{{
  [[ -x "/root/bin/$c.sh" ]] || { echo "unknown command '$c'" >&2; exit 1; }
  "/root/bin/$c.sh" "$@"
  ;; # }}}
esac
