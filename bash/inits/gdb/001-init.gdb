# vim: ft=gdb

# When inspecting large portions of code the scrollbar works better than 'less'
set pagination off


# Keep a history of all the commands typed. Search is possible using ctrl-r
set history save on
set history filename ~/.config/gdb/history
set history size 32768
set history expansion on
set auto-load safe-path /

# Beloved assembly
python
import os
h = os.getenv("GDB_USE_INTEL_DISASSEMBLY")
if not h == "False":
  gdb.execute("set disassembly-flavor intel")
end

