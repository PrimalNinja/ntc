# fixchk.py - Fixed's 16 bit Add16 / Sub16 / Mul16 / Div16 (Z80 since 20261114) and Float.MulDiv (Fixed's 32 bit multiply
# and divide; its multiply and divide in the registers since 20261114) against exact integer arithmetic: the answer and
# Ok() / Overflow() of every case, bit for bit. Random cases and the edges (0, 1, -1, the biggest values, -32768, by 0),
# places 0-5 (5: 16 bit not offered - 0 and Ok() False).   python3 float/fixchk.py [seed]
# (c) 2026 Cyborg Unicorn Pty Ltd
import random, subprocess, sys, os
NTC_TEST = os.environ.get('NTC_TEST', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
LIB = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'src', 'lib', 'z80')
os.makedirs('/tmp/fp', exist_ok=True)
def run(lines):
    open('/tmp/fp/fx.bas', 'w').write("Dim a As Integer, b As Integer, la As Long, lb As Long, lc As Long, r As Integer, lr As Long\n" + '\n'.join(lines) + '\n')
    out = subprocess.run(['python3', 'ntcrun.py', '/tmp/fp/fx.bas', '', os.path.join(LIB, 'Fixed.cls'), os.path.join(LIB, 'Float.cls'), '--platform=test'],
                         cwd=NTC_TEST, capture_output=True, text=True, timeout=600,
                         env={'NTC_LIMIT': '400000', 'PATH': os.environ.get('PATH', '') + ':/usr/local/bin:/usr/bin:/bin'}).stdout
    return [l.rstrip() for l in out.split('\n') if l.strip() and not l.startswith('---') and 'Pass' not in l]
def lit(n, big):
    lo = -2147483648 if big else -32768
    s = '(%d - 1)' % (lo + 1) if n == lo else str(n)
    return s + ('&' if big and n != lo else '')
def clamp(v):
    if v > 32767: return 32767, 0
    if v < -32767: return -32767, 0
    return v, -1
def rescale(a, b):
    q = (abs(a) + abs(b) // 2) // abs(b)
    return -q if (a < 0) != (b < 0) else q
def model16(op, a, b, places):
    scale = 10 ** places
    if op == 'Add16': return clamp(a + b)
    if op == 'Sub16': return clamp(a - b)
    if places > 4: return 0, 0
    if op == 'Mul16': return clamp(rescale(a * b, scale))
    if b == 0: return (-32767 if a < 0 else 32767), 0
    return clamp(rescale(a * scale, b))
def muldiv(a, b, c):
    neg = (a < 0) ^ (b < 0) ^ (c < 0)
    if c == 0: return (-2147483647 if neg else 2147483647), -1
    q = (abs(a) * abs(b) + abs(c) // 2) // abs(c)
    if q > 2147483647: return (-2147483647 if neg else 2147483647), -1
    return (-q if neg else q), 0
random.seed(int(sys.argv[1]) if len(sys.argv) > 1 else 11)
E16 = [0, 1, -1, 2, 100, -100, 181, -182, 16384, 32767, -32767, -32768]
def r16():
    return random.choice([random.randint(-32768, 32767), random.randint(-300, 300), random.randint(-5000, 5000), random.choice(E16)])
E32 = [0, 1, -1, 100, 65535, 65536, -32768, 2147483647, -2147483647, -2147483648]
def r32():
    return random.choice([random.randint(-2147483648, 2147483647), random.randint(-70000, 70000), random.randint(-300, 300), random.randint(-20000000, 20000000), random.choice(E32)])
bad = 0; n = 0
for places in range(6):
    cases = [(a, b) for a in E16 for b in E16][::3] + [(r16(), r16()) for i in range(120)]
    for i in range(0, len(cases), 20):      # (20 lines a run: the test console keeps one screen)
        ch = cases[i:i + 20]; L = ['Fixed.SetPlaces %d' % places, 'r = Fixed.Ok()']
        for a, b in ch:
            L.append('a = %s : b = %s' % (lit(a, 0), lit(b, 0)))
            L.append(' : '.join('r = Fixed.%s(a, b) : Print r; " "; Fixed.Ok(); " ";' % op for op in ('Add16', 'Sub16', 'Mul16', 'Div16')) + ' : Print')
        out = run(L)[-len(ch):]
        for j, (a, b) in enumerate(ch):
            got = [int(x) for x in out[j].split()] if j < len(out) else []
            for k, op in enumerate(('Add16', 'Sub16', 'Mul16', 'Div16')):
                want = model16(op, a, b, places); n += 1
                g = tuple(got[2 * k:2 * k + 2])
                if g != want:
                    bad += 1
                    if bad < 12: print('BAD places %d %s(%d, %d): got %s want %s' % (places, op, a, b, g, want))
n16 = n
cases = [(a, b, c) for a in E32 for b in E32[::2] for c in E32[::3]] + [(r32(), r32(), r32()) for i in range(400)] + [(r32(), r32(), random.choice([1, 10, 100, 1000, 10000, 1000000000])) for i in range(200)]
for i in range(0, len(cases), 20):
    ch = cases[i:i + 20]; L = ['r = Float.Overflow()']
    for a, b, c in ch:
        L.append('la = %s : lb = %s : lc = %s : lr = Float.MulDiv(la, lb, lc) : Print lr; " "; Float.Overflow()' % (lit(a, 1), lit(b, 1), lit(c, 1)))
    out = run(L)[-len(ch):]
    for j, (a, b, c) in enumerate(ch):
        want = muldiv(a, b, c); n += 1
        got = tuple(int(x) for x in out[j].split()) if j < len(out) else None
        if got != want:
            bad += 1
            if bad < 12: print('BAD MulDiv(%d, %d, %d): got %s want %s' % (a, b, c, got, want))
print('checked %d Fixed 16 bit results and %d MulDiv results; wrong: %d' % (n16, n - n16, bad))
if bad: print('FAIL')
