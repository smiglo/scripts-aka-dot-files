
filename=
dir=
prune_params=
accept_params=

if [ "$1" == '@@' ]; then
  if [ "$2" == '' ]; then
    echo -f -d -p -a -h
  else 
    case "$2" in
    -f) echo -f;;
    -d) echo -S/ -d;;
    esac
  fi
  exit 0
fi

while [ "$1" != "" ]; do
  case "$1" in
  "-f") 
    shift; 
    filename=$1;;
  "-d") 
    shift; 
    dir=$1;;
  "-p")
    shift;
    prune_params="$1 -o";;
  "-a")
    shift;
    accept_params="$1 ";;
  "-h") 
    echo "USAGE: $0 [-d dir] [-f dest_file] [-h] [-p filter] [-a filter]"
    echo "       -d    directory to tar, '.' will be taken if ommited"
    echo "       -f    destination file, directory name will be taken if ommited"
    echo "       -p    additional prune params for find command"
    echo "       -a    additional accept params for find command" 
    echo "       -h    this message"
    exit 1;;
  esac
  shift
done;

if [ "$dir" == '' ]; then
  dir="."
fi

if [ "$filename" == '' ]; then
  if [ "$dir" == '.' ]; then
    tmp_v=$(dirname $PWD)
    filename=$(basename $tmp_v)
  else
    filename=$dir
  fi
  filename=$filename.tgz
fi

if [ -e $filename ]; then
  rm $filename
fi

echo
echo "dir:            $dir"
echo "filename:       $filename"
echo "prune params:   $prune_params"
echo "accept params:  $accept_params"
echo

if [ "$find_cmd" == '' ]; then
  find_cmd=find
fi

pr_svn="-name .svn -prune"
pr_git="-name .git -prune -o -name .gitignore -prune"
pr_swp="-name *.swp -prune"
pr_vim="-name *.vim -prune"
prunes="$pr_svn -o $pr_git -o $pr_swp -o $pr_vim"

echo "$find_cmd -L $dir $prune_params $prunes -o $accept_params -printf \"%p\"\\n | xargs tar --no-recursion -czvf $filename"
echo

$find_cmd -L $dir $prune_params $prunes -o $accept_params -printf \"%p\"\\n | xargs tar --no-recursion -czvf $filename



