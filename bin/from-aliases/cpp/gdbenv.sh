#!/usr/bin/env bash
# vim: fdl=0

gdbenv() { # @@ # {{{
  if [[ $1 == @@ ]]; then # {{{
    case $(compl-short -i $3) in
    --db)
      echo "asm brk exp his mem reg src sta thr var";;
    --set-env)
      echo "core rr asm source"
      echo "db dashboard --db"
      echo "+core +rr -rr";;
    *)
      case $2 in
      1) get-file-list "*.out";;&
      2) # {{{
        [[ $3 == '--set-core' ]] && echo '---' && return 0
        local l="$(get-file-list "core.$3.*")"
        [[ -z "$l" ]] && echo "---" && return 0
        echo "$l";; # }}}
      *) echo "--set-env"; [[ $2 != '--' ]] && compl-short;;&
      esac;;
    esac
    return 0
  fi # }}}
  case $(compl-short -i $1) in
  --set-env) # {{{
    shift
    export GDB_DB="dbsource"
    export GDB_DB_O="$(tmux list-panes -F '#T #{pane_tty}' | awk '/gdb/ {print $2}' | sed 's|.*/||' | head -n 1)"
    local i=
    for i in asm brk exp his mem reg src sta thr var; do
      local -n v="GDB_DB_O_${i^^}"
      v="$(tmux list-panes -F '#T #{pane_tty}' | awk '/gdb-'$i'/ {print $2}' | sed 's|.*/||' | head -n 1)"
    done
    while [[ ! -z $1 ]]; do # {{{
      case $1 in
      +core) # {{{
        ulimit -c unlimited
        echo "core-%e-%p-%t.dmp" | sudo tee /proc/sys/kernel/core_pattern;; # }}}
      +rr) # {{{
        ulimit -c unlimited
        echo "1" | sudo tee /proc/sys/kernel/perf_event_paranoid
        [[ -e cpufreq-set ]] && sudo cpufreq-set -g performance;; # }}}
      -rr) # {{{
        echo "4" | sudo tee /proc/sys/kernel/perf_event_paranoid
        [[ -e cpufreq-set ]] && sudo cpufreq-set -g powersave;; # }}}
      esac
      case $1 in
      core | +core)   export GDB_DB="dbcore";;
      rr | asm | +rr) export GDB_DB="dbasm";;
      source | src)   export GDB_DB="dbsource";;
      db | dashboard) set-title --lock-force --set-pane gdb;;
      db-*)           set-title --lock-force --set-pane gdb-${1#db-};;
      --db)           set-title --lock-force --set-pane gdb-$2;;
      esac; shift
    done # }}}
    ;; # }}}
  *) # {{{
    local f="${1:-$(get-file-list -t -1 \*.out)}" && f="${f#./}"
    [[ -e $f ]] || { echor "Executable not found"; return 1; }
    local c="${2:-$(get-file-list -t -1 core.$f.\*)}"
    [[ -e $c ]] || { echor "Core file for executable [$f] not found"; return 1; }
    echo -e "\nRunning: gdb $f $c\n"
    gdb $f $c;; # }}}
  esac
} # }}}
_gdbenv "$@"

