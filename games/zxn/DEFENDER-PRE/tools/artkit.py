# artkit.py - draws the games' default PNG sheets (scratch build tool, not delivered)
import re
from PIL import Image

MAGENTA = (255, 0, 255)

def plat_asm():
    # NTC's ntc_plat_zxn.asm: NTC_SRC (NTC's src folder), else a folder above this one that has it
    import os
    tries = []
    if os.environ.get('NTC_SRC'): tries.append(os.environ['NTC_SRC'])
    d = os.path.dirname(os.path.abspath(__file__))
    for _ in range(6):
        tries += [d, os.path.join(d, 'src'), os.path.join(d, 'src', 'src')]
        d = os.path.dirname(d)
    tries.append('/home/claude/src/src')
    for t in tries:
        f = os.path.join(t, 'asm', 'ntc_plat_zxn.asm')
        if os.path.exists(f): return f
    raise SystemExit('artkit: NTC\'s src folder not found - set NTC_SRC to it (the folder with asm/ntc_plat_zxn.asm)')

def font8x8():
    # the platform's font (font8x8_basic, public domain) from ntc_plat_zxn.asm
    src = open(plat_asm()).read()
    out = {}
    for m in re.finditer(r'db ((?:#[0-9A-F]{2}, ){7}#[0-9A-F]{2})\s*;\s*(\d+)', src):
        out[int(m.group(2))] = [int(x.strip()[1:], 16) for x in m.group(1).split(',')]
    return out

class Sheet:
    def __init__(s, cell, rows, pal):
        s.cell = cell; s.w = 16 * cell; s.h = rows * cell
        s.img = Image.new('RGBA', (s.w, s.h), MAGENTA + (255,))
        s.pal = pal
    def put(s, col, row, art, key, ox=0, oy=0):
        # art: list of strings; key: char -> palette index (15 / '.' / ' ' transparent)
        px = s.img.load()
        for y, line in enumerate(art):
            for x, ch in enumerate(line):
                if ch in ' .': continue
                i = key[ch]
                if i == 15: continue
                X = col * s.cell + ox + x; Y = row * s.cell + oy + y
                if 0 <= X < s.w and 0 <= Y < s.h:
                    px[X, Y] = s.pal[i] + (255,)
    def pixel(s, X, Y, i):
        if 0 <= X < s.w and 0 <= Y < s.h:
            s.img.load()[X, Y] = (MAGENTA if i == 15 else s.pal[i]) + (255,)
    def fill(s, col, row, i, w=1, h=1):
        for y in range(row * s.cell, (row + h) * s.cell):
            for x in range(col * s.cell, (col + w) * s.cell):
                s.pixel(x, y, i)
    def save(s, path):
        s.img.save(path)

def font_into(sheet, ink, shadow=None, paper=15, chars=range(32, 127)):
    f = font8x8()
    for c in chars:
        col, row = c % 16, c // 16
        if paper != 15: sheet.fill(col, row, paper)
        g = f[c]
        for y in range(8):
            for x in range(8):
                if g[y] & (0x80 >> x):
                    if shadow is not None and x < 7 and y < 7:
                        if not (g[y + 1] & (0x80 >> (x + 1)) if y < 7 else 0):
                            sheet.pixel(col * 8 + x + 1, row * 8 + y + 1, shadow)
        for y in range(8):
            for x in range(8):
                if g[y] & (0x80 >> x): sheet.pixel(col * 8 + x, row * 8 + y, ink)

def palette_png(path, rows):
    img = Image.new('RGBA', (16, len(rows)))
    for y, row in enumerate(rows):
        for x in range(16):
            c = row[x] if x < len(row) and x != 15 else MAGENTA
            img.putpixel((x, y), tuple(c) + (255,))
    img.save(path)

def mirror(art):
    return [l[::-1] for l in art]
