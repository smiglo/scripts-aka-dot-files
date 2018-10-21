if [[ $1 == '@@' ]]; then
  echo "$(ls *.adoc)"
  exit 0
fi

# ------------------------------------------------------------------------
# a2x -v --fop -a icons -a iconsdir=/opt/local/etc/asciidoc/images/icons -a toc2 -a theme=flask
# ------------------------------------------------------------------------

params="-b ${2:-"html5"} -a icons -a iconsdir=/opt/local/etc/asciidoc/images/icons -a toc2 -a theme=flask"
file=${1:-"conf_call_notes.adoc"}
file_tmp=$file.tmp
commitId="$(git log -1 --pretty=format:%H)"

[[ $? != 0 ]] && commitId="v0.1"

eval sed 's/{docCommitId}/$commitId/g' < $file >$file_tmp

cmd="asciidoc $params $file_tmp"
echo $cmd
eval $cmd

rm -f $file_tmp

