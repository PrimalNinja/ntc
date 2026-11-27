# expect.py - what gfx.bas draws on a w x h screen, as a set of (x, y): the same line loop as
# the Graphics classes (tools/graphics/gen.js), every dot XORed. check() compares a screen with it.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
def line(s, w, h, x0, y0, x1, y1):
    if min(x0, x1, y0, y1) < 0 or x0 >= w or x1 >= w or y0 >= h or y1 >= h: return
    x, y = x0, y0; dx = x1 - x0; sx = 1
    if dx < 0: dx, sx = -dx, -1
    dy = y1 - y0; sy = 1
    if dy < 0: dy, sy = -dy, -1
    n = max(dx, dy); e = dx - dy
    while True:
        s ^= {(x, y)}
        if n == 0: break
        n -= 1; e2 = e + e
        if e2 > -dy: e -= dy; x += sx
        if e2 < dx: e += dx; y += sy

def expected(w, h):
    s = set()
    for a in ((0, 0, w - 1, 0), (w - 1, 0, w - 1, h - 1), (w - 1, h - 1, 0, h - 1), (0, h - 1, 0, 0),
              (2, 2, w - 3, h - 3), (2, h - 3, w - 3, 2), (4, h // 2, w // 4, h // 2), (4, h // 2, w // 4, h // 2),
              (w // 2, 4, w // 2, 4), (0, 0, w, h), (-1, 5, 10, 5)):
        line(s, w, h, *a)
    return s

def check(name, lit, w, h, skip=None):
    """lit: the set of dots on. skip: (x0, y0, x1, y1) left out (where the text is)."""
    exp = expected(w, h)
    if skip:
        f = lambda p: not (skip[0] <= p[0] <= skip[2] and skip[1] <= p[1] <= skip[3])
        exp = set(filter(f, exp)); lit = set(filter(f, lit))
    miss = exp - lit; extra = lit - exp
    ok = not miss and not extra
    print('%-12s %s  %d x %d, %d dots expected, %d missing, %d extra%s' % (name, 'PASS' if ok else 'FAIL', w, h, len(exp), len(miss), len(extra),
          '' if ok else '  e.g. missing %s extra %s' % (sorted(miss)[:3], sorted(extra)[:3])))
    return ok
