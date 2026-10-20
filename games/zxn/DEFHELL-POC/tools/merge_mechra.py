# merge_mechra.py - DEFENDER HELLGATE's sprites: DEFENDER HYPERSPACE's (gfx/, from art_defhyper.py)
# with MECHRA's pickups, guard and giant mechs added below them (from tools/mechra/, made by
# tools/mechra/art_mechra.py). The MECHRA cells keep their colour numbers; their colours come
# with them as sprite palette rows 8 (the pickups, the guard) and 9-13 (the five giant mechs).
#   run after art_defhyper.py:  python3 tools/merge_mechra.py
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.join(HERE, '..', 'gfx')
M = os.path.join(HERE, 'mechra')

def rows(path):
    p = Image.open(path).convert('RGBA')
    return [[p.getpixel((x, y)) for x in range(16)] for y in range(p.size[1])]

dpal = rows(os.path.join(G, 'spr_pal.png'))[:8]
mpal = rows(os.path.join(M, 'spr_pal.png'))
d0 = [c[:3] for c in dpal[0]]
m0 = [c[:3] for c in mpal[0]]

src = Image.open(os.path.join(M, 'sprites.png')).convert('RGBA')
dst = Image.open(os.path.join(G, 'sprites.png')).convert('RGBA')
out = Image.new('RGBA', (256, 128), (255, 0, 255, 255))
out.paste(dst.crop((0, 0, 256, 64)), (0, 0))

def cell(sc, sr, dc, dr):
    # MECHRA's cell (sc, sr) into ours (dc, dr), colour number for colour number
    for y in range(16):
        for x in range(16):
            r, g, b, a = src.getpixel((sc * 16 + x, sr * 16 + y))
            if a < 128 or (r, g, b) == (255, 0, 255):
                continue
            i = min(range(15), key=lambda k: sum((u - v) ** 2 for u, v in zip(m0[k], (r, g, b))))
            out.putpixel((dc * 16 + x, dr * 16 + y), d0[i] + (255,))

# row 4: ITEM x4 (MECHRA 4-7, 2), BIGP x2 (8-9, 2), GEM x2 (10-11, 2), GUARD (12, 2), SPARK (13, 2)
for k in range(10):
    cell(4 + k, 2, k, 4)
# rows 5-7: the five giant mechs, each its left half 2 cells x 3 (MECHRA's at 4 + 2b, rows 3-5)
for b in range(5):
    for cy in range(3):
        for cx in range(2):
            cell(4 + b * 2 + cx, 3 + cy, b * 2 + cx, 5 + cy)
out.save(os.path.join(G, 'sprites.png'))

pal = dpal + [mpal[0]] + mpal[5:10]
p = Image.new('RGBA', (16, len(pal)))
for y, r in enumerate(pal):
    for x, c in enumerate(r):
        p.putpixel((x, y), c)
p.save(os.path.join(G, 'spr_pal.png'))

lay = open(os.path.join(G, 'layout.txt')).read().rstrip('\n')
if 'MECHRA' not in lay:
    lay = lay.replace('# DEFENDER HYPERSPACE', '# DEFENDER HELLGATE', 1)
    lay += '''
# from MECHRA (tools/merge_mechra.py): palette row 8 the pickups and the guard, 9-13 the giant mechs
sprite ITEM     0 4 4     # a P: spinning
sprite BIGP     4 4 2     # a big P: glinting
sprite GEM      6 4 2     # a gem (score)
sprite GUARD    8 4       # the guard (twice the size, round the ship)
sprite SPARK    9 4       # a shot hitting
sprite BOSS1    0 5 1 2 3 # the giant mechs: their left halves (32 x 48; the right halves mirrored)
sprite BOSS2    2 5 1 2 3
sprite BOSS3    4 5 1 2 3
sprite BOSS4    6 5 1 2 3
sprite BOSS5    8 5 1 2 3
'''
    open(os.path.join(G, 'layout.txt'), 'w').write(lay)
print('merged: sprites.png 256 x 128, %d palette rows' % len(pal))
