# emu.py - the emulator for NTC3D games' tests: nextemu.py's Next (here, in tools/emu) with   # <--- CHANGED
# the two things the E3 engine needs that it doesn't do itself:                               # <--- CHANGED
#   - Z80N's NEXTREG n, A (ED 92 n): the engine maps the screen's pages with it - a breakpoint on
#     each one in the program, done by hand (as nextemu does MUL D, E)
#   - the zxnDMA copying memory to memory (the engine clears the screen with it: a fixed source
#     byte filled over 16K) - done at once when the DMA is enabled, its time (DMA_T T-states a byte,
#     4 unless the environment says: the CPU waits while it runs) then taken off the CPU's
import os
DMA_T = int(os.environ.get('DMA_T', '4'))
#   - needs Python 3, the z80 module (pip install z80) and Pillow (pip install pillow)          # <--- NEW
#   - from a game's test:  sys.path.insert(0, '<game>/tools/emu'); from emu import NX           # <--- NEW
#     z = NX('build/GAME.NEX', 'build/GAME.sym'); z.held = {56}; z.run_frames(50); z.shot('a.png') # <--- NEW
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # <--- CHANGED (nextemu.py is here)
from nextemu import NextX

class NX(NextX):
    def dma_out(s, v):
        s.dma_init(); d = s.dma
        if not d['need']:
            if not v & 0x80:
                if v & 3: d['dirab'] = bool(v & 4)
                elif (v & 7) == 4: d['amode'] = v
                elif (v & 7) == 0: d['bmode'] = v
            elif v == 0x87:
                bm = d.get('bmode', 0); am = d.get('amode', 0)
                if not bm & 8 and not am & 8:
                    def step(m):
                        k = (m >> 4) & 3
                        return -1 if k == 0 else 1 if k == 1 else 0
                    sa = step(am); sb = step(bm)
                    a = d['a']; b = d['b']; n = d['len'] or 65536
                    mem = s.m.memory
                    if not d.get('dirab', True): a, b, sa, sb = b, a, sb, sa
                    s.dma_debt = getattr(s, 'dma_debt', 0) + n * DMA_T
                    if sa == 0 and sb == 1:
                        v0 = mem[a & 0xFFFF]
                        for i in range(n): mem[(b + i) & 0xFFFF] = v0
                    else:
                        for i in range(n):
                            mem[b & 0xFFFF] = mem[a & 0xFFFF]; a += sa; b += sb
                    NextX.dma_out(s, v); d['on'] = False
                    return
        NextX.dma_out(s, v)

    def setup_n(s):
        s.nrpcs = set()
        for k in range(6):
            pg = s.pages.get(16 + k)
            if pg is None: continue
            for o in range(0x2000 - 2):
                if pg[o] == 0xED and pg[o + 1] == 0x92:
                    a = k * 0x2000 + o
                    if a >= 0x40: s.nrpcs.add(a); s.m.set_breakpoint(a)

    def pay(s):
        # the DMA's time: taken off the CPU's run (what's left of it carried on to the next)
        d = getattr(s, 'dma_debt', 0)
        if d > 0 and s.m.ticks_to_stop > 1:
            x = min(d, s.m.ticks_to_stop - 1)
            s.m.ticks_to_stop -= x; s.dma_debt = d - x

    def run_bp(s):
        if not hasattr(s, 'nrpcs'): s.setup_n()
        s.pay()
        m = s.m; ev = m.run()
        while ev & 1:
            pc = m.pc
            mem = m.memory
            if pc in s.mulpcs and mem[pc] == 0xED and mem[pc + 1] == 0x30:
                m.de = (m.d * m.e) & 0xFFFF
                m.pc = (pc + 2) & 0xFFFF
                m.ticks_to_stop = max(1, m.ticks_to_stop - 8)
            elif pc in s.nrpcs and mem[pc] == 0xED and mem[pc + 1] == 0x92:
                r = mem[pc + 2]
                m.pc = (pc + 3) & 0xFFFF
                m.ticks_to_stop = max(1, m.ticks_to_stop - 17)
                s.nreg_write(r, m.a)
            else:
                if pc == s.waitkey and not s.typed: s.typed.append('\r')
                ev = m.step_over_breakpoint()
                if m.halted or m.ticks_to_stop <= 0: break
            s.pay()
            ev = m.run()
