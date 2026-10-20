# chbot.py - a bot for CHAOTIC: plays it in the emulator (nextemu.py), takes screenshots.
# It slides to the lane of whatever is nearest the rim (or a pickup), fires all the time, uses
# the GUARD when bullets are close and the NOVA when things are about to reach the rim.
#   python3 test/chbot.py FRAMES [seed] [tag] [level]   (from the game's folder, after build.js;
#   level: jump straight to it, to see the later things)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys, os, random
sys.path.insert(0, os.environ.get('NEXTEMU', '/home/claude/work/emu'))
import nextemu
SP, Q, A, O, P, M, N = 56, 16, 8, 41, 40, 58, 59
OUT = os.environ.get('OUT', 'test/shots/')
os.makedirs(OUT, exist_ok=True)
z = nextemu.NextX('build/CHAOTIC.NEX', 'build/CHAOTIC.sym')
r = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
TAG = sys.argv[3] if len(sys.argv) > 3 else 'b'
JUMP = int(sys.argv[4]) if len(sys.argv) > 4 else 0   # start at this level (a test)
def v(n): return z.var('var_' + n)
def a(n, i, size=2): return z.arr('arr_' + n, i, size)
held = set()
seen = {}
def snap(key, delay=0):
    if key not in seen:
        seen[key] = z.frame; z.shots[z.frame + delay + 1] = OUT + TAG + '_' + key + '.png'
def lane_way(cur, want, closed):
    d = want - cur
    if closed:
        if d > 8: d -= 16
        if d < -8: d += 16
    return (d > 0) - (d < 0)
st = {'lv': 0, 'deaths': 0, 'lives': 0}
def onframe(z):
    held.clear()
    f = z.frame
    if f < 120: return
    lv = v('level'); alive = v('alive')
    if v('bosson') and 'core%d' % lv not in seen: snap('core%d' % lv, 200)
    if v('bosson') and f % 250 == 0: print(f, 'core hp', v('bosshp'), 'gap', v('bossgap'), 'plane', v('plane'), 'lives', v('lives'), flush=True)
    if lv != st['lv']:
        st['lv'] = lv; snap('level%02d' % lv, 260)
        print(f, 'frames', v('frames'), 'level', lv, 'score', z.var('var_score') & 0xFFFF, 'lives', v('lives'), 'power', v('power'), flush=True)
    if JUMP and lv == 1 and v('spawned') > 3 and not st.get('jumped'):
        # test: jump ahead (the level before JUMP, cleared)
        st['jumped'] = 1; z.setvar('var_level', JUMP - 1); z.setvar('var_spawned', v('quota'))
        for n in range(20): z.m.memory[z.symtab['arr_ek'] + n * 2] = 0; z.m.memory[z.symtab['arr_ek'] + n * 2 + 1] = 0
    if f == 250: snap('title')
    if f < 300: return
    # the title / game over: space
    if v('alive') == 0 and v('lives') == 0 and v('deadt') <= 0:
        if (f // 10) % 2: held.add(SP)
        return
    held.add(SP) if (f // 3) % 4 else None
    if not alive:
        if v('deadt') == 100: snap('death%d' % (f // 1000))
        return
    plane = v('plane'); closed = v('isclosed')
    # the target: the thing nearest the rim (or on it), else a pickup
    best = None; bz = -1
    for n in range(20):
        if a('ek', n) > 0:
            ez = a('ez', n)
            if ez > bz: bz = ez; best = a('el', n)
    for n in range(6):
        if a('ik', n) > 0 and a('iz', n) > 3000 and (best is None or bz < 2500): best = a('il', n); bz = 9999
    if bz > 3700 and v('novas') > 0 and r.random() < 0.02: held.add(N)
    if v('bosson'): best = v('bossgap')
    # bullets near: guard
    if v('guards') > 0 and v('guardt') == 0:
        px, py = v('px'), v('py'); near = 0
        base = z.symtab['arr_bul_eb']
        for b in range(64):
            if z.m.memory[base + b * 10 + 8] != 255:
                bx = z.m.memory[base + b * 10 + 1]; by = z.m.memory[base + b * 10 + 3]
                if abs(bx - px) < 20 and abs(by - py) < 20: near += 1
        if near >= 2: held.add(M)
    if v('bosson') and v('novas') > 0 and r.random() < 0.004: held.add(N)
    if best is None: return
    w = lane_way(plane, best, closed)
    if w == 0: return
    dx = a('dirx', plane); dy = a('diry', plane)
    if dx: held.add(P if w * dx > 0 else O)
    elif dy: held.add(A if w * dy > 0 else Q)
    if (f // 50) % 9 == 0: snap('play%d' % (f // 3000))
    if JUMP and f % 300 == 0: snap('seq%03d' % (f // 300))
z.onframe = onframe
z.keysheld = lambda f: held
n = int(sys.argv[1])
for f in range(0, n, 1000):
    z.run_frames(1000)
    if z.m.halted or z.reset: print('CRASH', z.frame, hex(z.m.pc)); break
z.shot(OUT + TAG + '_last.png')
print('end', z.frame, 'level', v('level'), 'lives', v('lives'), flush=True)
