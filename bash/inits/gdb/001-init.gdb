# vim: ft=gdb

# When inspecting large portions of code the scrollbar works better than 'less'
set pagination off

# Beloved assembly
set disassembly-flavor intel

# Keep a history of all the commands typed. Search is possible using ctrl-r
set history save on
set history filename ~/.config/gdb/history
set history size 32768
set history expansion on
set auto-load safe-path /


