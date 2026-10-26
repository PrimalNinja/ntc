# nextemu.py - a ZX Spectrum Next with a picture, for NTC3D games' tests (tools/emu).   # <--- CHANGED
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License   # <--- NEW
# Built on NTC's zxnrun.py (the Z80, MMU, NextRegs, interrupts, keyboard) and adds what the games
# use: Layer 2 (256 x 192 / 320 x 256, scroll, clip, palette offset), the tilemap (40 / 80 x 32,
# 1 or 2 bytes a cell, 4 bit or text mode, scroll, clip), 128 sprites (4 / 8 bit, scale, mirror,
# rotate, clip), the palettes, global / sprite / tile transparency, the layer order, the copper
# (MOVE / WAIT per line, its registers seen line by line when the picture is made), the ULA.
#
#   python3 nextemu.py build DIR NAME files...      sjasmplus DIR/NAME.asm -> NEX + .sym (compile with build.js)
#   python3 nextemu.py run NEX SYM frames=N [keys=f:k,k;f2:k] [shots=f1,f2] [out=prefix] [watch=var_x] [every=n]
#
# keys: held keys by frame: '100-200:56,16' holds Space and Q in frames 100-200 (key number:
# half row * 8 + bit: Space 56, Enter 48, Q 16, A 8, O 41, P 40, M 58, N 59, 1-5 24-28)
import os, sys, re, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)   # <--- CHANGED (zxnrun.py, cpcrun.py are here)
import zxnrun, cpcrun
from PIL import Image

def rgb332(v, lowb=None):
    r = (v >> 5) & 7; g = (v >> 2) & 7; b = v & 3
    b3 = (b << 1) | (b != 0 if lowb is None else lowb)
    return (r * 255 // 7, g * 255 // 7, b3 * 255 // 7)

def syms_of(path):
    return load_syms(path)

def load_syms(path):
    syms = {}
    if path and os.path.exists(path):
        for line in open(path):
            m = re.match(r'^\s*([A-Za-z_.@][\w.@]*):?\s+(?:EQU|equ)\s+(0x[0-9A-Fa-f]+|\$[0-9A-Fa-f]+|\d+)', line)
            if m:
                v = m.group(2)
                v = int(v[2:], 16) if v.startswith('0x') else int(v[1:], 16) if v.startswith('$') else int(v)
                syms[m.group(1)] = v
                syms.setdefault(m.group(1).lower(), v)
    return syms

class NextX(zxnrun.Next):
    def __init__(s, nexpath, syms=None, typed=None):
        if isinstance(syms, str): syms = load_syms(syms)
        s.symtab = syms or {}
        s.held = set(); s.cur_held = set()
        s.sprattr = [[0, 0, 0, 0, 0] for _ in range(128)]
        s.sprslot = 0; s.sprbyte = 0
        s.pattern = bytearray(16384); s.patidx = 0
        s.copper = bytearray(2048); s.copidx = 0
        s.clips = {0x18: [0, 255, 0, 191], 0x19: [0, 255, 0, 191], 0x1A: [0, 255, 0, 191], 0x1B: [0, 159, 0, 255]}
        s.clipi = {0x18: 0, 0x19: 0, 0x1A: 0, 0x1B: 0}
        s.p123b = 0; s.border = 0; s.frame = 0
        s.shots = {}; s.hooks = []; s.onframe = None
        s.pal = {}                    # (palette 0-7, index) -> (r, g, b)
        zxnrun.Next.__init__(s, nexpath, '', s.symtab)
        s.regs.setdefault(0x14, 0xE3); s.regs.setdefault(0x4A, 0); s.regs.setdefault(0x4B, 0xE3)
        s.regs.setdefault(0x4C, 0x0F); s.regs.setdefault(0x12, 8); s.regs.setdefault(0x15, 0)
        s.regs.setdefault(0x6E, 0x6C); s.regs.setdefault(0x6F, 0x0C)
        # Z80N's MUL D,E (ED 30): the Z80 module doesn't know it - a breakpoint on each one in the
        # program (#0000-#BFFF), done by hand
        s.mulpcs = set()
        for k in range(6):                     # pages 16-21 end up in slots 0-5
            pg = s.pages.get(16 + k)
            if pg is None: continue
            for o in range(0x2000 - 1):
                if pg[o] == 0xED and pg[o + 1] == 0x30:
                    a = k * 0x2000 + o
                    if a >= 0x40: s.mulpcs.add(a); s.m.set_breakpoint(a)
        s.waitkey = s.symtab.get('kw_waitkey')

    def run_bp(s):
        m = s.m; ev = m.run()
        while ev & 1:
            pc = m.pc
            if pc in s.mulpcs and m.memory[pc] == 0xED and m.memory[pc + 1] == 0x30:
                m.de = (m.d * m.e) & 0xFFFF
                m.pc = (pc + 2) & 0xFFFF
                m.ticks_to_stop = max(1, m.ticks_to_stop - 8)
            else:
                if pc == s.waitkey and not s.typed: s.typed.append('\r')
                ev = m.step_over_breakpoint()
                if m.halted or m.ticks_to_stop <= 0: break
            ev = m.run()

    # ---- keys: held ones (keysheld(frame) -> a set of key numbers) on top of zxnrun's typed text
    def keysheld(s, frame):
        return s.held

    # ---- the zxnDMA (port #6B), enough for samples to a DAC: A memory -> B port, burst with the
    # prescaler, auto restart; Read Mask / read sequence for the counter and the addresses. The bytes
    # it sends to the DAC ports go to s.dac (one list, in order) - save_dac writes them as a WAV
    def dma_init(s):
        if hasattr(s, 'dma'): return
        s.dma = {'a': 0, 'len': 0, 'b': 0, 'pre': 0, 'auto': False, 'on': False, 'pos': 0, 'frac': 0.0,
                 'need': [], 'mask': 0x7F, 'rd': [], 'reg': None}
        s.dac = []
    def dma_out(s, v):
        s.dma_init(); d = s.dma
        if d['need']:
            k = d['need'].pop(0)
            if k == 'alo': d['a'] = (d['a'] & 0xFF00) | v
            elif k == 'ahi': d['a'] = (d['a'] & 0xFF) | (v << 8)
            elif k == 'llo': d['len'] = (d['len'] & 0xFF00) | v
            elif k == 'lhi': d['len'] = (d['len'] & 0xFF) | (v << 8)
            elif k == 'blo': d['b'] = (d['b'] & 0xFF00) | v
            elif k == 'bhi': d['b'] = (d['b'] & 0xFF) | (v << 8)
            elif k == 't2':
                if v & 0x20: d['need'].insert(0, 'pre')
            elif k == 'pre': d['pre'] = v
            elif k == 'mask': d['mask'] = v
            return
        if not v & 0x80:
            if v & 3:                                   # WR0
                d['need'] = [x for b, x in ((3, 'alo'), (4, 'ahi'), (5, 'llo'), (6, 'lhi')) if v & (1 << b)]
            elif (v & 7) == 4:                          # WR1
                if v & 0x40: d['need'] = ['t1']
            elif (v & 7) == 0:                          # WR2
                if v & 0x40: d['need'] = ['t2']
            return
        if (v & 0x83) == 0x80:                          # WR3
            d['need'] = [x for b, x in ((3, 'm'), (4, 'mt')) if v & (1 << b)]
            if v & 0x40: d['on'] = True
        elif (v & 0x83) == 0x81:                        # WR4
            d['need'] = [x for b, x in ((2, 'blo'), (3, 'bhi'), (4, 'int')) if v & (1 << b)]
        elif (v & 0xC7) == 0x82:                        # WR5
            d['auto'] = bool(v & 0x20)
        elif (v & 0x83) == 0x83:                        # WR6 commands
            if v == 0x83: d['on'] = False
            elif v == 0x87: d['on'] = True
            elif v == 0xCF: d['pos'] = 0
            elif v == 0xD3: d['pos'] = 0
            elif v == 0xBB: d['need'] = ['mask']
            elif v == 0xA7 or v == 0xBF:
                a = (d['a'] + d['pos']) & 0xFFFF; c = d['pos'] & 0xFFFF
                vals = [0x3A, c & 255, c >> 8, a & 255, a >> 8, d['b'] & 255, d['b'] >> 8]
                d['rd'] = [vals[k] for k in range(7) if d['mask'] & (1 << k)]
    def dma_in(s):
        s.dma_init()
        return s.dma['rd'].pop(0) if s.dma['rd'] else 0xFF
    def dma_frame(s):
        if not hasattr(s, 'dma'): return
        d = s.dma
        if not d['on'] or not d['pre'] or not d['len']: return
        d['frac'] += 875000.0 / d['pre'] / 50.0
        n = int(d['frac']); d['frac'] -= n
        dac = (d['b'] & 0xFF) in (0xDF, 0x0F, 0x1F, 0x3F, 0x4F, 0x5F, 0xFB)
        mem = s.m.memory
        for _ in range(n):
            if dac: s.dac.append(mem[(d['a'] + d['pos']) & 0xFFFF])
            d['pos'] += 1
            if d['pos'] >= d['len']:
                if d['auto']: d['pos'] = 0
                else: d['on'] = False; break
    def save_dac(s, path):
        import wave
        s.dma_init()
        rate = int(875000 / (s.dma['pre'] or 80))
        w = wave.open(path, 'wb'); w.setnchannels(1); w.setsampwidth(1); w.setframerate(rate)
        w.writeframes(bytes(s.dac)); w.close()

    def inp(s, port):
        if (port & 0xFF) == 0x6B: return s.dma_in()
        if port == 0x303B: return 0
        if (port & 0xFF) == 0xFE:
            v = zxnrun.Next.inp(s, port)
            hi = port >> 8
            for k in s.cur_held:
                r, b = k // 8, k % 8
                if not hi & (1 << r): v &= ~(1 << b)
            return v & 0xFF
        if port == 0x123B: return s.p123b
        return zxnrun.Next.inp(s, port)

    def out(s, port, val):
        if port == 0x303B:
            s.sprslot = val & 127; s.sprbyte = 0
            s.patidx = ((val & 63) << 8) | (128 if val & 128 else 0)
        elif (port & 0xFF) == 0x57: s.attr_write(val)
        elif (port & 0xFF) == 0x5B:
            s.pattern[s.patidx & 16383] = val; s.patidx = (s.patidx + 1) & 16383
        elif port == 0x123B: s.p123b = val
        elif (port & 0xFF) == 0x6B: s.dma_out(val)
        elif (port & 0xFF) == 0xFE: s.border = val & 7
        else: zxnrun.Next.out(s, port, val)

    def attr_write(s, val):
        a = s.sprattr[s.sprslot]
        a[s.sprbyte] = val
        s.sprbyte += 1
        if s.sprbyte == 4 and not (a[3] & 0x40): a[4] = 0; s.sprbyte = 5
        if s.sprbyte >= 5: s.sprbyte = 0; s.sprslot = (s.sprslot + 1) & 127

    def nreg_write(s, r, v):
        if r == 0x41:
            sel = (s.regs.get(0x43, 0) >> 4) & 7
            s.pal[(sel, s.palidx)] = rgb332(v)
            s.regs[r] = v
            if not s.regs.get(0x43, 0) & 0x80: s.palidx = (s.palidx + 1) & 255
            return
        if r == 0x44:
            sel = (s.regs.get(0x43, 0) >> 4) & 7
            if not getattr(s, 'p44', False): s.p44v = v; s.p44 = True; return
            s.p44 = False
            s.pal[(sel, s.palidx)] = rgb332(s.p44v, v & 1)
            if not s.regs.get(0x43, 0) & 0x80: s.palidx = (s.palidx + 1) & 255
            return
        if r == 0x40: s.p44 = False
        if r in s.clips:
            s.clips[r][s.clipi[r]] = v; s.clipi[r] = (s.clipi[r] + 1) & 3; s.regs[r] = v; return
        if r == 0x1C:
            if v & 1: s.clipi[0x18] = 0
            if v & 2: s.clipi[0x19] = 0
            if v & 4: s.clipi[0x1A] = 0
            if v & 8: s.clipi[0x1B] = 0
            return
        if r == 0x60:
            s.copper[s.copidx & 2047] = v; s.copidx = (s.copidx + 1) & 2047; return
        if r == 0x61:
            s.copidx = (s.copidx & 0x700) | v; s.regs[r] = v; return
        if r == 0x62:
            s.copidx = ((v & 7) << 8) | (s.copidx & 255); s.regs[r] = v; return
        if r == 0x34:
            s.sprslot = v & 127; s.regs[r] = v; return
        zxnrun.Next.nreg_write(s, r, v)

    def palc(s, sel, i):
        c = s.pal.get((sel, i))
        if c is None:
            if sel & 3 == 0:          # the ULA's default: 16 Spectrum colours + 240 more
                c = rgb332(i)
            else: c = rgb332(i)
        return c

    # ---- frames
    def run_frames(s, n, every=None):
        """run n frames (a frame: frame_t() T), calling hooks and taking shots at the frame starts"""
        end = s.frame + n
        while s.frame < end and not s.m.halted and not s.reset:
            if s.onframe: s.onframe(s)
            try: kh = s.keysheld(s.frame)
            except TypeError: kh = s.keysheld()
            if isinstance(kh, tuple): kh = kh[0]
            s.cur_held = set(kh)
            for h in s.hooks: h(s)
            if s.frame in s.shots: s.shot(s.shots[s.frame])
            s.run_one()
            s.dma_frame()
            s.frame += 1
            if every and s.frame % every[0] == 0: every[1](s)

    def run_one(s):
        # one frame of the zxnrun loop: until tframe wraps
        start = s.T
        ft = s.frame_t()
        while not s.m.halted and not s.reset and s.T - start < ft:
            q = max(1, min(s.next_event() - s.tframe, ft - (s.T - start)))
            s.stop = False; left = q
            while left > 0 and not (s.stop or s.m.halted or s.reset):
                s.q = left; s.m.ticks_to_stop = left; s.run_bp(); s.q = 0
                d = (s.stopdone + 1) if s.stop else (left - s.m.ticks_to_stop)
                s.T += d; s.tframe += d; left -= d
            if s.m.halted or s.reset: break
            if s.stop:
                while s.tframe >= ft: s.tframe -= ft
                continue
            if s.tframe >= s.next_event() or s.tframe >= ft:
                if s.tframe >= s.next_event():
                    steps = 0
                    while not s.m.halted and not s.reset and steps < 4000:
                        if s.m.iff1 and s.m.on_handle_active_int(): s.ints += 1; break
                        s.q = 1; s.m.ticks_to_stop = 1; s.run_bp(); steps += 1; d = 1 - s.m.ticks_to_stop; s.q = 0; s.T += d; s.tframe += d
            while s.tframe >= ft: s.tframe -= ft

    def run(s, n=100):
        s.run_frames(n)

    # ---- memory
    def peek(s, a):
        return s.m.memory[a]
    def deek(s, a):
        return s.m.memory[a] | s.m.memory[a + 1] << 8
    def poke(s, a, v):
        s.m.memory[a] = v & 255
    def var(s, name):
        """an Integer variable (var_x) as signed"""
        a = s.symtab.get(name if name in s.symtab else name.lower())
        v = s.deek(a)
        return v - 65536 if v >= 32768 else v
    def setvar(s, name, v):
        a = s.symtab.get(name if name in s.symtab else name.lower())
        s.poke(a, v & 255); s.poke(a + 1, (v >> 8) & 255)
    def arr(s, name, i, size=2):
        a = s.symtab.get(name if name in s.symtab else name.lower())
        if size == 1: return s.peek(a + i)
        v = s.deek(a + i * 2)
        return v - 65536 if v >= 32768 else v
    def pageall(s):
        for k in range(8): s.store(k)

    # ---- the picture
    def copper_states(s):
        """the NextRegs the copper changes, for each paper line -32 .. 223 (a dict of changes a line)"""
        ctrl = (s.regs.get(0x62, 0) >> 6) & 3
        if ctrl == 0: return None
        prog = []
        for i in range(1024):
            hi = s.copper[i * 2]; lo = s.copper[i * 2 + 1]
            prog.append((hi << 8) | lo)
        # run the program over a frame: line -> list of (reg, val)
        moves = {}
        line = 0; pc = 0
        for _ in range(1024):
            w = prog[pc]
            if w & 0x8000:
                wl = w & 0x1FF
                if wl == 511 or wl > 311: break
                line = max(line, wl)
            elif w:
                moves.setdefault(line, []).append(((w >> 8) & 0x7F, w & 255))
            pc += 1
            if pc >= 1024: break
        return moves

    def render(s):
        s.pageall()
        regs = dict(s.regs)
        moves = s.copper_states()
        # the border lines (y 0-31, raster lines 280-311) see the copper's last values
        if moves:
            for ln in sorted(moves):
                for r, v in moves[ln]: regs[r] = v
        img = Image.new('RGB', (320, 256))
        px = img.load()
        L2pages = {}
        for y in range(256):
            pl = y - 32
            if moves and pl == 0:
                pass
            if moves and pl >= 0 and pl in moves:
                for r, v in moves[pl]: regs[r] = v
            row = s.render_line(y, regs, L2pages)
            for x in range(320): px[x, y] = row[x]
        return img

    def render_line(s, y, regs, cache):
        # each layer: a list of 320 colours or None (transparent)
        trans = rgb332(regs.get(0x14, 0xE3))
        fallback = rgb332(regs.get(0x4A, 0))
        # Layer 2
        L2 = [None] * 320
        on = (s.p123b & 2) or (regs.get(0x69, 0) & 0x80)
        if on:
            res = (regs.get(0x70, 0) >> 4) & 3
            off = (regs.get(0x70, 0) & 15) << 4
            bank = regs.get(0x12, 8) & 0x7F
            sel = 1 + ((regs.get(0x43, 0) >> 2) & 1) * 4
            cl = s.clips[0x18]
            sx = regs.get(0x16, 0) | ((regs.get(0x71, 0) & 1) << 8); sy = regs.get(0x17, 0)
            if res == 0:
                ly = y - 32
                if 0 <= ly < 192 and cl[2] <= ly <= cl[3]:
                    yy = (ly + sy) % 192
                    base = bank * 16384 + yy * 256
                    for x in range(256):
                        if not (cl[0] <= x <= cl[1]): continue
                        a = base + ((x + sx) & 255)
                        p = s.page(a >> 13)[a & 8191]
                        c = s.palc(sel, (p + off) & 255)
                        if c != trans: L2[x + 32] = c
            elif res == 1:
                if cl[2] <= y <= cl[3]:
                    yy = (y + sy) & 255
                    for x in range(320):
                        if not (cl[0] * 2 <= x <= cl[1] * 2 + 1): continue
                        xx = (x + sx) % 320
                        a = bank * 16384 + xx * 256 + yy
                        p = s.page(a >> 13)[a & 8191]
                        c = s.palc(sel, (p + off) & 255)
                        if c != trans: L2[x] = c
        # ULA (only when on)
        U = [None] * 320
        if not regs.get(0x68, 0) & 0x80:
            ly = y - 32
            b5 = s.page(10)
            usel = 0 + ((regs.get(0x43, 0) >> 1) & 1) * 4
            for x in range(320):
                lx = x - 32
                if 0 <= ly < 192 and 0 <= lx < 256:
                    a = ((ly & 0xC0) << 5) | ((ly & 7) << 8) | ((ly & 0x38) << 2) | (lx >> 3)
                    at = b5[0x1800 + (ly >> 3) * 32 + (lx >> 3)]
                    bit = (b5[a] >> (7 - (lx & 7))) & 1
                    ink = (at & 7) + (8 if at & 64 else 0); paper = ((at >> 3) & 7) + (8 if at & 64 else 0)
                    c = s.palc(usel, ink if bit else paper + 16)   # <--- CHANGED (paper: palette 16-31, as the Next)
                else:
                    c = s.palc(usel, s.border)
                if c != trans: U[x] = c
        # the tilemap
        T = [None] * 320
        c6b = regs.get(0x6B, 0)
        if c6b & 0x80:
            cols = 80 if c6b & 0x40 else 40
            noattr = c6b & 0x20
            text = c6b & 0x08
            t512 = c6b & 0x02
            tsel = 3 + ((c6b >> 4) & 1) * 4
            mapo = (regs.get(0x6E, 0x6C) & 63) << 8; tilo = (regs.get(0x6F, 0x0C) & 63) << 8
            b5 = s.page(10) + s.page(11)
            sx = ((regs.get(0x2F, 0) & 3) << 8) | regs.get(0x30, 0); sy = regs.get(0x31, 0)
            tt = regs.get(0x4C, 0xF) & 15
            defattr = regs.get(0x6C, 0)
            cl = s.clips[0x1B]
            if cl[2] <= y <= cl[3]:
                yy = (y + sy) & 255
                r = yy >> 3; py = yy & 7
                pw = 320 if cols == 40 else 640
                for x in range(320):
                    if not (cl[0] * 2 <= x <= cl[1] * 2 + 1): continue
                    if cols == 40:
                        xx = (x + sx) % 320; c = xx >> 3; pxx = xx & 7
                        subs = [pxx]
                    else:
                        xx = (x * 2 + sx) % 640; c = xx >> 3; pxx = xx & 7
                        subs = [pxx]
                    if noattr:
                        tile = b5[(mapo + r * cols + c) & 16383]; at = defattr
                    else:
                        o = mapo + (r * cols + c) * 2
                        tile = b5[o & 16383]; at = b5[(o + 1) & 16383]
                    if t512 and (at & 1): tile |= 256
                    mx = at & 8; my = at & 4; rot = at & 2
                    u = pxx; v = py
                    if mx: u = 7 - u
                    if my: v = 7 - v
                    if rot: u, v = v, 7 - u
                    if text:
                        bits = b5[(tilo + tile * 8 + v) & 16383]
                        bit = (bits >> (7 - u)) & 1
                        idx = ((at >> 1) << 1 | bit) & 255
                        if True:
                            col = s.palc(tsel, idx)
                            if col != trans: T[x] = col
                    else:
                        byte = b5[(tilo + tile * 32 + v * 4 + (u >> 1)) & 16383]
                        n = (byte >> 4) if not (u & 1) else (byte & 15)
                        if n == tt: continue
                        T[x] = s.palc(tsel, ((at & 0xF0) | n))
        # sprites
        S = [None] * 320
        c15 = regs.get(0x15, 0)
        if c15 & 1:
            border = c15 & 2
            cl = s.clips[0x19]
            if border:
                if c15 & 0x20: xa, xb, ya, yb = cl[0] * 2, cl[1] * 2 + 1, cl[2], cl[3]
                else: xa, xb, ya, yb = 0, 319, 0, 255
            else:
                xa, xb, ya, yb = cl[0] + 32, cl[1] + 32, cl[2] + 32, cl[3] + 32
            ssel = 2 + ((regs.get(0x43, 0) >> 3) & 1) * 4
            st = regs.get(0x4B, 0xE3)
            if ya <= y <= yb:
                for n in range(128):          # sprite 0 is under 127 (#15 bit 6 clear)
                    a = s.sprattr[n]
                    if not a[3] & 0x80: continue
                    ext = a[3] & 0x40
                    b4 = a[4] if ext else 0
                    if ext and (b4 & 0xC0) == 0x40: continue   # relative sprites: not used
                    xs = 1 << ((b4 >> 3) & 3); ys = 1 << ((b4 >> 1) & 3)
                    sx = a[0] | ((a[2] & 1) << 8)
                    sy = a[1] | ((b4 & 1) << 8 if ext else 0)
                    h = 16 * ys
                    dy = (y - sy) & 511
                    if dy >= h: continue
                    four = ext and (b4 & 0x80)
                    pat = a[3] & 63
                    if four: base = pat * 256 + (128 if b4 & 0x40 else 0)
                    else: base = pat * 256
                    poff = a[2] & 0xF0
                    mx = a[2] & 8; my = a[2] & 4; rot = a[2] & 2
                    v0 = dy // ys
                    for dx in range(16 * xs):
                        X = (sx + dx) & 511
                        if X >= 320 or not (xa <= X <= xb): continue
                        u = dx // xs; v = v0
                        if mx: u = 15 - u
                        if my: v = 15 - v
                        if rot: u, v = v, 15 - u
                        if four:
                            byte = s.pattern[(base + v * 8 + (u >> 1)) & 16383]
                            nib = (byte >> 4) if not (u & 1) else (byte & 15)
                            if nib == (st & 15): continue
                            idx = (poff | nib) & 255
                        else:
                            p = s.pattern[(base + v * 16 + u) & 16383]
                            if p == st: continue
                            idx = (p + poff) & 255
                        S[X] = s.palc(ssel, idx)
        # the order: U = the tilemap over / under the ULA
        if c6b & 1:
            UT = [T[i] if T[i] is not None else U[i] for i in range(320)]
        else:
            UT = [U[i] if U[i] is not None else T[i] for i in range(320)]
        order = (c15 >> 2) & 7
        layers = {0: (S, L2, UT), 1: (L2, S, UT), 2: (S, UT, L2), 3: (L2, UT, S), 4: (UT, S, L2), 5: (UT, L2, S)}.get(order, (S, L2, UT))
        out = []
        for i in range(320):
            c = layers[0][i]
            if c is None:
                c = layers[1][i]
                if c is None:
                    c = layers[2][i]
                    if c is None: c = fallback
            out.append(c)
        return out

    def shot(s, path, scale=2):
        img = s.render()
        if scale != 1: img = img.resize((320 * scale, 256 * scale), Image.NEAREST)
        if path.lower().endswith('.jpg'): img.save(path, quality=92)
        else: img.save(path)
        return img

    def text(s):
        return s.screen()

def build(d, name, files=None):
    g = os.path.dirname(os.path.abspath(d))
    if os.path.exists(os.path.join(g, 'build.js')):
        r = subprocess.run(['node', 'build.js'] + ([os.environ['NTC_SRC']] if os.environ.get('NTC_SRC') else []), cwd=g, capture_output=True, text=True)   # <--- CHANGED (NTC's src folder: NTC_SRC)
        if r.returncode: print(r.stdout, r.stderr); return r.returncode
    r = subprocess.run(['sjasmplus', '--nologo', '--sym=%s.sym' % name, name + '.asm'], cwd=d, capture_output=True, text=True)
    if r.returncode: print(r.stdout, r.stderr)
    return r.returncode

def parse_keys(spec):
    ev = []
    if not spec: return ev
    for part in spec.split(';'):
        fr, ks = part.split(':')
        if '-' in fr: a, b = fr.split('-')
        else: a = b = fr
        ev.append((int(a), int(b), [int(k) for k in ks.split(',') if k]))
    return ev

def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'build':
        d, name = sys.argv[2], sys.argv[3]
        sys.exit(build(d, name))
    if len(sys.argv) > 1 and sys.argv[1] == 'run':
        nex, sym = sys.argv[2], sys.argv[3]
        kw = dict(a.split('=', 1) for a in sys.argv[4:])
        z = NextX(nex, sym)
        ev = parse_keys(kw.get('keys'))
        z.keysheld = lambda f: {k for a, b, ks in ev if a <= f <= b for k in ks}
        out = kw.get('out', 'shot')
        for f in kw.get('shots', '').split(','):
            if f: z.shots[int(f)] = '%s_%s.png' % (out, f)
        every = None
        if 'watch' in kw:
            names = kw['watch'].split(',')
            every = (int(kw.get('every', 50)), lambda z: print(z.frame, ' '.join('%s=%d' % (n, z.var(n)) for n in names)))
        z.run_frames(int(kw.get('frames', 100)), every)
        print('frame', z.frame, 'pc=%04x' % z.m.pc, 'halted' if z.m.halted else '', 'reset' if z.reset else '')

if __name__ == '__main__':
    main()
