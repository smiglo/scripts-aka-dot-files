# vim: ft=python

python
import os

pwnDbgConf = os.environ.get("GDB_PWNDBG_INIT")
if not pwnDbgConf:
    pwnDbgConf = '/usr/share/pwndbg/gdbinit.py'
if os.path.exists(pwnDbgConf):
    gdb.execute('source ' + pwnDbgConf)

end

