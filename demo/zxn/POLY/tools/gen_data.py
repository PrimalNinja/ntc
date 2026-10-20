# gen_data.py - POLY's tables, written as E3Data.cls (db lines the Z80 reads directly):
#   the palette (16 ramps of 16 shades, 9 bit), sines, reciprocals for the edges and the
#   projection, and the models. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, math, random
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'E3Data.cls')

# ---------------------------------------------------------------- the palette
# ramp k is palette entries k*16 .. k*16+15, dark to light. Entry 0 is black.
def lerp(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))
RAMPS = [
    ((0, 0, 0), (1.0, 1.0, 1.0)),          # 0 grey (rock, stars; 0 = black)
    ((0.10, 0.06, 0.03), (0.85, 0.65, 0.45)),  # 1 brown rock
    ((0.00, 0.06, 0.16), (0.08, 0.45, 0.62)),  # 2 planet ocean (darker, greener than the sky)
    ((0.03, 0.12, 0.03), (0.55, 0.85, 0.40)),  # 3 planet land / grass
    ((0.00, 0.06, 0.30), (0.50, 0.72, 1.00)),  # 4 sky
    ((0.06, 0.16, 0.04), (0.50, 0.70, 0.30)),  # 5 ground
    ((0.08, 0.08, 0.10), (0.80, 0.80, 0.85)),  # 6 concrete
    ((0.02, 0.06, 0.15), (0.40, 0.75, 0.95)),  # 7 glass
    ((0.15, 0.10, 0.05), (0.95, 0.85, 0.65)),  # 8 sandstone
    ((0.20, 0.03, 0.02), (1.00, 0.60, 0.30)),  # 9 red / fire
    ((0.10, 0.17, 0.32), (0.55, 0.70, 0.95)),  # 10 haze (shade 10 about the low sky)
    ((0.10, 0.02, 0.15), (0.90, 0.60, 1.00)),  # 11 violet
    ((0.15, 0.12, 0.00), (1.00, 0.95, 0.40)),  # 12 gold / windows lit
    ((0.00, 0.10, 0.10), (0.40, 1.00, 0.90)),  # 13 teal
    ((0.10, 0.05, 0.08), (0.75, 0.55, 0.70)),  # 14 dusk
    ((0.00, 0.00, 0.00), (0.50, 0.90, 0.30)),  # 15 hud green
]
def palette():
    out = []
    for k, (a, b) in enumerate(RAMPS):
        for s in range(16):
            t = s / 15.0
            r, g, bb = lerp(a, b, t)
            if k == 0 and s == 0: r = g = bb = 0
            R, G, B = (min(7, int(round(v * 7))) for v in (r, g, bb))
            out += [(R << 5) | (G << 2) | (B >> 1), B & 1]
    return out

# ---------------------------------------------------------------- the tables
def sines():
    return [int(round(math.sin(i * 2 * math.pi / 256) * 127)) & 255 for i in range(256)]

def recip_edge():
    # 65536 / dy for dy 0-1023 (0 and 1: 65535)
    out = []
    for d in range(1024):
        v = 65535 if d < 2 else 65536 // d
        out += [v & 255, v >> 8]
    return out

def recip_proj():
    # 2^24 / n for n 256-4095 (n 256: 65535): the projection's reciprocals
    out = []
    for n in range(256, 4096):
        v = min(65535, (1 << 24) // n)
        out += [v & 255, v >> 8]
    return out

def sqrt_tab():
    # sqrt(1 - (i/255)^2) * 255 for i 0-255: a circle's half width by its row
    return [int(round(math.sqrt(max(0.0, 1 - (i / 255.0) ** 2)) * 255)) for i in range(256)]

# ---------------------------------------------------------------- the models
# a model: vertices (int8 x, y, z), faces (ramp, normal int8 x3, vertex indices clockwise seen
# from outside). Written: nv, nf, radius, verts, then each face: n, ramp, nx, ny, nz, d (16 bit:
# n . v for its vertices), indices
def norm(v):
    l = math.sqrt(sum(c * c for c in v)) or 1
    return [c / l for c in v]

def sub(a, b): return [a[i] - b[i] for i in range(3)]
def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def dot(a, b): return sum(a[i] * b[i] for i in range(3))

def hull_faces(pts):
    # the convex hull's triangles (outward), by brute force (small point sets)
    n = len(pts); faces = []
    for i in range(n):
        for j in range(i + 1, n):
            for k in range(j + 1, n):
                a, b, c = pts[i], pts[j], pts[k]
                nn = cross(sub(b, a), sub(c, a))
                if dot(nn, nn) < 1e-9: continue
                side = [dot(nn, sub(p, a)) for p in pts]
                if all(s <= 1e-6 for s in side): faces.append((i, j, k))
                elif all(s >= -1e-6 for s in side): faces.append((i, k, j))
    return faces

def model_bytes(verts, faces):
    # faces: (ramp, [indices]) wound so the normal points out (counter-clockwise from outside in
    # a right-handed y-up world = clockwise on the screen, y down)
    rad = int(math.ceil(max(math.sqrt(dot(v, v)) for v in verts)))
    out = [len(verts), len(faces), min(255, rad)]
    for v in verts: out += [int(c) & 255 for c in v]
    for ramp, idx in faces:
        a, b, c = [verts[i] for i in idx[:3]]
        nn = norm(cross(sub(b, a), sub(c, a)))
        n8 = [int(round(c * 120)) for c in nn]
        d = dot(n8, a)                     # the plane: n . v = d (visible from e when n . e > d)
        out += [len(idx), ramp] + [c & 255 for c in n8] + [d & 255, (d >> 8) & 255] + list(idx)
    return out

def asteroid(seed, ramp):
    rnd = random.Random(seed)
    pts = []
    phi = (1 + 5 ** 0.5) / 2
    base = [(-1, phi, 0), (1, phi, 0), (-1, -phi, 0), (1, -phi, 0), (0, -1, phi), (0, 1, phi),
            (0, -1, -phi), (0, 1, -phi), (phi, 0, -1), (phi, 0, 1), (-phi, 0, -1), (-phi, 0, 1)]
    for v in base:
        r = 90 + rnd.random() * 35
        u = norm(v)
        pts.append([round(c * r) for c in u])
    tris = hull_faces(pts)
    return model_bytes(pts, [(ramp, list(t)) for t in tris])

def asteroid_lo(seed, ramp):
    # the far version: an octahedron, its corners as far out as the full one's are about there
    rnd = random.Random(seed * 7 + 3)
    base = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    pts = []
    for v in base:
        r = 95 + rnd.random() * 25
        pts.append([round(c * r) for c in v])
    tris = hull_faces(pts)
    return model_bytes(pts, [(ramp, list(t)) for t in tris])

def stars(n=96, seed=11):
    # directions (x, y, z x 126, a unit vector) and a colour (grey ramp shades 6..15, a few blue or
    # gold): 4 bytes each
    rnd = random.Random(seed)
    out = []
    for i in range(n):
        while True:
            v = [rnd.uniform(-1, 1) for _ in range(3)]
            l = math.sqrt(dot(v, v))
            if 0.2 < l <= 1: break
        v = [round(c / l * 126) for c in v]
        b = rnd.random()
        col = 0 * 16 + int(6 + 9 * b * b)
        if rnd.random() < 0.12: col = 4 * 16 + 12 + rnd.randrange(4)
        elif rnd.random() < 0.08: col = 12 * 16 + 10 + rnd.randrange(5)
        out += [v[0] & 255, v[1] & 255, v[2] & 255, col]
    return out

# ---------------------------------------------------------------- the world and the city
PLANET = (157 * 256, -352 * 256, 1172 * 256)   # its middle (world units: multiples of 256)
PRAD = 102400                            # its radius
def site():
    # the city: on the planet where it faces the start (0, 0, 0); its frame: east, up, north
    # (east x up = north), s1.14
    c = PLANET
    up = norm([-c[0], -c[1], -c[2]])
    s = [c[i] + PRAD * up[i] for i in range(3)]
    east = norm(cross(up, [0, 0, 1]))   # (up x z: roughly along x)
    north = cross(east, up)
    return [round(v) for v in s], up, east, north

CELLS = 48                               # the city: 48 x 48 cells of 128 units
TYPES = [  # half width, half depth (units), height (units / 4), ramp
    (40, 40, 15, 6), (48, 36, 30, 7), (36, 48, 45, 8), (52, 52, 22, 6),
    (32, 32, 70, 7), (44, 44, 55, 13), (56, 40, 12, 9), (40, 56, 100, 7)]

def city(seed=5):
    rnd = random.Random(seed)
    m = []
    for j in range(CELLS):
        for i in range(CELLS):
            if i % 4 == 0 or j % 4 == 0:      # the roads
                m.append(0); continue
            dx, dz = i - CELLS / 2 + 0.5, j - CELLS / 2 + 0.5
            r = math.sqrt(dx * dx + dz * dz) / (CELLS / 2)
            if r > 1.0 or rnd.random() < 0.15 + 0.35 * r:
                m.append(0); continue
            if r < 0.35: t = rnd.choice([4, 5, 7, 7, 1, 2])     # the middle: tall
            elif r < 0.7: t = rnd.choice([1, 2, 3, 5, 0])
            else: t = rnd.choice([0, 3, 6, 6])
            m.append(t + 1)
    return m

def blocks():
    # the city's blocks (the 3 x 3 cells between roads), 12 x 12: their buildings' mean height
    # (units / 4; 0 none) and a ramp (the commonest), 2 bytes each - the far view's boxes
    m = city()
    out = []
    for bj in range(CELLS // 4):
        for bi in range(CELLS // 4):
            hs = []; ramps = []
            for j in range(4 * bj + 1, 4 * bj + 4):
                for i in range(4 * bi + 1, 4 * bi + 4):
                    t = m[j * CELLS + i]
                    if t:
                        hs.append(TYPES[t - 1][2]); ramps.append(TYPES[t - 1][3])
            if len(hs) < 2:
                out += [0, 0]
            else:
                out += [max(4, int(sum(hs) / len(hs) * 0.9)), max(set(ramps), key=ramps.count)]
    return out

def citydata():
    s, up, east, north = site()
    out = []
    for v in s:                          # 24 bits each
        v &= 0xFFFFFF
        out += [v & 255, (v >> 8) & 255, (v >> 16) & 255]
    for vec in (east, up, north):        # the frame: rows (east, up, north), s1.14
        for c in vec:
            w = round(c * 16384) & 0xFFFF
            out += [w & 255, w >> 8]
    for w, d, h, ramp in TYPES:
        out += [w, d, h, ramp]
    return out

# a 5 x 7 font (in 6 x 8 cells): space, 0-9, A-Z, - . : / % (the HUD's)
FONT = {
 ' ': ["     "]*7,
 '0': [" ### ","#   #","#  ##","# # #","##  #","#   #"," ### "],
 '1': ["  #  "," ##  ","  #  ","  #  ","  #  ","  #  "," ### "],
 '2': [" ### ","#   #","    #","   # ","  #  "," #   ","#####"],
 '3': ["#####","   # ","  #  ","   # ","    #","#   #"," ### "],
 '4': ["   # ","  ## "," # # ","#  # ","#####","   # ","   # "],
 '5': ["#####","#    ","#### ","    #","    #","#   #"," ### "],
 '6': ["  ## "," #   ","#    ","#### ","#   #","#   #"," ### "],
 '7': ["#####","    #","   # ","  #  "," #   "," #   "," #   "],
 '8': [" ### ","#   #","#   #"," ### ","#   #","#   #"," ### "],
 '9': [" ### ","#   #","#   #"," ####","    #","   # "," ##  "],
 'A': [" ### ","#   #","#   #","#####","#   #","#   #","#   #"],
 'B': ["#### ","#   #","#   #","#### ","#   #","#   #","#### "],
 'C': [" ### ","#   #","#    ","#    ","#    ","#   #"," ### "],
 'D': ["#### ","#   #","#   #","#   #","#   #","#   #","#### "],
 'E': ["#####","#    ","#    ","#### ","#    ","#    ","#####"],
 'F': ["#####","#    ","#    ","#### ","#    ","#    ","#    "],
 'G': [" ### ","#   #","#    ","# ###","#   #","#   #"," ####"],
 'H': ["#   #","#   #","#   #","#####","#   #","#   #","#   #"],
 'I': [" ### ","  #  ","  #  ","  #  ","  #  ","  #  "," ### "],
 'J': ["  ###","   # ","   # ","   # ","   # ","#  # "," ##  "],
 'K': ["#   #","#  # ","# #  ","##   ","# #  ","#  # ","#   #"],
 'L': ["#    ","#    ","#    ","#    ","#    ","#    ","#####"],
 'M': ["#   #","## ##","# # #","# # #","#   #","#   #","#   #"],
 'N': ["#   #","#   #","##  #","# # #","#  ##","#   #","#   #"],
 'O': [" ### ","#   #","#   #","#   #","#   #","#   #"," ### "],
 'P': ["#### ","#   #","#   #","#### ","#    ","#    ","#    "],
 'Q': [" ### ","#   #","#   #","#   #","# # #","#  # "," ## #"],
 'R': ["#### ","#   #","#   #","#### ","# #  ","#  # ","#   #"],
 'S': [" ####","#    ","#    "," ### ","    #","    #","#### "],
 'T': ["#####","  #  ","  #  ","  #  ","  #  ","  #  ","  #  "],
 'U': ["#   #","#   #","#   #","#   #","#   #","#   #"," ### "],
 'V': ["#   #","#   #","#   #","#   #","#   #"," # # ","  #  "],
 'W': ["#   #","#   #","#   #","# # #","# # #","# # #"," # # "],
 'X': ["#   #","#   #"," # # ","  #  "," # # ","#   #","#   #"],
 'Y': ["#   #","#   #"," # # ","  #  ","  #  ","  #  ","  #  "],
 'Z': ["#####","    #","   # ","  #  "," #   ","#    ","#####"],
 '-': ["     ","     ","     ","#####","     ","     ","     "],
 '.': ["     ","     ","     ","     ","     "," ##  "," ##  "],
 ':': ["     "," ##  "," ##  ","     "," ##  "," ##  ","     "],
 '/': ["    #","    #","   # ","  #  "," #   ","#    ","#    "],
 '%': ["##   ","##  #","   # ","  #  "," #   ","#  ##","   ##"],
}
FONT_CHARS = ' 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-.:/%'
def font():
    # 7 bytes a character (rows, bit 7 the left), in FONT_CHARS' order
    out = []
    for ch in FONT_CHARS:
        for row in FONT[ch]:
            b = 0
            for i, c in enumerate(row):
                if c == '#': b |= 0x80 >> i
            out.append(b)
    return out

def font_index():
    # ASCII 32..95 -> the font's character (0: space)
    return [FONT_CHARS.index(chr(c)) if chr(c) in FONT_CHARS else 0 for c in range(32, 96)]

def write():
    # models: 0-3 the asteroids, 4-7 their far versions (ModelTab: each model's near and far)
    models = [asteroid(1, 0), asteroid(2, 1), asteroid(3, 0), asteroid(4, 1),
              asteroid_lo(1, 0), asteroid_lo(2, 1), asteroid_lo(3, 0), asteroid_lo(4, 1)]
    lod = [(0, 4), (1, 5), (2, 6), (3, 7)]
    L = ["' E3Data - POLY's tables and models, made by tools/gen_data.py: don't edit, run it",
         "' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License",
         'Option Explicit', '',
         'Public Const Models = %d' % len(models), '']
    def block(name, data, comment):
        L.append("' %s" % comment)
        L.append('Public Function %s() As Integer' % name)
        L.append('#asm')
        L.append('            pop hl')
        L.append('            ld de, %s_d' % name.lower())
        L.append('            ld (hl), e')
        L.append('            inc hl')
        L.append('            ld (hl), d')
        L.append('            jp %s_e' % name.lower())
        L.append('%s_d:' % name.lower())
        for i in range(0, len(data), 16):
            L.append('            db ' + ', '.join(str(b) for b in data[i:i + 16]))
        L.append('%s_e:' % name.lower())
        L.append('#endasm')
        L.append('End Function')
        L.append('')
    block('Pal', palette(), 'Pal(): the palette, 256 x 2 bytes (9 bit colours)')
    block('Sines', sines(), 'Sines(): 256 signed bytes, x 127')
    block('REdge', recip_edge(), 'REdge(): 65536 / dy, dy 0-1023')
    block('RProj', recip_proj(), 'RProj(): 2^24 / n, n 256-4095')
    block('CitySite', citydata(), 'CitySite(): the city: its site (24 bits x 3), its frame (east, up, north: s1.14), 8 kinds of building (half width, half depth, height / 4, ramp)')
    block('CityBlocks', blocks(), 'CityBlocks(): the city\'s 12 x 12 blocks: mean height (units / 4, 0 none), ramp')
    block('CityMap', city(), 'CityMap(): the city: 48 x 48 cells (rows of x; 0 none, else 1 + a kind)')
    block('Font', font(), 'Font(): the HUD font, 5 x 7 (7 bytes a character: space, 0-9, A-Z, - . : / %)')
    block('FontIx', font_index(), 'FontIx(): ASCII 32..95 to the font\'s characters')
    block('Stars', stars(), 'Stars(): 96 stars: a direction (x, y, z x 126) and a colour each')
    block('SqrtT', sqrt_tab(), 'SqrtT(): a circle row\'s half width x 255, by row / radius x 255')
    allm = []
    offs = []
    for m in models:
        offs.append(len(allm)); allm += m
    block('ModelData', allm, 'ModelData(): the models one after another')
    tab = []
    for hi, lo in lod:
        tab += [offs[hi] & 255, offs[hi] >> 8, offs[lo] & 255, offs[lo] >> 8]
    L.append("' ModelTab(): the kinds' models (near, far), offsets in ModelData (2 x 2 bytes each)")
    L.append('Public Function ModelTab() As Integer')
    L.append('#asm')
    L.append('            pop hl')
    L.append('            ld de, modeltab_d')
    L.append('            ld (hl), e')
    L.append('            inc hl')
    L.append('            ld (hl), d')
    L.append('            jp modeltab_e')
    L.append('modeltab_d:')
    for i in range(0, len(tab), 16):
        L.append('            db ' + ', '.join(str(b) for b in tab[i:i + 16]))
    L.append('modeltab_e:')
    L.append('#endasm')
    L.append('End Function')
    L.append('')
    L.append("' ModelAt(n): where model n starts")
    L.append('Public Function ModelAt(ByVal n As Integer) As Integer')
    L.append('  Select Case n')
    for i, o in enumerate(offs):
        L.append('    Case %d: ModelAt = ModelData() + %d' % (i, o))
    L.append('  End Select')
    L.append('End Function')
    L.insert(5, 'Public Const Kinds = %d' % len(lod))
    L.insert(6, 'Public Const NStars = 96')
    for k, v in (('PlanetX', PLANET[0] // 256), ('PlanetY', PLANET[1] // 256), ('PlanetZ', PLANET[2] // 256), ('PlanetR', PRAD // 256)):
        L.insert(7, 'Public Const %s = %d   \' (world units / 256: for E3.ppos, prad)' % (k, v))
    open(OUT, 'w').write('\n'.join(L) + '\n')
    print('E3Data.cls:', ', '.join('model %d %d bytes' % (i, len(m)) for i, m in enumerate(models)))

if __name__ == '__main__':
    write()
