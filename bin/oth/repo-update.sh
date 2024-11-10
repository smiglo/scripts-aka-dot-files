#!/bin/bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  case $3 in
  -f | --dump-rev) getFileList 'manifest*.xml';;
  --tag) echo "tmp/b- -";;
  *) echo -f -v --verify --diff --checkout{,+} --dump --tag --dump-rev;;
  esac
  exit 0
fi # }}}

fManifest="manifest.xml"
verify=false
verifyAfter=false
differs=false
showDiff=false
checkout=false
verbose=false
dump=false
tag=false
wtdSet=false
head=HEAD

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  -f)          fManifest="$2"; shift;;
  -v)          verbose=true;;
  --verify)    verify=true; wtdSet=true;;
  --diff)      showDiff=true; wtdSet=true;;
  --diff-to)   showDiff=true; wtdSet=true; head=$2; shift;;
  --checkout+) verifyAfter=true;&
  --checkout)  checkout=true; verify=true; wtdSet=true; dump=true;;
  --dump)      dump=true; wtdSet=true;;
  --tag)       tag=true; tagName="$2"; wtdSet=true; shift;;
  --dump-rev) # {{{
    fManifest="$2"; shift
    [[ ! -e $fManifest ]] && exit 1
    listRev=
    if [[ ! -z $fManifest ]]; then # {{{
      listRevMani="$(cat $fManifest | sed -n '/<project/s/.*\(path=[^ ]*\) .*\(revision=[^ ]*\).*/\1 \2/p' | sed 's|../onemw/|./|')"
      listRev=
      while read l; do
        [[ "$l" =~ path=\"(.*)\".*revision=\"(.*)\" ]] || continue
        d=${BASH_REMATCH[1]}
        [[ $d == './' ]] && continue
        [[ ! -e $d ]] && continue
        r=${BASH_REMATCH[2]}
        listRev+="<project path=\"$d\" revision=\"$r\"\\>\n"
      done < <(echo "$listRevMani")
      listRev="$(echo -e "$listRev" | sed '/^\s*$/d' | sort)"
    fi # }}}
    list=$(find . -type d -path '*/build-*' -prune -o -name .git -exec dirname {} \;)
    listRevRepo=$( # {{{
      for d in $list; do
        pushd $d >&/dev/null
        rHead="$(git rev-parse $head)"
        popd >&/dev/null
        if [[ -z $listRev ]] || echo "$listRev" | command grep -q "$d"; then
          echo "<project path=\"$d\" revision=\"$rHead\"\\>"
        fi
      done | sort
    ) # }}}
    [[ -z $fManifest ]] && echo "$listRevRepo" && exit 0
    if ! diff -q <(echo "$listRevRepo") <(echo "$listRev") >/dev/null; then
      if [[ -t 1 ]]; then
        vimdiff <(echo "$listRevRepo") <(echo "$listRev")
      else
        diff <(echo "$listRevRepo") <(echo "$listRev")
      fi
    else
      echo "The same"
    fi
    exit 0
    ;; # }}}
  esac; shift
done # }}}

[[ ! -e $fManifest ]] && echo "Manifest file [$fManifest] not found" >/dev/stderr && exit 1
! $wtdSet && exit 1

if $tag && [[ -z $tagName || $tagName == '-' ]]; then
  if echo "$fManifest" | command grep -q "\-[0-9]\{14\}"; then
    tagName="tmp/b$(command grep "\-[0-9]\{8\}")"
  else
    tagName="tmp/ts-$(command date +"$DATE_FMT")"
  fi
fi
$dump && rm -f manifest-{new,dump}.xml

list="$(cat $fManifest | grep -v '^!' | sed -n '/<project/s/.*\(path=[^ ]*\) .*\(revision=[^ ]*\).*/\1 \2/p' | sed 's|../onemw/|./|')"
$verbose && echo "List:" && echo "$list" | column -t | sed 's/^/* /'

while read l; do
  [[ "$l" =~ path=\"(.*)\"\ revision=\"(.*)\" ]] || continue
  d=${BASH_REMATCH[1]}
  [[ $d == './' ]] && continue
  if [[ ! -e $d ]]; then # {{{
    $verbose && echo "Dir [$d] not exist"
    continue
  fi # }}}
  r=${BASH_REMATCH[2]}
  $verbose && echo "$d $r"
  pushd $d >&/dev/null
  rHead="$(git rev-parse $head)"
  if $checkout; then # {{{
    if [[ $r != $rHead ]]; then
      echo "$d: Checking out ${rHead:0:7} --> ${r:0:7}"
      if ! git checkout $r 2>/dev/null; then
        git fetch origin
        cleanRepo=$(git status --short)
        [[ ! -z $cleanRepo ]] && git stash -q
        git checkout m/master
        git reset --hard origin/master
        if ! git checkout $r; then
          echo "Cannot checkout to $r" >/dev/stderr
          $SHELL </dev/tty >/dev/tty 2>/dev/stderr
        fi
        if [[ ! -z $cleanRepo ]] && ! git stash pop -q; then
          echo "Cannot pop stash" >/dev/stderr
          $SHELL </dev/tty >/dev/tty 2>/dev/stderr
        fi
      fi
      rHead="$(git rev-parse HEAD)"
    fi
  fi # }}}
  if $tag; then # {{{
    if git tag | command grep -q "^$tagName$"; then
      $verbose && echo "$d: Cannot tag: tag already exists"
    elif git cat-file -e $r >/dev/null; then
      git tag $tagName $r
    else
      echo "$d: Revision not present"
    fi
  fi # }}}
  if $verify; then # {{{
    if [[ $r != $rHead ]]; then
      echo "$d: Log: ${r:0:7}..${rHead:0:7} ($head)"
      git ld $r..$rHead | cat -
      differs=true
    else
      echo "$d: Log: ${r:0:7}..${rHead:0:7} ($head) : the same"
    fi
  fi # }}}
  if $showDiff; then # {{{
    if [[ $r != $rHead ]]; then
      echo "$d: Diff: ${r:0:7}..${rHead:0:7} ($head)"
      git diff $r..$rHead | cat -
    else
      echo "$d: Diff: ${r:0:7}..${rHead:0:7} ($head) : the same"
    fi
  fi # }}}
  rm -f manifest-orig.xml
  popd >&/dev/null
  ts="$(command date +$DATE_FMT)"
  $dump \
    && echo "<project path=\"$d\" revision=\"$rHead\"\\>" >>manifest-$ts-prev.xml \
    && echo "<project path=\"$d\" revision=\"$r\"\\>" >>manifest-$ts-new.xml
done < <(echo "$list")

if $differs; then # {{{
  if $verify; then
    echo
    echo "!!! Repos differ"
  fi # }}}
elif $verifyAfter; then # {{{
  $0 --dump-rev $fManifest
fi # }}}
# }}}

