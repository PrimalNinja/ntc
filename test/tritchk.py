# tritchk.py - Trit's single trit operations (Z80 since 20261115: Tand, Tor, Tnot, Tmul, Tmaj, Gate, FromByte, ToByte,
# Get4, Set4) against the BASIC they replaced, worked out here: every answer, for trits and for other Integers too.
#   python3 tritchk.py        (c) 2026 Cyborg Unicorn Pty Ltd
import subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
TRIT = os.path.join(HERE, '..', 'src', 'lib', 'z80', 'Trit.cls')
os.makedirs('/tmp/fp', exist_ok=True)
def run(lines):
    open('/tmp/fp/tr.bas', 'w').write("Dim a As Integer, b As Integer, c As Integer, r As Integer, buf(3) As Byte, pa As Integer\npa = VarPtr(buf(1))\n" + '\n'.join(lines) + '\n')
    out = subprocess.run(['python3', 'ntcrun.py', '/tmp/fp/tr.bas', '', TRIT, '--platform=test'], cwd=HERE, capture_output=True, text=True, timeout=600,
                         env={'NTC_LIMIT': '400000', 'PATH': os.environ.get('PATH', '') + ':/usr/local/bin:/usr/bin:/bin'}).stdout
    return [l.rstrip() for l in out.split('\n') if l.strip() and not l.startswith('---') and 'Pass' not in l]
def w(v):
    v &= 0xFFFF
    return v - 65536 if v > 32767 else v
def lit(n): return '(-32767 - 1)' if n == -32768 else str(n)
def sgn(v): return 1 if v > 0 else -1 if v < 0 else 0
V = [0, 1, -1, 2, -2, 255, 256, 3, 32767, -32767, -32768, 181]
bad = 0; n = 0
def check(lines, wants, tag):
    global bad, n
    for i in range(0, len(lines), 20):          # (20 lines a run: the test console keeps one screen)
        out = run(lines[i:i + 20])[-len(lines[i:i + 20]):]
        for j, want in enumerate(wants[i:i + 20]):
            got = [int(x) for x in out[j].split()] if j < len(out) else []
            n += len(want)
            if got != want:
                bad += 1
                if bad < 10: print('BAD %s case %d: got %s want %s' % (tag, i + j, got, want))
L = []; W = []
for a in V:
    for b in V:
        L.append('a = %s : b = %s : Print Trit.Tand(a, b); " "; Trit.Tor(a, b); " "; Trit.Tmul(a, b); " "; Trit.Gate(a, b); " "; Trit.Tnot(a); " "; Trit.FromByte(a); " "; Trit.ToByte(a)' % (lit(a), lit(b)))
        W.append([min(a, b), max(a, b), w(a * b), 0 if a == 0 else b if a > 0 else w(-b), w(-a), a if a in (0, 1) else -1, 0 if a == 0 else 1 if a > 0 else 255])
check(L, W, 'two')
L = []; W = []; T = [0, 1, -1, 2, 32767, -32768]
for a in T:
    for b in T:
        L.append('a = %s : b = %s : ' % (lit(a), lit(b)) + ' : '.join('c = %s : Print Trit.Tmaj(a, b, c); " ";' % lit(c) for c in T) + ' : Print')
        W.append([sgn(w(a + b + c)) for c in T])
check(L, W, 'Tmaj')
L = []; W = []
for byte in (0, 255, 0x1B, 0xE4, 0x6D, 0x93, 0x40, 0x0C):
    for i in (0, 1, 2, 3, 4, -1, 256):
        sh = 2 * i if i in (1, 2, 3) else 0
        g = (byte >> sh) & 3
        ln = 'buf(1) = %d : Print Trit.Get4(pa, %d); " ";' % (byte, i); want = [1 if g == 1 else -1 if g == 3 else 0]
        for t in (0, 1, -1, 5, -32768):
            v = (0 if t == 0 else 1 if t > 0 else 3) << sh; m = 3 << sh
            ln += ' : buf(1) = %d : Trit.Set4 pa, %d, %s : Print buf(1); " ";' % (byte, i, lit(t)); want.append((byte & (255 - m)) | v)
        L.append(ln + ' : Print buf(0); " "; buf(2)'); W.append(want + [0, 0])
check(L, W, 'packed')
print('checked %d Trit results; wrong lines: %d' % (n, bad))
if bad: print('FAIL')
