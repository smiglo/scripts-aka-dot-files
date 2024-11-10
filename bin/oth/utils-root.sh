#!/usr/bin/env bash
# vim: fdl=0

ret= c=$1
shift
ask() { # {{{
  [[ $1 == '-y' ]] && return 0
  local k=
  if ! read -t5 -p "$1 [NY] ? " k; then
    echo; return 2
  fi
  [[ $k == 'Y' ]] || return 1
} # }}}
case $c in
-H | --help | help) # {{{
  ret+=" $(awk -F ')' '/^-.*).*#\s*\{{3}$/{print $1}' "$0" | sed -e '/($/d' -e 's/|//g' -e "s/''//g")" ;& # }}}
-h | '') # {{{
  ret+=" $( command grep -v "# IGN" "$0" | awk -F ')' '/^[a-z].*).*#\s*\{{3}$/{print $1}' | sed -e '/(/d')"
  echo $ret | tr ' ' '\n' | sort | tr '\n' ' '; echo;; # }}}
-i | --install) # {{{
  sudo cp $0 /root/bin/utils.sh;; # }}}
resolv) # {{{
  vim /etc/resolv.conf </dev/tty >/dev/tty;; # }}}
reboot) # @@: -y # {{{
  if ask $1 'Reboot'; then
    if [[ -e /usr/sbin/reboot.ask ]]; then
      /usr/sbin/reboot.ask
    elif [[ -e /usr/sbin/reboot ]]; then 
      /usr/sbin/reboot
    elif which reboot >/dev/null 2>&1; then
      reboot
    else
      echo "Reboot command not found" >/dev/stderr
    fi
  fi;; # }}}
suspend) # {{{
  systemctl suspend;; # }}}
shutdown) # @@: -y # {{{
  if ask $1 'Shutdown'; then
    if [[ -e /usr/sbin/shutdown.ask ]]; then
      /usr/sbin/shutdown.ask now
    elif [[ -e /usr/sbin/shutdown ]]; then
      /usr/sbin/shutdown now
    elif which shutdown >/dev/null 2>&1; then
      shutdown now
    else
      echo "Reboot command not found" >/dev/stderr
    fi
  fi;; # }}}
fix-routing) # {{{
  ip route add 10.42.0.0/24 via 10.42.0.1;; # }}}
esac

