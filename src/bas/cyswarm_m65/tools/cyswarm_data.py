#!/usr/bin/env python3
# cyswarm_data.py - CYBORG SWARM's tables (MEGA65): makes ../Paths.cls (the flight paths, the sine and
# arctangent tables, the formation's slots) and ../assets/paths.png (every path drawn).
# (c) 2026 Cyborg Unicorn Pty Ltd
#
#   python3 cyswarm_data.py
#
# Angles: 1024 a turn, 0 = up, 256 = right, 512 = down, 768 = left (a positive turn is
# clockwise on the screen). Speeds and positions are in 1/16 pixels.
# A path is segments (frames, turn a frame, speed). Special segments:
#   (AIM, 0, 0)        turn to face the fighter (and maybe shoot at it)
#   (END, state, 0)    the end: the enemy goes to that state (HOME, WRAP, OFF, GOTO)
# A mirrored enemy (Swarm.em bit 0) turns the other way.

import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'Paths.cls')
ASSETS = os.path.join(HERE, '..', 'assets')

AIM = -1
END = 0
# states (Swarm.es)
HOME, FORM, BEAM, WRAP, OFF, GOTO = 2, 3, 5, 7, 12, 13

PATHS = [
	# ---- coming in (normal stages): then HOME (to the slot)
	# from the top, left of the middle: down, a loop to the left, back up and right
	('P_TOP', [(26, 0, 44), (40, 12, 40), (40, 9, 40), (END, HOME, 0)]),
	# from the bottom left: up and right, a wide loop over the top, then home
	('P_SIDE', [(28, -2, 48), (50, -9, 44), (34, -6, 44), (END, HOME, 0)]),
	# ---- dives
	# a Drone: a loop up and over, face the fighter, swing down and off the bottom
	('P_DRONE', [(16, 32, 28), (AIM, 0, 0), (34, 3, 52), (40, -4, 56), (60, 3, 60), (END, WRAP, 0)]),
	# a Hornet: the loop, aim, a straight dash, a wide S
	('P_HORNET', [(16, 32, 28), (AIM, 0, 0), (22, 0, 56), (30, -10, 50), (36, 9, 50), (50, 0, 56), (END, WRAP, 0)]),
	# a Queen (with escorts): the loop, aim, a long sweep
	('P_QUEEN', [(16, 32, 26), (AIM, 0, 0), (40, 2, 44), (36, -7, 44), (40, 6, 46), (80, 0, 52), (END, WRAP, 0)]),
	# a Queen going down to beam: the loop, then to the point above the fighter
	('P_BEAM', [(16, 32, 26), (END, GOTO, 0)]),
	# back up after beaming
	('P_UP', [(60, 0, 40), (END, HOME, 0)]),
	# an escort on its own (its Queen gone): straight on
	('P_ESCAPE', [(200, 0, 52), (END, WRAP, 0)]),
	# the captured fighter turned enemy: a dive and away
	('P_ROGUE', [(16, 32, 26), (AIM, 0, 0), (200, 0, 56), (END, OFF, 0)]),
	# ---- the bonus stage: in, show off, away (OFF)
	('P_C1', [(40, 0, 48), (60, 17, 44), (40, 0, 52), (60, -17, 44), (120, 0, 56), (END, OFF, 0)]),
	('P_C2', [(30, -4, 52), (64, 16, 48), (64, 16, 48), (120, 2, 56), (END, OFF, 0)]),
	('P_C3', [(50, 0, 40), (32, 32, 40), (40, 0, 48), (32, -32, 40), (160, 0, 52), (END, OFF, 0)]),
	('P_C4', [(20, 0, 56), (90, 11, 44), (90, -11, 44), (120, 0, 56), (END, OFF, 0)]),
	('P_C5', [(60, 6, 44), (60, -6, 44), (60, 6, 44), (120, -2, 56), (END, OFF, 0)]),
]

# the formation: 40 slots (Swarm index 0-39): column 0-9, row 0-4
SLOTS = []
for c in (3, 4, 5, 6):
	SLOTS.append((c, 0))							# 0-3 Queens
for r in (1, 2):
	for c in range(1, 9):
		SLOTS.append((c, r))						# 4-19 Hornets
for r in (3, 4):
	for c in range(10):
		SLOTS.append((c, r))						# 20-39 Drones


def sine(a):
	return int(round(256 * math.sin(2 * math.pi * a / 1024)))


def main():
	words = []
	consts = []
	for name, segs in PATHS:
		consts.append((name, len(words)))
		for s in segs:
			words += list(s)
	sines = [sine(a) for a in range(1024)]
	atans = [int(round(math.atan(t / 32.0) * 1024 / (2 * math.pi))) for t in range(33)]
	lines = []
	lines.append("' Paths - CYBORG SWARM's flight paths and tables")
	lines.append("' (c) 2026 Cyborg Unicorn Pty Ltd")
	lines.append("' Made by tools/cyswarm_data.py - change that and run it again, not this file.")
	lines.append("")
	lines.append("' where each path starts in the table (in words: 3 a segment)")
	for name, off in consts:
		lines.append('Public Const %s = %d' % (name, off))
	lines.append("")

	def table(fn, comment, data, per=12):
		lines.append("' " + comment)
		lines.append("Public Function %s() As Integer" % fn)
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
		for i in range(0, len(data), per):
			lines.append('            dw ' + ', '.join(str(v) for v in data[i:i + per]))
		lines.append("done:")
		lines.append("#endasm")
		lines.append("End Function")
		lines.append("")
	table('Table', 'the paths: frames, turn, speed (frames -1: aim at the fighter; 0: the end, turn = the state after)', words, 15)
	table('Sines', 'sine * 256 for 1024 angles (cosine: the angle + 256)', sines, 16)
	table('Atans', 'arctangent(t / 32) for t = 0-32, in the 1024 angles (0-128)', atans, 11)
	table('Slots', 'the formation: column, row of each of the 40 slots', [v for s in SLOTS for v in s], 16)
	open(OUT, 'w').write('\n'.join(lines) + '\n')

	# ---- a picture of each path (from a typical start)
	os.makedirs(ASSETS, exist_ok=True)
	starts = {'P_TOP': (96, -8, 512), 'P_SIDE': (-8, 164, 160)}
	img = Image.new('RGB', (256 * 2, 200 * 2), (8, 8, 24))
	d = ImageDraw.Draw(img)
	cols = [(255, 255, 0), (0, 255, 255), (255, 80, 80), (80, 255, 80), (255, 128, 255), (255, 160, 0), (160, 160, 255), (255, 255, 255)]
	for k, (name, segs) in enumerate(PATHS):
		x, y, a = starts.get(name, (64 + (k % 4) * 40, 40, 512))
		x *= 16
		y *= 16
		mirror = False
		pts = []
		for f, t, v in segs:
			if f == END:
				break
			if f == AIM:
				a = 512
				continue
			for _ in range(f):
				a = (a + (-t if mirror else t)) & 1023
				x += sines[a] * v // 256
				y -= sines[(a + 256) & 1023] * v // 256
				pts.append((x / 16 * 2, y / 16 * 2))
		if len(pts) > 1:
			d.line(pts, fill=cols[k % len(cols)], width=2)
			d.text(pts[0], name, fill=cols[k % len(cols)])
	img.save(os.path.join(ASSETS, 'paths.png'))
	print('Paths.cls: %d path words' % len(words))


if __name__ == '__main__':
	main()
