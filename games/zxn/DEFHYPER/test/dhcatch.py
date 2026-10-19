import sys
sys.path.insert(0, '/home/claude/work/emu')
exec(open('/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad/dhtest.py').read().split('log = []')[0])
st = {'n': -1, 'last': None, 'f0': 0}
def onframe(z):
    bot(z)
    if z.frame % 300 == 0: z.setvar('var_lives', 3)
    if z.frame == 600:
        for n in range(10):
            if arr('arr_ps', n) == 1:
                seta('arr_ps', n, 3); seta('arr_py', n, 70); seta('arr_pf', n, 70); seta('arr_pv', n, 0)
                seta('arr_px', n, (v('var_hx') // 8 + 40) & 2047); st['n'] = n; break
    n = st['n']
    if n >= 0:
        s = (arr('arr_ps', n), v('var_aboard'), v('var_catches'))
        if s != st['last']: print(z.frame, 'ps aboard catches', s, 'py', arr('arr_py', n), 'hy', v('var_hy'), 'score', score(), flush=True); st['last'] = s
    if z.frame == 1000: st['f0'] = v('var_frames')
    if z.frame == 1500: print('game frames in 500:', (v('var_frames') - st['f0']) & 0x7fff)
    if z.frame == 3500: st['f0'] = v('var_frames'); z.setvar('var_wave', 6); 
    if z.frame == 4000: print('game frames in 500 (later):', (v('var_frames') - st['f0']) & 0x7fff, 'enemies', sum(1 for k in range(32) if arr('arr_uk', k)))
z.onframe = onframe
z.keysheld = lambda f: held
z.run_frames(4001)
