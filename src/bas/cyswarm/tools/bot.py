#!/usr/bin/env python3
# bot.py - plays CYBORG SWARM on the Genesis Plus GX core (NTC's test/mdrun.py) for testing:
# it reads the game's RAM by the labels in the vasm listing, steers under the lowest enemy,
# dodges shots, fires, and reports what happened (stages, deaths, captures, rescues).
# (c) 2026 Cyborg Unicorn Pty Ltd
#
#   python3 bot.py build/CYSWARM.md build/CYSWARM.lst [frames] [--shots=prefix] [--every=n]
#                  [--seed=n] [--nofire-queens]

import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', 'test'))			# (NTC's src/test/: the old place)
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'test'))		# NTC's test/, beside src/
from mdrun import MD		# noqa: E402


def symbols(lst):
	out = {}
	for line in open(lst, errors='replace'):
		m = re.match(r'^(\w+)\s+[AE]:00([0-9A-F]{6})\s*$', line)
		if m:
			out[m.group(1)] = int(m.group(2), 16)
	return out


def main():
	rom, lst = sys.argv[1], sys.argv[2]
	frames = 20000
	prefix = None
	every = 600
	seed = 1
	capture = False
	idle = False
	for a in sys.argv[3:]:
		if a.startswith('--shots='):
			prefix = a[8:]
		elif a.startswith('--every='):
			every = int(a[8:])
		elif a.startswith('--seed='):
			seed = int(a[7:])
		elif a == '--idle':
			idle = True
		elif a == '--capture':
			capture = True
		elif a.isdigit():
			frames = int(a)
	rnd = random.Random(seed)
	S = symbols(lst)
	md = MD(rom)

	def w(name, i=0):
		v = md.rword((S[name] + i * 2) & 0xFFFF)
		return v - 65536 if v >= 32768 else v

	def l(name):
		b = md.ram(S[name] & 0xFFFF, 4)
		return int.from_bytes(b, 'big', signed=True)
	last = {}
	events = []
	slow = []
	fr0 = None
	fire = 0
	for f in range(frames):
		pstate = w('var_pstate')
		phase = w('var_phase')
		stage = w('var_stage')
		state = (stage, phase, pstate, w('var_dual'), w('var_lives'))
		if f > 50 and state != last.get('s'):
			events.append((f, 'stage %d phase %d pstate %d dual %d lives %d score %d' % (stage, phase, pstate, w('var_dual'), w('var_lives'), l('var_score'))))
			last['s'] = state
		buttons = ''
		if (stage == 0 or phase == 9) and f % 60 == 30:
			buttons += 'S'		# start a game on the title
		if pstate == 0 and not idle:
			px = w('var_px')
			# the danger: enemy shots coming down near
			threat = None
			for k in range(8):
				if w('arr_bba', k):
					bx, by = w('arr_bx', k), w('arr_by', k)
					if by > 120 * 16 and abs(bx - px) < 20 * 16:
						threat = bx
			target = None
			best = -9999
			for e in range(44):
				s = w('arr_swarm_es', e)
				if s in (1, 2, 3, 5, 9, 13, 14):
					ey = w('arr_swarm_ey', e)
					ex = w('arr_swarm_ex', e)
					if s != 3 and ey > 150 * 16 and abs(ex - px) < 24 * 16:
						threat = ex
					if ey > best and (s == 3 or ey < 170 * 16):
						best = ey
						target = ex
			if capture and w('var_beamq') >= 0 and w('arr_swarm_es', w('var_beamq')) == 5:
				threat = None
				target = w('arr_swarm_ex', w('var_beamq'))
			if threat is not None:
				buttons += 'L' if threat > px else 'R'
				if px < 30 * 16:
					buttons = buttons.replace('L', '') + 'R'
				if px > 226 * 16:
					buttons = buttons.replace('R', '') + 'L'
			elif target is not None:
				if target < px - 32:
					buttons += 'L'
				elif target > px + 32:
					buttons += 'R'
			fire = (fire + 1) % 6
			hold = False
			if capture:
				# a Queen holding a fighter in the formation: not her (shoot her when she dives)
				for q in range(4):
					if w('arr_cap', q) and w('arr_swarm_es', q) == 3 and abs(w('arr_swarm_ex', q) - px) < 20 * 16:
						hold = True
					if w('arr_swarm_es', 40 + q) == 9 and abs(w('arr_swarm_ex', 40 + q) - px) < 10 * 16:
						hold = True
			if fire < 3 and not hold:
				buttons += 'A'
		md.set_pad(buttons or '-')
		md.run(1)
		if f % 120 == 0 and 'var_frames' in S:
			fr, tk = md.rword(S['var_frames'] & 0xFFFF), md.rword(S['ntc_ticks'] & 0xFFFF)
			if fr0 is not None and w('var_phase') == 1 and last.get('ph1'):
				lost = (tk - fr0[1]) - (fr - fr0[0])
				if lost > 1:
					slow.append((f, lost))
			last['ph1'] = (w('var_phase') == 1)
			fr0 = (fr, tk)
		if prefix and (f % every == 0):
			md.png('%s%06d.png' % (prefix, f), 1)
		t = md.text()
		if 'EXCEPTION' in t:
			print('EXCEPTION at frame', f)
			print(t)
			break
	for e in events:
		print(e[0], e[1])
	print('end: shots', l('var_shots'), 'hits', l('var_hits'))
	print('frames lost (more than 1 in 120):', len(slow), slow[:20])


if __name__ == '__main__':
	main()
