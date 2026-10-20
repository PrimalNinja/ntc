# CHAOTIC - the 16 webs: writes ../Shapes.cls (the data) and shapes_preview.png
# (run: python3 tools/shapes.py)   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# Each web is 16 lanes. A lane runs from the inner edge (far away, small) to the rim (near you).
# The rim is 17 points (closed webs: the 17th is the 1st again), the inner edge the same 17
# points pulled in towards a vanishing point. Coordinates are Layer 2's (0-255 across, 0-191 down).
import os, math
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
CX, CY = 128, 100          # the middle of the play area
R = 86                     # how far out the rim reaches (down); across it's scaled 1.3
K = 0.14                   # the inner edge's size against the rim's

def resample(pts, closed, n=16):
    # n equal steps along the path through pts (closed: back to the start)
    path = pts + ([pts[0]] if closed else [])
    segs = [math.dist(path[i], path[i + 1]) for i in range(len(path) - 1)]
    total = sum(segs)
    out = []
    for k in range(n + 1):
        d = total * k / n
        i = 0
        while i < len(segs) - 1 and d > segs[i]:
            d -= segs[i]; i += 1
        t = d / segs[i] if segs[i] else 0
        a, b = path[i], path[i + 1]
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out

def poly(n, r=1.0, rot=0.0):
    return [(r * math.sin(rot + 2 * math.pi * k / n), -r * math.cos(rot + 2 * math.pi * k / n)) for k in range(n)]

def corners(pts, closed, n=16):
    # put the points on the corners where the counts allow (a square: 4 a side)
    m = len(pts)
    if closed and n % m == 0:
        out = []
        for k in range(m):
            a, b = pts[k], pts[(k + 1) % m]
            for j in range(n // m):
                t = j / (n // m)
                out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        return out + [out[0]]
    return resample(pts, closed, n)

S = []   # (name, rim points (unit), closed, vanishing point offset (unit))
def add(name, pts, closed, vp=(0, 0), exact=False):
    S.append((name, corners(pts, closed) if exact else resample(pts, closed), closed, vp))

add('CIRCLE', [(math.sin(a / 64 * 2 * math.pi), -math.cos(a / 64 * 2 * math.pi)) for a in range(64)], True)
add('SQUARE', [(-0.8, -0.8), (0.8, -0.8), (0.8, 0.8), (-0.8, 0.8)], True, exact=True)
add('CROSS', [(-0.33, -1), (0.33, -1), (0.33, -0.33), (1, -0.33), (1, 0.33), (0.33, 0.33), (0.33, 1),
              (-0.33, 1), (-0.33, 0.33), (-1, 0.33), (-1, -0.33), (-0.33, -0.33)], True)
add('FLAT', [(-1.05, 0.85), (1.05, 0.85)], False, vp=(0, -1.0))
add('STAR', [(p[0] * (1 if k % 2 == 0 else 0.45), p[1] * (1 if k % 2 == 0 else 0.45)) for k, p in enumerate(poly(16))], True, exact=True)
add('VEE', [(-1.05, 0.0), (0, 0.95), (1.05, 0.0)], False, vp=(0, -1.0))
add('TRIANGLE', poly(3, 1.05, math.pi), True, vp=(0, 0.1))
add('BOWTIE', [(-1, -0.8), (0, -0.25), (1, -0.8), (1, 0.8), (0, 0.25), (-1, 0.8)], True)
add('U', [(-0.9, -0.2), (-0.9, 0.5), (-0.5, 0.9), (0.5, 0.9), (0.9, 0.5), (0.9, -0.2)], False, vp=(0, -1.0))
add('HEART', [(0.0, -0.45), (0.25, -0.85), (0.65, -0.95), (0.95, -0.65), (0.95, -0.2), (0.5, 0.4),
              (0.0, 0.95), (-0.5, 0.4), (-0.95, -0.2), (-0.95, -0.65), (-0.65, -0.95), (-0.25, -0.85)], True)
add('STEPS', [(-1.05, -0.1), (-0.55, -0.1), (-0.55, 0.4), (0, 0.4), (0, 0.9), (0.55, 0.9),
              (0.55, 0.4), (1.05, 0.4)], False, vp=(0, -1.0))
add('HEXAGON', poly(6, 1.0, math.pi / 6), True)
add('WAVE', [(-1.05 + 2.1 * k / 40, 0.45 + 0.4 * math.sin(k / 40 * 3 * math.pi)) for k in range(41)], False, vp=(0, -1.0))
add('PEANUT', [((1.0 + 0.0) * math.sin(a / 64 * 2 * math.pi), -(0.55 + 0.4 * abs(math.sin(a / 64 * 2 * math.pi))) * math.cos(a / 64 * 2 * math.pi)) for a in range(64)], True)
add('DOUBLEV', [(-1.05, 0.0), (-0.5, 0.9), (0, 0.2), (0.5, 0.9), (1.05, 0.0)], False, vp=(0, -1.0))
add('DIAMOND', [(0, -1.05), (1.0, 0), (0, 1.05), (-1.0, 0)], True, exact=True)
assert len(S) == 16

def to_screen(p):
    return (CX + p[0] * R * 1.3, CY + p[1] * R)

def clamp(v, lo, hi): return max(lo, min(hi, int(round(v))))

# the depth curve: how far from the inner edge (0) to the rim (255) a thing at depth d (0-64) is
# drawn - perspective, so the far end is squeezed
def depth_t(d):
    u = d / 64
    s = 1 / (1 / K + (1 - 1 / K) * u)
    lin = u
    return 0.7 * (s - K) / (1 - K) + 0.3 * lin

TT = [clamp(depth_t(d) * 255, 0, 255) for d in range(65)]

# the claw's way: 0 up, 1 up-right ... 7 up-left (pointing in, across the rim)
def claw_dir(a, b, vpx, vpy):
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    # the rim's normal, the side towards the vanishing point
    nx, ny = -(b[1] - a[1]), b[0] - a[0]
    if nx * (vpx - mx) + ny * (vpy - my) < 0: nx, ny = -nx, -ny
    ang = math.atan2(nx, -ny)          # 0 up, clockwise
    return int(round(ang / (math.pi / 4))) % 8

data = []
img = Image.new('RGB', (256 * 4, 192 * 4), (0, 0, 0))
dr = ImageDraw.Draw(img)
for n, (name, pts, closed, vp) in enumerate(S):
    rim = [to_screen(p) for p in pts]
    vpx, vpy = CX + vp[0] * R * 1.3, CY + vp[1] * R
    k = K if closed else 0.3
    inn = [(vpx + (x - vpx) * k, vpy + (y - vpy) * k) for x, y in rim]
    rx = [clamp(x, 4, 251) for x, y in rim]; ry = [clamp(y, 4, 187) for x, y in rim]
    ix = [clamp(x, 4, 251) for x, y in inn]; iy = [clamp(y, 4, 187) for x, y in inn]
    claw = [claw_dir(rim[k], rim[k + 1], vpx, vpy) for k in range(16)]
    rec = rx + ry + ix + iy + [1 if closed else 0] + [0, 0, 0] + claw + [0] * 8
    assert len(rec) == 96
    data += rec
    ox, oy = (n % 4) * 256, (n // 4) * 192
    for k in range(17 if not closed else 16):
        dr.line([(ox + ix[k], oy + iy[k]), (ox + rx[k], oy + ry[k])], fill=(60, 60, 255))
    for k in range(16):
        dr.line([(ox + rx[k], oy + ry[k]), (ox + rx[k + 1], oy + ry[k + 1])], fill=(120, 120, 255))
        dr.line([(ox + ix[k], oy + iy[k]), (ox + ix[k + 1], oy + iy[k + 1])], fill=(120, 120, 255))
    dr.text((ox + 4, oy + 4), name, fill=(255, 255, 0))
img.save(os.path.join(HERE, 'shapes_preview.png'))

names = [s[0] for s in S]
lines = ["' Shapes - CHAOTIC's 16 webs and the depth curve, made by tools/shapes.py.",
         "' Don't edit: change tools/shapes.py and run  python3 tools/shapes.py",
         "' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License",
         "' Webs(): the address of 16 records of 96 bytes: rim x (17), rim y (17), inner x (17),",
         "' inner y (17), closed (1 = the 17th point is the 1st), 3 spare, the claw's way for each lane",
         "' (16: 0 up, 1 up-right ... 7 up-left), 8 spare.",
         "' Depth(): the address of 65 bytes: how far out (0 inner edge - 255 rim) depth 0-64 is drawn.",
         "' The webs: " + ', '.join(names),
         "Option Explicit", "",
         "Public Const NSHAPE = 16, REC = 96", "",
         "Public Function Webs() As Integer", "#asm",
         "            pop hl", "            ld de, wb_data", "            ld (hl), e", "            inc hl",
         "            ld (hl), d", "            ret", "wb_data:"]
for i in range(0, len(data), 16):
    lines.append('            db ' + ', '.join(str(v) for v in data[i:i + 16]))
lines += ["#endasm", "End Function", "",
          "Public Function Depth() As Integer", "#asm",
          "            pop hl", "            ld de, dp_data", "            ld (hl), e", "            inc hl",
          "            ld (hl), d", "            ret", "dp_data:"]
for i in range(0, 65, 16):
    lines.append('            db ' + ', '.join(str(v) for v in TT[i:i + 16]))
lines += ["#endasm", "End Function", ""]
open(os.path.join(HERE, '..', 'Shapes.cls'), 'w').write('\n'.join(lines))
print('16 webs,', len(data), 'bytes; depth', TT[::8])
