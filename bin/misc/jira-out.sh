#/usr/bin/env bash
# vim: ft=sh fdm=marker fdl=0

if [[ $1 == '@@' ]]; then # {{{
  case $2 in
  -f) # {{{
    get-file-list '*.txt';; # }}}
  -r) # {{{
    f=
    if [[ $@ =~ \ ?-f\ +([^\ ]+) ]]; then
      f=${BASH_REMATCH[1]}
    elif [[ -e $NOTE_FILE && $NOTE_FILE == $PWD/* ]]; then
      f="$NOTE_FILE"
    fi
    [[ -n $f && -e $f ]] || { echo "---"; exit 0; }
    # vim: {
    sed -n -e '/^#.* }\{3\}/d' -e 's/^#\+ \+\([^ ]\+\) # {\{3\}/\1/p' -e 's/^#\+ \+\([^ ]\+\)$/\1/p' "$f" | grep -vE "^(NF|TABLE|CODE)$" # vim: }
    ;; # }}}
  *) # {{{
    echo "-r -f - --slack --jira"
    echo "-v -vv -vvv"
    echo "-v"{1..5}
    get-file-list '*.txt';; # }}}
  esac
  exit 0
fi # }}}
region= f= forSlack= vLvl=0
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --slack) forSlack=true;;
  --jira)  forSlack=false;;
  -v) ((++vLvl));;
  -v[0-9]) vLvl=${1#-v};;
  -vv*) vLvl=${1#-}; vLvl="${#vLvl}";;
  -r) region="$2"; shift;;
  -f) f="$2"; shift;;
  *)  f="$1 ";;
  esac; shift
done # }}}
if [[ ! -t 0 || $f == '-' ]]; then # {{{
  cat - >$TMP_PATH/jira-out.txt
  f="$TMP_PATH/jira-out.txt"
elif [[ -e $NOTE_FILE && $NOTE_FILE == $PWD/* ]]; then
  f="$NOTE_FILE"
fi # }}}
regionS= regionE=
declare -A colorMap=([module]='yellow')
if [[ ! -z $region ]]; then # {{{
  regionS="^# \(.* \)\?$region\( .*\)\? # {\{3\}" foldet=true # vim: }
  if ! grep -q "$regionS" "$f"; then
    regionS="^# \(.* \)\?$region\( .*\)\?$"
    ! grep -q "$regionS" "$f" && die "Start region [$region] not found"
    foldet=false
  fi
  if $foldet; then # vim: {
    regionE="^# \(.* \)\?$region\(.* \)\? # }\{3\}"
    if ! grep -q "$regionE" "$f"; then
      region="$($ENV_SCRIPTS/file-tools/matching-section.sh -f $f -p "^# (.* )?$region")"
      [[ -z $region ]] && die "End region [$region] not found"
      echo -n "$region" | jira-out.sh
      exit
    fi
  else
    regionE="^$"
  fi
fi # }}}
[[ ! -z $region ]] && echoe $((vLvl >= 1)) -m $module -C "%module:{region}: [$regionS|$regionE]"
s=plain until= untilReplace= tableInfo=
if [[ -z $forSlack ]]; then
  grep -q "https://.*/browse/.*" $f && forSlack=false
  [[ -z $forSlack ]] && forSlack=${JIRA_OUT_SLACK_DEFAULT:-true}
fi
{ if [[ -z $region ]]; then cat "$f"; else sed -n '/'"$regionS"'/,/'"$regionE"'/p' "$f" | sed -e '1 d' -e '$ d'; fi; } | \
while IFS= read -r l; do
  echoe $((vLvl>=5)) -m $module "$l"
  l="${l%# IGN}"
  l="$(echo "$l" | sed 's/\s\+$//')"
  case $l in
  '# - # }}}' | '# # }}}') continue;;
  esac
  case $s in
  plain) # {{{
    case $l in
    '# TABLE'*) # {{{
      echoe $((vLvl >= 1)) -m $module -C "%module:{$s}: %imp:switching into '%i2:{table}'"
      s="table" tableInfo="header"
      [[ $l == *'# {{{' ]] && until="# }}}" || until="^$"
      continue
      ;; # }}}
    [^#]*' # NF'*) # {{{
      echo -e "${l% # NF*}"
      l="# NF${l#* # NF}"
      echoe $((vLvl>=1)) -m $module -C "%module:{$s}: %imp:switching into '%i2:{noformat}' (combined line)"
      ;& # }}}
    '# NF '* | '# NF' | '``` '* | '```') # {{{
      echoe $((vLvl>=1)) -m $module -C "%module:{$s}: %imp:switching into '%i2:{noformat}'"
      s="noformat" untilReplace="{noformat}"
      if [[ $l =~ ( *# \{\{\{)$ ]]; then
        l=${l%${BASH_REMATCH[1]}}
        until="# }}}" # {{{
      else
        until="# NF|^$"
      fi
      case $l in
      '# NF '*) l="$(echo ${l#\# NF} | tr -s ' ')";;
      '``` '*)  l='```';;
      esac
      if ! $forSlack; then
        if [[ ! -z $l && $l != '```' ]]; then
          echoe $((vLvl>=2)) -m $module -C "%module:{$s}: noformat %green:{title}=[$l]"
          l="{noformat:title=$l}"
        else
          l="{noformat}"
        fi
      else
        l='```'
      fi
      echoe $((vLvl >= 2)) -m $module -C "%module:{$s}: noformat entry: [$l], %green:{until}=[$until]"
      ;; # }}}
    '# CODE:'* | '# CODE '*) # {{{
      echoe $((vLvl >= 1)) -m $module -C "%module:{$s}: %imp:switching into '%i2:{code}'"
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
        echoe $((vLvl >= 2)) -m $module -C "%module:{$s}: code %green:{title}=[$l]"
        l="{${cEntry}${cEntryD}title=$l}"
      else
        l="{$cEntry}"
      fi
      echoe $((vLvl >= 2)) -m $module -C "%module:{$s}: code entry: [$l], %green:{until}=[$until]"
      ;; # }}}
    '{noformat'*'}') # {{{
      echoe $((vLvl >= 1)) -m $module -C "%module:{$s}:  %imp:switching into '%i2:{noformat}'"
      s="noformat" until="{noformat}"
      echoe $((vLvl >= 2)) -m $module -C "%module:{$s}: noformat entry: l=[$l], u=[$until]"
      ;; # }}}
    '{code'*'}') # {{{
      echoe $((vLvl >= 1)) -m $module -C "%module:{$s}:  %imp:switching into '%i2:{code}'"
      s="noformat" until="{code}"
      echoe $((vLvl >= 2)) -m $module -C "%module:{$s}: code entry: l=[$l], u=[$until]"
      ;; # }}}
    '#'[0-9]?*) # {{{
      [[ $l =~ ^\#([0-9]+)\ (.*)('# {{{')? ]] # }}}
      l="h${BASH_REMATCH[1]}. ${l#* }"
      echoe $((vLvl >= 1)) -m $module -C "%module:{$s}: %green:{header-v1}: l=[$l]"
      ;; # }}}
    '##'*) # {{{
      [[ $l =~ ^(\#+).* ]]
      len=$((${#BASH_REMATCH[1]}-1))
      l="h$len. ${l#* }"
      echoe $((vLvl >= 2)) -m $module -C "%module:{$s}: %green:{header-v2}: l=[$l]"
      ;; # }}}
    *) # {{{
      ;; # }}}
    esac;; # }}}
  table) # {{{
    if [[ "$l" =~ $until ]]; then
      echoe $((vLvl >= 2)) -m $module -C "%module:{$s}: %imp:switching into '%i2:{plain}' l=[$l], u=[$until]"
      s="plain" until=
      continue
    fi;; # }}}
  noformat) # {{{
    if [[ "$l" =~ $until ]]; then
      echoe $((vLvl >= 1)) -m $module -C "%module:{$s}: %imp:switching into '%i2:{plain}' l=[$l], u=[$until]"
      addNL=false
      [[ -z $l ]] && addNL=true
      if ! $forSlack; then
        l="${untilReplace:-$until}"
      else
        l='```'
      fi
      $addNL && l+="\n"
      s="plain" until= untilReplace=
    fi;; # }}}
  esac
  l="${l#\# \}\}\}}"
  l=${l% # \{\{\{} && l="${l% # \}\}\}}"
  case $s in
  plain) # {{{
    if [[ $l == '# '* ]]; then
      echoe $((vLvl >= 2)) -m $module -C "%module:{$s}: %gray:%s l=[$l]" "skipping comment line"
      continue
    fi
    case $l in
    '```')
      if $forSlack; then
        echo "$l"
      else
        echo "{noformat}"
      fi
      continue;;
    esac
    if ! $forSlack; then
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
    fi
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
    echoe $((vLvl >= 4)) -m $module -C "%module:{$s}: %gray:%s [$l]" "parsing header"
    [[ $l =~ ^([a-zA-Z][a-zA-Z0-9_%/-]{3,}:[0-9]+: *) ]] && l="${l#${BASH_REMATCH[1]}}"
    [[ $l =~ ^([0-9a-fA-F]+~: ) ]] && l="${l#${BASH_REMATCH[1]}}"
    echo "$l";; # }}}
  esac
done
if [[ f == "$TMP_PATH/jira-out.txt" ]]; then
  rm -f "$f"
fi

