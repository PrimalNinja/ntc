#!/usr/bin/env python3
# m65run.py - run a MEGA65 program on Xemu (xmega65) for NTC's m65 platform
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# Xemu runs headless and as fast as it can; this script steers it frame by frame through the
# test driver NTC adds to Xemu (targets/mega65/ntctest.c, see docs/m65.md): it lets the
# hypervisor boot, puts the PRG into memory, starts it at its SYS address, holds the joystick,
# types keys, takes pictures and reads memory.
#
#   python3 m65run.py PROGRAM.PRG [--frames=N] [--joy=SCRIPT] [--keys=SCRIPT] [--shot=out.png]
#                     [--shots=f1,f2:prefix] [--text] [--log] [--untilend] [--ram=addr,len]
#                     [--xemu=path/to/xmega65.native]
#
# --joy: frame:buttons,... - from that frame on (counted from the program's start) port 2 holds
#   the buttons (U D L R F, '-' none), e.g. --joy=100:F,104:-,200:R
# --keys: frame:text,... - types the text from that frame on, one key a frame ('~' = RETURN)
# --text: prints the console (screen memory at $0800, NTC's m65 console: ASCII codes)
# --log: prints the console's log (test builds: assembled with -DNTC_M65LOG=1)
# --untilend: runs until the program ends (its "end" marker) or --frames
# NTC_XEMU (the environment) can give Xemu's path.

import os
import subprocess
import sys
import tempfile

JOYBITS = {'U': 0, 'D': 1, 'L': 2, 'R': 3, 'F': 4}

# fixed places the m65 platform uses (asm/ntc_plat_m65.asm)
SCREEN = 0x0800			# the console's screen memory (ASCII)
SCRINFO = 0x07F0		# columns, rows, the end marker ($A5 once the program has ended)
LOGPTR = 0x1FFFC		# test builds: the log's end (a 16-bit offset from LOGBASE)
LOGBASE = 0x10000		# test builds: the log (the console's text, $10000-$1FFFB)


class M65:
	def __init__(self, prg, xemu=None, boot=True):
		xemu = xemu or os.environ.get('NTC_XEMU') or os.path.join(os.path.dirname(os.path.abspath(__file__)), 'xmega65.native')
		self.tmp = tempfile.mkdtemp(prefix='m65run')
		os.makedirs(os.path.join(self.tmp, 'sd'), exist_ok=True)
		ri, wo = os.pipe()		# commands: we write wo, Xemu reads ri
		rr, wr = os.pipe()		# answers: Xemu writes wr, we read rr
		env = dict(os.environ)
		env.update({'SDL_VIDEODRIVER': 'dummy', 'SDL_AUDIODRIVER': 'dummy', 'NTC_M65_FDS': '%d,%d' % (ri, wr), 'HOME': self.tmp})
		self.log = open(os.path.join(self.tmp, 'xemu.log'), 'w')
		self.proc = subprocess.Popen([xemu, '-headless', '-sleepless', '-usestubrom', '-nosound', '-virtsd', '-sdimg', os.path.join(self.tmp, 'sd')],
			env=env, pass_fds=(ri, wr), stdout=self.log, stderr=subprocess.STDOUT, cwd=self.tmp)
		os.close(ri)
		os.close(wr)
		self.wr = os.fdopen(wo, 'w')
		self.rd = os.fdopen(rr, 'r')
		self.frame = 0
		self.prg = prg
		if boot:
			self.boot()
		if prg:
			self.start(prg)

	def cmd(self, text, answer=True):
		self.wr.write(text + '\n')
		self.wr.flush()
		if answer:
			r = self.rd.readline()
			if not r:
				raise RuntimeError('Xemu stopped (log: %s)' % os.path.join(self.tmp, 'xemu.log'))
			return r.strip()
		return None

	def run(self, n=1):
		self.cmd('run %d' % n)
		self.frame += n

	def boot(self):
		# the hypervisor's start: its on-boarding screen wants RETURN, then Xemu's stub ROM runs
		for i in range(200):
			self.run(10)
			if self.cmd('hyp') == '0' and i > 12:
				break
			if i % 3 == 0:
				self.cmd('key 13')
		self.run(20)

	def start(self, prg):
		data = open(prg, 'rb').read()
		load = data[0] | (data[1] << 8)
		body = data[2:]
		path = os.path.abspath(prg + '.body') if False else os.path.join(self.tmp, 'prg.bin')
		open(path, 'wb').write(body)
		self.cmd('loadf %x %s' % (load, path))
		# the SYS address in the BASIC line (token $9E, then digits)
		i = body.index(0x9E)
		j = i + 1
		while body[j] in b' ':
			j += 1
		k = j
		while 48 <= body[k] <= 57:
			k += 1
		self.sys = int(body[j:k])
		self.cmd('go %x' % self.sys)
		self.frame = 0

	def set_joy(self, buttons):
		v = 0xFF
		for c in buttons.upper():
			if c in JOYBITS:
				v &= ~(1 << JOYBITS[c])
		self.cmd('joy %x' % v)

	def key(self, code):
		self.cmd('key %d' % code)

	def ram(self, addr, n):
		h = self.cmd('mem %x %x' % (addr, n))
		return bytes.fromhex(h)

	def rword(self, addr):
		b = self.ram(addr, 2)
		return b[0] | (b[1] << 8)

	def ended(self):
		return self.ram(SCRINFO + 2, 1)[0] == 0xA5

	def text(self):
		cols, rows = self.ram(SCRINFO, 2)
		cols = cols or 80
		rows = rows or 25
		b = self.ram(SCREEN, cols * rows)
		out = []
		for r in range(rows):
			out.append(''.join(chr(c) if 32 <= c < 127 else ' ' for c in b[r * cols:(r + 1) * cols]).rstrip())
		while out and not out[-1]:
			out.pop()
		return '\n'.join(out)

	def logtext(self):
		b = self.ram(LOGPTR, 4)
		n = b[0] | (b[1] << 8) | (b[2] << 16)
		if n <= 0 or n > 0xFFFC:
			return ''
		return self.ram(LOGBASE, n).decode('latin-1')

	def png(self, path, crop=True):
		full = os.path.abspath(path)
		self.cmd('shot ' + full)
		self.run(2)
		if crop:
			try:
				from PIL import Image
				im = Image.open(full)
				# the PAL frame without the border: 640 x 400 from (80, 104) in Xemu's
				# 800 x 625 picture, halved to 320 x 200 when the screen is 40 columns
				im = im.crop((80, 104, 720, 504))
				im.save(full)
			except Exception:
				pass

	def close(self):
		try:
			self.cmd('exit', answer=False)
		except Exception:
			pass
		try:
			self.proc.wait(5)
		except Exception:
			self.proc.kill()


def main():
	args = sys.argv[1:]
	if not args or args[0].startswith('--'):
		print(__doc__ or 'm65run.py PROGRAM.PRG [options]')
		print(open(__file__).read().split('\n\n')[0])
		return 1
	prg = args[0]
	frames = 300
	joy = []
	keys = []
	shot = None
	shots = []
	prefix = 'shot'
	text = log = untilend = False
	ram = None
	xemu = None
	for a in args[1:]:
		if a.startswith('--frames='):
			frames = int(a[9:])
		elif a.startswith('--joy='):
			for part in a[6:].split(','):
				f, b = part.split(':')
				joy.append((int(f), b))
		elif a.startswith('--keys='):
			for part in a[7:].split(','):
				f, t = part.split(':', 1)
				keys.append((int(f), t))
		elif a.startswith('--shot='):
			shot = a[7:]
		elif a.startswith('--shots='):
			f, prefix = a[8:].split(':')
			shots = [int(x) for x in f.split(',')]
		elif a == '--text':
			text = True
		elif a == '--log':
			log = True
		elif a == '--untilend':
			untilend = True
		elif a.startswith('--ram='):
			x, n = a[6:].split(',')
			ram = (int(x, 0), int(n, 0))
		elif a.startswith('--xemu='):
			xemu = a[7:]
	m = M65(prg, xemu)
	typing = []
	try:
		for f in range(frames):
			for jf, b in joy:
				if jf == f:
					m.set_joy('' if b == '-' else b)
			for kf, t in keys:
				if kf == f:
					typing.extend(13 if c == '~' else ord(c) for c in t)
			if typing:
				m.key(typing.pop(0))
			if f in shots:
				m.png('%s%05d.png' % (prefix, f))
			m.run(1)
			if untilend and f % 10 == 0 and m.ended():
				break
		if shot:
			m.png(shot)
		if text:
			print(m.text())
		if log:
			print(m.logtext())
		if ram:
			print(m.ram(*ram).hex())
	finally:
		m.close()
	return 0


if __name__ == '__main__':
	sys.exit(main())
