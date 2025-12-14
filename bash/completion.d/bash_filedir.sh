is-installed --no-cache -f _filedir || return
[[ $UID != 0 ]] || return
case $(type _filedir | sha1sum) in
"87baf0ec5011d57b5fc030852cf872ea28fe4e9d  -");;
"a321bc36262483e0ad7bacecca63a0bdfe9cf768  -");;
"$BASH_FILEDIR_SHA");;
*)
  if [[ ! $TMP_MEM_PATH/bash-filedir.orig ]]; then
    [[ ! -e $TMP_MEM_PATH/bash-filedir.orig ]] && echoe -m filedir "unknown definition, overridding, ($(type _filedir | sha1sum | cut -d' ' -f1))"
    type _filedir >$TMP_MEM_PATH/bash-filedir.orig
  fi;;
esac
# /usr/share/bash-completion/bash_completion
_filedir()
{
    local IFS=$'\n'

    _tilde "${cur-}" || return

    local -a toks
    local reset arg=${1-}

    if [[ $arg == -d ]]; then
        reset=$(shopt -po noglob)
        set -o noglob
        toks=($(compgen -d -- "${cur-}"))
        IFS=' '
        $reset
        IFS=$'\n'
    else
        local quoted
        _quote_readline_by_ref "${cur-}" quoted

        # Munge xspec to contain uppercase version too
        # https://lists.gnu.org/archive/html/bug-bash/2010-09/msg00036.html
        # news://news.gmane.io/4C940E1C.1010304@case.edu
        local xspec=${arg:+"!*.@($arg|${arg^^})"} plusdirs=()

        # Use plusdirs to get dir completions if we have a xspec; if we don't,
        # there's no need, dirs come along with other completions. Don't use
        # plusdirs quite yet if fallback is in use though, in order to not ruin
        # the fallback condition with the "plus" dirs.
        local opts=(-f -X "$xspec")
        [[ $xspec ]] && plusdirs=(-o plusdirs)
        [[ ${COMP_FILEDIR_FALLBACK-} || -z ${plusdirs-} ]] ||
            opts+=("${plusdirs[@]}")

        reset=$(shopt -po noglob)
        set -o noglob
        # ---
        local l
        while read -r l; do
          toks+=("${l// /\ }")
        done < <(compgen "${opts[@]}" -- "$quoted")
        # ---
        IFS=' '
        $reset
        IFS=$'\n'

        # Try without filter if it failed to produce anything and configured to
        [[ -n ${COMP_FILEDIR_FALLBACK-} && -n $arg && ${#toks[@]} -lt 1 ]] && {
            reset=$(shopt -po noglob)
            set -o noglob
            toks+=($(compgen -f ${plusdirs+"${plusdirs[@]}"} -- $quoted))
            IFS=' '
            $reset
            IFS=$'\n'
        }
    fi

    if ((${#toks[@]} != 0)); then
        # 2>/dev/null for direct invocation, e.g. in the _filedir unit test
        compopt -o filenames 2>/dev/null
        COMPREPLY+=("${toks[@]}")
    fi
} # _filedir()

