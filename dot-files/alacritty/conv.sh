# generated as:
# ./conv.sh "a" "Alt" "$(./conv.sh --get 'a-z')"
# ./conv.sh "-=[]\\;',/" "Alt|Shift" "$(./conv.sh --get 'left+s')"

[[ -z $1 ]] && set -- --subset
case $1 in
--get) # {{{
  shift
  case $1 in
  #              abcdefghijklmnopqrstuvwxyz
  a-z)     echo "ąļć∂ęń©ķi∆ŻłĶńóĻŌ®ś†u√∑źīż";;
  A-Z)     echo "ĄűĆŽĘžŪÓťÔūŁųŃÓłő£ŚśŤ◊„ŹÁŻ";;
  #              0123456789
  0-9)     echo "ľŃ™€ßį§¶•Ľ";;
  0-9+S)   echo "‚ŕŘ‹›řŖŗ°Š";;
  #              -=[]\;',/
  left)    echo "–≠„‚«…ĺ≤÷";;
  left+S)  echo "—Ī”’»ÚģÝņ";;
  esac
  exit 0;; # }}}
--all) # {{{
  $0 "a"      "Alt"         "$($0 --get 'a-z')"
  $0 "a"      "Alt|Shift"   "$($0 --get 'A-Z')"
  $0 "0"      "Alt"         "$($0 --get '0-9')"
  $0 "0"      "Alt|Shift"   "$($0 --get '0-9+S')"
  $0 "LEFT"   "Alt"         "$($0 --get 'left')"
  $0 "LEFT"   "Alt|Shift"   "$($0 --get 'lef+S')"
  exit 0;; # }}}
--subset) # {{{
  # some nice chars not in the subset: ‹›≠„”«»
  $0 --all \
  | egrep -B2 -A1 "key = \"(a|c|e|l|n|o|s|x|z|-|;)\"" \
  | sed 's/^--$//'
  exit 0;; # }}}
esac

keys="$1" mods="$2" ch="$3"
[[ $keys == "LEFT" ]] && keys="-=[]\\;',/"
s="${keys:0:1}"
for (( i = 0; i < ${#ch}; ++i )); do
  printf "[[keyboard.bindings]]\n"
  printf "chars = \"\\\u%04x\" # %s\n" "'${ch:$i:1}" "${ch:$i:1}"
  printf "key = \"$s\"\n"
  printf "mods = \"$mods\"\n"
  if (( ${#keys} == 1 )); then
    s="$(printf "\x$(printf %x $(($(printf "%d" "'$s")+1)))")"
  else
    s="${keys:$((i+1)):1}"
  fi
done
