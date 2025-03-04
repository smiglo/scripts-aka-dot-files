#!/usr/bin/env bash
# vim: fdl=0

mode="1"
showCmd=false
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --show-cmd) # {{{
    showCmd=true;; # }}}
  0 | 1 | 2 | 3) # {{{
    mode="$1";; # }}}
  all) # {{{
    shift
    for i in 1 2 3; do
      echor "$ $0 $i $@"
      $0 $i --show-cmd "$@" || exit 1
      echo
    done
    exit;; # }}}
  *) # {{{
    break;; # }}}
  esac; shift
done # }}}

pCli=$@

case $mode in
1 | 2 | 0) # {{{
  params="-D"
  [[ $pCli == *"+D"* ]] && params="${params/-D}" && pCli=${pCli/+D}
  case $mode in # {{{
  1) echor -c $showCmd "$ hl.py $params -p green \"al.*a\" -p blue \"al\.\" -p yellow \"ma\" -p red \"bog.*m\" --no-embed -p green \"dan\" $pCli\n";;
  2) echor -c $showCmd "$ hl.py $params \"al.*a\" \"al\.\" \"ma\" \"bog.*m\" --no-embed \"dan\" $pCli\n";;
  esac # }}}
  cat <<-EOF |
		ala ma kota
		a kot ma ale
		al. ma psa
		bogdan ma ma ma cosie
		bagdan ma ma ma cosie
		ola nie ma kota
		ale ma rybki
	EOF
  case $mode in
  0) python hl.py $params $pCli;;
  1) python hl.py $params -p green "al.*a" -p blue "al\." -p yellow "ma" -p red "bog.*m" --no-embed -p green "dan" $pCli;;
  2) python hl.py $params "al.*a" "al\." "ma" "bog.*m" --no-embed "dan" $pCli;;
  esac;; # }}}
3) # {{{
  [[ $pCli == *"+D"* ]] && pCli=${pCli/+D}
  echor -c $showCmd "$ hl.py $pCli\n"
  cat <<-EOF |
		message TB] II normal # {{{ here and here # }}}
		message TB] IMP important # {{{ here and here # }}}
		message TB] EE error, sum is: [0bee89b07a248e27c83fc3d5951213c1]
		message TB] FF fatal 
		message TB] BB before
		message TB] AA after
		message TB] TT trace
		12:34:34 message, crash at 11:30:40.345
		date: 250101-14:30:45.123456
		date: 20250101-143045.123456
		id: 0022AB33-THISISID-01234012348844 ticket: JIRAID-12345 [JIRAID-12345]
		ticket: JIRAID-12345 [JIRAID-12345]
	EOF
  python hl.py $pCli;; # }}}
esac

