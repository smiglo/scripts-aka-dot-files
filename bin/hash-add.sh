#!/usr/bin/env bash
# vim: fdl=0

if [[ $1 == '@@' ]]; then # {{{
  case $3 in
  --sum-len)          echo "5 7 9 12";;
  -n | --n-stop-at)   echo "9 12 15 22 h m s us H M S US";; # HMSUS: ignore 'Mon XY', hmsus: no 'Mon XY part'
  --n-start-at)       echo "1 8 h";;                        # 8: ignore 'Mon XY ' part (default)
  --matches)          echo "Sed-RegEx";;
  --cpu)              echo "1 2 12 24";;
  --file | -f)        echo "@@-f";;
  --out  | -o)        echo "@@-f";;
  --sum-cmd) # {{{
    echo "dateSsum dateUSsum"
    isInstalled xxh32sum && echo "xxh32sum xxh64sum xxh128sum"
    isInstalled sha1sum  && echo "sha1sum sha256sum"
    isInstalled md5sum   && echo "md5sum"
    isInstalled cksum    && echo "cksum"
    isInstalled hashrat  && echo "hashrat"
    echo "Script Function Script:Function";; # }}}
  *) # {{{
    echo "-n --n-stop-at --n-start-at --sum-len --keep --file -f --out -o --hash-at-end"
    echo --separator={SEPARATOR,#,~:,:} --no-separator '--separator="# HASH"'
    echo --{,no-}progress
    echo --matches{,-v}
    echo --map{,--sort} +map{,-v,-reuse}
    echo --{,single-}cpu
    echo "--sum-cmd --sum-no-repeat" --sum-buffered{,={100,500,1000}}
    getFileList '*.log'; getFileList '*.txt'
    ;; # }}}
  esac
  exit 0
fi # }}}
# Env # {{{
inFile=
outFile=
sum_cmd="sha1sum"
sumBuffered=false
sumBufferSize=250
sumRepeat=true
n=8
separator='~:'
hashAtEnd=false
n_startAt=
n_stopAt=S   # date: Jan 01 H:M:S.US, by default Mon XY is ignored
matches=
matches_skipOthers=false
mapMake=false
mapSort=false
mapBrowseMode=false
mapBrowse_ignoreOthers=false
mapUseExisting=false
singleCPU=false
useProgress=
linesForProgress=1000
inesForSingleCpu=5000
if [[ -e /proc/cpuinfo ]]; then
  cpu="$(awk '/siblings/ {print $3}' /proc/cpuinfo | head -n1)"
else
  cpu=4
fi
keepFo=false
workerMode=false
if false; then :
elif isInstalled hashrat;  then sum_cmd="hashrat -sha1"
elif isInstalled xxh32sum; then sum_cmd="xxh32sum"
fi
$IS_MAC && source-basic
# }}}
dateSsum() { # {{{
  local l=
  cat - | while read l; do
    command date +%s -d "$l"
  done
} # }}}
dateUSsum() { # {{{
  local l=
  cat - | while read l; do
    echo "$(command date +%s -d "${l%.*}")${l##*.}"
  done
} # }}}
cksum() { # {{{
  local r=$(command cksum)
  printf "%011d" ${r/ }
} # }}}
worker() { # {{{
  local fin="$1" l= sumLast= sum= i= num= dbgFull=false
  if [[ ! -z $2 ]]; then # {{{
    num="$(printf "%03d" $2)" && fin+="$num"
    $dbgFull && echorm --name hash-add-$num -M + 2
  fi # }}}
  [[ -e "$fin" ]] || { echorm 0 "File [$fin] not found, $$" && return 0; }
  $dbgFull && echor -M 2 "fin: '$fin' lines-in: $(cat "$fin" | wc -l)"
  local sum_cmd=$sum_cmd isHashrat=false sumEmpty="$(printf "%${n}s" " ")"
  if [[ $sum_cmd == hashrat* ]]; then # {{{
    isHashrat=true
    sum_cmd+=" -lines -n $n"
  fi # }}}
  if [[ $cmdWorker == *:* && -e "${cmdWorker%%:*}" ]]; then
    source ${sum_cmd%%:*} && sum_cmd=${sum_cmd#*:} # form: shell-script:function-to-call - for time optimisation
  fi
  local ignoreFirstN=
  [[ $n_startAt != 1 ]] && ignoreFirstN=".\{$((n_startAt - 1))\}"
  local sed_cmd="sed 's/$ignoreFirstN\(.\{1,$n_stopAt\}\).*/\1/'" regionMatch=false sed_filter="cat -" sed_others="cat -"
  echorv -M 2 matches
  if [[ ! -z $matches ]]; then # {{{
    sed_cmd="sed -n -e '/$matches/{ s/.*\($matches\).*/\1/p;b}'"
    if $matches_skipOthers; then
      sed_filter="sed -n -e '/$matches/p'"
    else
      sed_cmd+=" -e 's/.*//p'"
      local sumIgn="$(echo -n "" | ${sum_cmd/-lines} | cut -c1-$n)"
      sed_others="sed 's/^$sumIgn/$sumEmpty/'"
    fi
    regionMatch=true # }}}
  elif $mapMake; then # {{{
    local sumEmpty="$(printf "%${n}s" " ")"
    local sumIgn="$(echo -n "" | ${sum_cmd/-lines} | cut -c1-$n)"
    sed_others="sed 's/^$sumIgn/$sumEmpty/'"
  fi # }}}
  echorv -M 2 regionMatch sed_cmd sumIgn mapMake
  echorv -M 2 sed_filter sed_others
  declare -a aryIn
  local sumLast=
  while mapfile -t -n $sumBufferSize aryIn && ((${#aryIn[@]})); do
    unset arySum aryMatch
    declare -a arySum aryMatch
    # $dbgFull && for i in ${!aryIn[@]}; do echor "aryIn[$i]=${aryIn[$i]}"; done
    mapfile -t -n $sumBufferSize aryMatch < <(printf '%s\n' "${aryIn[@]}" | eval "$sed_cmd")
    # $dbgFull && for i in ${!aryMatch[@]}; do echor "aryMatch[$i]=${aryMatch[$i]}"; done
    if $isHashrat; then # {{{
      mapfile -t -n $sumBufferSize arySum < <(printf '%s\n' "${aryMatch[@]}" | $sum_cmd | eval "$sed_others")
    elif $sumBuffered; then # {{{
      mapfile -t -n $sumBufferSize arySum < <(printf '%s\n' "${aryMatch[@]}" | $sum_cmd | eval "$sed_others" | cut -c1-$n)
    else # {{{
      for i in ${!aryMatch[@]}; do
        arySum[$i]="$(echo -n "${aryMatch[$i]}" | $sum_cmd | eval "$sed_others" | cut -c1-$n)"
      done
    fi # }}}
    # $dbgFull && for i in ${!arySum[@]}; do echor "arySum[$i]=${arySum[$i]}"; done
    if $mapMake && ! $mapBrowseMode; then
      local -n aryOut=aryMatch
    else
      local -n aryOut=aryIn
    fi
    for i in ${!aryMatch[@]}; do # {{{
      sum="${arySum[$i]}"
      if ! $mapMake; then # {{{
        if [[ $sum == $sumLast ]]; then
          $sumRepeat || sum=$sumEmpty
        else
          sumLast=$sum
        fi
      fi # }}}
      if [[ ${sum:0:1} == " " ]]; then # {{{
        # $mapMake && continue
        $matches_skipOthers && continue
      fi # }}}
      if ! $hashAtEnd; then
        echo "$sum$separator ${aryOut[$i]}"
      elif [[ $sum != $sumEmpty ]]; then
        echo "${aryOut[$i]} $separator $sum~"
      else
        echo "${aryOut[$i]}"
      fi
    done # }}} # }}}
  done < <(cat "$fin" | eval "$sed_filter") # }}}
} # }}}
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --matches)          matches="$2"; shift;;
  --matches-v)        matches_skipOthers=true;;
  +map-reuse)         mapUseExisting=true; keepFo=true;;&
  +map-v)             mapBrowse_ignoreOthers=true;;&
  +map | +map-v | +map-reuse) # {{{
    mapBrowseMode=true;& # }}}
  --map)              mapMake=true;;
  --map-sort)         mapSort=true;;
  --keep)             keepFo=true;;
  --n-start-at)       n_startAt=$2; shift;;
  -n | --n-stop-at)   n_stopAt=$2; shift;;
  --no-separator)     separator="";;
  --separator=*)      separator="${1#--separator=}";;
  --hash-at-end)      hashAtEnd=true; separator="#";;
  --sum-len)          n=$2; shift;;
  --sum-buffered)     sumBuffered=true;;
  --sum-buffered=*)   sumBuffered=true; sumBufferSize=${1#--sum-buffered=}; [[ $sumBufferSize == *:* ]] && sumBuffered=${sumBufferSize%%:*} && sumBufferSize=${sumBufferSize#*:};;
  --sum-no-repeat)    sumRepeat=false;;
  --sum-repeat=*)     sumRepeat=${1#--sum-repeat=};;
  --no-progress)      useProgress=false;;
  --progress)         useProgress=true;;
  --single-cpu)       singleCPU=true;;
  --cpu)              cpu=$2; shift;;
  --worker)           workerMode=true; shift; break;;
  -f | --file)        inFile="$2"; shift;;
  -o | --out)         outFile="$2"; keepFo=true; shift;;
  --sum-cmd) # {{{
    sum_cmd=$2; shift
    case $sum_cmd in
    cksum)     n=11;;
    dateSsum)  n=10; n_startAt=1; n_stopAt=15; separator="";;
    dateUSsum) n=16; n_startAt=1; n_stopAt=22; separator="";;
    esac;; # }}}
  *) # {{{
    inFile="$1";; # }}}
  esac; shift
done # }}}
if [[ -z $n_startAt ]]; then # {{{
  n_startAt=1
  case $n_stopAt in
  H | M | S | US) n_startAt=h;;
  esac
fi # }}}
case $n_startAt in # {{{
h) n_startAt=8;;
esac # }}}
len=
case ${n_stopAt,,} in # {{{
h)  len=2;;  # HH
m)  len=5;;  # HH:MM
s)  len=8;;  # HH:MM:SS
us) len=15;; # HH:MM:SS.123456
esac # }}}
[[ ! -z $len ]] && n_stopAt=$((len))
if [[ -z $useProgress ]]; then # {{{
  [[ -t 1 ]] && useProgress=true || useProgress=false
fi # }}}
isStdin=false
doCat=false
doRemove=false
if ! $sumBuffered; then # {{{
  case $sum_cmd in
  hashrat* | dateSsum | dateUSsum) # {{{
    sumBuffered=true;; # }}}
  xxh*sum) # {{{
    if $sum_cmd -l? >/dev/null 2>&1; then
      sum_cmd+=" -l"
      sumBuffered=true
    fi;; # }}}
  esac
fi # }}}
if $sumBuffered; then # {{{
  linesForProgress=7500
  linesForSingleCpu=20000
fi # }}}
if [[ "$inFile" == '-' || ( ! -t 0 && -z $inFile ) ]]; then # {{{
  inFile="$TMP_PATH/hash-add-stdin.$$"
  cat - >"$inFile"
  isStdin=true
  doCat=true
  doRemove=true
elif [[ ! -z $inFile ]]; then
  $keepFo || doReplace=true
fi # }}}
[[ -z "$inFile" ]] && inFile=$(getFileList -t -1 "*.log")
[[ -z "$inFile" ]] && inFile=$(getFileList -t -1 "*.txt")
[[ -z "$inFile" ]] && echorm 0 "File [$inFile] not found" && exit 1
if $workerMode; then # {{{
  if [[ ! -z $matches ]]; then # {{{
    matches="${matches#\'}"
    matches="${matches%\'}"
    [[ ! -z $matches ]] && echor -M 2 "matches-for-workers: [$matches]"
  fi # }}}
  if $isStdin; then
    worker "$inFile"
  else
    num="$(printf "%03d" ${1:-0})"
    worker "$inFile$num" >$inFile$num.tmp
  fi
  if $doRemove; then rm -f "$inFile"; fi
  exit 0
fi # }}}
isInstalled parallel split || singleCPU=true
echorv -M n separator
[[ -z $matches ]] && echorv -M n_stopAt n_startAt || echorv -M matches matches_skipOthers
echorv -M mapMake mapBrowseMode mapBrowse_ignoreOthers
echorv -M sum_cmd sumBuffered sumBufferSize sumRepeat
echorv -M singleCPU linesForSingleCpu cpu
echorv -M useProgress linesForProgress
foHash="${outFile:-${inFile%.hash}}.hash"
foMap="${foHash%.hash}.map"
if $mapUseExisting; then # {{{
  [[ ! -e "$foHash" && -e "$(basename "$foHash")" ]] && foHash="$(basename "$foHash")" && foMap="$(basename "$foMap")"
  [[ ! -e "$foHash" || ! -e "$foMap" ]] && echorm 0 "Files not exist [$foHash] [$foMap], will be created"
fi # }}}
echorv -M inFile foHash isStdin doCat doRemove keepFo foMap
if ! $mapUseExisting || [[ ! -e "$foHash" || ! -e "$foMap" ]]; then # {{{
  rm -f "$foHash" "$foMap"
  lines="$(cat "$inFile" | wc -l)"
  echorv -M lines
  ! $singleCPU && [[ $lines -gt $linesForSingleCpu ]] && echorm "Using parallel mode, cpu: $cpu"
  progressShown=false
  $useProgress && [[ $lines -gt $linesForProgress ]] && progressShown=true && progress --mark --msg "Adding hashes"
  if ! $singleCPU && [[ $lines -gt $linesForSingleCpu ]]; then # {{{
    work-parallel.sh \
      --file "$inFile" --cpu $cpu --no-progress \
      $(which bash) $0 \
        $($hashAtEnd && echo "--hash-at-end") --separator="$separator" \
        --sum-len $n --n-stop-at $n_stopAt --n-start-at $n_startAt \
        --sum-cmd "${sum_cmd@Q}" --sum-buffered=$sumBuffered:$sumBufferSize --sum-repeat=$sumRepeat \
        --matches "${matches@Q}" $($matches_skipOthers && echo "--matches-v") \
        $($mapMake && echo "--map") $($mapBrowseMode && echo "+map") \
        --worker
    # }}}
  else # {{{
    worker "$inFile"
    # }}}
  fi >"$foHash"
  if $makeMap; then # {{{
    cat "$foHash" \
    | if ! $hashAtEnd; then
        command grep -v "^ \+$separator "
      else
        command grep -v "$separator *$"
      fi \
    | if ! $mapSort; then
        cat -n | sort -k2,2 -s | uniq -c -s8 -w$n | sort -k2,2n -s | cut -c1-8,16-
      else
        sort -k1,1 -s | uniq -c -w$n | sort -k1,1n -s
      fi >"$foMap"
  fi # }}}
  $progressShown && progress --unmark
fi # }}}
if $mapBrowseMode; then # {{{
  while true; do
    l="$(cat "$foMap" | fzf | awk '{print $2}' | sed 's/~://' | tr "\n" " " | sed -e 's/ $//' -e 's/ /\\|/g')"
    [[ -z $l ]] && break
    cp "$foHash" "$foHash.tmp"
    vim --fast -c "/$l/" $($mapBrowse_ignoreOthers && echo "-c :g!//d") "$foHash.tmp" </dev/tty
  done
  rm -f "$foHash.tmp"
  # }}}
elif $doCat; then # {{{
  cat "$foHash"
fi # }}}
if $doRemove; then rm -f "$inFile"; fi
if ! $keepFo; then # {{{
  $doReplace && mv "$foHash" "$inFile"
  rm -f "$foHash" "$foMap" # }}}
else # {{{
  [[ -s $foHash ]] || rm -f "$foHash"
  [[ -s $foMap  ]] || rm -f "$foMap"
  if $isStdin; then # {{{
    [[ -e $foHash ]] && mv "$foHash" ./$(basename "$foHash")
    [[ -e $foMap  ]] && mv "$foMap"  ./$(basename "$foMap")
  fi # }}}
fi # }}}

# Patch for xxhash for getting hash for each line from stdin # {{{
#  cli/xxhsum.c | 123 +++++++++++++++++++++++++++++++++++++++++++++++++++
#  1 file changed, 123 insertions(+)
# 
# diff --git a/cli/xxhsum.c b/cli/xxhsum.c
# index 0744669..b5e28a0 100644
# --- a/cli/xxhsum.c
# +++ b/cli/xxhsum.c
# @@ -49,6 +49,7 @@
#  #include <string.h>     /* strerror, strcmp, memcpy */
#  #include <assert.h>     /* assert */
#  #include <errno.h>      /* errno */
# +#include <stdio.h>      /* getline */
#  
#  #define XXH_STATIC_LINKING_ONLY   /* *_state_t */
#  #include "../xxhash.h"
# @@ -242,6 +243,62 @@ typedef union {
#      XXH128_hash_t hash128;
#  } Multihash;
#  
# +static Multihash
# +XSUM_hashCString(char* inStr,
# +                AlgoSelected hashType)
# +{
# +    XXH32_state_t state32;
# +    XXH64_state_t state64;
# +    XXH3_state_t  state3;
# +
# +    /* Init */
# +    (void)XXH32_reset(&state32, XXHSUM32_DEFAULT_SEED);
# +    (void)XXH64_reset(&state64, XXHSUM64_DEFAULT_SEED);
# +    (void)XXH3_128bits_reset(&state3);
# +
# +    /* Load file & update hash */
# +    {
# +        switch(hashType)
# +        {
# +        case algo_xxh32:
# +            (void)XXH32_update(&state32, inStr, strlen(inStr));
# +            break;
# +        case algo_xxh64:
# +            (void)XXH64_update(&state64, inStr, strlen(inStr));
# +            break;
# +        case algo_xxh128:
# +            (void)XXH3_128bits_update(&state3, inStr, strlen(inStr));
# +            break;
# +        case algo_xxh3:
# +            (void)XXH3_64bits_update(&state3, inStr, strlen(inStr));
# +            break;
# +        default:
# +            assert(0);
# +        }
# +    }
# +
# +    {   Multihash finalHash = {0};
# +        switch(hashType)
# +        {
# +        case algo_xxh32:
# +            finalHash.hash32 = XXH32_digest(&state32);
# +            break;
# +        case algo_xxh64:
# +            finalHash.hash64 = XXH64_digest(&state64);
# +            break;
# +        case algo_xxh128:
# +            finalHash.hash128 = XXH3_128bits_digest(&state3);
# +            break;
# +        case algo_xxh3:
# +            finalHash.hash64 = XXH3_64bits_digest(&state3);
# +            break;
# +        default:
# +            assert(0);
# +        }
# +        return finalHash;
# +    }
# +}
# +
#  /*
#   * XSUM_hashStream:
#   * Reads data from `inFile`, generating an incremental hash of type hashType,
# @@ -386,6 +443,67 @@ static XSUM_displayLine_f XSUM_kDisplayLine_fTable[2][2] = {
#      { XSUM_printLine_BSD, XSUM_printLine_BSD_LE }
#  };
#  
# +static int XSUM_hashLines(const AlgoSelected hashType,
# +                         const Display_endianess displayEndianess,
# +                         const Display_convention convention)
# +{
# +    XSUM_displayLine_f const f_displayLine = XSUM_kDisplayLine_fTable[convention][displayEndianess];
# +    FILE* inFile;
# +    Multihash hashValue;
# +    assert(displayEndianess==big_endian || displayEndianess==little_endian);
# +    assert(convention==display_gnu || convention==display_bsd);
# +
# +    inFile = stdin;
# +    XSUM_setBinaryMode(stdin);
# +
# +    /* Memory allocation & streaming */
# +    {
# +        char *line = NULL;
# +        size_t len = 0;
# +        ssize_t read;
# +
# +        while ((read = getline(&line, &len, inFile)) != -1) {
# +              hashValue = XSUM_hashCString(line, hashType);
# +
# +              /* display Hash value in selected format */
# +              switch(hashType)
# +              {
# +              case algo_xxh32:
# +                  {   XXH32_canonical_t hcbe32;
# +                      (void)XXH32_canonicalFromHash(&hcbe32, hashValue.hash32);
# +                      f_displayLine(stdinFileName, &hcbe32, hashType);
# +                      break;
# +                  }
# +              case algo_xxh64:
# +                  {   XXH64_canonical_t hcbe64;
# +                      (void)XXH64_canonicalFromHash(&hcbe64, hashValue.hash64);
# +                      f_displayLine(stdinFileName, &hcbe64, hashType);
# +                      break;
# +                  }
# +              case algo_xxh128:
# +                  {   XXH128_canonical_t hcbe128;
# +                      (void)XXH128_canonicalFromHash(&hcbe128, hashValue.hash128);
# +                      f_displayLine(stdinFileName, &hcbe128, hashType);
# +                      break;
# +                  }
# +              case algo_xxh3:
# +                  {   XXH64_canonical_t hcbe64;
# +                      (void)XXH64_canonicalFromHash(&hcbe64, hashValue.hash64);
# +                      f_displayLine(stdinFileName, &hcbe64, hashType);
# +                      break;
# +                  }
# +              default:
# +                  assert(0);  /* not possible */
# +              }
# +        }
# +
# +        free(line);
# +        fclose(inFile);
# +    }
# +
# +    return 0;
# +}
# +
#  static int XSUM_hashFile(const char* fileName,
#                           const AlgoSelected hashType,
#                           const Display_endianess displayEndianess,
# @@ -1151,6 +1269,7 @@ XSUM_API int XSUM_main(int argc, const char* argv[])
#      const char* const exename = XSUM_lastNameFromPath(argv[0]);
#      XSUM_U32 benchmarkMode = 0;
#      XSUM_U32 fileCheckMode = 0;
# +    XSUM_U32 lineMode      = 0;
#      XSUM_U32 strictMode    = 0;
#      XSUM_U32 statusOnly    = 0;
#      XSUM_U32 warn          = 0;
# @@ -1174,6 +1293,8 @@ XSUM_API int XSUM_main(int argc, const char* argv[])
#          assert(argument != NULL);
#  
#          if (!strcmp(argument, "--check")) { fileCheckMode = 1; continue; }
# +        if (!strcmp(argument, "-l")) { lineMode = 1; continue; }
# +        if (!strcmp(argument, "-l?")) { return 0; }
#          if (!strcmp(argument, "--benchmark-all")) { benchmarkMode = 1; selectBenchIDs = kBenchAll; continue; }
#          if (!strcmp(argument, "--bench-all")) { benchmarkMode = 1; selectBenchIDs = kBenchAll; continue; }
#          if (!strcmp(argument, "--quiet")) { XSUM_logLevel--; continue; }
# @@ -1299,6 +1420,8 @@ XSUM_API int XSUM_main(int argc, const char* argv[])
#      if (fileCheckMode) {
#          return XSUM_checkFiles(argv+filenamesStart, argc-filenamesStart,
#                            displayEndianess, strictMode, statusOnly, warn, (XSUM_logLevel < 2) /*quiet*/, algoBitmask);
# +    } else if (lineMode) {
# +        return XSUM_hashLines(algo, displayEndianess, convention);
#      } else {
#          return XSUM_hashFiles(argv+filenamesStart, argc-filenamesStart, algo, displayEndianess, convention);
#      }
# -- 
# 2.25.1
# }}}
