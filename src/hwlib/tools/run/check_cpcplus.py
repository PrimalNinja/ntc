# check_cpcplus.py - the CPC Plus test can't be run here (no emulator has a CPC Plus without its
# ROMs), so: run it on a plain CPC 6128 in ZEsarUX - where there's no ASIC, so what the test
# writes to the ASIC's registers lands in RAM at #4000-#7FFF - and check those bytes: sprite 0's
# image, every sprite's position and size, the sprite palette. Also a screenshot (the text only:
# a plain CPC shows no sprites). Prints what it finds; build/shots/cpcplus_0.png.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.argv = [sys.argv[0], 'cpcplus']
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'shot_cpc.py')).read()
exec(src.split('os.makedirs(os.path.join(R, \'build\', \'shots\'), exist_ok=True)\nfor i')[0])
z.shot(os.path.join(R, 'build', 'shots', 'cpcplus_0.png'), full=True)
img = z.mem(0x4000, 256)
pos = z.mem(0x6000, 16 * 8)
pal = z.mem(0x6422, 30)
time.sleep(0.5)
pos2 = z.mem(0x6000, 16 * 8)
z.close(); os.remove(RAW)
print('sprite 0 image (low 4 bits a pixel):')
for r in range(16): print('  ' + ''.join('.123456789ABCDEF'[b & 15] for b in img[r * 16:r * 16 + 16]))
for n in range(16):
    p, q = pos[n * 8:n * 8 + 8], pos2[n * 8:n * 8 + 8]
    print('sprite %2d: x %4d y %4d size %02X  | half a second later: x %4d y %4d' % (n, p[0] | p[1] << 8, p[2] | p[3] << 8, p[4], q[0] | q[1] << 8, q[2] | q[3] << 8))
print('palette:', ' '.join('%02X%02X' % (pal[i], pal[i + 1]) for i in range(0, 30, 2)))
