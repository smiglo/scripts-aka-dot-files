#!/usr/bin/env bash

[[ -z $logger_level ]] && logger_level='NONE'
[[ -z $logger_debug_out ]] && logger_debug_out='/dev/stderr'

logger() { # {{{
  set +xv
  case $1 in # {{{
  '') # {{{
    [[ $logger_level -ge 5 ]] && set -xv
    return 0;; # }}}
  --help) # {{{
    (
      echo "logger --init|--reinit [LEVEL] [LOGGER_NAME] - Set a maximum level"
      echo "      LEVEL                                  - One of: [ NONE/-, ERROR/ERR/E, WARNING/WARN/W, INFO/I, DEBUG/DBG/D, TRACE/T ]"
      echo "                                               When TRACE, then 'set -xv' is enabled"
      echo "      LOGGER_NAME                            - A name"
      echo "logger [LEVEL] msg1                          - Print a message with given level, if level omitted, then it is INFO"
      echo "logger --end                                 - End work"
      echo
    ) >/dev/stderr
    [[ $logger_level -ge 5 ]] && set -xv
    return 0;; # }}}
  --end | --reinit) # {{{
    logger_level="$(logger --set-level 'NONE')"
    ;;& # }}}
  --init | --reinit) # {{{
    [[ ! -z $2 ]] && logger_level="$(logger --set-level $2)"
    [[ ! -z $3 ]] && logger_name="$3"
    [[ $logger_level -ge 5 ]] && set -xv
    return 0
    ;; # }}}
  --end) # {{{
    return 0;; # }}}
  --set-level) # {{{
    case $2 in
    [0-9])               echo "$2";;
    - | NONE)            echo "0";;
    E | ERR  | ERROR)    echo "1";;
    W | WARN | WARNING)  echo "2";;
    I | INFO)            echo "3";;
    D | DBG  | DEBUG)    echo "4";;
    T | TRACE)           echo "5";;
    *)                   return 1;;
    esac
    return 0;; # }}}
  esac # }}}
  [[ ${logger_level:-0} == 0 ]] && return 0
  local levels=(- ERR WARN INFO DBG TRACE) l="$(logger --set-level INFO)" v=
  v="$(logger --set-level "$1")" && l="$v" && shift
  if [[ $l -le $logger_level ]]; then
    [[ ! -z $logger_name ]] && printf "%s: " "$logger_name"
    printf "%-6s: %s\n" "${levels[$l]}" "$@"
  fi >>${logger_debug_out:-/dev/stderr}
  [[ $logger_level -ge 5 ]] && set -xv
  return 0
} # }}}

logger_level="$(logger --set-level "$logger_level")"

