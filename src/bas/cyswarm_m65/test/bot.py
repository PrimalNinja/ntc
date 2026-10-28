#!/usr/bin/env python3
# bot.py - plays CYBORG SWARM on Xemu (NTC's test/m65run.py) for testing:
# it reads the game's RAM by the labels in the vasm listing, steers under the lowest enemy,
# dodges shots, fires, and reports what happened (stages, deaths, captures, rescues).
# (c) 2026 Cyborg Unicorn Pty Ltd
#
#   python3 test/bot.py build/CYSWARM.PRG build/CYSWARM.lst [frames] [--shots=prefix] [--every=n]
#   (--shots: a picture every n frames, and 40 frames after each change of state (15 into a rescue))
#                       [--capture] [--idle]
# --capture: walks into tractor beams and holds fire under captured fighters (tests the capture
# and the rescue); --idle: does nothing (tests dying, game over, the results). NTC_SRC: NTC's src
# folder (for test/m65run.py), else ../ntc/src next to the game's folder. build.js writes the listing.

import os
import re
import sys

# NTC's test folder: beside its src/ (src/test/ in an older NTC)
def ntctest(src):
	t = os.path.join(src, '..', 'test')
	return t if os.path.exists(os.path.join(t, 'm65run.py')) else os.path.join(src, 'test')

HERE = os.path.dirname(os.path.abspath(__file__))
NTC = os.environ.get('NTC_SRC') or next((p for p in (os.path.join(HERE, '..', '..', 'ntc', 'src'), os.path.join(HERE, '..', '..', '..', 'ntc', 'src'), os.path.join(HERE, '..', '..', '..')) if os.path.exists(os.path.join(p, '..', 'test', 'm65run.py')) or os.path.exists(os.path.join(p, 'test', 'm65run.py'))), '.')
sys.path.insert(0, ntctest(NTC))
from m65run import M65		# noqa: E402


def symbols(lst):
	out = {}
	for line in open(lst, errors='replace'):
		m = re.match(r'^(\w+)\s+[AE]:([0-9A-F]{4})\s*$', line)
		if m:
			out[m.group(1)] = int(m.group(2), 16)
	return out


def main():
	rom, lst = sys.argv[1], sys.argv[2]
	frames = 20000
	prefix = None
	every = 600
	later = []			# frames to take a picture at (40 after each change, 15 into a rescue: --shots)
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
	S = symbols(lst)
	md = M65(rom)
	pages = {}

	def byte(a):
		# memory read a 256 byte page at a time, fresh each frame (pages is emptied after run)
		p = a >> 8
		if p not in pages:
			pages[p] = md.ram(p << 8, 256)
		return pages[p][a & 255]

	def w(name, i=0):
		a = S[name] + i * 2
		v = byte(a) | (byte(a + 1) << 8)
		return v - 65536 if v >= 32768 else v

	def l(name):
		a = S[name]
		v = byte(a) | (byte(a + 1) << 8) | (byte(a + 2) << 16) | (byte(a + 3) << 24)
		return v - (1 << 32) if v >= (1 << 31) else v
	last = {}
	events = []
	slow = []
	total = [0, 0]			# frames lost, frames (in the fighting: phase 1)
	fr0 = None
	fire = 0
	for f in range(frames):
		pstate = w('var_pstate')
		phase = w('var_phase')
		stage = w('var_stage')
		state = (stage, phase, pstate, w('var_dual'), w('var_lives'), w('var_beamq') >= 0, w('var_freeing') != 0)
		if f > 50 and state != last.get('s'):
			events.append((f, 'stage %d phase %d pstate %d dual %d lives %d score %d%s%s' % (stage, phase, pstate, w('var_dual'), w('var_lives'), l('var_score'), ' (beam)' if state[5] else '', ' (freeing)' if state[6] else '')))
			last['s'] = state
			later.append(f + (15 if state[6] else 40))
		buttons = ''
		if (stage == 0 or phase == 9) and f % 60 == (30 + seed * 7) % 60:
			buttons += 'F'		# start a game on the title
		if pstate == 0 and not idle and stage != 0 and phase != 9:
			px = w('var_px')
			# the danger: enemy shots coming down near
			threat = None
			for k in range(8):
				if w('arr_bba', k):
					bx, by = w('arr_bx', k), w('arr_by', k)
					if by > 107 * 16 and abs(bx - px) < 20 * 16:
						threat = bx
			target = None
			best = -9999
			for e in range(44):
				s = w('arr_swarm_es', e)
				if s in (1, 2, 3, 5, 9, 13, 14):
					ey = w('arr_swarm_ey', e)
					ex = w('arr_swarm_ex', e)
					if s != 3 and ey > 134 * 16 and abs(ex - px) < 24 * 16:
						threat = ex
					if ey > best and (s == 3 or ey < 152 * 16):
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
			if capture and w('var_beamq') >= 0 and w('arr_swarm_es', w('var_beamq')) == 5 and w('var_dual') == 0:
				hold = True
			if capture:
				# a Queen holding a fighter in the formation: not her (shoot her when she dives)
				for q in range(4):
					if w('arr_cap', q) and w('arr_swarm_es', q) == 3 and abs(w('arr_swarm_ex', q) - px) < 20 * 16:
						hold = True
					if w('arr_swarm_es', 40 + q) == 9 and abs(w('arr_swarm_ex', 40 + q) - px) < 10 * 16:
						hold = True
			if fire < 3 and not hold:
				buttons += 'F'
		md.set_joy(buttons)
		md.run(1)
		pages.clear()
		if f % 120 == 0 and 'var_frames' in S:
			fr, tk = w('var_frames') & 0xFFFF, w('ntc_ticks') & 0xFFFF
			if fr0 is not None and w('var_phase') == 1 and last.get('ph1'):
				lost = ((tk - fr0[1]) & 0xFFFF) - ((fr - fr0[0]) & 0xFFFF)
				total[0] += lost
				total[1] += (tk - fr0[1]) & 0xFFFF
				if lost > 1:
					slow.append((f, lost))
			# (the results screen at the game's end waits on its own: not the game loop)
			last['ph1'] = (w('var_phase') == 1) and not (w('var_pstate') == 4 and w('var_lives') == 0)
			fr0 = (fr, tk)
		if prefix and f in later:
			md.png('%se%06d.png' % (prefix, f))
		if prefix and (f % every == 0):
			md.png('%s%06d.png' % (prefix, f))
		if f % 50 == 0 and md.ended():
			print('the program stopped at frame', f)
			break
	for e in events:
		print(e[0], e[1])
	print('end: shots', l('var_shots'), 'hits', l('var_hits'))
	print('frames lost (more than 1 in 120):', len(slow), slow[:20])
	print('frames lost in all: %d of %d (phase 1)' % (total[0], total[1]))
	md.close()


if __name__ == '__main__':
	main()
