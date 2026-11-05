# vim: ft=python

python
import os

pwnDbgConf = os.environ.get("GDB_PWNDBG_INIT")
if "pwndbg" in sys.modules and hasattr(sys.modules["pwndbg"], "_is_loaded_from_pwndbg"):
    pwnDbgConf = '/NONE'
elif not pwnDbgConf:
    pwnDbgConf = '/usr/share/pwndbg/gdbinit.py'
if os.path.exists(pwnDbgConf):
    gdb.execute('source ' + pwnDbgConf)

end
