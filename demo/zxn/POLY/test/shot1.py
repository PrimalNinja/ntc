import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx
z = Zx(os.path.abspath(sys.argv[1]), wait=float(sys.argv[3]) if len(sys.argv) > 3 else 6)
z.shot(os.path.abspath(sys.argv[2]))
z.close()
