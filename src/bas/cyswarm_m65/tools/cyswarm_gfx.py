#!/usr/bin/env python3
# cyswarm_gfx.py - CYBORG SWARM's graphics for the MEGA65: makes ../Gfx.cls (the images, the
# palette and the image numbers as constants) and ../assets/*.png (what they look like).
# (c) 2026 Cyborg Unicorn Pty Ltd
#
#   python3 cyswarm_gfx.py
#
# Every picture is drawn here as text (one character a pixel: . clear, 1-9 A-F the palette's
# colours). The enemies and the fighter are turned to 16 directions: 5 are drawn (up, 22.5,
# 45, 67.5 and 90 degrees to the right) and the game flips them for the rest.
# An image for the Vic class: w, h, then w columns of h / 2 bytes (two pixels a byte, the low
# nybble the upper). Its colours 1-15 are shown as 16 + the sprite's palette * 16 + the colour:
# the 4 palettes below are the MEGA65's colours 16-79.

import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_CLS = os.path.join(HERE, '..', 'Gfx.cls')
ASSETS = os.path.join(HERE, '..', 'assets')


def rgb12(rgb):
	r, g, b = rgb
	q = lambda v: min(15, int(round(v / 255.0 * 15)))
	return (q(r) << 8) | (q(g) << 4) | q(b)


# ---- the 4 palettes (16 colours each, colour 0 is clear)
PAL = [
	# 0: the console's text (white), the HUD, the stars (9-14: cycled by the game), 15 black (every
	#    palette's 15 is black: the HUD's opaque font and tiles)
	[(0, 0, 0), (255, 255, 255), (255, 36, 36), (255, 255, 0), (0, 255, 255), (36, 72, 255), (0, 219, 0), (255, 0, 255),
	 (255, 146, 0), (255, 255, 255), (255, 255, 0), (0, 255, 255), (255, 72, 72), (146, 146, 255), (0, 255, 109), (0, 0, 0)],
	# 1: the fighter (1 red, 2 white, 3 blue, 4 grey), the Queen (5 green, 6 yellow, 7 dark green,
	#    8 orange), the missile (9 yellow), the fighter's explosion (10-14)
	[(0, 0, 0), (255, 36, 36), (255, 255, 255), (36, 109, 255), (109, 109, 146), (0, 219, 73), (255, 255, 0), (0, 109, 36),
	 (255, 109, 0), (255, 255, 109), (255, 255, 255), (255, 255, 0), (255, 146, 0), (255, 36, 0), (146, 0, 0), (0, 0, 0)],
	# 2: the Drone (1 yellow, 2 blue, 3 red, 4 white, 5 dark blue), the Hornet (3 red, 4 white, 2
	#    blue, 1 yellow, 6 dark red), explosions (7-12), the enemy shot (13), 14 orange
	[(0, 0, 0), (255, 255, 0), (36, 72, 255), (255, 36, 36), (255, 255, 255), (0, 0, 146), (146, 0, 0), (255, 255, 255),
	 (255, 255, 73), (255, 182, 0), (255, 73, 0), (219, 0, 146), (73, 73, 255), (255, 255, 255), (255, 146, 0), (0, 0, 0)],
	# 3: the captured fighter (1 cyan, 2 red, 3 white, 4 dark red), the hit Queen (5 purple, 6 blue,
	#    7 dark purple, 8 orange), the tractor beam (9-12: cycled), 13 white
	[(0, 0, 0), (0, 255, 255), (255, 36, 36), (255, 255, 255), (146, 0, 0), (182, 73, 255), (73, 109, 255), (109, 0, 146),
	 (255, 109, 0), (109, 182, 255), (182, 219, 255), (36, 109, 255), (255, 255, 255), (255, 255, 255), (0, 0, 0), (0, 0, 0)],
]

# ---- the pictures (facing up)
FIGHTER = '''
.......11.......
.......22.......
.......22.......
......2222......
......2332......
...1..2332..1...
...1.223322.1...
...2.222222.2...
.1.2222222222.1.
.1222224422222 1
.12222.44.22221.
.222...44...222.
.22....11....22.
.2.....11.....2.
................
................
'''

DRONE_A = '''
................
.......33.......
......3113......
......1221......
.444..1221..444.
44444.2112.44444
44444421124444 4
.4444422224444..
..44.512215.44..
.....211112.....
.....222222.....
......2112......
......5225......
.......55.......
................
................
'''

DRONE_B = '''
................
.......33.......
......3113......
......1221......
......1221......
...44.2112.44...
..4444211244 44.
.444442222444 4.
.4444512215444 .
.444.211112.444.
..4..222222..4..
......2112......
......5225......
.......55.......
................
................
'''

HORNET_A = '''
....1......1....
.....1....1.....
......3333......
.....366663.....
.2...333333...2.
.42..363363..24.
.442.333333.244.
.4442.3333.2444.
.44442.33.24444.
.4444423324444 4
..44442332444 4.
...444.33.444...
....4..33..4....
.......66.......
................
................
'''

HORNET_B = '''
....1......1....
.....1....1.....
......3333......
.....366663.....
......333333....
..2..363363..2..
..42.333333.24..
..442.3333.244..
.4444.2332.4444.
.44442.33.24444.
.44444.33.44444.
..444..33..444..
...4...33...4...
.......66.......
................
................
'''

QUEEN_A = '''
.....6....6.....
......6..6......
.....855558.....
....55555555....
...7.565565.7...
..77.555555.77..
.777.556655.777.
7777.556655.7777
77777566665 7777
777775666657777.
.7777.5665.7777.
..77..5555..77..
......5665......
.......55.......
................
................
'''

QUEEN_B = '''
.....6....6.....
......6..6......
.....855558.....
....55555555....
....7565565.7...
...77555555.77..
..777556655.777.
..777556655.777.
.777756666577 7.
.7777566665777 .
.777.55665.777..
..7...5555...7..
......5665......
.......55.......
................
................
'''


def grid(text):
	rows = [r.replace(' ', '.') for r in text.strip('\n').split('\n')]
	out = []
	for r in rows[:16]:
		r = (r + '.' * 16)[:16]
		out.append([0 if c == '.' else int(c, 16) for c in r])
	while len(out) < 16:
		out.append([0] * 16)
	return out


def scale2x(g):
	h = len(g)
	w = len(g[0])
	o = [[0] * (w * 2) for _ in range(h * 2)]
	for y in range(h):
		for x in range(w):
			p = g[y][x]
			a = g[y - 1][x] if y > 0 else p
			b = g[y][x + 1] if x < w - 1 else p
			c = g[y][x - 1] if x > 0 else p
			d = g[y + 1][x] if y < h - 1 else p
			e0 = c if (c == a and c != d and a != b) else p
			e1 = b if (a == b and a != c and b != d) else p
			e2 = c if (d == c and d != b and c != a) else p
			e3 = b if (b == d and b != a and d != c) else p
			o[y * 2][x * 2] = e0
			o[y * 2][x * 2 + 1] = e1
			o[y * 2 + 1][x * 2] = e2
			o[y * 2 + 1][x * 2 + 1] = e3
	return o


def rotate(g, deg):
	# the picture turned clockwise by deg: scale2x twice, then each pixel sampled back
	if deg == 0:
		return [row[:] for row in g]
	big = scale2x(scale2x(g))
	n = len(big)
	k = n // len(g)
	a = math.radians(deg)
	ca, sa = math.cos(a), math.sin(a)
	out = [[0] * len(g) for _ in range(len(g))]
	c = len(g) / 2.0
	for y in range(len(g)):
		for x in range(len(g)):
			px = x + 0.5 - c
			py = y + 0.5 - c
			sx = px * ca + py * sa + c
			sy = -px * sa + py * ca + c
			bx = int(math.floor(sx * k))
			by = int(math.floor(sy * k))
			if 0 <= bx < n and 0 <= by < n:
				out[y][x] = big[by][bx]
	return out


def blank(w, h):
	return [[0] * w for _ in range(h)]


# ---- explosions
def explosion16(frame):
	g = blank(16, 16)
	cols = [7, 8, 9, 10, 11, 12]
	import random
	rnd = random.Random(10 + frame)
	r = 2 + frame * 2
	for i in range(18 + frame * 6):
		a = rnd.random() * math.pi * 2
		d = rnd.random() * r
		x = int(8 + math.cos(a) * d)
		y = int(8 + math.sin(a) * d)
		if 0 <= x < 16 and 0 <= y < 16:
			g[y][x] = cols[min(5, int(d / (r + 0.01) * 3) + frame // 2)]
	# a few rays
	for k in range(8):
		a = k * math.pi / 4 + frame * 0.3
		for d in range(r - 1, r + 2):
			x = int(8 + math.cos(a) * d)
			y = int(8 + math.sin(a) * d)
			if 0 <= x < 16 and 0 <= y < 16:
				g[y][x] = cols[min(5, 1 + frame)]
	return g


def explosion32(frame):
	g = blank(32, 32)
	import random
	rnd = random.Random(99 + frame)
	cols = [10, 11, 12, 13, 14, 14]
	r = 4 + frame * 4
	for i in range(60 + frame * 30):
		a = rnd.random() * math.pi * 2
		d = rnd.random() * r
		x = int(16 + math.cos(a) * d)
		y = int(16 + math.sin(a) * d)
		if 0 <= x < 32 and 0 <= y < 32:
			g[y][x] = cols[min(5, int(d / (r + 0.01) * 4) + frame // 2)]
	for k in range(12):
		a = k * math.pi / 6 + frame * 0.2
		for d in range(r - 2, r + 2):
			x = int(16 + math.cos(a) * d)
			y = int(16 + math.sin(a) * d)
			if 0 <= x < 32 and 0 <= y < 32:
				g[y][x] = cols[min(5, frame + 1)]
	return g


MISSILE = '''
...99...
...22...
...22...
...22...
...11...
...11...
........
........
'''

EBULLET = '''
........
...dd...
..dddd..
..dddd..
...dd...
........
........
........
'''


def small(text):
	rows = text.strip('\n').split('\n')
	return [[0 if c == '.' else int(c, 16) for c in (r + '........')[:8]] for r in rows[:8]]


# ---- the tractor beam: 3 pieces of 48 x 32, a cone 16 -> 48 wide, banded (colours 9-12)
def beam_piece(k):
	g = blank(24, 32)		# the left half (the right is the same flipped)
	for y in range(32):
		yy = k * 32 + y
		w = 16 + 32 * yy // 96
		half = w // 2
		band = 9 + ((yy // 2) % 4)
		if (yy % 2) == 1:
			continue		# lines between the bands
		for x in range(24 - half, 24):
			g[y][x] = band
		g[y][24 - half] = 12
	return g


def font8():
	src = os.path.join(HERE, 'font8x8.txt')		# font8x8_basic (public domain)
	rows = []
	for line in open(src):
		line = line.split(';')[0].strip()
		if line:
			b = line.split()
			if len(b) == 8:
				rows.append([int(x, 16) for x in b])
	return rows


FONT = font8()


FLAG1 = '''
..2.....
..2333..
..23333.
..2333..
..2.....
..2.....
..2.....
..2.....
..2.....
..2.....
.1111...
........
........
........
........
........
'''

FLAG5 = '''
..2.....
..26666.
..266666
..26666.
..2.....
..2.....
..2.....
..2.....
..2.....
..2.....
.1111...
........
........
........
........
........
'''


def logo_letter(ch):
	# a 16 x 16 letter: the font doubled, coloured by rows (yellow, orange, red), outlined in blue
	gl = FONT[ord(ch) - 32]
	g = blank(16, 16)
	for y in range(16):
		for x in range(16):
			if (gl[y // 2] >> (7 - x // 2)) & 1:
				g[y][x] = (1 if y < 6 else (14 if y < 11 else 3))
	o = [row[:] for row in g]
	for y in range(16):
		for x in range(16):
			if g[y][x] == 0:
				for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
					yy, xx = y + dy, x + dx
					if 0 <= yy < 16 and 0 <= xx < 16 and g[yy][xx]:
						o[y][x] = 2
						break
	return o


def image(g):
	# a picture (rows of colours) as an image: w, h, columns of nybble pairs
	h = len(g)
	w = len(g[0])
	if h % 2:
		g = g + [[0] * w]
		h += 1
	out = [w, h]
	for x in range(w):
		for y in range(0, h, 2):
			out.append((g[y][x] & 15) | ((g[y + 1][x] & 15) << 4))
	return out


def text_image(s, colour):
	# a row of text, 8 x 8 a character
	g = blank(8 * len(s), 8)
	for i, ch in enumerate(s):
		gl = FONT[ord(ch) - 32]
		for y in range(8):
			for x in range(8):
				if (gl[y] >> (7 - x)) & 1:
					g[y][i * 8 + x] = colour
	return g


def flag_grid(text):
	rows = text.strip('\n').split('\n')
	g = [[0 if c == '.' else int(c, 16) for c in (r + '........')[:8]] for r in rows[:16]]
	while len(g) < 16:
		g.append([0] * 8)
	return g


def main():
	images = []				# the pictures (grids)
	consts = []

	def add(name, grids):
		consts.append((name, len(images)))
		images.extend(grids)

	angles = [0, 22.5, 45, 67.5, 90]
	fighter = grid(FIGHTER)
	add('I_FIGHTER', [rotate(fighter, a) for a in angles])
	for name, fa, fb in (('I_DRONE', DRONE_A, DRONE_B), ('I_HORNET', HORNET_A, HORNET_B), ('I_QUEEN', QUEEN_A, QUEEN_B)):
		ga = grid(fa)
		gb = grid(fb)
		gl = []
		for a in angles:
			gl.append(rotate(ga, a))
			gl.append(rotate(gb, a))
		add(name, gl)
	add('I_EXPL', [explosion16(f) for f in range(4)])
	add('I_PEXPL', [explosion32(f) for f in range(4)])
	add('I_MISSILE', [small(MISSILE)])
	add('I_EBULLET', [small(EBULLET)])
	add('I_BEAM', [beam_piece(k) for k in range(3)])
	add('I_POP', [text_image(s, 1) for s in ('400 ', '800 ', '1600', '1000', '500 ')])
	add('I_FLAG1', [flag_grid(FLAG1)])
	add('I_FLAG5', [flag_grid(FLAG5)])
	letters = 'CYBORGSWAM'
	add('I_LOGO', [logo_letter(ch) for ch in letters])
	consts.append(('I_LIFE', dict(consts)['I_FIGHTER']))		# the reserve fighters: the fighter

	data = [image(g) for g in images]
	total = sum(len(d) for d in data)

	# ---- Gfx.cls
	lines = []
	lines.append("' Gfx - CYBORG SWARM's graphics: the images, the palette and the image numbers")
	lines.append("' (c) 2026 Cyborg Unicorn Pty Ltd")
	lines.append("' Made by tools/cyswarm_gfx.py - change that and run it again, not this file.")
	lines.append("")
	for name, val in consts:
		lines.append('Public Const %s = %d' % (name, val))
	lines.append('Public Const N_IMAGES = %d' % len(images))
	lines.append("Public Const LOGO_LETTERS = \"%s\"" % letters)
	lines.append("")
	lines.append("' the image table (for Vic.Images): each image's address, then the images (%d bytes)" % total)
	lines.append("Public Function Images() As Integer")
	lines.append("#asm")
	lines.append("            NTC_POP z_p0")
	lines.append("            ldy #0")
	lines.append("            lda #<tab")
	lines.append("            sta (z_p0),y")
	lines.append("            iny")
	lines.append("            lda #>tab")
	lines.append("            sta (z_p0),y")
	lines.append("            jmp done")
	lines.append("tab:")
	for i in range(0, len(data), 8):
		lines.append('            dw ' + ', '.join('img%d' % k for k in range(i, min(len(data), i + 8))))
	for k, d in enumerate(data):
		lines.append('img%d:' % k)
		for i in range(0, len(d), 16):
			lines.append('            db ' + ', '.join('$%02X' % v for v in d[i:i + 16]))
	lines.append("done:")
	lines.append("#endasm")
	lines.append("End Function")
	lines.append("")
	lines.append("' the 4 palettes: 64 colours (&HRGB) for colours 16-79 (Vic.Colors)")
	lines.append("Public Function Palettes() As Integer")
	lines.append("#asm")
	lines.append("            NTC_POP z_p0")
	lines.append("            ldy #0")
	lines.append("            lda #<data")
	lines.append("            sta (z_p0),y")
	lines.append("            iny")
	lines.append("            lda #>data")
	lines.append("            sta (z_p0),y")
	lines.append("            jmp done")
	lines.append("data:")
	for p in PAL:
		lines.append('            dw ' + ', '.join('$%03X' % rgb12(c) for c in p))
	lines.append("done:")
	lines.append("#endasm")
	lines.append("End Function")
	open(OUT_CLS, 'w').write('\n'.join(lines) + '\n')

	# ---- previews
	os.makedirs(ASSETS, exist_ok=True)

	def show(g, pal):
		img = Image.new('RGB', (len(g[0]), len(g)))
		px = img.load()
		for y in range(len(g)):
			for x in range(len(g[0])):
				v = g[y][x]
				px[x, y] = PAL[pal][v] if v else (24, 24, 40)
		return img

	sheet = Image.new('RGB', (16 * 12 + 8, 16 * 7), (24, 24, 40))
	start = dict(consts)
	rows = [('I_FIGHTER', 1, 1), ('I_FIGHTER', 3, 1), ('I_DRONE', 2, 2), ('I_HORNET', 2, 2), ('I_QUEEN', 1, 2), ('I_QUEEN', 3, 2)]
	for r, (name, pal, anims) in enumerate(rows):
		for d in range(5):
			for an in range(anims):
				sheet.paste(show(images[start[name] + d * anims + an], pal), ((d * anims + an) * 18 + 2, r * 18 + 2))
	sheet = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
	sheet.save(os.path.join(ASSETS, 'sprites.png'))
	ex = Image.new('RGB', (4 * 36, 36), (24, 24, 40))
	for f in range(4):
		ex.paste(show(images[start['I_PEXPL'] + f], 1), (f * 36 + 2, 2))
	ex = ex.resize((ex.width * 4, ex.height * 4), Image.NEAREST)
	ex.save(os.path.join(ASSETS, 'explosions.png'))
	print('Gfx.cls: %d images (%d bytes)' % (len(images), total))
	for name, val in consts:
		print(' ', name, val)


if __name__ == '__main__':
	main()
