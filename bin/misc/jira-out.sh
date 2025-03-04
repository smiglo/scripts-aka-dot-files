#/usr/bin/env bash
# vim: ft=sh fdm=marker fdl=0

if [[ $1 == '@@' ]]; then # {{{
  case $3 in
  -f) # {{{
    get-file-list '*.txt';; # }}}
  -r) # {{{
    if [[ $@ =~ \ ?-f\ +([^\ ]+) ]]; then
      f=${BASH_REMATCH[1]} # vim: {
      sed -n -e '/^#.* }\{3\}/d' -e 's/^#\+ \+\([^ ]\+\) # {\{3\}/\1/p' -e 's/^#\+ \+\([^ ]\+\)$/\1/p' "$f" # vim: }
    else
      echo "---"
    fi;; # }}}
  *) # {{{
    echo "-r -f - --dbg"
    get-file-list '*.txt';; # }}}
  esac
  exit 0
fi # }}}
region= f= dbg=false
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --dbg) dbg=true;;
  -r) region="$2"; shift;;
  -f) f="$2"; shift;;
  *)  f="$1 ";;
  esac; shift
done # }}}
if [[ ! -t 0 || $f == '-' ]]; then # {{{
  cat - >$TMP_PATH/jira-out.txt
  f="$TMP_PATH/jira-out.txt"
fi # }}}
regionS= regionE=
declare -A colorsMap=([module]='yellow')
$dbg && echorm -M +
eval $(echorm -f?var)
if [[ ! -z $region ]]; then # {{{
  regionS="^# \(.* \)\?$region\( .*\)\? # {\{3\}" foldet=true # vim: }
  if ! grep -q "$regionS" "$f"; then
    regionS="^# \(.* \)\?$region\( .*\)\?$"
    ! grep -q "$regionS" "$f" && echorm 0 "Start region [$region] not found" && exit 1
    foldet=false
  fi
  if $foldet; then # vim: {
    regionE="^# \(.* \)\?$region\(.* \)\? # }\{3\}"
    if ! grep -q "$regionE" "$f"; then
      region="$(matching-section -f $f -p "^# (.* )?$region")"
      [[ -z $region ]] && echorm 0 "End region [$region] not found" && exit 1
      echo -n "$region" | jira-out.sh
      exit
    fi
  else
    regionE="^$"
  fi
fi # }}}
[[ ! -z $region ]] && $dbg && echorm -m $module -C "%module:{region}: [$regionS|$regionE]"
s=plain until= untilReplace= tableInfo=
cat $f | \
if [[ -z $region ]]; then
    cat -
  else
    sed -n '/'"$regionS"'/,/'"$regionE"'/p' | sed -e '1 d' -e '$ d'
fi | \
while IFS= read -r l; do
  $dbg && echorm -m $module 5 "$l"
  l="${l%# IGN}"
  l="$(echo "$l" | sed 's/\s\+$//')"
  case $l in
  '# - # }}}' | '# # }}}') continue;;
  esac
  case $s in
  plain) # {{{
    case $l in
    '# TABLE'*) # {{{
      $dbg && echorm -m $module -C "%module:{$s}: %imp:switching into '%i2:{table}'"
      s="table" tableInfo="header"
      [[ $l == *'# {{{' ]] && until="# }}}" || until="^$"
      continue
      ;; # }}}
    [^#]*' # NF'*)
      echo -e "${l% # NF*}"
      l="# NF${l#* # NF}"
      $dbg && echorm -m $module -C "%module:{$s}: %imp:switching into '%i2:{noformat}' (combined line)"
      ;&
    '# NF '* | '# NF') # {{{
      $dbg && echorm -m $module -C "%module:{$s}: %imp:switching into '%i2:{noformat}'"
      l="$(echo ${l#\# NF} | tr -s ' ')"
      s="noformat" untilReplace="{noformat}"
      if [[ $l =~ ( *# \{\{\{)$ ]]; then
        l=${l%${BASH_REMATCH[1]}}
        until="# }}}" # {{{
      else
        until="# NF|^$"
      fi
      if [[ ! -z $l ]]; then
        $dbg && echorm -m $module -C 2 "%module:{$s}: noformat %green:{title}=[$l]"
        l="{noformat:title=$l}"
      else
        l="{noformat}"
      fi
      $dbg && echorm -m $module -C 2 "%module:{$s}: noformat entry: [$l], %green:{until}=[$until]"
      ;; # }}}
    '# CODE:'* | '# CODE '*) # {{{
      $dbg && echorm -m $module -C "%module:{$s}: %imp:switching into '%i2:{code}'"
      lang= cEntry="code" cEntryD=":"
      [[ $l =~ CODE:([^ ]*) ]] && lang=${BASH_REMATCH[1]} && cEntry+=":$lang" && cEntryD="|"
      l="${l#\# CODE }"
      l="${l#\# CODE:$lang }"
      s="noformat" untilReplace="{code}"
      if [[ $l =~ ( *# \{\{\{)$ ]]; then
        l=${l%${BASH_REMATCH[1]}}
        until="# }}}" # {{{
      else
        until="# CODE"
      fi
      if [[ ! -z $l ]]; then
        $dbg && echorm -m $module -C 2 "%module:{$s}: code %green:{title}=[$l]"
        l="{${cEntry}${cEntryD}title=$l}"
      else
        l="{$cEntry}"
      fi
      $dbg && echorm -m $module -C 2 "%module:{$s}: code entry: [$l], %green:{until}=[$until]"
      ;; # }}}
    '{noformat'*'}') # {{{
      $dbg && echorm -m $module -C "%module:{$s}:  %imp:switching into '%i2:{noformat}'"
      s="noformat" until="{noformat}"
      $dbg && echorm -m $module -C 2 "%module:{$s}: noformat entry: l=[$l], u=[$until]"
      ;; # }}}
    '{code'*'}') # {{{
      $dbg && echorm -m $module -C "%module:{$s}:  %imp:switching into '%i2:{code}'"
      s="noformat" until="{code}"
      $dbg && echorm -m $module -C 2 "%module:{$s}: code entry: l=[$l], u=[$until]"
      ;; # }}}
    '#'[0-9]?*) # {{{
      [[ $l =~ ^\#([0-9]+)\ (.*)('# {{{')? ]] # }}}
      l="h${BASH_REMATCH[1]}. ${l#* }"
      $dbg && echorm -m $module -C "%module:{$s}: %green:{header-v1}: l=[$l]"
      ;; # }}}
    '##'*) # {{{
      [[ $l =~ ^(\#+).* ]]
      len=$((${#BASH_REMATCH[1]}-1))
      l="h$len. ${l#* }"
      $dbg && echorm -m $module -C "%module:{$s}: %green:{header-v2}: l=[$l]"
      ;; # }}}
    *) # {{{
      ;; # }}}
    esac;; # }}}
  table) # {{{
    if [[ "$l" =~ $until ]]; then
      $dbg && echorm -m $module -C "%module:{$s}: %imp:switching into '%i2:{plain}' l=[$l], u=[$until]"
      s="plain" until=
      continue
    fi;; # }}}
  noformat) # {{{
    if [[ "$l" =~ $until ]]; then
      $dbg && echorm -m $module -C "%module:{$s}: %imp:switching into '%i2:{plain}' l=[$l], u=[$until]"
      addNL=false
      [[ -z $l ]] && addNL=true
      l="${untilReplace:-$until}"
      $addNL && l+="\n"
      s="plain" until= untilReplace=
    fi;; # }}}
  esac
  l="${l#\# \}\}\}}"
  l=${l% # \{\{\{} && l="${l% # \}\}\}}"
  case $s in
  plain) # {{{
    if [[ $l == '# '* ]]; then
      $dbg && echorm -m $module -C 2 "%module:{$s}: %gray:%s l=[$l]" "skipping comment line"
      continue
    fi
    markup='{{'
    while [[ $l == *"\`"* ]]; do # treat `text` as monospace
      l="${l/\`/$markup}"
      case $markup in
      '{{') markup='}}';;
      '}}') markup='{{';;
      esac
    done
    while [[ $l == *"''"* ]]; do # treat ''text'' as monospace
      l="${l/\'\'/$markup}"
      case $markup in
      '{{') markup='}}';;
      '}}') markup='{{';;
      esac
    done
    l="${l//\'\"/\{\{}" # treat '"text"' as monospace
    l="${l//\"\'/\}\}}"
    echo -e "$l";; # }}}
  table) # {{{
    if [[ ! -z $l ]]; then
      if [[ $tableInfo == 'header' ]]; then
        l="$(echo "||$l||" | sed 's/\t/||/g')"
        tableInfo=
      else
        l="$(echo "|$l|" | sed 's/\t/|/g')"
      fi
      echo "$l"
    fi
    ;; # }}}
  noformat) # {{{
    $dbg && echorm -m $module -C 4 "%module:{$s}: %gray:%s [$l]" "parsing header"
    [[ $l =~ ^([a-zA-Z][a-zA-Z0-9_%/-]{3,}:[0-9]+: *) ]] && l="${l#${BASH_REMATCH[1]}}"
    [[ $l =~ ^([0-9a-fA-F]+~: ) ]] && l="${l#${BASH_REMATCH[1]}}"
    echo "$l";; # }}}
  esac
done
if [[ f == "$TMP_PATH/jira-out.txt" ]]; then
  rm -f "$f"
fi

