# cvkit.py - an index canvas for drawing sprites in code (scratch build tool)
import math

class Cv:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.p = [[None] * w for _ in range(h)]
    def set(s, x, y, i):
        x, y = int(x), int(y)
        if 0 <= x < s.w and 0 <= y < s.h: s.p[y][x] = i
    def get(s, x, y):
        if 0 <= x < s.w and 0 <= y < s.h: return s.p[y][x]
        return None
    def rect(s, x0, y0, x1, y1, i):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1): s.set(x, y, i)
    def poly(s, pts, i):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(s.w):
                if inside(pts, x + 0.5, y + 0.5): s.set(x, y, i)
    def circle(s, cx, cy, r, i):
        for y in range(s.h):
            for x in range(s.w):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r: s.set(x, y, i)
    def mirror(s):          # the left half copied to the right
        for y in range(s.h):
            for x in range(s.w // 2):
                s.p[y][s.w - 1 - x] = s.p[y][x]
    def mirror_r(s):        # the right half copied to the left
        for y in range(s.h):
            for x in range(s.w // 2):
                s.p[y][x] = s.p[y][s.w - 1 - x]
    def outline(s, i=0):    # a dark edge round everything drawn
        q = [r[:] for r in s.p]
        for y in range(s.h):
            for x in range(s.w):
                if s.p[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        v = s.get(x + dx, y + dy)
                        if v is not None and v != i:
                            q[y][x] = i; break
        s.p = q
    def shade(s, frm, to, test):  # recolour pixels where test(x, y)
        for y in range(s.h):
            for x in range(s.w):
                if s.p[y][x] == frm and test(x, y): s.p[y][x] = to
    def into(s, sheet, col, row):
        for y in range(s.h):
            for x in range(s.w):
                v = s.p[y][x]
                sheet.pixel(col * 16 + x, row * 16 + y, 15 if v is None else v)

def inside(pts, x, y):
    n = len(pts); r = False; j = n - 1
    for k in range(n):
        xi, yi = pts[k]; xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi: r = not r
        j = k
    return r

