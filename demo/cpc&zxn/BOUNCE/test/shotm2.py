# shotm2.py dump.bin out.png: NTC_SHOT's dump (R12, main RAM #4000, #C000) as mode 2 pictures,
# the one R12 shows on the left. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys
from PIL import Image
d = open(sys.argv[1], 'rb').read(); r12 = d[0]; s4 = d[1:0x4001]; sc = d[0x4001:0x8001]
def pic(m):
    im = Image.new('RGB', (640, 200)); px = im.load()
    for y in range(200):
        a = (y // 8) * 80 + (y % 8) * 0x800
        for xb in range(80):
            b = m[a + xb]
            for i in range(8):
                px[xb * 8 + i, y] = (255, 255, 0) if b & (0x80 >> i) else (0, 0, 128)
    return im
a, b = (pic(s4), pic(sc)) if (r12 & 0x30) == 0x10 else (pic(sc), pic(s4))
print('R12 = #%02X: showing %s' % (r12, '#4000' if (r12 & 0x30) == 0x10 else '#C000'))
a = a.resize((640, 400)); b = b.resize((640, 400))          # (a CPC line is two pixels tall)
out = Image.new('RGB', (640, 810), (60, 60, 60)); out.paste(a, (0, 0)); out.paste(b, (0, 410))
out.save(sys.argv[2])
