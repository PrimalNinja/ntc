import sys, os
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
z = nextemu.NextX('build/CHAOTIC.NEX', 'build/CHAOTIC.sym')
held=set()
S='/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad/'
def w(name, i, v):
    a = z.symtab[name] + i * 2; z.m.memory[a] = v & 255; z.m.memory[a + 1] = (v >> 8) & 255
def onframe(z):
    held.clear(); f=z.frame
    if 300 < f < 310: held.add(56)
    if f == 900:
        z.setvar('var_inv', 0); w('arr_ek', 0, 1); w('arr_el', 0, z.var('var_plane')); w('arr_ez', 0, 4096)
    if f in (905, 912, 925, 945):
        a = z.symtab['arr_web_pt']
        on = [i for i in range(160) if z.m.memory[a + i*32 + 8]]
        print(f, 'live', len(on), 'alive', z.var('var_alive'), [(z.m.memory[a+i*32+1], z.m.memory[a+i*32+3], z.m.memory[a+i*32+8], z.m.memory[a+i*32+9], z.m.memory[a+i*32+16], hex(z.m.memory[a+i*32+14] + 256*z.m.memory[a+i*32+15])) for i in on[::8]], flush=True)
        z.shot(S + 'chd%d.png' % f)
z.onframe=onframe; z.keysheld=lambda f: held
z.run_frames(950)
