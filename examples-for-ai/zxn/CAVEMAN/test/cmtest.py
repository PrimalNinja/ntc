import sys
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
z = nextemu.NextX('build/CAVEMAN.NEX', 'build/CAVEMAN.sym')
z.keysheld = lambda f: {56} if f in (200, 201, 202, 300, 301, 302) else ({40} if 400 < f < 700 else set())
hits = []
def per(z):
    print(z.frame, 'hp', z.arr('arr_ahp', 0), 'afl', z.arr('arr_afl', 0), 'st', z.arr('arr_ast', 0), flush=True)
z.run_frames(3000, (150, per))
