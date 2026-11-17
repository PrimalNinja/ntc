#!/usr/bin/env python3
# townsrun.py - run an FM Towns boot disc on the Tsugaru emulator (headless), for NTC's towns platform
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
#   python3 townsrun.py DISC.bin [--secs=N] [--keys=SECONDS:text,...] [--shot=out.png] [--log]
#                       [--exe=path/to/Tsugaru_Headless] [--rom=folder]
#
# Boots the disc with no window and waits until the program ends (a test build, townsbuild.js
# --log, marks its end in RAM) or --secs have gone (default 60). --log prints what the console
# was given (the transcript a test build keeps from $0A0000). --shot saves a picture.
# --keys types text at a time: \n = Return (the emulator always ends typed text with Return).
# --freq=N sets the emulated CPU's speed in MHz (the emulator's own default when left out).
# --anykey presses a key when the transcript ends with "Press a key".
# An exception in the program (a test build) is reported: EXCEPTION and the two words the CPU
# pushed.
# Tsugaru: github.com/captainys/TOWNSEMU (cmake, target Tsugaru_Headless). NTC_TSUGARU (the
# environment) can give its path, NTC_TOWNSROM the folder with the ROM images (the free
# compatible ones: github.com/captainys/TOWNSROM, release/forTsugaru).

import os
import subprocess
import sys
import tempfile
import time


def main():
	disc = None
	secs = 60.0
	keys = []
	shot = None
	want_log = False
	anykey = False
	freq = ''
	exe = os.environ.get('NTC_TSUGARU', 'Tsugaru_Headless')
	rom = os.environ.get('NTC_TOWNSROM', '.')
	for a in sys.argv[1:]:
		if a.startswith('--secs='):
			secs = float(a[7:])
		elif a.startswith('--keys='):
			for part in a[7:].split(','):
				t, text = part.split(':', 1)
				keys.append((float(t), text.replace('\\n', '\n')))
		elif a.startswith('--shot='):
			shot = os.path.abspath(a[7:])
		elif a == '--log':
			want_log = True
		elif a == '--anykey':
			anykey = True
		elif a.startswith('--freq='):
			freq = a[7:]
		elif a.startswith('--exe='):
			exe = a[6:]
		elif a.startswith('--rom='):
			rom = a[6:]
		else:
			disc = a
	tmp = tempfile.mkdtemp(prefix='townsrun')
	p = subprocess.Popen([exe, rom, '-FD0', os.path.abspath(disc), '-NOWAIT', '-DONTAUTOSAVECMOS', '-BOOTKEY', 'F0'] + (['-FREQ', freq] if freq else []),
		stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True, cwd=tmp)

	def cmd(text):
		p.stdin.write(text + '\n')
		p.stdin.flush()

	def peek(seg, off, n, name):
		f = os.path.join(tmp, name)
		if os.path.exists(f):
			os.remove(f)
		cmd('!SAVEMEMDUMP %s PHYS:%08X %X' % (f, (seg << 4) + off, n))
		for _ in range(40):
			time.sleep(0.05)
			if os.path.exists(f) and os.path.getsize(f) >= n:
				return open(f, 'rb').read()
		return b''

	t0 = time.time()
	state = b''
	done = set()
	while time.time() - t0 < secs:
		time.sleep(0.5)
		now = time.time() - t0
		for i, (t, text) in enumerate(keys):
			if (i not in done) and now >= t:
				done.add(i)
				for line in text.split('\n')[:-1] if text.endswith('\n') else [text]:
					cmd(line)
		state = peek(0x9000, 0xFFF0, 16, 'state.bin')
		if len(state) >= 4 and state[:4] in (b'\x0d\x0e\x0d\x0e', b'\xad\xde\xad\xde') and len(done) == len(keys):
			break
		if anykey and len(done) == len(keys) and len(state) >= 16:
			# --anykey: "Press a key" at the end of the transcript (Option PressAnyKeyOnEnd): press one
			end = int.from_bytes(state[12:16], 'little')
			if 0xA0000 + 11 <= end <= 0xAE000 and b'Press a key' in peek(0xA000, end - 0xA0000 - 14 if end >= 0xA000E else 0, 14 if end >= 0xA000E else end - 0xA0000, 'tail.bin'):
				anykey = False
				cmd('x')
	if shot:
		cmd('!SS ' + shot)
		time.sleep(0.7)
	out = ''
	if want_log and len(state) >= 16:
		end = int.from_bytes(state[12:16], 'little')
		if 0xA0000 < end <= 0xAE000:
			out = peek(0xA000, 0, end - 0xA0000, 'log.bin').decode('latin-1')
	cmd('!QUIT')
	try:
		p.wait(timeout=15)
	except subprocess.TimeoutExpired:
		p.kill()
	sys.stdout.write(out)
	if len(state) >= 12 and state[:4] == b'\xad\xde\xad\xde':
		print('\nEXCEPTION %08X %08X' % (int.from_bytes(state[4:8], 'little'), int.from_bytes(state[8:12], 'little')))
	elif len(state) < 4 or state[:4] != b'\x0d\x0e\x0d\x0e':
		print('\n(the program had not ended after %d seconds)' % secs)


if __name__ == '__main__':
	main()
