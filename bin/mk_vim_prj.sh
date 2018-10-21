clean() {
  rm -f cscope*
  rm -f tags
}

exclude_dirs() {
  local i= ret=
  for i in .git .hg .svn CVS $VIM_PRJ_EXCLUDE; do
    case $1 in
    cscope) ret+=" -path '*/$i' -prune -o";;
    tags)   ret+=" --exclude=$i";;
    esac
  done
  echo "$ret"
}

mk_cscope() {
  local DIR=.
  if ! $RELATIVE; then
    DIR=$PWD
    pushd / >/dev/null
  fi
  eval find -L $DIR             \
    $(exclude_dirs 'cscope')    \
    -name "*.[chxsS]" -print -o \
    -name "*.cpp"     -print -o \
    -name "*.java"    -print | sort > $DIR/cscope.files
  ! $RELATIVE && popd >/dev/null

  cscope -b -q
}

mk_tags() {
  echo ctags -R --sort=yes --c-kinds=cdefglmnpstuvx --c++-kinds=cdefglmnpstuvx --Java-kinds=cfilmp --fields=+iaStnml --extra=+q $(exclude_dirs 'tags') .
}

DEFAULT_TODO="cscope tags"
todo=
RELATIVE=true
[[ -z $1 && ! -z $VIM_PRJ_PARAMS ]] && set - $VIM_PRJ_PARAMS
while [[ ! -z $1 ]]; do
  case $1 in
    cscope)     todo+=" cscope";;
    tags)       todo+=" tags";;
    all)        todo="cscope tags";;
    --absolute) RELATIVE=false;;
    *)          echo "Invalid param" && exit 1;;
  esac
  shift
done

[[ -z $todo ]] && todo=$DEFAULT_TODO
clean
for t in $todo; do
  eval mk_$t
done

