# bot.py - X-TYPE flown by a script (the ship made safe): pictures down the stage, and how many frames the game
# managed per frame the Next had (a slow frame shows as the game's frame counter falling behind).
#   python3 test/bot.py [stage] [frames]
# (c) 2026 Cyborg Unicorn Pty Ltd
import os, sys, time, math
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
sys.path.insert(0, HERE)
import nextemu
SHOT = os.path.join(ROOT, 'screenshots'); os.makedirs(SHOT, exist_ok=True)
stage = int(sys.argv[1]) if len(sys.argv) > 1 else 1
total = int(sys.argv[2]) if len(sys.argv) > 2 else 6000
e = nextemu.Emu(os.path.join(ROOT, 'build', 'XTYPE.NEX'), os.path.join(ROOT, 'build', 'XTYPE.sym'))
V = lambda n: e.peekw('var_' + n)
e.frame(60); e.press('space', 4, 4); e.frame(60); e.press('space', 4, 4); e.frame(100)
if stage == 2:
    # start stage 2 by finishing... (the stage number is set before the game starts: poke it into the menu loop is not possible,
    # so jump: set g_intStage = 2 won't stick; use the debug start in Main when a key is held)
    pass
e.press('space', 4, 4); e.frame(150)
f0 = V('g_intframe'); t0 = e.frames; lastshot = -999
worst = 0; prev = f0
for i in range(total):
    ph = i / 40.0
    keys = set()
    y = V('g_intpy')
    want = 128 + 70 * math.sin(i / 70.0)
    if y > want + 3: keys.add('q')
    if y < want - 3: keys.add('a')
    px = V('g_intpx')
    if px < 60: keys.add('p')
    if px > 90: keys.add('o')
    ph = i % 360
    if ph < 60 and i > 1500: keys.add('space')
    elif ph >= 60 and (i // 6) % 2 == 0: keys.add('space')
    if i % 90 == 0: keys.add('z')
    e.held = keys
    if i == 200 and len(sys.argv) > 3: e.pokew('g_intpow', 2); e.pokew('g_intspd', 1); e.pokew('g_intorb', 1)
    e.frame(1)
    if i % 30 == 0 and 'mortal' not in sys.argv:
        e.pokew('g_intinv', 300) if V('g_intdead') == 0 else None
    if V('g_intlives') <= 0 and V('g_intdead') >= 100:
        e.frame(30); e.picture(os.path.join(SHOT, '05_game_over.png'), 2, False); print('game over shot'); break
    fr = V('g_intframe')
    if fr - prev > 1: worst = max(worst, fr - prev)
    prev = fr
    scr = V('g_intscr')
    if i % 250 == 249:
        e.picture(os.path.join(SHOT, 'bot_%05d.png' % (i + 1)), 2, False)
        print(i + 1, 'dead', V('g_intdead'), 'scr', scr, 'lives', V('g_intlives'), 'score', V('g_inthi'), V('g_intlo'), 'pow', V('g_intpow'), 'spd', V('g_intspd'), 'orb', V('g_intorb'), 'bk', V('g_intbk'), 'won', V('g_intwon'))
print('game frames', V('g_intframe') - f0, 'emu frames', e.frames - t0, 'worst skip', worst)
