# ref.py - ZX Craft's renderer in Python, with the same integer steps as the Z80 one (Vox.cls,
# made by gen_vox.py), to try changes on and to check the Z80's pictures against. (c) 2026 Cyborg
# Unicorn Pty Ltd - MIT License.  python3 ref.py: pictures of a few views (ref_N.png) and counts.
# front to back by Manhattan distance, a coverage list a row, every pixel written once.
import math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import world

W, H = 128, 80          # logical pixels (2 x 2 on Layer 2)
NEAR = 32
OX, OY = 128, 128       # screen x' = OX + 64x/z (visible 64..191), y' = OY - 64y/z (visible 88..167)
XL, XR, YT, YB = 64, 192, 88, 168

SIN = [int(round(16384 * math.sin(2 * math.pi * a / 256))) for a in range(256)]
def COS(a): return SIN[(a + 64) & 255]
def fix(a, b):          # a * b >> 14, signed (vm_fix)
    p = a * b
    return p >> 14       # floor, as an arithmetic shift of the product

# reciprocal tables
RA = [0] * 1024
for z in range(1, 1024): RA[z] = min(65535, (2 ** 21 + z // 2) // z)
RB = [0] * 768
for j in range(768):
    zm = 1024 + 4 * j + 2; RB[j] = min(65535, (2 ** 26 + zm // 2) // zm)
RC = [0] * 768
for j in range(768):
    zm = 4096 + 16 * j + 8; RC[j] = min(65535, (2 ** 28 + zm // 2) // zm)
RY = [0] * 256
for d in range(2, 256): RY[d] = 65536 // d

def proj_q(a, z):
    # 64 * a / z, a >= 0, z in NEAR..16383: a x R as ah rh << 8 + ah rl + al rh (al rl left out)
    if z < 1024: R = RA[z]; sh = 7
    elif z < 4096: R = RB[(z - 1024) >> 2]; sh = 12
    else: R = RC[(z - 4096) >> 4]; sh = 14
    ah, al, rh, rl = a >> 8, a & 255, R >> 8, R & 255
    return ((ah * rh << 8) + ah * rl + al * rh) >> sh

# faces: (corner offsets in order), outward normal
FACES = [
    [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],   # -X
    [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)],   # +X
    [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],   # -Y
    [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)],   # +Y
    [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)],   # -Z
    [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)],   # +Z
]
NB = [(-1, 0, 0), (1, 0, 0), (0, -1, 0), (0, 1, 0), (0, 0, -1), (0, 0, 1)]

class Stats:
    def __init__(s): s.__dict__.update(groups=0, cells=0, faces=0, slow=0, corners=0, edgerows=0, spans=0, fills=0, fillpx=0, maxiv=0, culled=0, clipped=0, ccull=0)

class Ref:
    def __init__(s, blk):
        s.blk = blk
        s.colours = world.colours()
        s.sky = world.sky()
        s.build()
        s.stamp = [0] * 4913; s.csx = [0] * 4913; s.csy = [0] * 4913; s.fr = 0
    def solid(s, x, y, z):
        if 0 <= x < 16 and 0 <= y < 16 and 0 <= z < 16: return s.blk[world.idx(x, y, z)] != 0
        return False
    def build(s):
        s.groups = [[] for _ in range(64)]
        for y in range(16):
            for z in range(16):
                for x in range(16):
                    t = s.blk[world.idx(x, y, z)]
                    if not t: continue
                    m = 0
                    for f, (dx, dy, dz) in enumerate(NB):
                        if not s.solid(x + dx, y + dy, z + dz): m |= 1 << f
                    if m: s.groups[(x >> 2) + (z >> 2) * 4 + (y >> 2) * 16].append((x, y, z, m, t))
        s.ncells = sum(len(g) for g in s.groups)
    # ---- a frame
    def render(s, cx, cy, cz, yaw, pitch):
        st = s.st = Stats()
        s.fr += 1
        sy_, cy_ = SIN[yaw & 255], COS(yaw)
        sp, cp = SIN[pitch & 255], COS(pitch)
        F = (fix(sy_, cp), sp, fix(cy_, cp))
        R = (cy_, 0, -sy_)
        U = (-fix(sy_, sp), cp, -fix(cy_, sp))
        s.TX = [(fix(i * 256 - cx, R[0]), fix(i * 256 - cx, U[0]), fix(i * 256 - cx, F[0])) for i in range(17)]
        s.TY = [(0, fix(j * 256 - cy, U[1]), fix(j * 256 - cy, F[1])) for j in range(17)]
        s.TZ = [(fix(k * 256 - cz, R[2]), fix(k * 256 - cz, U[2]), fix(k * 256 - cz, F[2])) for k in range(17)]
        s.fb = [[None] * W for _ in range(H)]     # what was written (to check: once each)
        s.iv = [[] for _ in range(H)]
        s.full = 0
        ccx, ccy, ccz = cx >> 8, cy >> 8, cz >> 8
        s.cam = (ccx, ccy, ccz)
        cg = [max(-1, min(4, c >> 2)) for c in (ccx, ccy, ccz)]
        buckets = [[] for _ in range(16)]
        s.gst = [False] * 64
        s.hd = [((s.TX[1][c] - s.TX[0][c]) + (s.TY[1][c] - s.TY[0][c]) + (s.TZ[1][c] - s.TZ[0][c])) >> 1 for c in range(3)]
        for g in range(64):
            if not s.groups[g]: continue
            gx, gz, gy = g & 3, (g >> 2) & 3, g >> 4
            # the frustum, a sphere round the group's middle
            x, y, z = s.corner_cam(gx * 4 + 2, gy * 4 + 2, gz * 4 + 2)
            if z < -887 or x - z > 1254 or -x - z > 1254 or y - (z >> 1) - (z >> 3) > 1046 or -y - (z >> 1) - (z >> 3) > 1046:
                st.culled += 1; continue
            d = abs(gx - cg[0]) + abs(gy - cg[1]) + abs(gz - cg[2])
            t = (z >> 1) + (z >> 3)
            inside = z > 887 and x - z < -1254 and -x - z < -1254 and y - t < -1046 and -y - t < -1046
            s.gst[g] = not inside
            buckets[d].insert(0, g)     # (in front: the Z80's lists are pushed on)
        for d in range(16):
            for g in buckets[d]:
                if s.full == H: break
                st.groups += 1
                s.do_group(g)
        # the sky in what's left
        for r in range(H):
            s.cover(r, 0, W, s.sky[r])
        return st
    def do_group(s, g):
        ccx, ccy, ccz = s.cam
        cells = s.groups[g]
        gx, gz, gy = (g & 3) * 4, ((g >> 2) & 3) * 4, (g >> 4) * 4
        def mind(c, lo): return lo - c if c < lo else (c - lo - 3 if c > lo + 3 else 0)
        dmin = mind(ccx, gx) + mind(ccy, gy) + mind(ccz, gz)
        bk = [[] for _ in range(10)]
        for c in cells:
            x, y, z = c[0], c[1], c[2]
            d = abs(x - ccx) + abs(y - ccy) + abs(z - ccz) - dmin
            bk[d].insert(0, c)
        for b in bk:
            for (x, y, z, m, t) in b:
                s.st.cells += 1
                v = 0
                if ccx < x: v |= 1
                if ccx > x: v |= 2
                if ccy < y: v |= 4
                if ccy > y: v |= 8
                if ccz < z: v |= 16
                if ccz > z: v |= 32
                v &= m
                if not v: continue
                if s.gst[g]:
                    cx_, cy_, cz_ = s.corner_cam(x, y, z)
                    cx_ += s.hd[0]; cy_ += s.hd[1]; cz_ += s.hd[2]
                    tt = (cz_ >> 1) + (cz_ >> 3)
                    if cz_ < -224 or cx_ - cz_ > 316 or -cx_ - cz_ > 316 or cy_ - tt > 264 or -cy_ - tt > 264:
                        s.st.ccull += 1; continue
                for f in range(6):
                    if v & (1 << f):
                        col = s.colours[t * 8 + f]
                        if f == 3 and (x + z) & 1: col = s.colours[t * 8 + 6]
                        s.face(x, y, z, f, col)
    def corner_cam(s, i, j, k):
        a, b, c = s.TX[i], s.TY[j], s.TZ[k]
        return (a[0] + b[0] + c[0], a[1] + b[1] + c[1], a[2] + b[2] + c[2])
    def corner(s, i, j, k):
        gid = i + 17 * k + 289 * j
        if s.stamp[gid] == s.fr: return s.csx[gid], s.csy[gid]
        s.st.corners += 1
        x, y, z = s.corner_cam(i, j, k)
        X = Y = 255
        if z >= NEAR and z < 16384 and abs(x) <= 2 * z and abs(y) <= 2 * z:
            qx = proj_q(abs(x), z); qy = proj_q(abs(y), z)
            X = OX + qx if x >= 0 else OX - qx
            Y = OY - qy if y >= 0 else OY + qy
            if not (0 <= X <= 254 and 0 <= Y <= 254): X = Y = 255
        s.stamp[gid] = s.fr; s.csx[gid] = X; s.csy[gid] = Y
        return X, Y
    def face(s, x, y, z, f, col):
        s.st.faces += 1
        pts = []
        for (dx, dy, dz) in FACES[f]:
            X, Y = s.corner(x + dx, y + dy, z + dz)
            if Y == 255: return s.slow(x, y, z, f, col)
            pts.append((X, Y))
        s.raster(pts, col)
    def slow(s, x, y, z, f, col):
        # a face with a corner too near (z < NEAR: cut at the near plane) or off the fast range:
        # projected in 16 bits, dropped when off the screen, cut to the guard band 0 .. 254
        s.st.slow += 1
        P = [s.corner_cam(x + dx, y + dy, z + dz) for (dx, dy, dz) in FACES[f]]
        if any(p[2] >= 16384 for p in P): return
        if any(p[2] < NEAR for p in P):
            out = []
            for i in range(len(P)):
                a, b = P[i], P[(i + 1) % len(P)]
                ain, bin_ = a[2] >= NEAR, b[2] >= NEAR
                if ain: out.append(a)
                if ain != bin_:
                    t0 = NEAR - a[2]; dz = b[2] - a[2]
                    out.append((a[0] + muldiv(b[0] - a[0], t0, dz), a[1] + muldiv(b[1] - a[1], t0, dz), NEAR))
            if len(out) < 3: return
            P = out
        V = []
        for (px, py, pz) in P:
            qx = proj_q(abs(px), pz); qy = proj_q(abs(py), pz)
            V.append((OX + qx if px >= 0 else OX - qx, OY - qy if py >= 0 else OY + qy))
        xs = [v[0] for v in V]; ys = [v[1] for v in V]
        if max(xs) < XL or min(xs) >= XR or max(ys) < YT or min(ys) >= YB: return
        s.st.clipped += 1
        planes = []
        if min(xs) < 0: planes.append((0, 0, True))
        if max(xs) > 254: planes.append((0, 254, False))
        if min(ys) < 0: planes.append((1, 0, True))
        if max(ys) > 254: planes.append((1, 254, False))
        for (axis, lim, keep_ge) in planes:
            out = []
            n = len(V)
            for i in range(n):
                a, b = V[i], V[(i + 1) % n]
                ain = a[axis] >= lim if keep_ge else a[axis] <= lim
                bin_ = b[axis] >= lim if keep_ge else b[axis] <= lim
                if ain: out.append(a)
                if ain != bin_:
                    o = 1 - axis
                    t = a[o] + muldiv(b[o] - a[o], lim - a[axis], b[axis] - a[axis])
                    out.append((lim, t) if axis == 0 else (t, lim))
            V = out
            if len(V) < 3: return
        s.raster(V, col)
    def raster(s, pts, col):
        n = len(pts)
        code_and = 15
        for (X, Y) in pts:
            c = (X < XL) | ((X >= XR) << 1) | ((Y < YT) << 2) | ((Y >= YB) << 3)
            code_and &= c
        if code_and: return
        ys = [p[1] for p in pts]
        ytop, ybot = max(min(ys), YT), min(max(ys), YB)
        if ytop >= ybot: return
        D = {}; U = {}
        for i in range(n):
            (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % n]
            if ya == yb: continue
            dst = D
            if ya > yb: xa, ya, xb, yb = xb, yb, xa, ya; dst = U
            dy = yb - ya; dx = xb - xa
            step = abs(dx) * 256 if dy == 1 else (abs(dx) * RY[dy]) >> 8
            if dx < 0: step = -step
            y0 = max(ya, YT); y1 = min(yb, YB)
            acc = (xa * 256 + 128 + (y0 - ya) * step) & 0xFFFF
            for yy in range(y0, y1):
                dst[yy] = acc >> 8
                acc = (acc + step) & 0xFFFF
                s.st.edgerows += 1
        for yy in range(ytop, ybot):
            l, r = U.get(yy), D.get(yy)
            if l is None or r is None:
                continue
            l = max(XL, min(XR, l)) - XL; r = max(XL, min(XR, r)) - XL
            if l < r: s.cover(yy - YT, l, r, col)
    def cover(s, row, a, b, col):
        # the coverage list: draw the parts of [a, b) not drawn yet, and merge
        iv = s.iv[row]
        if len(iv) == 1 and iv[0] == (0, W): return
        s.st.spans += 1
        i = 0
        while i < len(iv) and iv[i][1] < a: i += 1
        j = i; cur = a; ns, ne = a, b
        while j < len(iv) and iv[j][0] <= b:
            if iv[j][0] > cur: s.fill(row, cur, iv[j][0], col)
            cur = max(cur, iv[j][1]); ns = min(ns, iv[j][0]); ne = max(ne, iv[j][1]); j += 1
        if cur < b: s.fill(row, cur, b, col)
        iv[i:j] = [(ns, ne)]
        s.st.maxiv = max(s.st.maxiv, len(iv))
        if iv == [(0, W)]: s.full += 1
    def fill(s, row, a, b, col):
        s.st.fills += 1; s.st.fillpx += b - a
        r = s.fb[row]
        for x in range(a, b):
            if r[x] is not None: raise Exception('pixel written twice %d %d' % (row, x))
            r[x] = col
    def image(s):
        from PIL import Image
        img = Image.new('RGB', (W * 2, H * 2))
        px = img.load()
        for y in range(H):
            for x in range(W):
                v = s.fb[y][x]
                c = (255, 0, 255) if v is None else (((v >> 5) & 7) * 255 // 7, ((v >> 2) & 7) * 255 // 7, (v & 3) * 85)
                for dy in range(2):
                    for dx in range(2): px[x * 2 + dx, y * 2 + dy] = c
        return img

def muldiv(a, b, c):    # a * b / c, truncated toward zero (vm_divs)
    p = a * b
    q = abs(p) // abs(c)
    return q if (p >= 0) == (c > 0) else -q
def div64(a, z):
    v = muldiv(a, 64, z)
    return max(-12000, min(12000, v))

if __name__ == '__main__':
    blk = world.make()
    r = Ref(blk)
    print('surface cells', r.ncells, 'per group max', max(len(g) for g in r.groups))
    views = [(8 * 256, 12 * 256, -2 * 256, 0, -20), (2 * 256 + 128, 9 * 256, 2 * 256, 40, -10), (8 * 256, 9 * 256 + 100, 8 * 256, 100, 0), (14 * 256, 14 * 256, 14 * 256, 160, -40)]
    for n, v in enumerate(views):
        st = r.render(*v)
        print(v, st.__dict__)
        r.image().resize((512, 320)).save('ref_%d.png' % n)
