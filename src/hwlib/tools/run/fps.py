# fps.py - how many pictures a second a cube test draws: reads Vec's turn angle (it goes up 2 a
# picture) twice, 2 seconds apart, in the emulator. MSX tests in openMSX, Next and CPC in ZEsarUX.
#   python3 tools/run/fps.py cube_msx1 cube_msx2 cube_msx_v9990 cube_next cube_cpc
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, re, subprocess, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
B = os.path.join(HERE, '..', '..', 'build')

def addr(name):
    n8 = name.upper().replace('_', '')[:8]
    m = re.search(r'^var_vec_ra: EQU 0x([0-9A-F]+)', open(os.path.join(B, name, n8 + '.sym')).read(), re.M)
    return int(m.group(1), 16)

def msx(name, machine, ext=None):
    a = addr(name); T = tempfile.mkdtemp(); out = os.path.join(T, 'r.txt')
    tcl = os.path.join(T, 'f.tcl')
    open(tcl, 'w').write('set f [open %s w]\nafter time 12 { puts $f [debug read memory %d] }\nafter time 14 { puts $f [debug read memory %d]; close $f; exit }\n' % (out, a, a))
    cmd = ['xvfb-run', '-a', 'openmsx', '-machine', machine, '-cart', os.path.join(B, name, name.upper().replace('_', '')[:8] + '.ROM'), '-script', tcl]
    if ext: cmd[5:5] = ['-ext', ext]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    r = [int(x) for x in open(out).read().split()]
    return ((r[1] - r[0]) & 255) / 2 / 2

def zes(name):
    import zx
    zx.ZBIN = os.environ.get('ZESARUX', '/tmp/claude-0/-home-claude/ac607555-f87f-5ddd-b185-d83b7802f0e0/scratchpad/zesarux/src/zesarux')
    a = addr(name)
    if name.endswith('next'):
        z = zx.Zx(os.path.join(B, name, name.upper().replace('_', '')[:8] + '.NEX'), port=15303, wait=6)
    else:
        sys.argv = [sys.argv[0], name]
        src = open(os.path.join(HERE, 'shot_cpc.py')).read()
        g = {'__file__': os.path.join(HERE, 'shot_cpc.py'), '__name__': 'x'}
        exec(src.split("os.makedirs(os.path.join(R, 'build', 'shots'), exist_ok=True)\nfor i")[0], g)
        z = g['z']
    r0 = z.mem(a, 1)[0]; t0 = time.time(); time.sleep(2); r1 = z.mem(a, 1)[0]; dt = time.time() - t0
    z.close()
    return ((r1 - r0) & 255) / 2 / dt

M = {'cube_msx1': lambda: msx('cube_msx1', 'C-BIOS_MSX1'), 'cube_msx2': lambda: msx('cube_msx2', 'C-BIOS_MSX2'),
     'cube_msx_v9990': lambda: msx('cube_msx_v9990', 'C-BIOS_MSX2', 'gfx9000'), 'cube_next': lambda: zes('cube_next'),
     'cube_cpc': lambda: zes('cube_cpc')}
# (cube_cpcplus can't run on a plain CPC: it switches the CPC Plus's ASIC, which on a plain CPC
# turns the lower ROM on over the program)
for n in sys.argv[1:] or list(M):
    print('%s: %.1f pictures a second' % (n, M[n]()))
