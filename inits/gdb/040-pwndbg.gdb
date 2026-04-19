# vim: ft=python

python
import os

pwnDbgConf = os.environ.get("GDB_PWNDBG_INIT")
if not pwnDbgConf:
    pwnDbgConf = os.environ["SCRIPT_PATH"] + '/bash/inits/gdb/pwn-dbg/gdbinit.py'
if os.path.exists(pwnDbgConf):
    gdb.execute('source ' + pwnDbgConf)

end

