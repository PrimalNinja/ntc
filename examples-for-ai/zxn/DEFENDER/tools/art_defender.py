# DEFENDER - the font tiles (the words) for the NTC build: writes ../gfx/*
# (run: python3 tools/art_defender.py)   The sprites are made by Main.bas itself (or DEFENDER.SPR).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from artkit import *
HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', 'gfx')
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)
TP = [c(0,0,0), c(7,7,3)] + [c(0,0,0)] * 12 + [c(1,1,1), MAGENTA]
TP[2] = c(0,0,1)
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=14, paper=0, chars=range(32, 127))
T.put(0, 0, ['ffffffff'] * 8, {'f': 15})
T.save(D + '/tiles.png')
palette_png(D + '/spr_pal.png', [[c(0,0,0)] * 15 + [MAGENTA]])
S = Sheet(16, 1, [c(0,0,0)] * 15 + [MAGENTA])
S.save(D + '/sprites.png')
open(D + '/layout.txt', 'w').write('''# DEFENDER - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
tile   CLEAR    0
sprite NONE     0 0
''')
