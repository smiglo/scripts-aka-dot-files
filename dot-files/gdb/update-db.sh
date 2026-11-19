#!/usr/bin/env bash

url="https://raw.githubusercontent.com/cyrus-and/gdb-dashboard/refs/heads/master/.gdbinit"
wget "$url" -O ./050-gdb-dashboard.gdb
