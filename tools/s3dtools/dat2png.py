# dat2png.py AUCKLAND.DAT out.png [buildings|trees|all]: the data from above - buildings white,
# trees green, coast and water cyan, roads grey (all); 24 pixels a 384 m tile
import struct, sys
from PIL import Image, ImageDraw
d = open(sys.argv[1], 'rb').read()
what = sys.argv[3] if len(sys.argv) > 3 else 'all'
nx, nz = struct.unpack('<HH', d[4:8]); B = 16384; T = 24; f = T / 192.0
W, H = nx * T, nz * T
im = Image.new('RGB', (W, H)); dr = ImageDraw.Draw(im)
for k in range(nx * nz):
    b = d[64 + 3 * k]
    if not b:
        continue
    t = b * B + (d[65 + 3 * k] | d[66 + 3 * k] << 8)
    cx = (k % nx) * T + T / 2; cy = H - ((k // nx) * T + T / 2)
    n0, n1, n2, nl, n3, nt, o3, otr = struct.unpack('<8H', d[t:t + 16])
    p = t + 16
    pt = lambda q: (cx + struct.unpack('b', d[q:q + 1])[0] * f, cy - struct.unpack('b', d[q + 1:q + 2])[0] * f)
    for i in range(n0 + n1 + n2):
        n = d[p]; pts = [pt(p + 2 + 2 * j) for j in range(n)]; p += 2 + 2 * n
        if what in ('all', 'buildings') and n > 1:
            dr.polygon(pts, outline=(255, 255, 255))
    for i in range(nl):
        n = d[p]; ty = d[p + 1]; pts = [pt(p + 2 + 2 * j) for j in range(n)]; p += 2 + 2 * n
        if n > 1 and ty in (4, 5):
            dr.line(pts, fill=(0, 200, 255))
        elif n > 1 and what == 'all':
            dr.line(pts, fill=(110, 110, 110))
    if what in ('all', 'trees'):
        p = t + otr
        for i in range(nt):
            dr.point(pt(p), fill=(0, 255, 0)); p += 2
im.save(sys.argv[2])
print(sys.argv[2], im.size)
