# vim: ft=gdb

# When inspecting large portions of code the scrollbar works better than 'less'
set pagination off

# Keep a history of all the commands typed. Search is possible using ctrl-r
set auto-load safe-path /
set auto-load local-gdbinit
set history save on
set history filename .gdb.hist
set history size 32768
set history expansion on
set print address
set print array
set print raw-values
set $PRM = "☯"
set $PR = "$PRM >>>"

alias -a ib = info breakpoint

define set-radix
  set output-radix $arg0
end
define xp
  if $argc == 1
    printf "%s $arg0\n", $PR
  else
    if $argc == 2
      printf "%s $arg0 $arg1\n", $PR
    else
      if $argc == 3
        printf "%s $arg0 $arg1 $arg2\n", $PR
      else
        if $argc == 4
          printf "%s $arg0 $arg1 $arg2 $arg3\n", $PR
        else
          if $argc == 5
            printf "%s $arg0 $arg1 $arg2 $arg3 $arg4\n", $PR
          else
            printf "%s $arg0 $arg1 $arg2 $arg3 $arg4 ...\n", $PR
          end
        end
      end
    end
  end
end
define pp
  xp p $arg0
  p $arg0
  xp p/x $arg0
  p/x $arg0
  xp p/x *$arg0
  p/x *$arg0
end
define dump_native
    dump binary memory dump.bin $arg0 $arg0+$arg1
end
define xxde
  if $argc == 2
    dump_native $arg0 $arg0+$arg1
  else
    dump_native $arg0 $arg0+256
  end
  shell xxd -e -g4 dump.bin
end
define xxd
  if $argc == 2
    dump_native $arg0 $arg0+$arg1
  else
    dump_native $arg0 $arg0+256
  end
  shell xxd -g4 dump.bin
end
define rev
  set exec-direction reverse
  set $PR = "$PRM <<:"
  dashboard -style prompt_running '\\[\\e[1;35m\\]<<:\\[\\e[0m\\]'
end
define ffd
  set exec-direction forward
  set $PR = "$PRM >>:"
  dashboard -style prompt_running '\\[\\e[1;35m\\]>>:\\[\\e[0m\\]'
end

define ln
  if $argc == 1
    shell rm -f gdb.txt
  end
  set logging on
end
define lf
  set logging off
end

