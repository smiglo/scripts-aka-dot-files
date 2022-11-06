import os

h = os.getenv("GDB_USE_INTEL_DISASSEMBLY")
if not h == "False": gdb.execute("set disassembly-flavor intel")

class conn (gdb.Command):

    def __init__(self):
      super(conn, self).__init__("conn", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        ip = os.getenv("STB_IP")
        print("target remote " + ip + ":8055")
        gdb.execute("target remote " + ip + ":8055")

conn()

class concat(gdb.Function):
    def __init__(self):
        super(concat, self).__init__("concat")

    def _unwrap_string(self, v):
        try:
            return v.string()
        except gdb.error:
            return str(v)

    def invoke(self, *args):
        return ''.join([ self._unwrap_string(x) for x in args])
concat()

