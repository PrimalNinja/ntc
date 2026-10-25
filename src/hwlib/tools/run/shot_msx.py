# shot_msx.py - runs the MSX tests in openMSX (C-BIOS machines; the V9990 one with the GFX9000
# cartridge) and the SC-3000 test in MAME (with a software list giving the cartridge BASIC Level
# III's 32K of RAM at #8000), saving screenshots to build/shots/<target>_0..2.png.
# Needs openmsx, xvfb-run, mame.   python3 tools/run/shot_msx.py [target ...]
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, subprocess, tempfile, zlib, hashlib, shutil, glob
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
B = os.path.join(ROOT, 'build'); SH = os.path.join(B, 'shots'); os.makedirs(SH, exist_ok=True)
T = tempfile.mkdtemp()

def openmsx(machine, rom, name, ext=None):
    t0 = 7 if 'MSX2' in machine else 4      # (the MSX2 C-BIOS takes longer to start)
    t0 += float(os.environ.get('SHOT_LATER', '0'))
    tcl = os.path.join(T, name + '.tcl')
    open(tcl, 'w').write(('after time 1 { set videosource GFX9000 }\n' if ext else '') + ''.join('after time %g { screenshot -raw %s }\n' % (t0 + i * 0.5, os.path.join(SH, '%s_%d.png' % (name, i))) for i in range(3)) + 'after time %g { exit }\n' % (t0 + 2))
    cmd = ['xvfb-run', '-a', 'openmsx', '-machine', machine, '-cart', rom, '-script', tcl]
    if ext: cmd[5:5] = ['-ext', ext]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)

def sc3000(rom, name):
    d = open(rom, 'rb').read(); d += b'\xff' * (32768 - len(d))
    os.makedirs(os.path.join(T, 'roms', 'sc3000_cart', 'hwtest')); os.makedirs(os.path.join(T, 'hash'))
    open(os.path.join(T, 'roms', 'sc3000_cart', 'hwtest', 'hwtest.bin'), 'wb').write(d)
    open(os.path.join(T, 'hash', 'sc3000_cart.xml'), 'w').write('''<?xml version="1.0"?>
<softwarelist name="sc3000_cart" description="hwtest"><software name="hwtest"><description>HWTEST</description><year>2026</year><publisher>-</publisher>
<part name="cart" interface="sg1000_cart"><feature name="slot" value="level3" />
<dataarea name="rom" size="32768"><rom name="hwtest.bin" size="32768" crc="%08x" sha1="%s" offset="0" /></dataarea>
<dataarea name="ram" size="32768"></dataarea></part></software></softwarelist>''' % (zlib.crc32(d) & 0xffffffff, hashlib.sha1(d).hexdigest()))
    for i, t in enumerate([4, 5, 6]):
        snap = os.path.join(T, 'snap%d' % i)
        subprocess.run(['mame', 'sc3000', 'hwtest', '-hashpath', os.path.join(T, 'hash'), '-rompath', os.path.join(T, 'roms'),
                        '-snapshot_directory', snap, '-video', 'none', '-sound', 'none', '-seconds_to_run', str(t), '-nothrottle', '-skip_gameinfo'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120, env=dict(os.environ, PATH=os.environ['PATH'] + ':/usr/games'))
        shutil.copy(glob.glob(os.path.join(snap, '*', '*.png'))[0], os.path.join(SH, '%s_%d.png' % (name, i)))

RUN = {}
for pre in ('', 'cube_'):
    for n, mach, ext in (('msx1', 'C-BIOS_MSX1', None), ('msx2', 'C-BIOS_MSX2', None), ('msx_v9990', 'C-BIOS_MSX2', 'gfx9000')):
        t = pre + n; f = t.upper().replace('_', '')[:8] + '.ROM'
        RUN[t] = (lambda t=t, f=f, mach=mach, ext=ext: openmsx(mach, os.path.join(B, t, f), t, ext))
    t = pre + 'sc3000'; f = t.upper().replace('_', '')[:8] + '.SC'
    RUN[t] = (lambda t=t, f=f: sc3000(os.path.join(B, t, f), t))
if __name__ == '__main__':
    for n in (sys.argv[1:] or [k for k in RUN if not k.startswith('cube_')]):
        RUN[n]()
        print('build/shots/%s_0..2.png' % n)
