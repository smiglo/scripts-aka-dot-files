case $PWD in
$SCRIPT_PATH/bin | $SCRIPT_PATH/bin/* );;
*) echo "wrong dir, $PWD"; return 0;;
esac
compl-add ./mk_install_scripts.sh

