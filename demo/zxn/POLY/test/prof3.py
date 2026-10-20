# prof3.py NEX [secs] [n] - where the time goes: the emulator's cpu history (the last n
# instructions' PCs, after secs), counted by routine (nearest symbol below; local labels folded
# into their routine by the prefix up to the first label name)
import os, sys, time, bisect, collections, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
nex = os.path.abspath(sys.argv[1]); S = syms(nex[:-4] + '.sym')
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 4
N = int(sys.argv[3]) if len(sys.argv) > 3 else 400000
items = sorted((v, k) for k, v in S.items() if not k.startswith(('var_', 'arr_', 'lit_', 'llit_')) and v < 0xC000)
addrs = [a for a, _ in items]
z = Zx(nex, wait=1)
time.sleep(secs)
def sc(c):
    z.s.sendall((c + '\n').encode())
    r = ''
    z.s.settimeout(20)
    while not r.rstrip().endswith('>'):
        d = z.s.recv(1 << 20)
        if not d: break
        r += d.decode(errors='replace')
    return r
z.cmd = lambda c, w=0: sc(c)
for attempt in range(10):
    z.cmd('cpu-history enabled yes')
    z.cmd('enter-cpu-step')
    z.cmd('cpu-history set-max-size %d' % N)
    z.cmd('cpu-history started yes')
    ok = z.cmd('cpu-history is-started').strip().startswith('1')
    z.cmd('exit-cpu-step')
    if ok: break
    time.sleep(0.5)
time.sleep(3)
z.cmd('enter-cpu-step')
z.cmd('cpu-history started no')
r = z.cmd('cpu-history get-size')
print('size:', repr(r[:60]))
size = int(r.split()[0])
pcs = []
k = 0
while k < size:
    n = min(2000, size - k)
    z.s.sendall(('cpu-history get-pc %d %d\n' % (k, n)).encode())
    r = ''
    while not r.rstrip().endswith('>'):
        r += z.s.recv(1 << 20).decode(errors='replace')
    pcs += [int(x, 16) for x in re.findall(r'\b[0-9A-F]{4}\b', r)]
    k += n
z.cmd('exit-cpu-step')
try:
    z.p.kill()
except Exception: pass
c = collections.Counter()
for pc in pcs:
    i = bisect.bisect_right(addrs, pc) - 1
    c[items[i][1] if i >= 0 else '?'] += 1
tot = sum(c.values())
print('%d instructions' % tot)
G = {'mt': 'mt', 'of': 'faces', 'ow': 'faces', 'fr': 'fill rows', 'ff': 'fill setup', 'al': 'fill setup', 'ar': 'fill setup',
     'fi': 'fill setup', 'e8': 'fill setup', 'edge88': 'fill setup', 'ffi': 'fill setup', 'fill': 'fill setup', 'fs': 'fill setup',
     'fl': 'fill setup', 'c2': 'clip2', 'c2d': 'clip2', 'clip2': 'clip2', 'c1': 'clip3', 'clip1': 'clip3', 'cdist': 'clip3', 'cd': 'clip3',
     'p3': 'clip3', 'poly3': 'clip3', 'ud': 'clip3', 'udivf': 'clip3', 'umul': 'mul16', 'smul': 'mul16', 'ssmul': 'mul16', 'ss': 'mul16',
     'pm': 'proj', 'pj': 'proj', 'proj': 'proj', 'sc': 'scene', 'scene': 'scene', 'm8': 'faces', 'm816': 'faces', 'ndot': 'faces', 'nd': 'faces',
     'mul8s': 'faces', 'm8s': 'faces', 'o8': 'cull', 'oprep8': 'cull', 'ocull': 'cull', 'op': 'cull', 'ctest': 'cull', 'reld': 'cull', 'rd': 'cull',
     'orel': 'cull', 'oprep': 'odraw setup', 'oc': 'odraw setup', 'odraw': 'odraw setup', 'trig': 'odraw setup', 'xs': 'odraw setup',
     'xv': 'vertices', 'xt': 'vertices', 'xr': 'vertices', 'ov': 'vertices', 'vcode': 'vertices', 'vc': 'vertices', 'mrow': 'mul16',
     'mr': 'mul16', 'oe': 'faces', 'absh': 'misc', 'dot': 'dots', 'dt': 'dots'}
g = collections.Counter()
for name, v in c.items():
    n = name
    if n.startswith('fn_e3_lib_'):
        loc = n[len('fn_e3_lib_'):]
        key = loc if loc in G else loc.split('_')[0]
        n = G.get(key, 'lib ' + key)
    elif n.startswith('ntc_fr') or n.startswith('kw_frame'):
        n = 'waiting (Frame)'
    elif n.startswith(('fn_e3_begin', 'fn_e3_flip')):
        n = 'begin/flip'
    else:
        n = 'other: ' + n
    g[n] += v
for name, v in g.most_common(30):
    print('%6.2f%%  %s' % (100.0 * v / tot, name))
if os.environ.get('DETAIL'):  # DETAIL=1: the labels too
    print('---')
    for name, v in c.most_common(60):
        print('%6.2f%%  %s' % (100.0 * v / tot, name))
