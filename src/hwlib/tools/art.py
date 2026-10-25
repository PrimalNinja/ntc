# art.py - the test programs' art: a bouncing ball (4 frames, a stripe rolling round it) and an
# 8 x 8 font, made into each chip's own format and written as NTC BASIC data classes
# (tests/<target>/Art.cls): a Function per table giving its address (asm keyword procedures).
# Also writes build/art_<format>.png previews.
#   python3 tools/art.py
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, math
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
FONT = os.path.join(HERE, 'font8x8.txt')      # font8x8_basic by Daniel Hepper (public domain)
FRAMES = 4

# ---- the ball, as shade numbers: 0 outside, 1-6 the sphere dark to light, 7 the shine,
#      8-10 the stripe dark to light
def ball(f, thr=0.35, w=16):
    # w: the width in pixels (8 for the CPC's mode 0, whose pixels are twice as wide as high)
    g = [[0] * w for _ in range(16)]
    ang = f * math.pi / FRAMES                # the stripe turns a quarter of a half turn a frame
    for y in range(16):
        for x in range(w):
            dx, dy = (x - (w - 1) / 2) * 16 / w, y - 7.5
            r = math.hypot(dx, dy)
            if r > 7.6:
                continue
            nz = math.sqrt(max(0.0, 7.6 * 7.6 - r * r)) / 7.6
            nx, ny = dx / 7.6, dy / 7.6
            light = max(0.0, -0.55 * nx - 0.6 * ny + 0.6 * nz)
            # the stripe: a band across the ball, rolling (its offset moves with the frame)
            u = nx * math.cos(ang) + ny * math.sin(ang)
            band = math.sin((u * 2.2 + f * 0.5) * math.pi)
            if (nx - 0.35) ** 2 + (ny + 0.4) ** 2 < 0.045:
                v = 7
            elif band > thr:
                v = 8 + min(2, int(light * 3))
            else:
                v = 1 + min(5, int(light * 6))
            g[y][x] = v
    return g

BALLS = [ball(f) for f in range(FRAMES)]
NARROW = [ball(f, w=8) for f in range(FRAMES)]  # (mode 0)
def thin(f):
    # the 1 bit chips: the ball solid but for one gap line rolling across it (2 = on, 0 = off)
    g = [[0] * 16 for _ in range(16)]
    off = -0.6 + f * 0.4
    for y in range(16):
        for x in range(16):
            nx, ny = (x - 7.5) / 7.6, (y - 7.5) / 7.6
            if nx * nx + ny * ny <= 1.0 and abs((nx + ny * 0.5) - off) > 0.13:
                g[y][x] = 2
    return g
THIN = [thin(f) for f in range(FRAMES)]

def font():
    out = []
    for l in open(FONT):
        l = l.split(';')[0].split()
        if len(l) == 8:
            out.append([int(b, 16) for b in l])
    assert len(out) == 95, len(out)
    return out

# ---- the formats
def zxn8():
    # 8 bit RGB332 per pixel, #E3 transparent (the Next's default sprite palette is RGB332)
    def rgb332(r, g, b): return (r & 0xE0) | ((g >> 3) & 0x1C) | (b >> 6)
    pal = {0: 0xE3}
    shades = [(60, 0, 0), (100, 0, 20), (150, 20, 30), (200, 40, 40), (230, 80, 60), (255, 130, 100)]
    for i, c in enumerate(shades): pal[1 + i] = rgb332(*c)
    pal[7] = rgb332(255, 255, 255)
    for i, c in enumerate([(160, 160, 0), (220, 220, 0), (255, 255, 120)]): pal[8 + i] = rgb332(*c)
    return [[pal[v] for row in b for v in row] for b in BALLS]

def cpc0():
    # mode 0: 2 pixels a byte, each twice as wide as high - so the ball is 8 pixels wide, 16 high.
    # Pens: 0 paper (see-through), 1 the text (white), 2-11 the ball's shades 1-10. Each frame
    # twice: on an even pixel and an odd one (shifted one pixel right), 5 bytes wide, 16 rows;
    # each byte a pair: the mask (1 bits keep the screen), then the data. Frame f, shift s at
    # (f * 2 + s) * 160
    def enc(p0, p1):
        # bit7 p0.b0, bit6 p1.b0, bit5 p0.b2, bit4 p1.b2, bit3 p0.b1, bit2 p1.b1, bit1 p0.b3, bit0 p1.b3
        b = ((p0 >> 0) & 1) << 7 | ((p1 >> 0) & 1) << 6 | ((p0 >> 2) & 1) << 5 | ((p1 >> 2) & 1) << 4
        b |= ((p0 >> 1) & 1) << 3 | ((p1 >> 1) & 1) << 2 | ((p0 >> 3) & 1) << 1 | ((p1 >> 3) & 1)
        return b
    out = []
    for bl in NARROW:
        for sh in (0, 1):
            d = []
            for row in bl:
                px = [0] * sh + [(v + 1 if v else 0) for v in row] + [0] * (2 - sh)
                for x in range(0, 10, 2):
                    p0, p1 = px[x], px[x + 1]
                    d += [enc(15 if p0 == 0 else 0, 15 if p1 == 0 else 0), enc(p0, p1)]
            out.append(d)
    return out

# the CPC's pens 0-15 as hardware colour numbers (the gate array's: 4 blue, 11 bright white,
# 28 red, 12 bright red, 14 orange, 7 pink, 30 yellow, 10 bright yellow, 3 pastel yellow)
CPC_INKS = [4, 11, 28, 28, 12, 12, 14, 7, 11, 30, 10, 3, 4, 4, 4, 4]

def asic():
    # 1 byte a pixel, the low 4 bits the colour (0 transparent); the palette 15 words #0GRB
    pix = [[v for row in b for v in row] for b in BALLS]
    pal = [(4, 0, 0), (7, 0, 1), (10, 1, 2), (13, 2, 2), (15, 5, 4), (15, 8, 6), (15, 15, 15),
           (10, 10, 0), (14, 14, 0), (15, 15, 8), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0)]
    words = []
    for r, g, b in pal:
        words += [(r << 4) | b, g]            # the ASIC's order: red and blue, then green
    return pix, words

def onebit(b):
    # 16 x 16 1 bit, as the TMS9918 wants it: top left 8 rows, bottom left, top right, bottom right.
    # On: the sphere; off: outside and the stripe (so the stripe shows as a rolling gap)
    def on(x, y): return 1 if (b[y][x] != 0 and b[y][x] < 8) else 0
    out = []
    for (x0, y0) in [(0, 0), (0, 8), (8, 0), (8, 8)]:
        for y in range(y0, y0 + 8):
            v = 0
            for x in range(x0, x0 + 8):
                v = (v << 1) | on(x, y)
            out.append(v)
    return out

def tms():
    return [onebit(b) for b in THIN]

def v9938():
    # sprite mode 2: the same patterns, and a colour a line (palette 8-13, set as a ramp by the test, top light)
    lines = [13, 13, 12, 12, 12, 11, 11, 11, 10, 10, 10, 9, 9, 9, 8, 8]
    return [onebit(b) for b in THIN], lines

def v9990():
    # P1 sprites: 4 bits a pixel, 16 x 16 -> 128 bytes (2 pixels a byte, the left one high)
    out = []
    for bl in BALLS:
        d = []
        for row in bl:
            for x in range(0, 16, 2):
                d.append((row[x] << 4) | row[x + 1])
        out.append(d)
    return out


# the cube tests' extras
# the CPC: pen 0 black, 1 bright white, 2-7: blue, bright blue, sky blue, pastel blue, pastel cyan, bright white
CUBE_INKS = [20, 11, 4, 21, 23, 31, 27, 11, 20, 20, 20, 20, 20, 20, 20, 20]
# the CPC Plus: 14 shades for pens 2-15, dark blue to near white (4 bits each: r, g, b)
def _cube_pal():
    out = [0x00, 0x00, 0xFF, 0x0F]                  # pen 0 black, pen 1 white
    for i in range(14):
        t = i / 13
        r = int(round(t * t * 14)); g = int(round(t * 13)); b = int(round(4 + t * 11))
        out += [(r << 4) | b, g]
    return out
CUBE_PAL = _cube_pal()
# the TMS9918's shading: 4 x 4 ordered dither, 8 levels (1/16 .. 16/16), each 4 lines of a byte
def _dither():
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    out = []
    for lv in [2, 4, 6, 8, 10, 12, 14, 16]:
        for y in range(4):
            b = 0
            for x in range(8):
                b = (b << 1) | (1 if bayer[y][x & 3] < lv else 0)
            out.append(b)
    return out
DITHER = _dither()

# ---- writing NTC BASIC
def dbs(label, data, per=16):
    lines = [label + ':']
    for i in range(0, len(data), per):
        lines.append('            db ' + ', '.join('#%02X' % b for b in data[i:i + per]))
    return lines

def fn(name, label, data, comment):
    l = ["' " + comment, 'Public Function %s() As Integer' % name, '#asm',
         '            pop hl              ; the result: the table\'s address',
         '            ld de, %s' % label, '            ld (hl), e', '            inc hl', '            ld (hl), d',
         '            ret                 ; (on along the thread; the table after it is never run)']
    l += dbs(label, data)
    l += ['#endasm', 'End Function', '']
    return l

def write(target, title, parts):
    d = os.path.join(ROOT, 'tests', target)
    os.makedirs(d, exist_ok=True)
    out = ["' Art - %s: the test's ball (4 frames) and what else it needs, made by tools/art.py" % title,
           "' (don't edit: run the tool). (c) 2026 Cyborg Unicorn Pty Ltd", 'Option Explicit', '']
    for p in parts:
        out += fn(*p)
    open(os.path.join(d, 'Art.cls'), 'w').write('\n'.join(out))
    print(target, 'Art.cls', sum(len(p[2]) for p in parts), 'bytes')

def preview():
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    cols = {0: (0, 0, 0), 1: (60, 0, 0), 2: (100, 0, 20), 3: (150, 20, 30), 4: (200, 40, 40), 5: (230, 80, 60),
            6: (255, 130, 100), 7: (255, 255, 255), 8: (160, 160, 0), 9: (220, 220, 0), 10: (255, 255, 120)}
    im = Image.new('RGB', (16 * FRAMES, 16))
    for f, b in enumerate(BALLS):
        for y in range(16):
            for x in range(16):
                im.putpixel((f * 16 + x, y), cols[b[y][x]])
    im.resize((16 * FRAMES * 8, 128), Image.NEAREST).save(os.path.join(ROOT, 'build', 'art_ball.png'))

if __name__ == '__main__':
    F = [b for ch in font() for b in ch]
    z = zxn8()
    write('next', 'ZX Spectrum Next (Zxn)', [('Ball', 'art_ball', [b for fr in z for b in fr], 'the ball: 4 frames of 16 x 16, 8 bit (RGB332, #E3 see-through)')])
    c = cpc0()
    write('cpc', 'Amstrad CPC (Cpc, mode 0)', [('Ball', 'art_ball', [b for fr in c for b in fr], 'the ball: 4 frames of 8 x 16 (mode 0), each on an even and an odd pixel: 16 rows of 5 byte pairs (mask, data)'),
                                             ('Inks', 'art_inks', CPC_INKS, 'pens 0-15 as hardware colour numbers')])
    p, w = asic()
    write('cpcplus', 'Amstrad CPC Plus (Asic)', [('Ball', 'art_ball', [b for fr in p for b in fr], 'the ball: 4 frames of 16 x 16, a byte a pixel (low 4 bits)'),
                                               ('SprPal', 'art_sprpal', w, 'the sprite palette: colours 1-15, 2 bytes each (red / blue, green)')])
    t = tms()
    for tgt, ttl in [('msx1', 'MSX1 (Tms9918)'), ('sc3000', 'Sega SC-3000 (Tms9918)')]:
        write(tgt, ttl, [('Ball', 'art_ball', [b for fr in t for b in fr], 'the ball: 4 frames of 16 x 16, 1 bit (32 bytes each)'),
                         ('Font', 'art_font', F, 'the font: characters 32-126, 8 bytes each')])
    pt, lines = v9938()
    write('msx2', 'MSX2 (V9938)', [('Ball', 'art_ball', [b for fr in pt for b in fr], 'the ball: 4 frames of 16 x 16, 1 bit (32 bytes each)'),
                                   ('BallLines', 'art_lines', lines, 'the ball\'s colour for each of its 16 lines (sprite mode 2)'),
                                   ('Font', 'art_font', F, 'the font: characters 32-126, 8 bytes each')])
    v = v9990()
    for tgt, ttl in [('msx_v9990', 'MSX + V9990 (GFX9000)'), ('cpc_v9990', 'Amstrad CPC + V9990')]:
        write(tgt, ttl, [('Ball', 'art_ball', [b for fr in v for b in fr], 'the ball: 4 frames of 16 x 16, 4 bits a pixel (128 bytes each)'),
                         ('Font', 'art_font', F, 'the font: characters 32-126, 8 bytes each')])

    # the cube tests (vectors): the font where there's no firmware to print with; the CPC's inks
    for tgt, ttl in [('cube_next', 'ZX Spectrum Next cube (Zxn, Layer 2)'), ('cube_msx1', 'MSX1 cube (Tms9918)'),
                     ('cube_sc3000', 'Sega SC-3000 cube (Tms9918)'), ('cube_msx2', 'MSX2 cube (V9938)'),
                     ('cube_msx_v9990', 'MSX + V9990 cube'), ('cube_cpc_v9990', 'Amstrad CPC + V9990 cube')]:
        parts = [('Font', 'art_font', F, 'the font: characters 32-126, 8 bytes each')]
        if tgt in ('cube_msx1', 'cube_sc3000'):
            parts.append(('Dither', 'art_dither', DITHER, 'the shading: 8 levels, dark to light, 4 lines of 8 pixels each (a repeating 4 x 4 pattern)'))
        write(tgt, ttl, parts)
    write('cube_cpc', 'Amstrad CPC cube (Cpc, mode 0)', [('Inks', 'art_inks', CUBE_INKS, 'pens 0-15 as hardware colour numbers: 0 black, 1 white (the text), 2-7 the cube dark to light')])
    write('cube_cpcplus', 'Amstrad CPC Plus cube (Cpc + Asic palette)', [('Inks', 'art_inks', CUBE_INKS, 'pens 0-15 as hardware colour numbers (the start, before the ASIC palette)'),
                                                                       ('Pal', 'art_pal', CUBE_PAL, 'the ASIC palette for pens 0-15: 2 bytes each (red * 16 + blue, green): 0 black, 1 white, 2-15 the cube dark to light')])
    preview()
