import sys
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
SP, UP, DN, LF, RT, M = 56, 16, 8, 41, 40, 58
z = nextemu.NextX('build/DUNGEON.NEX', 'build/DUNGEON.sym')
# frame -> key held for 2 frames
plan = {200: SP}
f = 300
for k in [UP, UP, RT, UP, UP, LF, UP, UP, UP, RT, UP, UP]:
    plan[f] = k; f += 40
f += 60
plan[f] = M; mapf = f + 60
z.shots = {150: sys.argv[1] + '_title.png', 260: sys.argv[1] + '_start.png', f - 50: sys.argv[1] + '_walk.png', f - 70: sys.argv[1] + '_walk2.png', f - 85: sys.argv[1] + '_walk3.png', f - 95: sys.argv[1] + '_walk4.png', mapf: sys.argv[1] + '_map.png'}
def keys(fr):
    for d in (0, 1):
        if fr - d in plan: return {plan[fr - d]}
    return set()
z.keysheld = keys
z.run_frames(mapf + 5)
