#!/usr/bin/env python3
# m65build.py - build a MEGA65 PRG from NTC BASIC (the m65 platform)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
#   python3 m65build.py Main.bas [More.cls ...] --out=GAME.PRG [--log] [--vasm=path/to/vasm6502_oldstyle]
#                       [--list=GAME.lst] [--asm=GAME.s] [--const=NAME=value]
#
# Compiles with the NTC compiler (test/cli.js, --platform=m65), assembles with vasm (6502,
# oldstyle syntax, the 45GS02's instructions: vasm6502_oldstyle -mega65 -opt-branch -Fbin),
# then puts the load address ($2001) in front: a PRG that BASIC 65 loads and RUNs.
# --log: a test build (vasm -DNTC_M65LOG=1): what the console prints is kept from $10000 too,
# for test/m65run.py --log.
# vasm: http://sun.hasenbraten.de/vasm/ (make CPU=6502 SYNTAX=oldstyle); NTC_VASM65 can give its path.

import os
import subprocess
import sys


def main():
	here = os.path.dirname(os.path.abspath(__file__))
	files = []
	out = None
	log = False
	vasm = os.environ.get('NTC_VASM65', 'vasm6502_oldstyle')
	listing = None
	asmout = None
	extra = []
	for a in sys.argv[1:]:
		if a.startswith('--out='):
			out = a[6:]
		elif a == '--log':
			log = True
		elif a.startswith('--vasm='):
			vasm = a[7:]
		elif a.startswith('--list='):
			listing = a[7:]
		elif a.startswith('--asm='):
			asmout = a[6:]
		elif a.startswith('--const='):
			extra.append(a)
		else:
			files.append(a)
	if not files:
		print('m65build.py Main.bas ... --out=GAME.PRG [--log]')
		sys.exit(1)
	out = out or os.path.splitext(files[0])[0] + '.prg'
	asmout = asmout or os.path.splitext(out)[0] + '.s'
	r = subprocess.run(['node', os.path.join(here, 'cli.js'), '--platform=m65', '--name=' + os.path.splitext(os.path.basename(out))[0]] + extra + files, capture_output=True, text=True)
	errs = [l for l in r.stderr.splitlines() if l.startswith('ERR')]
	for l in r.stderr.splitlines():
		print(l, file=sys.stderr)
	if errs or r.returncode != 0:
		sys.exit(1)
	open(asmout, 'w').write(r.stdout)
	binout = out + '.bin'
	cmd = [vasm, '-quiet', '-mega65', '-opt-branch', '-Fbin', '-o', binout]
	if log:
		cmd.append('-DNTC_M65LOG=1')
	if listing:
		cmd += ['-L', listing]
	cmd.append(asmout)
	r = subprocess.run(cmd, capture_output=True, text=True)
	if r.returncode != 0:
		print(r.stdout + r.stderr, file=sys.stderr)
		sys.exit(1)
	body = open(binout, 'rb').read()
	os.remove(binout)
	open(out, 'wb').write(bytes([0x01, 0x20]) + body)
	end = 0x2001 + len(body)
	print('%s: %d bytes ($2001-$%04X)' % (out, len(body) + 2, end - 1))


if __name__ == '__main__':
	main()
