# nxkit.py - the art and sound kit for NTC BASIC Next games: pictures (Layer 2), sprites (4 bit
# patterns, 16 palette rows), tiles (the tilemap's 4 bit font and pieces) and sampled sounds, made
# in Python and written as the game's NEX banks plus the classes that load them:
#   GfxData.cls  the sprite patterns and palettes, the tiles and the tilemap's palettes (Load)
#   Pics.cls     the Layer 2 pictures, 256 x 192, 256 colours of 512 each (Show, Copy)
#   Speech.cls   sampled sounds through the DAC, fed by the DMA (Say, Update)
# (c) 2026 Cyborg Unicorn Pty Ltd
#
# The generated #asm never pushes, pops or calls: in NTC, SP walks the program's thread.
import os, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

# ---------------------------------------------------------------- colours
def lvl(v):
    return min(7, int(v * 7 / 255 + 0.5))

def c9(r, g, b):
    """an RGB colour as the Next's 9 bits: (RRRGGGBB, the blue's low bit)"""
    R, G, B = lvl(r), lvl(g), lvl(b)
    return ((R << 5) | (G << 2) | (B >> 1), B & 1)

def rgb9(r, g, b):
    """the colour the Next really shows for r, g, b"""
    return (lvl(r) * 255 // 7, lvl(g) * 255 // 7, lvl(b) * 255 // 7)

def pal_bytes(cols, n):
    """n colours as 2n bytes for NextReg #44"""
    out = bytearray()
    for i in range(n):
        r, g, b = cols[i] if i < len(cols) else (0, 0, 0)
        a, lo = c9(r, g, b)
        out += bytes([a, lo])
    return bytes(out)

def snap(img, dither=0.9):
    """an RGB picture with every colour as the Next shows it (3 bits a channel), ordered dither"""
    a = np.asarray(img.convert('RGB')).astype(float)
    h, w, _ = a.shape
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
    t = np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w][:, :, None]
    q = np.clip(np.floor(a * 7 / 255 + 0.5 + t * dither), 0, 7)
    return Image.fromarray((q * 255 / 7).astype(np.uint8))

def quant(img, n, dither=0.9):
    """img (RGB) to n colours as the Next shows them: (palette [(r,g,b)], indices array)"""
    s = snap(img, dither)
    cnt = len(set(s.getdata())) if s.width * s.height < 70000 else 99999
    p = s.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = list(p.getpalette()[:n * 3])
    pal += [0] * (n * 3 - len(pal))
    cols = [rgb9(*pal[i * 3:i * 3 + 3]) for i in range(n)]
    return cols, np.asarray(p)

# ---------------------------------------------------------------- drawing helpers
def font(sz, path=FONTB):
    return ImageFont.truetype(path, sz)

def vgrad(w, h, stops):
    """a vertical gradient: stops [(t 0-1, (r,g,b))]"""
    a = np.zeros((h, w, 3))
    ys = np.linspace(0, 1, h)
    for c in range(3):
        a[:, :, c] = np.interp(ys, [s_[0] for s_ in stops], [s_[1][c] for s_ in stops])[:, None]
    return Image.fromarray(a.astype(np.uint8))

def noise(w, h, scale, octaves=4, seed=1):
    """smooth value noise 0-1"""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w)); amp = 1.0; tot = 0
    for o in range(octaves):
        s_ = max(1, int(scale / (2 ** o)))
        gw, gh = max(2, w // s_ + 3), max(2, h // s_ + 3)
        g = rng.random((gh, gw))
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((gw * s_, gh * s_), Image.BICUBIC)
        out += np.asarray(im)[:h, :w] / 255.0 * amp; tot += amp; amp *= 0.5
    return out / tot

def text_logo(txt, size, top, bot, outline=(0, 0, 0), shadow=4, glowc=None, fontpath=FONTB, ow=5):
    """big shaded letters: RGBA"""
    f = font(size, fontpath)
    bb = f.getbbox(txt)
    w, h = bb[2] - bb[0] + 24 + shadow, bb[3] - bb[1] + 24 + shadow
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).text((12 - bb[0], 12 - bb[1]), txt, font=f, fill=255)
    m = np.asarray(mask) > 128
    out = np.zeros((h, w, 4), np.uint8)
    big = np.asarray(mask.filter(ImageFilter.MaxFilter(ow))) > 128
    sh = np.roll(np.roll(big, shadow, 0), shadow, 1)
    out[sh] = (0, 0, 0, 255)
    out[big] = tuple(outline) + (255,)
    rows = np.where(m.any(1))[0]
    y0, y1 = (rows[0], rows[-1]) if len(rows) else (0, h)
    g = np.zeros((h, w, 3))
    ys = np.clip((np.arange(h) - y0) / max(1, (y1 - y0)), 0, 1)
    for c in range(3):
        g[:, :, c] = (top[c] * (1 - ys) + bot[c] * ys)[:, None]
    out[m, :3] = g[m].astype(np.uint8); out[m, 3] = 255
    yy = np.arange(h)[:, None] * np.ones((1, w))
    shine = m & (yy < y0 + (y1 - y0) * 0.3)
    out[shine, :3] = np.clip(out[shine, :3].astype(int) + 70, 0, 255)
    im = Image.fromarray(out, 'RGBA')
    if glowc:
        a = np.asarray(im)[:, :, 3]
        ga2 = np.asarray(Image.fromarray(a).filter(ImageFilter.GaussianBlur(7))).astype(float)
        base = np.zeros((h, w, 4), np.uint8); base[:, :, :3] = glowc; base[:, :, 3] = np.clip(ga2 * 1.5, 0, 255)
        bg = Image.fromarray(base, 'RGBA'); bg.alpha_composite(im); im = bg
    return im

def sphere(d, col, light=(-0.55, -0.65), spec=0.9, rim=None, alpha=255):
    """a shaded ball, RGBA, diameter d"""
    a = np.zeros((d, d, 4), np.uint8)
    c = (d - 1) / 2.0; r = d / 2.0
    ln = math.sqrt(light[0] ** 2 + light[1] ** 2 + 0.5)
    for y in range(d):
        for x in range(d):
            dx, dy = (x - c) / r, (y - c) / r
            q = dx * dx + dy * dy
            if q > 1: continue
            z = math.sqrt(1 - q)
            nd = (dx * light[0] + dy * light[1] + z * 0.7) / ln
            sh = 0.22 + 0.78 * max(0, nd)
            v = [min(255, int(cc * sh)) for cc in col]
            if spec:
                s_ = max(0, nd) ** 16 * spec
                v = [min(255, int(cc + 255 * s_)) for cc in v]
            if rim and q > 0.7:
                k = (q - 0.7) / 0.3
                v = [int(cc * (1 - k) + w * k) for cc, w in zip(v, rim)]
            a[y, x] = (v[0], v[1], v[2], alpha)
    return Image.fromarray(a, 'RGBA')

def cells(img):
    """an RGBA picture (w, h multiples of 16) cut into 16 x 16 cells, row by row"""
    w, h = img.size
    return [img.crop((x, y, x + 16, y + 16)) for y in range(0, h, 16) for x in range(0, w, 16)]

def pad16(img):
    w, h = img.size
    W, H = (w + 15) // 16 * 16, (h + 15) // 16 * 16
    if (W, H) == (w, h): return img
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0)); out.paste(img, ((W - w) // 2, (H - h) // 2)); return out

def asm_pal(lab, hl):
    """#asm lines: 256 colours (2 bytes each) from HL to the palette #43 picked (BC = #243B)"""
    return ["            ld hl, %s" % hl,
            "            ld a, #40", "            out (c), a", "            inc b", "            xor a", "            out (c), a", "            dec b",
            "            ld a, #44", "            out (c), a", "            inc b", "            ld e, 0",
            "%s:" % lab, "            ld a, (hl)", "            out (c), a", "            inc hl", "            ld a, (hl)", "            out (c), a",
            "            inc hl", "            dec e", "            jr nz, %s" % lab, "            dec b"]

def asm_reg(r, v):
    return ["            ld a, #%02X" % r, "            out (c), a", "            inc b", "            ld a, %s" % v, "            out (c), a", "            dec b"]

# ---------------------------------------------------------------- the graphics
class Gfx:
    def __init__(s):
        s.rows = []            # sprite palette rows: [15 colours]
        s.pats = []            # 128 bytes each
        s.names = []           # (name, first, frames, w, h, row)
        s.trows = [None] * 16  # tile palette rows
        s.tiles = {}           # n -> 32 bytes
        s.tnames = []
        s.patrow = {}
    def row(s, imgs, n=15, fixed=None):
        """a sprite palette row for these pictures (RGBA): its number"""
        if fixed is not None:
            cols = [rgb9(*c) for c in list(fixed)[:15]]
        else:
            px = []
            for im in imgs:
                a = np.asarray(im.convert('RGBA')).reshape(-1, 4)
                px.append(a[a[:, 3] >= 128][:, :3])
            px = np.concatenate(px) if px else np.zeros((1, 3), np.uint8)
            if len(px) == 0: px = np.zeros((1, 3), np.uint8)
            strip = Image.fromarray(px.reshape(1, -1, 3).astype(np.uint8))
            cols, _ = quant(strip, n, dither=0.0)
        while len(cols) < 15: cols.append((0, 0, 0))
        s.rows.append(cols[:15])
        if len(s.rows) > 16: raise ValueError('more than 16 sprite palette rows')
        return len(s.rows) - 1
    def _enc(s, im, cols):
        a = np.asarray(im.convert('RGBA')).astype(int)
        h, w, _ = a.shape
        out = np.full((h, w), 15, np.uint8)
        cs = np.array(cols)
        op = a[:, :, 3] >= 128
        if op.any():
            d = ((a[:, :, None, :3] - cs[None, None, :, :]) ** 2).sum(-1)
            out[op] = d.argmin(-1)[op]
        return out
    def sprite(s, name, frames, row=None):
        """frames (RGBA, all one size): their patterns from the next free one; (first, row)"""
        frames = [pad16(f) for f in frames]
        if row is None: row = s.row(frames)
        cols = s.rows[row]
        first = len(s.pats)
        w, h = frames[0].size
        for f in frames:
            for c in cells(f):
                ix = s._enc(c, cols)
                s.patrow[len(s.pats)] = row
                s.pats.append(bytes(((int(ix[y, x]) << 4) | int(ix[y, x + 1])) for y in range(16) for x in range(0, 16, 2)))
        s.names.append((name, first, len(frames), w // 16, h // 16, row))
        if len(s.pats) > 128: raise ValueError('more than 128 patterns (%s)' % name)
        return first
    def trow(s, n, cols):
        """tile palette row n: up to 15 colours (+ 15 see-through)"""
        cols = [rgb9(*c) for c in cols][:15]
        while len(cols) < 15: cols.append((0, 0, 0))
        s.trows[n] = cols
    def tile(s, n, img, rown=0, name=None):
        """tile n (8 x 8 RGBA) in tile palette row rown's colours"""
        ix = s._enc(img, s.trows[rown])
        s.tiles[n] = bytes(((int(ix[y, x]) << 4) | int(ix[y, x + 1])) for y in range(8) for x in range(0, 8, 2))
        if name: s.tnames.append((name, n))
    def tile_ix(s, n, ix, name=None):
        """tile n from 8 x 8 colour numbers (0-15)"""
        s.tiles[n] = bytes(((int(ix[y][x]) << 4) | int(ix[y][x + 1])) for y in range(8) for x in range(0, 8, 2))
        if name: s.tnames.append((name, n))
    def font(s):
        """the font as tiles 32-126 in colour numbers: 1 top, 2 middle, 3 bottom, 4 the shadow"""
        glyphs = {}
        for line in open(os.path.join(HERE, 'font8x8.txt')):
            if line.startswith(';'): continue
            p = line.split(';')
            bs = [int(x, 16) for x in p[0].split()]
            try: c = int(p[1].split()[0])
            except Exception: continue
            glyphs[c] = bs
        for c in range(32, 127):
            g = glyphs.get(c, [0] * 8)
            px = [[(g[y] >> (7 - x)) & 1 for x in range(8)] for y in range(8)]   # (bit 7 is the left)
            ix = [[15] * 8 for _ in range(8)]
            for y in range(8):
                for x in range(8):
                    if y and x and px[y - 1][x - 1] and not px[y][x]: ix[y][x] = 4
            for y in range(8):
                for x in range(8):
                    if px[y][x]: ix[y][x] = 1 if y < 3 else (2 if y < 5 else 3)
            s.tile_ix(c, ix)
    def build(s):
        """two banks: the patterns (16K), then the tiles (8K) and the palettes"""
        b1 = bytearray(16384)
        for i, p in enumerate(s.pats): b1[i * 128:i * 128 + 128] = p
        b2 = bytearray(16384)
        b2[0:8192] = b'\xff' * 8192             # every tile see-through unless drawn
        for n, t in s.tiles.items(): b2[n * 32:n * 32 + 32] = t
        sp = []
        for r in range(16):
            cols = s.rows[r] if r < len(s.rows) else [(0, 0, 0)] * 15
            sp += list(cols[:15]) + [(255, 0, 255)]
        tp = []
        for r in range(16):
            cols = s.trows[r] if s.trows[r] else [(0, 0, 0)] * 15
            tp += list(cols[:15]) + [(255, 0, 255)]
        b2[8192:8192 + 512] = pal_bytes(sp, 256)
        b2[8704:8704 + 512] = pal_bytes(tp, 256)
        return [bytes(b1), bytes(b2)]
    def write_cls(s, path, dat, bank, game, datoff=0):
        L = ["' GfxData - %s's sprites and tiles (made by tools/art.py with tools/nxkit.py: don't edit)." % game,
             "' %d sprite patterns (4 bit, 16 x 16), %d sprite palette rows, %d tiles (4 bit, 8 x 8: the font is" % (len(s.pats), len(s.rows), len(s.tiles)),
             "' tiles 32-126) and the tilemap's palette rows, in banks %d (the patterns) and %d (the tiles at #0000," % (bank, bank + 1),
             "' the sprite palette at #2000, the tilemap palette at #2200) of the NEX file (INCBIN %s)." % dat,
             "' Load: the patterns to the sprite RAM, both palettes, the tiles to bank 5 + #0000 (#C000, where",
             "' Tiles.Init points the tilemap's tiles). S_NAME is a sprite's first pattern, P_NAME its palette",
             "' offset (for Spr.Put's flags), T_NAME a tile.",
             "' (c) 2026 Cyborg Unicorn Pty Ltd", "Option Explicit", ""]
        for nm, first, fr, w, h, row in s.names:
            L.append('Public Const S_%s = %d' % (nm, first))
            if fr > 1: L.append('Public Const S_%s_N = %d' % (nm, fr))
            if w > 1 or h > 1:
                L.append('Public Const S_%s_W = %d' % (nm, w)); L.append('Public Const S_%s_H = %d' % (nm, h))
            L.append('Public Const P_%s = %d' % (nm, row * 16))
        for nm, n in s.tnames: L.append('Public Const T_%s = %d' % (nm, n))
        L.append('Public Const Patterns = %d' % len(s.pats))
        L += ["", "Public Sub Load()", "#asm", "            ld bc, #243B"]
        L += asm_reg(0x56, bank * 2) + asm_reg(0x57, bank * 2 + 1)
        L += ["            ld bc, #303B            ; the patterns, from pattern 0",
              "            xor a", "            out (c), a",
              "            ld hl, #C000",
              "            ld de, %d" % max(1, len(s.pats) * 128),
              "gd_pat:", "            ld a, (hl)", "            out (#5B), a", "            inc hl", "            dec de",
              "            ld a, d", "            or e", "            jr nz, gd_pat",
              "            ld bc, #243B            ; the tiles: their bank's first page at #E000, bank 5's at #C000"]
        L += asm_reg(0x56, 10) + asm_reg(0x57, (bank + 1) * 2)
        L += ["            ld hl, #E000", "            ld de, #C000", "            ld bc, 8192", "            ldir", "            ld bc, #243B"]
        L += asm_reg(0x57, (bank + 1) * 2 + 1)
        L += asm_reg(0x43, '#20') + asm_pal('gd_p1', '#E000')
        L += asm_reg(0x43, '#30') + asm_pal('gd_p2', '#E200')
        L += asm_reg(0x43, '0') + asm_reg(0x57, 11)
        L += ["            jp gd_end", "gd_end:"]
        for k in range(2):
            L += ["            MMU 6 7, %d" % ((bank + k) * 2), "            ORG #C000", '            INCBIN "%s", %d, 16384' % (dat, datoff + k * 16384)]
        L += ["            MMU 6 7, 10", "            ORG gd_end", "#endasm", "End Sub"]
        open(path, 'w').write('\n'.join(L) + '\n')
    def sheet(s, path, scale=3):
        """every pattern in its colours (a preview), 16 a row"""
        n = len(s.pats); per = 16; rows = max(1, (n + per - 1) // per)
        im = Image.new('RGB', (per * 18, rows * 18), (36, 36, 56))
        for i, p in enumerate(s.pats):
            cols_ = s.rows[s.patrow.get(i, 0)]
            for y in range(16):
                for x in range(16):
                    v = p[y * 8 + x // 2]; c = (v >> 4) if x % 2 == 0 else (v & 15)
                    if c != 15: im.putpixel(((i % per) * 18 + 1 + x, (i // per) * 18 + 1 + y), tuple(cols_[c]))
        im.resize((im.width * scale, im.height * scale), Image.NEAREST).save(path)

# ---------------------------------------------------------------- the Layer 2 pictures
class Pics:
    def __init__(s):
        s.items = []           # (name, indices 192 x 256, palette)
    def add(s, name, img, dither=0.9):
        img = img.convert('RGB')
        if img.size != (256, 192): img = img.resize((256, 192))
        cols, ix = quant(img, 256, dither)
        s.items.append((name, ix, cols))
        return len(s.items) - 1
    def add_raw(s, name, ix, cols):
        """a picture already as colour numbers (192 x 256) and its 256 colours"""
        cols = [rgb9(*c) for c in cols] + [(0, 0, 0)] * (256 - len(cols))
        s.items.append((name, np.asarray(ix, np.uint8), cols[:256]))
        return len(s.items) - 1
    def shown(s, k):
        """picture k as the Next shows it"""
        nm, ix, cols = s.items[k]
        pal = np.array(cols, np.uint8)
        return Image.fromarray(pal[ix])
    def build(s):
        out = []
        for nm, ix, cols in s.items:
            raw = ix.astype(np.uint8).tobytes()
            out += [raw[0:16384], raw[16384:32768], raw[32768:49152]]
        pb = bytearray(16384)
        for k, (nm, ix, cols) in enumerate(s.items): pb[k * 512:k * 512 + 512] = pal_bytes(cols, 256)
        out.append(bytes(pb))
        return out
    def write_cls(s, path, dat, bank, game, datoff=0):
        n = len(s.items); pbank = bank + 3 * n
        L = ["' Pics - %s's Layer 2 pictures (made by tools/art.py with tools/nxkit.py: don't edit)." % game,
             "' %d pictures, 256 x 192, a byte a pixel, each its own 256 colours (of the Next's 512): picture n" % n,
             "' is banks %d + 3n .. %d + 3n + 2 of the NEX file, the palettes are in bank %d (INCBIN %s)." % (bank, bank, pbank, dat),
             "' Show n: Layer 2 shows picture n where it is (nothing copied: draw nothing on it).",
             "' Copy n: picture n copied to Layer 2's own screen (L2.cls's: bank 16) and shown there, to draw on.",
             "' (c) 2026 Cyborg Unicorn Pty Ltd", "Option Explicit", ""]
        for k, (nm, ix, cols) in enumerate(s.items): L.append('Public Const PIC_%s = %d' % (nm, k))
        L.append('Public Const FirstPage = %d          \' picture n is pages FirstPage + 6n ..' % (bank * 2))
        L += ["", "Private buf(511) As Byte", "Private pn As Integer, i As Integer, j As Integer", "",
              "' Show n: picture n's palette, and Layer 2 pointed at its banks",
              "Public Sub Show(ByVal n As Integer)",
              "  Palette n",
              "  Nx.Reg &H12, %d + n * 3" % bank,
              "End Sub", "",
              "' Copy n: picture n into Layer 2's screen (bank 16, pages 32-37), its palette, shown",
              "Public Sub Copy(ByVal n As Integer)",
              "  For i = 0 To 5",
              "    For j = 0 To 15",
              "      Move (%d + n * 3) * 2 + i, 32 + i, j * 512" % bank,
              "    Next",
              "  Next",
              "  Palette n",
              "  Nx.Reg &H12, 16",
              "End Sub", "",
              "' Move src, dst, off: 512 bytes from page src to page dst, both at offset off, through buf",
              "Private Sub Move(ByVal src As Integer, ByVal dst As Integer, ByVal off As Integer)",
              "#asm",
              "            pop hl", "            ld a, (hl)", "            ld (pm_s + 1), a",
              "            pop hl", "            ld a, (hl)", "            ld (pm_d + 1), a",
              "            pop hl", "            ld e, (hl)", "            inc hl", "            ld a, (hl)", "            or #C0", "            ld d, a",
              "            ld (pm_o + 1), de", "            ld (pm_o2 + 1), de",
              "            ld bc, #243B", "            ld a, #56", "            out (c), a", "            inc b",
              "pm_s:", "            ld a, 0", "            out (c), a",
              "pm_o:", "            ld hl, 0", "            ld de, {buf}", "            ld bc, 512", "            ldir",
              "            ld bc, #243B", "            ld a, #56", "            out (c), a", "            inc b",
              "pm_d:", "            ld a, 0", "            out (c), a",
              "            ld hl, {buf}",
              "pm_o2:", "            ld de, 0", "            ld bc, 512", "            ldir",
              "            ld bc, #243B", "            ld a, #56", "            out (c), a", "            inc b", "            ld a, 10", "            out (c), a",
              "#endasm", "End Sub", "",
              "' Palette n: picture n's 256 colours into Layer 2's first palette",
              "Public Sub Palette(ByVal n As Integer)",
              "  pn = n",
              "#asm",
              "            ld a, ({pn})              ; HL = #C000 + (n And 15) * 512, page = the bank's first + n / 16",
              "            and 15", "            add a, a", "            or #C0", "            ld h, a", "            ld l, 0",
              "            ld a, ({pn})", "            cp 16", "            ld a, %d" % (pbank * 2), "            jr c, pa_lo", "            inc a",
              "pa_lo:", "            ld e, a", "            ld bc, #243B", "            ld a, #56", "            out (c), a", "            inc b", "            out (c), e", "            dec b"]
        L += asm_reg(0x43, '#10')
        L += ["            ld a, #40", "            out (c), a", "            inc b", "            xor a", "            out (c), a", "            dec b",
              "            ld a, #44", "            out (c), a", "            inc b", "            ld e, 0",
              "pa_lp:", "            ld a, (hl)", "            out (c), a", "            inc hl", "            ld a, (hl)", "            out (c), a", "            inc hl",
              "            dec e", "            jr nz, pa_lp", "            dec b"]
        L += asm_reg(0x43, '0') + asm_reg(0x56, 10)
        L += ["#endasm", "  Banks", "End Sub", "",
              "' the pictures in the NEX file (it only jumps over them: called so it's kept)",
              "Private Sub Banks()", "#asm", "            jp pb_end", "pb_end:"]
        for k in range(3 * n + 1):
            L += ["            MMU 6 7, %d" % ((bank + k) * 2), "            ORG #C000", '            INCBIN "%s", %d, 16384' % (dat, datoff + k * 16384)]
        L += ["            MMU 6 7, 10", "            ORG pb_end", "#endasm", "End Sub"]
        open(path, 'w').write('\n'.join(L) + '\n')

# ---------------------------------------------------------------- the sampled sounds
RATE = 875000 // 64      # the DMA's rate (13671 a second)

def speech_cls(path, game, dat, bank, clips, datoff=0):
    """Speech.cls: clips [(name, bytes 8-bit unsigned)] laid out from bank `bank` (none crosses
    into a bank that doesn't follow it: they're one run of banks); returns the banks' bytes"""
    blob = bytearray(); tab = []
    for nm, b in clips:
        assert len(b) < 65536, nm + ': a clip must be under 64K'
        off = len(blob); blob += b
        tab.append((nm, off, len(b)))
    while len(blob) % 16384: blob.append(128)
    nb = len(blob) // 16384
    total = sum(len(b) for _, b in clips)
    L = ["' Speech - %s's sampled sounds (made by tools/speech.py with tools/nxkit.py: don't edit)." % game,
         "' (c) 2026 Cyborg Unicorn Pty Ltd",
         "'",
         "' %d clips, 8 bits, %d a second, %.1f seconds in all, in banks %d-%d of the NEX file (INCBIN %s," % (len(clips), RATE, total / RATE, bank, bank + nb - 1, dat),
         "' keep it next to the .asm). They play through the Next's DAC (#DF), fed by its DMA from a ring of",
         "' 4K at #F000 (bank 5's second page, in MMU slot 7 the whole time): the DMA goes round it by itself",
         "' (875 kHz / 64); Update (every frame) copies the clip on ahead of where the DMA is reading, through",
         "' MMU slot 6 (then bank 5's first page back, as L2 does), and silence after. As CYBORG HELLGATE's",
         "' voice. Say n plays clip n, cutting off one already playing (Say2 n waits its turn: skipped if busy).",
         "' Volume 0-5: below 5 each byte goes through a table of 256 at #EB00 as it's copied.",
         "Option Explicit", ""]
    for k, (nm, off, ln) in enumerate(tab): L.append('Public Const S_%s = %d          \' %.2f s' % (nm, k, ln / RATE))
    L += ["Public Const Clips = %d" % len(tab), "",
          "Private playT As Integer          ' frames still to go of the clip playing (0: none)",
          "Private cPage As Integer, cOff As Integer, cLeft As Integer   ' what's still to copy: page, offset, bytes (cLeft unsigned: up to 65535)",
          "Private quiet As Integer          ' bytes of silence still to put after a clip",
          "Private wp As Integer             ' where in the ring the next byte goes (0-4095)",
          "Private vlev As Integer           ' the volume, 0-5", "",
          "' Init: the DACs on, the ring silent, the DMA going round it",
          "Public Sub Init()",
          "  Nx.Reg &H08, Nx.RegGet(&H08) Or &H08",
          "#asm",
          "            ld hl, #F000            ; the ring: silence",
          "            ld de, #F001", "            ld bc, 4095", "            ld (hl), 128", "            ldir",
          "            ld hl, sp_dma", "            ld b, sp_dmae - sp_dma", "            ld c, #6B", "            otir",
          "            jp sp_go",
          "sp_dma:",
          "            db #83                  ; off",
          "            db #7D, #00, #F0, #00, #10   ; WR0: A to B, from #F000, 4096 bytes",
          "            db #54, #02             ; WR1: A memory, going up",
          "            db #68, #22, 64          ; WR2: B a port, fixed; the prescaler",
          "            db #CD, #DF, #00        ; WR4: burst; B is port #DF (the DAC)",
          "            db #A2                  ; WR5: round again at the end",
          "            db #CF                  ; load",
          "            db #87                  ; on",
          "sp_dmae:", "sp_go:", "#endasm",
          "  playT = 0 : cLeft = 0 : quiet = 0 : wp = 0 : vlev = 5",
          "  Table : Banks                    ' (they only jump over their data: called so it's kept)",
          "End Sub", "",
          "' Volume v: 0 off, 1 (quiet) to 5 (full)",
          "Public Sub Volume(ByVal v As Integer)",
          "  Dim i As Integer",
          "  If v < 0 Then v = 0",
          "  If v > 5 Then v = 5",
          "  vlev = v",
          "  If v >= 1 And v <= 4 Then",
          "    For i = 0 To 255",
          "      Poke &HEB00 + i, 128 + ((i - 128) * v) \\ 5",
          "    Next",
          "  End If",
          "End Sub", "",
          "Public Function Vol() As Integer", "  Vol = vlev", "End Function", "",
          "' Playing(): True while a clip plays",
          "Public Function Playing() As Integer", "  Playing = (playT > 0)", "End Function", "",
          "' Say n: clip n, from now (one playing is cut off)",
          "Public Sub Say(ByVal intN_a As Integer)",
          "  If vlev > 0 And intN_a >= 0 And intN_a < Clips Then",
          "    Look intN_a",
          "    If cLeft <> 0 Then",
          "      playT = (cLeft And 32767) \\ 273 + 3",
          "      If cLeft < 0 Then playT = playT + 120     ' (a clip over 32767 bytes: cLeft is unsigned)",
          "      quiet = 4096",
          "      wp = (Pos() + 64) And 4095",
          "      Update",
          "    End If",
          "  End If",
          "End Sub", "",
          "' Say2 n: clip n unless one is playing",
          "Public Sub Say2(ByVal intN_a As Integer)",
          "  If playT = 0 Then Say intN_a",
          "End Sub", "",
          "' Look n: clip n's page, offset and length from the table",
          "Private Sub Look(ByVal n As Integer)",
          "#asm",
          "            pop hl", "            ld a, (hl)", "            ld l, a", "            ld h, 0", "            ld d, h", "            ld e, l",
          "            add hl, hl", "            add hl, de", "            add hl, hl              ; 6 bytes a clip",
          "            ld de, sp_tab", "            add hl, de",
          "            ld a, (hl)", "            ld ({cPage}), a", "            xor a", "            ld ({cPage} + 1), a",
          "            inc hl", "            ld e, (hl)", "            inc hl", "            ld d, (hl)", "            inc hl", "            ld ({cOff}), de",
          "            ld e, (hl)", "            inc hl", "            ld d, (hl)", "            ld ({cLeft}), de",
          "#endasm", "End Sub", "",
          "' Pos(): where in the ring the DMA is reading (0-4095)",
          "Private Function Pos() As Integer",
          "#asm",
          "            ld bc, #006B",
          "            ld a, #BB               ; read mask: port A's address", "            out (c), a",
          "            ld a, #18", "            out (c), a",
          "            ld a, #A7               ; start the read", "            out (c), a",
          "            in e, (c)", "            in a, (c)", "            and #0F", "            ld d, a",
          "            pop hl", "            ld (hl), e", "            inc hl", "            ld (hl), d",
          "#endasm", "End Function", "",
          "' Update: every frame - the clip copied on into the ring ahead of the DMA, silence after it",
          "Public Sub Update()",
          "  Dim r As Integer, n As Integer, c As Integer",
          "  If playT > 0 Then playT = playT - 1",
          "  n = 0",
          "  If cLeft <> 0 Or quiet > 0 Then",
          "    r = Pos()",
          "    n = (r - wp - 32) And 4095",
          "    If n > 1024 Then n = 1024",
          "  End If",
          "  Do While n > 0",
          "    c = n",
          "    If 4096 - wp < c Then c = 4096 - wp",
          "    If cLeft <> 0 Then",
          "      If cLeft > 0 And cLeft < c Then c = cLeft",
          "      If 8192 - cOff < c Then c = 8192 - cOff",
          "      Copy cPage, cOff, wp, c",
          "      cOff = cOff + c : cLeft = cLeft - c",
          "      If cOff >= 8192 Then cOff = 0 : cPage = cPage + 1",
          "    Else",
          "      If quiet < c Then c = quiet",
          "      Copy 255, 0, wp, c",
          "      quiet = quiet - c",
          "    End If",
          "    wp = (wp + c) And 4095 : n = n - c",
          "    If c = 0 Then n = 0",
          "  Loop",
          "End Sub", "",
          "' Copy page, off, at, n: n bytes from page's offset off (page 255: silence) to the ring at at",
          "Private Sub Copy(ByVal page As Integer, ByVal off As Integer, ByVal at As Integer, ByVal n As Integer)",
          "#asm",
          "            pop hl", "            ld a, (hl)", "            ld (sc_pg + 1), a",
          "            pop hl", "            ld e, (hl)", "            inc hl", "            ld d, (hl)", "            ld hl, #C000", "            add hl, de", "            ld (sc_src + 1), hl",
          "            pop hl", "            ld e, (hl)", "            inc hl", "            ld d, (hl)", "            ld hl, #F000", "            add hl, de", "            ld (sc_dst + 1), hl",
          "            pop hl", "            ld c, (hl)", "            inc hl", "            ld b, (hl)",
          "            ld a, b", "            or c", "            jr z, sc_end",
          "sc_dst:", "            ld de, 0",
          "sc_pg:", "            ld a, 0", "            cp 255", "            jr nz, sc_copy",
          "            ld h, d                 ; silence", "            ld l, e", "            ld (hl), 128",
          "            dec bc", "            ld a, b", "            or c", "            jr z, sc_end", "            inc de", "            ldir", "            jr sc_end",
          "sc_copy:", "            ld (sc_bc + 1), bc",
          "            ld bc, #243B            ; its page in at #C000", "            ld l, a", "            ld a, #56", "            out (c), a", "            inc b", "            out (c), l",
          "sc_src:", "            ld hl, 0",
          "sc_bc:", "            ld bc, 0",
          "            ld a, ({vlev})", "            cp 5", "            jr c, sc_tr",
          "            ldir                    ; full volume: as it is", "            jr sc_back",
          "sc_tr:", "            ld a, (hl)              ; quieter: each byte through the table", "            ld (sc_t + 1), a",
          "sc_t:", "            ld a, (#EB00)", "            ld (de), a", "            inc hl", "            inc de", "            dec bc",
          "            ld a, b", "            or c", "            jr nz, sc_tr",
          "sc_back:", "            ld bc, #243B            ; bank 5's first page back", "            ld a, #56", "            out (c), a", "            inc b", "            ld a, 10", "            out (c), a",
          "sc_end:", "#endasm", "End Sub", "",
          "' the clips: page, offset (2 bytes), length (2 bytes), 0",
          "Private Sub Table()", "#asm", "            jp tb_end", "@sp_tab:"]
    for nm, off, ln in tab:
        pg = bank * 2 + off // 8192; o = off % 8192
        L.append("            db %d, %d, %d, %d, %d, 0       ; %s (%.2f s)" % (pg, o & 255, o >> 8, ln & 255, ln >> 8, nm, ln / RATE))
    L += ["tb_end:", "#endasm", "End Sub", "",
          "' the clips in the NEX file (banks %d-%d)" % (bank, bank + nb - 1),
          "Private Sub Banks()", "#asm", "            jp sb_end", "sb_end:"]
    for k in range(nb):
        L += ["            MMU 6 7, %d" % ((bank + k) * 2), "            ORG #C000", '            INCBIN "%s", %d, 16384' % (dat, datoff + k * 16384)]
    L += ["            MMU 6 7, 10", "            ORG sb_end", "#endasm", "End Sub"]
    open(path, 'w').write('\n'.join(L) + '\n')
    return [bytes(blob[k * 16384:(k + 1) * 16384]) for k in range(nb)]

def onebit_to_8(data, rate_in, gain=0.85, lo=110, hi=3600, nr=1.0):
    """1-bit samples (MSB first) cleaned to 8-bit unsigned at the DMA's rate: low-passed and
    high-passed, spectral noise reduction, normalised, faded in and out"""
    from scipy import signal
    x = np.unpackbits(np.frombuffer(bytes(data), np.uint8)).astype(float) * 2 - 1
    # up to the DMA's rate first (the filters at the new rate)
    n = int(len(x) * RATE / rate_in)
    y = signal.resample_poly(x, RATE, rate_in) if True else signal.resample(x, n)
    sos = signal.butter(6, [lo, hi], btype='band', fs=RATE, output='sos')
    y = signal.sosfiltfilt(sos, y)
    if nr > 0 and len(y) > 512:
        f, t, Z = signal.stft(y, RATE, nperseg=256)
        mag = np.abs(Z); floor = np.percentile(mag, 25, axis=1, keepdims=True) * nr
        g = np.clip((mag - floor) / np.maximum(mag, 1e-9), 0, 1)
        _, y = signal.istft(Z * g, RATE, nperseg=256)
    m = np.max(np.abs(y)) or 1
    y = y / m * gain
    fade = min(len(y) // 4, int(RATE * 0.008))
    if fade > 0:
        y[:fade] *= np.linspace(0, 1, fade); y[-fade:] *= np.linspace(1, 0, fade)
    return bytes(np.clip(np.round(y * 127 + 128), 0, 255).astype(np.uint8))

def wav8(path, b):
    import wave
    w = wave.open(path, 'wb'); w.setnchannels(1); w.setsampwidth(1); w.setframerate(RATE); w.writeframes(bytes(b)); w.close()

# ---------------------------------------------------------------- the NEX's banks
def write_dat(path, banks):
    with open(path, 'wb') as f:
        for b in banks:
            assert len(b) == 16384, len(b)
            f.write(b)

def set_banks(gamejson, key, banks):
    """game.json: the banks a tool puts in the NEX file (under key in bankuse), and the full list"""
    g = json.load(open(gamejson))
    g.setdefault('bankuse', {})[key] = list(banks)
    allb = []
    for k in sorted(g['bankuse']):
        for b in g['bankuse'][k]:
            if b not in allb: allb.append(b)
    g['banks'] = allb
    json.dump(g, open(gamejson, 'w'), indent=1)
