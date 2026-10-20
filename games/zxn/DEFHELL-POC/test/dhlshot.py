import sys
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
SP, UP, DN, LF, RT = 56, 16, 8, 41, 40
z = nextemu.NextX('build/DEFHELL.NEX', 'build/DEFHELL.sym')
plan = {}
seq = sys.argv[2].split(',') if len(sys.argv) > 2 else []
# seq items: frame:key:len
for it in seq:
    if not it: continue
    f, k, n = it.split(':'); f = int(f); n = int(n)
    for d in range(n): plan.setdefault(f + d, set()).add({'S': SP, 'U': UP, 'D': DN, 'L': LF, 'R': RT, 'B': 60}[k])
z.keysheld = lambda fr: plan.get(fr, set())
for a in sys.argv[3].split(','):
    z.shots[int(a)] = '%s_%s.png' % (sys.argv[1], a)
z.run_frames(max(z.shots) + 2)
print("lives", z.var("var_lives"), "wave", z.var("var_wave"), "power", z.var("var_power"), "level", z.var("var_level"))
