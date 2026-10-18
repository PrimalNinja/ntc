# STACKER - the tiles and sprites: writes ../gfx/*
# (run: python3 tools/art_stacker.py)   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# A block is one tile drawn in colours 1 (its shine), 2-4 (light, middle, dark): Main gives each
# piece its own palette row, so the one tile makes all seven colours.
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from artkit import *
from cvkit import Cv

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', 'gfx')
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)

# 0 black, 1 white, 2-4 a block's light / middle / dark, 5 the well's floor, 6 its grid dots,
# 7-9 the frame light / middle / dark, 14 the font's shadow
TP = [c(0,0,0), c(7,7,3), c(3,7,3), c(0,5,3), c(0,2,2), c(0,0,1), c(1,1,1), c(6,6,3),
      c(4,4,2), c(2,2,1), c(1,0,1), c(2,0,1), c(1,1,0), c(0,1,0), c(1,1,2), MAGENTA]
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=14, paper=0, chars=range(32, 96))
K = {('%x' % i): i for i in range(16)}; K['.'] = 15
def tile(n, rows): T.put(n % 16, n // 16, rows, K)
tile(0, ['ffffffff'] * 8)                       # see-through (Layer 2 behind)
tile(1, ['00000000'] * 8)                       # black
tile(2, ['11122223', '12222223', '12222233', '22233334', '22333334', '23333344', '33333444', '34444444'])   # a block
tile(3, ['33333333', '30000003', '30000003', '30000003', '30000003', '30000003', '30000003', '33333333'])   # the ghost
tile(4, ['55555555', '55555555', '55555555', '55555555', '55555555', '55555555', '55555555', '55555556'])   # the well's floor
# the frame: top left, top, top right, left, right, bottom left, bottom, bottom right
tile(5, ['........', '.7777777', '.7888888', '.7899999', '.7890000', '.7890000', '.7890000', '.7890000'])
tile(6, ['........', '77777777', '88888888', '99999999', '00000000', '00000000', '00000000', '00000000'])
tile(7, ['........', '7777777.', '8888889.', '9999989.', '0000789.', '0000789.', '0000789.', '0000789.'])
tile(8, ['.7890000'] * 8)
tile(9, ['0000789.'] * 8)
tile(10, ['.7890000', '.7890000', '.7890000', '.7890000', '.7899999', '.7888888', '.9999999', '........'])
tile(11, ['00000000', '00000000', '00000000', '00000000', '99999999', '88888888', '99999999', '........'])
tile(12, ['0000789.', '0000789.', '0000789.', '0000789.', '9999989.', '8888889.', '9999999.', '........'])
tile(13, ['00000000'] * 8)                      # (a panel's inside)
T.save(D + '/tiles.png')

# ---------------------------------------------------------------- sprites: the title's big blocks
SP0 = [c(0,0,0), c(7,7,3), c(3,7,3), c(0,5,3), c(0,2,2)] + [c(0,0,0)] * 10 + [MAGENTA]
# the pieces' colours (light, middle, dark): I O T S Z J L
PC = [((3,7,3), (0,6,3), (0,3,2)), ((7,7,1), (6,6,0), (3,3,0)), ((6,3,3), (4,0,3), (2,0,1)), ((3,7,1), (1,5,0), (0,2,0)),
      ((7,3,2), (6,0,0), (3,0,0)), ((3,4,3), (1,1,3), (0,0,2)), ((7,5,1), (7,3,0), (4,1,0))]
rows = [SP0]
for l, m, d in PC:
    r = SP0[:]; r[2], r[3], r[4] = c(*l), c(*m), c(*d); rows.append(r)
palette_png(D + '/spr_pal.png', rows)
def hx(t): return '%02X' % (t[0] << 5 | t[1] << 2 | t[2])
for k, (l, m, d) in enumerate(PC):
    print('piece %d: 00FF%s%s%s' % (k + 1, hx(l), hx(m), hx(d)))
S = Sheet(16, 1, SP0)
v = Cv(16, 16)
v.rect(0, 0, 15, 15, 3); v.rect(0, 0, 15, 1, 2); v.rect(0, 0, 1, 15, 2); v.rect(14, 0, 15, 15, 4); v.rect(0, 14, 15, 15, 4)
v.rect(2, 2, 4, 3, 1); v.rect(2, 2, 3, 4, 1)
v.into(S, 0, 0)
S.save(D + '/sprites.png')

open(D + '/layout.txt', 'w').write('''# STACKER - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
# tile   NAME   index [count]
# sprite NAME   column row [frames [w h]]
tile   CLEAR    0
tile   BLACK    1
tile   BLOCK    2
tile   GHOST    3
tile   FLOOR    4
tile   FRAME    5 8       # top left, top, top right, left, right, bottom left, bottom, bottom right
tile   PANEL    13
sprite BIG      0 0       # a block, drawn big on the title
''')
