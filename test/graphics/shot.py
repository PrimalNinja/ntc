# shot.py - a picture of gfx.bas's screen (from a machine's run tool) compared with expect.py.
#   python3 test/graphics/shot.py NAME picture.png W H [--at=x,y] [--scale=sx,sy] [--skip=x0,y0,x1,y1]
# W x H: the Graphics class's size. --min=N: a dot is on when its red + green + blue is over N (96). --at: where its dot 0, 0 is in the picture; --scale: how many
# of the picture's pixels a dot is. A dot is on when the picture is not black there.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import expect
from PIL import Image
def main():
    a = [x for x in sys.argv[1:] if not x.startswith('--')]; o = dict(x[2:].split('=') for x in sys.argv[1:] if x.startswith('--'))
    name, png, w, h = a[0], a[1], int(a[2]), int(a[3])
    ax, ay = [int(v) for v in o.get('at', '0,0').split(',')]; sx, sy = [float(v) for v in o.get('scale', '1,1').split(',')]
    skip = tuple(int(v) for v in o['skip'].split(',')) if 'skip' in o else None
    im = Image.open(png).convert('RGB'); px = im.load(); lit = set()
    for y in range(h):
        for x in range(w):
            X = int(ax + x * sx + sx / 2); Y = int(ay + y * sy + sy / 2)
            if X < im.size[0] and Y < im.size[1] and sum(px[X, Y]) > int(o.get('min', '96')): lit.add((x, y))
    return 0 if expect.check(name, lit, w, h, skip) else 1
sys.exit(main())
