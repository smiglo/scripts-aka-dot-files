#!/usr/bin/env bash
# vim: fdl=0

_share() { # @@ # {{{
  local share_path="$SHARABLE_PATH/shares"
  local mode=list
  if [[ ! -t 0 ]]; then
    mode=put
  elif [[ ! -t 1 ]]; then
    mode=list
  fi
  if [[ $1 == '@@' ]]; then # {{{
    local d="$share_path" list=
    [[ " $@ " == *" --path "* ]] && d="$(echo " $@ " | sed -e 's/.* --path *//' -e 's/ .*//')"
    case $3 in
    -i);;
    -e) # {{{
      ag --follow -g "" ;; # }}}
    --path) # {{{
      "@@-d";; # }}}
    -n) # {{{
      [[ -e $d ]] && list="$(cd "$d"; find -mindepth 1 -maxdepth 1 -type d -not -path './.*'  | cut -c3-)"
      echo "${list:----}";; # }}}
    *) # {{{
      echo "- -- -n --path -N -i --include -e --exclude --clean --note -F"
      echo "--get --list --list-full --put --vim --cd --cfg"
      echo "--cp --cat --rsync"
      ;;# }}}
    esac
    return 0
  fi # }}}
  local direct=false clean=false copyMode=cp cfgFile=".shr.cfg" short=true dry= i=
  local name= toInclude= toExclude fName= dbgLvl=0
  local rsyncP="-ahtpH --no-whole-file --modify-window=2 --no-v --no-progress --info=progress2"
  while [[ ! -z $1 ]]; do # {{{
    case $1 in
    --clean)  clean=true;;
    --path)   share_path=$2; shift;;
    --get)    mode=get;;
    --list)   mode=list;;
    --list-full) mode=list; short=false;;
    --put)    mode=put;;
    --vim)    mode=vim;;
    --cat)    copyMode=cat; mode=get;;
    --cp)     copyMode=cp;;
    --rsync)  copyMode=rsync;;
    --cd)     mode=cd;;
    --cfg)    mode=edit-cfg;;
    --note)   mode=put-note; direct=true;;
    -i | --include) toInclude+=" $2"; shift;;
    -e | --exclude) toExclude+=" $2"; shift;;
    -N)       dry=echo;;
    -v)       dbgLvl=1;;
    -)        direct=true;;
    --)       direct=true; clean=true;;
    -n)       name=$2; shift;;
    -F)       name=; fName="$share_path"; direct=true;;
    esac; shift
  done # }}}
  [[ ! -e $share_path ]] && mkdir -p $share_path
  local nameStored= toIncludeStored= toExcludeStored= toExcludeAlways="\.ign"
  declare -A path toIncludeA toExcludeA
  [[ -e $cfgFile ]] || touch $cfgFile
  source <(sed 's/=/Stored=/' $cfgFile)
  if [[ -z $name ]]; then # {{{
    if [[ ! -z $nameStored ]]; then
      name="$nameStored"
      echoe $dbgLvl "Using stored share: $name"
    else
      case $mode in
      put) # {{{
        [[ -z $name ]] && name="$(date +$DATE_FMT)";; # }}}
      get | list | vim | cd | edit-cfg) # {{{
        [[ -z $name ]] && name=$(get-file-list --pwd $share_path -t -1 '*')
        [[ -z $name ]] && eval $(die "No shares are present")
        ;; # }}}
      esac
      echoe $dbgLvl "Using auto-detected share: $name"
    fi
  fi # }}}
  [[ -z $fName ]] && fName=$share_path/$name
  if [[ -e $fName/$cfgFile ]]; then # {{{
    local nameOrig= toIncludeOrig= toExcludeOrig=
    source <(sed 's/=/Orig=/' $fName/$cfgFile)
  fi # }}}
  for i in ${!pathOrig[*]}; do # {{{
    path[$i]=${pathOrig[$i]}
  done # }}}
  while read i; do # {{{
    [[ -z $i ]] && continue
    toIncludeA[$i]=""
  done < <(echo "$toInclude $toIncludeStored $toIncludeOrig")
  toInclude="${!toIncludeA[*]}" # }}}
  while read i; do # {{{
    [[ -z $i ]] && continue
    toExcludeA["$i"]=""
  done < <(echo "$toExclude $toExcludeStored $toExcludeOrig")
  toExclude="${!toExcludeA[*]}" # }}}
  local hostName="$(echo "$HOSTNAME" | sha1sum | cut -c1-6)"
  path[$hostName]="$(echo "${PWD/$HOME/\~}" | base64)"
  rm $cfgFile
  echo "name=\"$name\"" >>$cfgFile
  echo "$(declare -p path)" >>$cfgFile
  [[ ! -z $toInclude ]] && echo "toInclude=\"$toInclude\"" >>$cfgFile
  [[ ! -z $toExclude ]] && echo "toExclude=\"$toExclude\"" >>$cfgFile
  case $mode in
  put | put-note) # {{{
    [[ ! -e $fName ]] && mkdir -p $fName
    $clean && $dry rm -rf $fName/* $fName/.*
    local in=
    case $mode in
    put) # {{{
      if [[ -t 0 ]]; then # {{{
        in="$(ag --follow -g "")"
        in="$(echo -e "$in\n$(echo "$toInclude" | tr ' ' '\n')")"
        in="$(echo -e "$in" | grep -v "$toExcludeAlways")"
        [[ ! -z $toExclude ]] && in="$(echo -e "$in" | grep -v "${toExclude// /\\|}")"
        [[ -e notes.txt ]] && in="$(echo -e "$in\nnotes.txt")"
        in="$(echo -e "$in\n$cfgFile")"
        direct=false
        # }}}
      else # {{{
        in="$(cat -)"
        if ! $direct; then # {{{
          local out=
          for i in $in; do
            [[ -e $i ]] && out+="$i\n"
          done
          in="$(echo -e "$out")"
        fi # }}}
      fi # }}}
      [[ -z $in ]] && eval $(die "No input");; # }}}
    esac
    if $direct; then # {{{
      fName+="/notes.txt"
      [[ ! -e $fName ]] && echo -e "# vim: fdm=marker fdl=0\n" >$fName
      (
        echo "Note: $(date +$DATE_FMT): # {{{"
        echo "$in"
        echo "# }}}"
      ) >>$fName
      case $mode in
      put-note) # {{{
        vim --fast +"normal! GzMzvk" $fName;; # }}}
      esac
      # }}}
    else # {{{
      local list= cnt=0
      while read i; do
        [[ -z $i ]] && continue
        [[ ! -e $i ]] && eval $(die -c "Src: [$i] not exists, skipping")
        list+="$i "
        cnt=$((cnt+1))
      done < <(echo "$in" | sort -f)
      [[ -z $list ]] && eval $(die "Nothing to put")
      echoe $dbgLvl "To put: $(echo $list | sort -f | tr '\n' ' ')"
      if [[ $cnt -gt 15 ]]; then
        progress --wait 10s --key --msg "$(echoe -f "Copy all $cnt files?" 2>&1)" </dev/tty || return 0
      fi
      case $copyMode in
      cp)    $dry cp -a --parents $list $fName/;;
      rsync) $dry rsync $rsyncP $list $fName/;;
      esac
    fi # }}}
    ;; # }}}
  get | list) # {{{
    [[ ! -e $fName ]] && eval $(die "Src: [$name] not exists")
    case $mode in
    list) # {{{
      find $fName -path '*/*.git' -prune -o -type f | { if $short; then sed 's|.*/'$(basename $fName)'/||'; else cat -; fi; } | sort -f
      ;; # }}}
    get) # {{{
      cp $cfgFile $cfgFile.local
      local p=$PWD
      (
        cd $fName
        local list="$(find . -path './*.git' -prune -o -print | cut -c3- )"
        echoe $dbgLvl "To get: $(echo "$list" | sort -f | tr '\n' ' ' | sed 's/^ *//')"
        case $copyMode in
        cp)    $dry cp -a --parents $list $p/;;
        rsync) $dry rsync $rsyncP $list $p/;;
        cat)   find . -path '*/*.git' -prune -o -type f -exec cat {} \; ;;
        esac
      )
      mv $cfgFile.local $cfgFile
      ;; # }}}
    esac;; # }}}
  vim) # {{{
    [[ ! -e $fName ]] && mkdir -p $fName
    vim --fast $fName/notes.txt </dev/tty;; # }}}
  cd) # {{{
    (
      cd $fName
      $SHELL </dev/tty >/dev/tty
    );; # }}}
  edit-cfg) # {{{
    vim $cfgFile $fName/$cfgFile </dev/tty >/dev/tty;; # }}}
  esac
  return 0
} # }}}
_share "$@"
