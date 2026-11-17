# nextemu.py - an emulated ZX Spectrum Next for testing NTC BASIC games: NTC's zxnrun.py (the
# Z80, the MMU, NextRegs, sprites, palettes) run a frame at a time, keys held from Python, and
# pictures of what the Next shows: Layer 2 (256 x 192, its scroll), the tilemap (40 x 32, 4 bit,
# with or without attribute bytes) and the sprites (8 bit and 4 bit, mirrors, rotation, scale),
# in the layer order NextReg #15 asks for. Test tool only (needs the z80 module, numpy, Pillow).
# (c) 2026 Cyborg Unicorn Pty Ltd
import os, sys, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np
import zxnrun, cpcrun

ROWS = zxnrun.ROWS
KEYPOS = {}
for r, keys in enumerate(ROWS):
    for b, k in enumerate(keys): KEYPOS[k] = (r, b)
KEYPOS['enter'] = KEYPOS['\r']; KEYPOS['space'] = KEYPOS[' ']

def syms_of(symfile):
    d = {}
    for line in open(symfile):
        m = re.match(r'^(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)', line)
        if m: d[m.group(1)] = int(m.group(2), 16)
    return d

class Emu(zxnrun.Next):
    def __init__(s, nex, sym=None):
        syms = syms_of(sym) if sym and os.path.exists(sym) else {}
        zxnrun.Next.__init__(s, nex, '', syms)
        s.held = set(); s.joy = 0; s.frames = 0
    def inp(s, port):
        if (port & 0xFF) == 0xFE:
            hi = port >> 8; v = 0xFF
            for k in s.held:
                r, b = KEYPOS[k]
                if not hi & (1 << r): v &= ~(1 << b)
            return v & 0xFF
        if (port & 0xFF) == 0x1F: return s.joy
        if (port & 0xFF) == 0x37: return 0
        if port == 0x253B: return s.nreg_read(s.sel)
        return 0xFF
    def frame(s, n=1):
        # one frame = the frame's T (28MHz: 559104); the interrupts taken at their times when on
        for _ in range(n):
            end = s.T + s.frame_t() - s.tframe
            while s.T < end and not s.m.halted and not s.reset:
                ev = s.next_event()
                q = max(1, min(ev, s.frame_t()) - s.tframe)
                s.stop = False; left = q
                while left > 0 and not (s.stop or s.m.halted or s.reset):
                    s.q = left; s.m.ticks_to_stop = left; cpcrun.endkey_run(s); s.q = 0
                    d = (s.stopdone + 1) if s.stop else (left - s.m.ticks_to_stop)
                    s.T += d; s.tframe += d; left -= d
                if s.stop: continue
                if s.tframe >= ev or s.tframe >= s.frame_t():
                    steps = 0
                    while steps < 64 and not s.m.halted:
                        if s.m.iff1 and s.m.on_handle_active_int(): s.ints += 1; break
                        s.q = 1; d = cpcrun.step1(s); steps += 1; s.q = 0; s.T += d; s.tframe += d
                while s.tframe >= s.frame_t(): s.tframe -= s.frame_t()
            s.frames += 1
        return s
    def press(s, keys, frames=3, after=3):
        s.held = set(keys if isinstance(keys, (list, tuple, set)) else [keys]); s.frame(frames)
        s.held = set(); s.frame(after)
    def mem(s):
        for k in range(8): s.store(k)
        return bytes(s.m.memory)
    def peekw(s, name):
        m = s.mem(); ks = [k for k in s.syms if k == name or k.endswith('_' + name)]
        if not ks: return None
        a = s.syms[ks[0]]; v = m[a] | m[a + 1] << 8
        return v - 65536 if v > 32767 else v
    def pokew(s, name, v):
        ks = [k for k in s.syms if k == name or k.endswith('_' + name)]
        a = s.syms[ks[0]]; v &= 0xFFFF
        for k in range(8): s.store(k)
        s.m.set_memory_block(a, bytes([v & 255, v >> 8]))
        # (the page under that address keeps it too)
        sl = a // 0x2000; p = s.mmu[sl]
        if p is not None and p != 255: s.pages[p][a % 0x2000] = v & 255; s.pages[p][(a + 1) % 0x2000] = v >> 8
    def rgb(s, g, i, default=None):
        v = s.palette.get((g, i))
        if v is None: return default if default is not None else (i & 0xE0, (i << 3) & 0xE0, (i << 6) & 0xC0)
        return s.rgb9(g, i, v)
    def picture(s, path=None, scale=2, crop=True):
        from PIL import Image
        for k in range(8): s.store(k)
        W, H = 320, 256
        # Layer 2 (256 x 192 at 32, 32)
        L = np.zeros((H, W, 3), np.uint8); La = np.zeros((H, W), bool)
        if s.regs.get(0x69, 0) & 0x80 or True:
            b = s.regs.get(0x12, 8)
            data = np.frombuffer(b''.join(bytes(s.page(p)) for p in range(2 * b, 2 * b + 6)), np.uint8).reshape(192, 256)
            cl = s.copper_lines()
            sy = s.regs.get(0x17, 0)
            data = np.roll(data, -(sy % 192), axis=0).copy()
            for y in range(192): data[y] = np.roll(data[y], -cl[y].get(0x16, 0))
            pal = np.array([s.rgb(1, i) for i in range(256)], np.uint8)
            gt = s.regs.get(0x14, 0xE3)
            raw = np.array([s.palette.get((1, i), i) for i in range(256)])
            vis = raw[data] != gt
            c = getattr(s, 'l2clip', [0, 255, 0, 191])
            clipm = np.zeros((192, 256), bool); clipm[c[2]:c[3] + 1, c[0]:c[1] + 1] = True
            L[32:224, 32:288] = pal[data]; La[32:224, 32:288] = vis & clipm & bool(s.l2on)
        # the tilemap
        U = np.zeros((H, W, 3), np.uint8); Ua = np.zeros((H, W), bool)
        c6b = s.regs.get(0x6B, 0)
        if c6b & 0x80:
            b5 = s.bank5()
            mapo = (s.regs.get(0x6E, 0x6C) & 63) << 8; tilo = (s.regs.get(0x6F, 0x4C) & 63) << 8
            attr = not (c6b & 0x20); cols = 80 if c6b & 0x40 else 40
            tp = s.regs.get(0x4C, 0x0F) & 15; defa = s.regs.get(0x6C, 0)
            tpal = np.array([s.rgb(3, i) for i in range(256)], np.uint8)
            if cols == 40:
                for r in range(32):
                    for c in range(40):
                        o = mapo + (r * 40 + c) * (2 if attr else 1)
                        t = b5[o]; a = b5[o + 1] if attr else defa
                        po = a & 0xF0
                        tb = tilo + t * 32
                        if tb + 32 > len(b5): continue
                        cell = np.frombuffer(bytes(b5[tb:tb + 32]), np.uint8)
                        px = np.empty(64, np.uint8); px[0::2] = cell >> 4; px[1::2] = cell & 15
                        px = px.reshape(8, 8)
                        if a & 8: px = px[:, ::-1]
                        if a & 4: px = px[::-1, :]
                        if a & 2: px = px.T[:, ::-1]
                        U[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = tpal[(px | po) & 255]
                        Ua[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = px != tp
            cl = s.copper_lines()
            y = s.regs.get(0x31, 0)
            U = np.roll(U, -y, 0); Ua = np.roll(Ua, -y, 0)
            U2 = U.copy(); Ua2 = Ua.copy()
            last = cl[-1]
            for Y in range(256):
                rg = cl[Y - 32] if 32 <= Y < 224 else last
                x = ((rg.get(0x2F, 0) & 3) << 8 | rg.get(0x30, 0)) % 320
                if x: U2[Y] = np.roll(U[Y], -x, 0); Ua2[Y] = np.roll(Ua[Y], -x)
            U, Ua = U2, Ua2
            tc = getattr(s, 'tmclip', [0, 159, 0, 255])
            Ua[:, :tc[0] * 2] = False; Ua[:, tc[1] * 2 + 2:] = False; Ua[:tc[2], :] = False; Ua[tc[3] + 1:, :] = False
        # the sprites
        S = np.zeros((H, W, 3), np.uint8); Sa = np.zeros((H, W), bool)
        if s.regs.get(0x15, 0) & 1:
            spal = np.array([s.rgb(2, i) for i in range(256)], np.uint8)
            tr = s.regs.get(0x4B, 0xE3)
            pat = np.frombuffer(bytes(s.spat), np.uint8)
            for n in range(127, -1, -1):
                a = s.sattr[n]
                if not a[3] & 0x80: continue
                ext = a[3] & 0x40
                sx = a[0] | ((a[2] & 1) << 8); sy = a[1] | ((a[4] & 1) << 8 if ext else 0)
                four = ext and (a[4] & 0x80)
                po = a[2] & 0xF0
                if four:
                    base = (a[3] & 63) * 256 + (128 if a[4] & 0x40 else 0)
                    c = pat[base:base + 128]
                    px = np.empty(256, np.uint8); px[0::2] = c >> 4; px[1::2] = c & 15
                    px = px.reshape(16, 16); trans = px == (tr & 15); idx = (px | po) & 255
                else:
                    base = (a[3] & 63) * 256
                    px = pat[base:base + 256].reshape(16, 16); trans = px == tr; idx = (px.astype(int) + po) & 255
                img = spal[idx]
                if a[2] & 2: img = np.rot90(img, -1); trans = np.rot90(trans, -1)
                if a[2] & 8: img = img[:, ::-1]; trans = trans[:, ::-1]
                if a[2] & 4: img = img[::-1]; trans = trans[::-1]
                kx = 1 << ((a[4] >> 3) & 3) if ext else 1; ky = 1 << ((a[4] >> 1) & 3) if ext else 1
                if kx > 1 or ky > 1:
                    img = np.repeat(np.repeat(img, ky, 0), kx, 1); trans = np.repeat(np.repeat(trans, ky, 0), kx, 1)
                h, w = trans.shape
                for yy in range(h):
                    Y = (sy + yy) & 511
                    if Y >= H: continue
                    for xx in range(w):
                        X = (sx + xx) & 511
                        if X >= W or trans[yy, xx]: continue
                        S[Y, X] = img[yy, xx]; Sa[Y, X] = True
        order = (s.regs.get(0x15, 0) >> 2) & 7
        orders = ['SLU', 'LSU', 'SUL', 'LUS', 'USL', 'ULS', 'SLU', 'SLU']
        v4a = s.regs.get(0x4A, 0)
        fb = (((v4a >> 5) & 7) * 255 // 7, ((v4a >> 2) & 7) * 255 // 7, ((((v4a & 3) << 1) | ((v4a | (v4a >> 1)) & 1)) * 255 // 7))
        out = np.zeros((H, W, 3), np.uint8); out[:] = fb
        lay = {'S': (S, Sa), 'L': (L, La), 'U': (U, Ua)}
        for ch in reversed(orders[order]):
            im, al = lay[ch]; out[al] = im[al]
        img = Image.fromarray(out)
        if crop: img = img.crop((32, 32, 288, 224))
        if scale != 1: img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        if path: img.save(path)
        return img
    def nreg_write(s, r, v):
        if r == 0x60:
            if not hasattr(s, 'cop'): s.cop = bytearray(2048); s.copi = 0
            s.cop[s.copi & 2047] = v; s.copi = (s.copi + 1) & 2047
        elif r == 0x61:
            s.copi = (getattr(s, 'copi', 0) & 0x700) | v
        elif r == 0x62:
            s.copi = (getattr(s, 'copi', 0) & 0xFF) | ((v & 7) << 8)
        elif r == 0x1C:
            if v & 1: s.l2ci = 0
            if v & 2: s.sci = 0
            if v & 8: s.tci = 0
        elif r == 0x1B:
            c = getattr(s, 'tmclip', [0, 159, 0, 255]); i = getattr(s, 'tci', 0)
            c[i & 3] = v; s.tmclip = c; s.tci = (i + 1) & 3
        elif r == 0x18:
            c = getattr(s, 'l2clip', [0, 255, 0, 191]); i = getattr(s, 'l2ci', 0)
            c[i & 3] = v; s.l2clip = c; s.l2ci = (i + 1) & 3
        zxnrun.Next.nreg_write(s, r, v)
    def copper_lines(s):
        """per paper line (0-191): the values of the registers the copper moves"""
        regs = dict(s.regs); lines = []
        cop = getattr(s, 'cop', None)
        prog = []
        if cop is not None and (s.regs.get(0x62, 0) & 0xC0):
            for k in range(0, 2048, 2):
                b0, b1 = cop[k], cop[k + 1]
                if b0 == 0xFF and b1 == 0xFF: break
                if b0 & 0x80: prog.append(('w', ((b0 & 1) << 8) | b1))
                else: prog.append(('m', b0 & 0x7F, b1))
        pi = 0
        for y in range(192):
            while pi < len(prog):
                p = prog[pi]
                if p[0] == 'w':
                    if p[1] > y: break
                    pi += 1
                else:
                    if p[1]: regs[p[1]] = p[2]
                    pi += 1
            lines.append(dict(regs))
        return lines
    def out(s, port, val):
        if port == 0x123B: s.l2port = val
        zxnrun.Next.out(s, port, val)
    @property
    def l2on(s):
        return (getattr(s, 'l2port', 0) & 2) or (s.regs.get(0x69, 0) & 0x80)
