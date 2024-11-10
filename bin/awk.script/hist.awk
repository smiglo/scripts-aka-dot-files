function max(arr, big)
{
  big = 0
  for (i in hist) {
    if (hist[i] > big)
      big = hist[i]
  }
  return big
}

BEGIN {
  if (help) {
    printf "* -v i=INDEX\n"
    printf "* -v scale=60\n"
    printf "* -v prefix=1\n"
    printf "\n"
  }
}

{
  hist[$i]++
}

END {
  maxm = max(hist)
  sum = 0
  len_i_str = 0
  len_i = 0
  for (i in hist) {
    sum += hist[i]
    if (length(i) > len_i_str)   len_i_str = length(i)
    if (length(hist[i]) > len_i) len_i     = length(hist[i])
  }
  len_i += 1
  len_i_str += 1
  if (!scale) {
    scale = ENVIRON["COLUMNS"]
    if (scale) scale = scale - 5
    else scale = 80
    scale = scale - len_i_str - 2 - len_i - 3 - 2 - 3
    if (!!prefix) scale = scale - len_i - 4
  }
  if (!!dbg) {
    printf "\n"
    printf "lIStr=%d, lI=%d, scale=%d\n", len_i_str, len_i, scale
  }
  if (!prefix) printf "\n"
  for (i in hist) {
    scaled = scale * hist[i] / maxm
    if (!!prefix) printf "%"len_i"d -- ", hist[i]
    else printf " "
    printf "%-"len_i_str"."len_i_str"s [%"len_i"d : %2d%% ]:", i, hist[i], hist[i]/sum*100
    for (i = 0; i < scaled; i++) printf "#"
    printf "\n"
  }
  if (!prefix) printf "\n"
  len = len_i_str
  if (!!prefix) len += len_i + 4
  else len += 1
  printf "%"len"s  %"len_i"d : total\n", " ", sum
  if (!prefix) printf "\n"
}

