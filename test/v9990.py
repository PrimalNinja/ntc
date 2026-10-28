# v9990.py - a model of the Yamaha V9990 (E-VDP-III: the MSX's GFX9000 / Video9000 at #60-#6F, the
# CPC's Powergraph or an MSX card through AMSDAP at &FF60-&FF6F) for NTC's harnesses (msxrun.py,
# ntcrun.py): its 16 ports, its registers (P#4's select, auto increment unless WII / RII), VRAM
# (512K, written and read through P#0 at R#0-2 / R#3-5, the addresses moving on unless AII),
# the palette (R#14's pointer, three 5-bit parts an entry, P#1), the status (P#5: CE never set -
# a command runs at once) and the block commands that matter for text and boxes: LMMV, LMMM, LMMC
# (P#2's data), PSET, with the logical operations (R#45: L00-L11, TP) and the write mask. VRAM is
# its logical address space: in a bit map mode line y starts at y * (image width * bits a pixel / 8).
# The picture: the bit map modes (R#6's DSPM 2), the image width (XIMM) and bits a pixel (CLRM),
# 212 lines shown from the vertical scroll (R#17 / R#18: SCAY, rolled at 256 / 512 lines or the
# image's height) - pixels() gives palette numbers, ocr() reads text off it.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, re

def font6():
    # NTC's ntc_font6 (asm/ntc_lib_vdp.asm): characters 32-126, 8 bytes each, the left 6 pixels
    here = os.path.dirname(os.path.abspath(__file__))
    txt = open(os.path.join(here, '..', 'src', 'asm', 'ntc_lib_vdp.asm')).read()
    txt = txt[txt.index('\nntc_font6:'):]
    out = []
    for line in txt.split('\n')[2:]:
        m = re.match(r'\s*db\s+(.*?)\s*;', line)
        if not m: break
        out += [int(x.strip().replace('#', ''), 16) for x in m.group(1).split(',')]
    return bytes(out)

class V9990:
    def __init__(s):
        s.vram = bytearray(0x80000); s.r = [0] * 64; s.sel = 0
        s.pal = [[0, 0, 0] for _ in range(64)]; s.wa = 0; s.ra = 0; s.flags = 0; s.mcs = 0
        s.lmmc = None; s.outs = 0
    # ---- the ports (p = 0-15)
    def out(s, p, v):
        s.outs += 1
        if p == 0:
            s.vram[s.wa & 0x7FFFF] = v
            if not (s.r[2] & 0x80): s.wa = (s.wa + 1) & 0x7FFFF
        elif p == 1:
            i = s.r[14] >> 2; c = s.r[14] & 3
            if c < 3: s.pal[i][c] = v & (0x9F if c == 0 else 0x1F)
            c += 1
            if c >= 3: i = (i + 1) & 63; c = 0
            s.r[14] = (i << 2) | c
        elif p == 2:
            if s.lmmc is not None: s.lmmc_data(v)
        elif p == 3:
            n = s.sel & 63; s.r[n] = v
            if not (s.sel & 0x80): s.sel = (s.sel & 0xC0) | ((n + 1) & 63)
            if n <= 2: s.wa = s.r[0] | (s.r[1] << 8) | ((s.r[2] & 7) << 16)
            elif n <= 5: s.ra = s.r[3] | (s.r[4] << 8) | ((s.r[5] & 7) << 16)
            elif n == 52: s.command(v)
        elif p == 4: s.sel = v
        elif p == 6: s.flags &= ~v
        elif p == 7:
            s.mcs = v & 1
            if v & 2: s.r = [0] * 64; s.sel = 0; s.lmmc = None
    def inp(s, p):
        if p == 0:
            v = s.vram[s.ra & 0x7FFFF]
            if not (s.r[5] & 0x80): s.ra = (s.ra + 1) & 0x7FFFF
            return v
        if p == 1:
            i = s.r[14] >> 2; c = s.r[14] & 3
            return s.pal[i][c] if c < 3 else 0
        if p == 3:
            n = s.sel & 63; v = s.r[n]
            if not (s.sel & 0x40): s.sel = (s.sel & 0xC0) | ((n + 1) & 63)
            return v
        if p == 5: return 0x80 * (s.lmmc is not None) | (s.mcs << 2)
        if p == 6: return s.flags
        return 0xFF
    # ---- the bit map
    def bpp(s): return (2, 4, 8, 16)[s.r[6] & 3]
    def iwidth(s): return 256 << ((s.r[6] >> 2) & 3)
    def lbytes(s): return s.iwidth() * s.bpp() // 8
    def getpx(s, x, y):
        b = s.bpp(); w = s.iwidth(); x &= w - 1; a = y * s.lbytes()
        if b == 4:
            v = s.vram[(a + (x >> 1)) & 0x7FFFF]; return (v >> 4) if not (x & 1) else (v & 15)
        if b == 8: return s.vram[(a + x) & 0x7FFFF]
        if b == 2:
            v = s.vram[(a + (x >> 2)) & 0x7FFFF]; return (v >> (6 - 2 * (x & 3))) & 3
        o = (a + 2 * x) & 0x7FFFF; return s.vram[o] | (s.vram[o + 1] << 8)
    def setpx(s, x, y, c):
        b = s.bpp(); w = s.iwidth(); x &= w - 1; a = y * s.lbytes()
        if b == 4:
            o = (a + (x >> 1)) & 0x7FFFF; v = s.vram[o]
            s.vram[o] = ((v & 0x0F) | ((c & 15) << 4)) if not (x & 1) else ((v & 0xF0) | (c & 15))
        elif b == 8: s.vram[(a + x) & 0x7FFFF] = c & 255
        elif b == 2:
            o = (a + (x >> 2)) & 0x7FFFF; sh = 6 - 2 * (x & 3); s.vram[o] = (s.vram[o] & ~(3 << sh) & 255) | ((c & 3) << sh)
        else:
            o = (a + 2 * x) & 0x7FFFF; s.vram[o] = c & 255; s.vram[o + 1] = (c >> 8) & 255
    def lop(s, sc, dc):
        # R#45: TP (bit 4: a source of 0 leaves the pixel), L11 L10 L01 L00 for each bit of the pixel
        l = s.r[45]
        if (l & 0x10) and sc == 0: return dc
        out = 0
        for bit in range(s.bpp()):
            k = (((sc >> bit) & 1) << 1) | ((dc >> bit) & 1)
            out |= ((l >> k) & 1) << bit
        return out
    def put(s, x, y, sc):
        s.setpx(x, y, s.lop(sc, s.getpx(x, y)))
    def fcpx(s, x):
        # FC's pixel for column x: 4 bits a pixel - the high nibble for an even x, the low for an odd
        fc = s.r[48] | (s.r[49] << 8); b = s.bpp()
        if b == 4: return (fc >> 4) & 15 if not (x & 1) else fc & 15
        if b == 8: return fc & 255
        if b == 2: return (fc >> (6 - 2 * (x & 3))) & 3
        return fc
    def command(s, op):
        R = s.r; w = lambda n: R[n] | (R[n + 1] << 8)
        sx, sy, dx, dy = w(32) & 2047, w(34) & 4095, w(36) & 2047, w(38) & 4095
        nx, ny = w(40) & 2047, w(42) & 4095
        nx = nx or 2048; ny = ny or 4096
        ix = -1 if R[44] & 4 else 1; iy = -1 if R[44] & 8 else 1
        o = op >> 4
        if o == 2:      # LMMV
            for j in range(ny):
                for i in range(nx): x = dx + i * ix; s.put(x, dy + j * iy, s.fcpx(x))
        elif o == 4:    # LMMM
            src = [[s.getpx(sx + i * ix, sy + j * iy) for i in range(nx)] for j in range(ny)]
            for j in range(ny):
                for i in range(nx): s.put(dx + i * ix, dy + j * iy, src[j][i])
        elif o == 1:    # LMMC: the pixels to come through P#2
            s.lmmc = [dx, dy, nx, ny, 0, 0, ix, iy]
        elif o == 14:   # PSET
            s.put(dx, dy, s.fcpx(dx))
    def lmmc_data(s, v):
        dx, dy, nx, ny, i, j, ix, iy = s.lmmc; b = s.bpp(); per = 8 // b if b < 8 else 1
        for k in range(per):
            px = (v >> (8 - b * (k + 1))) & ((1 << b) - 1) if b < 8 else v
            s.put(dx + i * ix, dy + j * iy, px); i += 1
            if i >= nx:
                i = 0; j += 1
                if j >= ny: s.lmmc = None; return
        s.lmmc = [dx, dy, nx, ny, i, j, ix, iy]
    # ---- the picture
    def shown(s): return (s.r[6] >> 6) == 2 and (s.r[8] & 0x80)
    def width(s): return 256 << ((s.r[6] >> 4) & 3)      # DCKM: 0 B1 256, 1 B3 512
    def scay(s): return s.r[17] | ((s.r[18] & 31) << 8)
    def roll(s):
        if s.r[18] & 0x80: return 512
        if s.r[18] & 0x40: return 256
        return 0x80000 // s.lbytes()
    def line(s, y):
        # the image's line shown at screen line y
        return (s.scay() + y) % s.roll()
    def pixels(s, lines=212):
        return [[s.getpx(x, s.line(y)) for x in range(s.width())] for y in range(lines)]
    def ocr(s, font=None, cw=6, ch=8, x0=None, rows=None):
        # the text on the screen: each cell's pixels (not the backdrop's colour: the paper is the
        # most common one) against the font's characters (32-126, a byte a line, the left cw bits);
        # x0 None: the cells' offset the one that reads best, the blank cells all lines start with
        # left out
        font = font or font6()
        px = s.pixels()
        from collections import Counter
        paper = Counter(v for row in px for v in row).most_common(1)[0][0]
        glyphs = {}
        for c in range(95):
            key = tuple((font[c * 8 + l] >> (8 - cw)) & ((1 << cw) - 1) for l in range(ch))
            glyphs.setdefault(key, chr(32 + c))
        rows = rows or len(px) // ch
        best = None
        for xo in ([x0] if x0 is not None else range(cw)):
            out = []; bad = 0
            for r in range(rows):
                t = ''
                for c in range((len(px[0]) - xo) // cw):
                    key = tuple(sum((1 << (cw - 1 - i)) for i in range(cw) if px[r * ch + l][xo + c * cw + i] != paper) for l in range(ch))
                    g = glyphs.get(key)
                    if g is None: g = '?'; bad += 1
                    t += g
                out.append(t.rstrip())
            if best is None or bad < best[0]: best = (bad, out)
        out = best[1]
        while out and not out[-1]: out.pop()
        if x0 is None:
            # (the left margin found: as many blank cells as every line starts with)
            lead = min([len(l) - len(l.lstrip(' ')) for l in out if l.strip()] or [0])
            out = [l[lead:] for l in out]
        return '\n'.join(out)
