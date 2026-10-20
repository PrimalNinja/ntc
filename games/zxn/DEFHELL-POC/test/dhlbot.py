# DEFENDER HELLGATE test: a simple pilot (fire held, sweeping up and down, turning now and then,
# guard and smart bombs when it's busy); argv: frames, out prefix, cheat (level 3 + warp at 700)
import sys, random
sys.path.insert(0, '/home/claude/work/emu')
import nextemu, os
os.chdir('/home/claude/work/games/DEFHELL')
SP, UP, DN, LF, RT, B, G = 56, 16, 8, 41, 40, 60, 0
z = nextemu.NextX('build/DEFHELL.NEX', 'build/DEFHELL.sym')
OUT = '/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad/'
N = int(sys.argv[1]); PFX = sys.argv[2]; CHEAT = int(sys.argv[3]) if len(sys.argv) > 3 else 0
r = random.Random(5)
KG = None
# find the G key number: half row of G (row 1: A S D F G -> keys 8..12; G = 12?)
def v(n): return z.var(n)
def L(n):
    a = z.symtab[n]; return z.deek(a) | z.deek(a + 2) << 16
state = {'dir': RT}
def keys(f):
    k = set()
    if f < 300: return k
    if 300 <= f < 304: return {SP}
    if f < 420: return k
    k.add(SP)
    if (f // 250) % 2: state['dir'] = LF if (f // 500) % 2 else RT
    if f % 250 < 120: k.add(state['dir'])
    k.add(UP if (f // 60) % 2 else DN)
    if f % 900 == 450: k.add(B)
    if f % 400 == 200: k.add(12)
    return k
z.keysheld = keys
shots = {}
def per(z):
    print(z.frame, 'wave', v('var_wave'), 'lives', v('var_lives'), 'level', v('var_level'), 'power', v('var_power'),
          'guards', v('var_guards'), 'chain', v('var_chain'), 'boss', v('var_bosshp'), '/', v('var_bossmax'), 'done', v('var_bossdone'),
          'score', L('var_score'), flush=True)
def hook(z):
    f = z.frame
    if CHEAT and f == 700:
        z.setvar('var_level', 3); z.setvar('var_warp', 1)
    if v('var_lives') < 2 and CHEAT: z.setvar('var_lives', 5)
    if CHEAT == 2 and f > 420: z.setvar('var_safe', 60)
z.onframe = hook
for s in sys.argv[4:]:
    z.shots[int(s)] = OUT + '%s_%s.png' % (PFX, s)
z.run_frames(N, (500, per))
