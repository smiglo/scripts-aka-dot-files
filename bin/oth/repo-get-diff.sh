#!/bin/bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  case $3 in
  --since | --until) echo "1.01.2022";;
  -r) find . -maxdepth 2 -type d -path '*/build-*' -prune -o -name .git -exec dirname {} \;;;
  *)  echo --since --until -r -R -p -a --new-list --all-repos;;
  esac
  exit 0
fi # }}}

since="4.02.2022 21:00"
until="7.02.2022 21:00"
repos=$REPO_LIST
if [[ -z $repos && ! -z $REPO_LIST_DEFAULT ]]; then
  for i in $REPO_LIST_DEFAULT; do
    [[ -e $i ]] && repos+=" $i"
  done
fi
add_patch=false
all_changes=false
list_out="$PWD/get-diff-list.txt"
color=always
stdout=true
[[ ! -t 1 ]] && stdout=false && color=never

while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --since) since="$2"; shift;;
  --until) until="$2"; shift;;
  -r)      repos="$2"; shift;;
  -R)      repos=;;
  -p)      add_patch=true;;
  -a)      all_changes=true;;
  --new-list) # {{{
    [[ -e $list_out ]] && cp $list_out $list_out.$(date +"$DATE_FMT") && rm -f $list_out;; # }}}
  --all-repos) # {{{
    [[ -e $list_out ]] && cp $list_out $list_out.$(date +"$DATE_FMT") && rm -f $list_out
    repos=
    list=$(find . -type d -path '*/build-*' -prune -o -name .git -exec dirname {} \;)
    for i in $list; do
      repos+="$(basename $i) "
    done;; # }}}
  esac; shift
done # }}}

if [[ -e $list_out ]]; then
  use_list=true
  repos="$(awk '/r: /{print $2}' $list_out)"
else
  use_list=false
fi

echo "# vim: fdl=0 ft=diff"
echo

for j in $repos; do
  dName=$(find . -maxdepth 6 -path '*/build-*' -prune -o -path '*/'$j'/.git' -print)
  [[ -z $dName ]] && echo "Err: $j" && continue
  pushd $dName &>/dev/null
  if $use_list; then # {{{
    list=$(sed -n '/^r: '$j'/,/^r:/p' $list_out | awk '/^c:/ {print $2}')
  else
    if $all_changes; then
      list=$(git log --since="$since" --until="$until" --pretty=date-first --date=local | awk '{print $6}')
    else
      list=$(git log --since="$since" --until="$until" --pretty=date-first --date=local --color=always | fzf --ansi -m | awk '{print $6}')
      [[ $? != 0 ]] && exit 1
    fi
  fi # }}}
  if [[ ! -z $list ]]; then
    echo "Checking $j:$($stdout || echo ' # {{{')"
    if ! $stdout; then # {{{
      log="$(git log --since="$since" --until="$until" --pretty=date-first --date=local --color=$color)"
      echo "$log"
      if ! $all_changes; then
        if [[ $(echo "$log" | wc -l) != $(echo "$list" | tr ' ' '\n' | wc -l) ]]; then
          echo && echo "Selected:" && echo "$list" | tr ' ' '\n' | sed 's/^/* /'
        fi
      fi
    fi # }}}
    echo
    $use_list || echo "r: $j" >>$list_out
    for i in $list; do # {{{
      $use_list || echo "c: $i $(git log -1 --format="%s" $i)" >>$list_out
      (
        $stdout || echo "$(git log --color=$color --pretty=oneline --date=local -1 $i) # {{{"
        git log --color=$color --pretty=fuller --date=local -1 $i
        git diff --color=$color --name-status $i~..$i
        echo
        if $add_patch; then
          $stdout || echo "Patch: # {{{"
          git diff --color=$color $i~..$i
          $stdout || echo "# }}}"
        fi
        $stdout || echo "# }}}"
      )
    done # }}}
    $stdout || echo "# }}}"
  else
    $stdout && echo "Checking $j: Empty" && echo
  fi
  popd &>/dev/null
done \
  | sed 's/^\s*$//' \
  | cat -

