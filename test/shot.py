# shot.py file.bin out.png: NTC_SHOT's dump (R12, main RAM #4000, #C000) as mode 1 pictures, both
# screens side by side (the one shown first)
import sys
from PIL import Image
d = open(sys.argv[1], 'rb').read(); r12 = d[0]; s4 = d[1:0x4001]; sc = d[0x4001:0x8001]
pal = [(0, 0, 0), (255, 255, 255), (0, 255, 0), (0, 255, 255)]
def pic(m):
    im = Image.new('RGB', (320, 200))
    px = im.load()
    for y in range(200):
        a = (y // 8) * 80 + (y % 8) * 0x800
        for xb in range(80):
            b = m[a + xb]
            for i in range(4):
                p = ((b >> (7 - i)) & 1) << 1 | ((b >> (3 - i)) & 1)
                px[xb * 4 + i, y] = pal[(p >> 1) | ((p & 1) << 1)]
    return im
a, b = (pic(s4), pic(sc)) if (r12 & 0x30) == 0x10 else (pic(sc), pic(s4))
out = Image.new('RGB', (650, 200)); out.paste(a, (0, 0)); out.paste(b, (330, 0))
out = out.resize((1300, 400), Image.NEAREST); out.save(sys.argv[2])
