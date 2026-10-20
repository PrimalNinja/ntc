# dbg.py NEX addrhex [steps] - stop at addr, show registers, then step
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx
z = Zx(os.path.abspath(sys.argv[1]), wait=0)
print(z.cmd('enter-cpu-step'))
print(z.cmd('enable-breakpoints'))
print(z.cmd('set-breakpoint 1 PC=%sH' % sys.argv[2]))
print(z.cmd('exit-cpu-step'))
time.sleep(float(os.environ.get("W","8")))
print(z.cmd('get-registers'))
print(z.cmd('enter-cpu-step'))
for k in range(int(sys.argv[3]) if len(sys.argv) > 3 else 0):
    print(z.cmd('cpu-step', 0.3))
z.close()
