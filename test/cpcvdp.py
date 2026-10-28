# CPC + an MSX video card at &FF88 (V9938) or &FF60 (V9990): cpcrun's CPC with a model of the
# card's ports, for cpccard / cpc9990 and the VDP / V9990 classes - scratch tool, not delivered
#   python3 cpcvdp.py prog.asm 'typed' [out.png]  (an assembled program's .asm: cli.js output)
#   prints the card's text (its name table, or the V9990 bit map read back through ntc_font6);
#   with no console on the card, out.png gets the V9990's 256 x 212 bit map
import sys, os, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpcrun
class Card(cpcrun.CPC):
    def __init__(s, *a):
        cpcrun.CPC.__init__(s, *a)
        s.vram = bytearray(0x80000); s.latch = None; s.vaddr = 0; s.vregs = [0]*64; s.cardouts = 0
        s.r9 = [0]*64; s.rsel = 0; s.wa = 0; s.ra = 0
    def out(s, port, val):
        hi = (port >> 8) & 0xff; lo = port & 0xff
        if hi == 0xff and 0x88 <= lo <= 0x8b:
            s.cardouts += 1
            if lo == 0x88: s.vram[s.vaddr & 0x1ffff] = val; s.vaddr += 1
            elif lo == 0x89:
                if s.latch is None: s.latch = val
                else:
                    if val & 0x80: s.vregs[val & 0x3f] = s.latch
                    else: s.vaddr = s.latch | ((val & 0x3f) << 8)
                    s.latch = None
            return
        if hi == 0xff and 0x60 <= lo <= 0x6f:
            s.cardouts += 1; p = lo - 0x60
            if p == 0: s.vram[s.wa & 0x7ffff] = val; s.wa += 1
            elif p == 4: s.rsel = val
            elif p == 3:
                r = s.rsel & 0x3f; s.r9[r] = val
                if not (s.rsel & 0x80): s.rsel = (s.rsel & 0xc0) | ((r + 1) & 0x3f)
                if r == 2: s.wa = s.r9[0] | (s.r9[1] << 8) | ((s.r9[2] & 7) << 16)
                if r == 52: s.cmd(val >> 4)
            return
        cpcrun.CPC.out(s, port, val)
    def inp(s, port):
        hi = (port >> 8) & 0xff; lo = port & 0xff
        if hi == 0xff and lo == 0x88:
            v = s.vram[s.vaddr & 0x1ffff]; s.vaddr += 1; s.latch = None; return v
        if hi == 0xff and lo == 0x89: s.latch = None; return 0
        if hi == 0xff and 0x60 <= lo <= 0x6f: return 0
        return cpcrun.CPC.inp(s, port)
    def width(s): return 512 if (s.r9[6] >> 2) & 3 == 1 else 256
    def px(s, x, y):
        w = s.width(); a = (y * w + x) >> 1; b = s.vram[a]
        return (b >> 4) if not (x & 1) else (b & 15)
    def setpx(s, x, y, c):
        w = s.width(); a = (y * w + x) >> 1
        s.vram[a] = (s.vram[a] & 0x0f) | (c << 4) if not (x & 1) else (s.vram[a] & 0xf0) | c
    def cmd(s, op):
        R = s.r9; g = lambda n: R[n] | (R[n + 1] << 8)
        sx, sy, dx, dy, nx, ny = g(32), g(34), g(36), g(38), g(40), g(42)
        if op == 2:
            c = R[48] & 15
            for y in range(dy, dy + ny):
                for x in range(dx, dx + nx): s.setpx(x, y, c)
        elif op == 4:
            for j in range(ny):
                for i in range(nx): s.setpx(dx + i, dy + j, s.px(sx + i, sy + j))
    def text(s, font6):
        cols = s.m.memory[s.syms['ntc_scols']]; out = []
        if s.r9[6]:
            w = s.width(); m0 = 4 if w == 256 else 8; paper = s.m.memory[s.syms['ntc_v9fg']] & 15
            for r in range(24):
                line = ''
                for c in range(cols):
                    pat = []
                    for y in range(8):
                        v = 0
                        for i in range(6):
                            if s.px(m0 * 2 + c * 6 + i, 10 + r * 8 + y) != paper: v |= 0x80 >> i
                        pat.append(v)
                    line += font6.get(tuple(pat), '#')
                out.append(line.rstrip())
        else:
            for r in range(24):
                out.append(bytes(s.vram[r * cols:(r + 1) * cols]).decode('latin1').rstrip())
        while out and not out[-1]: out.pop()
        return '\n'.join(out)
if __name__ == '__main__':
    asm = sys.argv[1]; typed = (sys.argv[2] if len(sys.argv) > 2 else '').replace('\\n', '\r')
    b, syms = cpcrun.assemble(asm)
    c = Card(b, syms.get('ntc_start', 0x4000), typed, syms); c.run(4000)
    if 'ntc_font6' not in syms:
        from PIL import Image
        im = Image.new('P', (256, 212)); pal = [0,0,0, 0,0,0, 36,219,36, 109,255,109, 36,36,255, 73,109,255, 182,36,36, 73,219,255, 255,36,36, 255,109,109, 219,219,36, 219,219,146, 36,146,36, 219,73,182, 182,182,182, 255,255,255]
        im.putpalette(pal + [0] * (768 - len(pal)))
        for y in range(212):
            for x in range(256):
                b = c.vram[y * 128 + (x >> 1)]; im.putpixel((x, y), (b >> 4) if not (x & 1) else (b & 15))
        im.save(sys.argv[3]); print('saved', sys.argv[3], 'card outs', c.cardouts, 'halted', c.m.halted); sys.exit(0)
    f = syms['ntc_font6']; font6 = {}
    for ch in range(32, 127): font6[tuple(c.m.memory[f + (ch - 32) * 8 + i] & 0xFC for i in range(8))] = chr(ch)
    print(c.text(font6))
    print('--- halted' if c.m.halted else '--- NOT halted', 'card outs', c.cardouts, 'regs', c.vregs[:10] if not c.r9[6] else c.r9[:16])
