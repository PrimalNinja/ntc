#!/usr/bin/env python3
# mdbuild.py - build a Mega Drive ROM from NTC BASIC (the md platform)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
#   python3 mdbuild.py Main.bas [More.cls ...] --out=GAME.md [--name="GAME NAME"] [--log]
#                      [--vasm=path/to/vasmm68k_mot] [--list=GAME.lst] [--asm=GAME.s]
#
# Compiles with the NTC compiler (test/cli.js, --platform=md), assembles with vasm (Motorola
# syntax: vasmm68k_mot -spaces -Fbin -coalesced), then fills in the cartridge header: the
# name ($120 and $150), the ROM's end ($1A4) and the checksum ($18E).
# --log: a test build (vasm -DNTC_MDLOG=1): what the console prints is kept in RAM from
# $FF0000 too, for test/mdrun.py --log.
# vasm: http://sun.hasenbraten.de/vasm/ (make CPU=m68k SYNTAX=mot); NTC_VASM can give its path.

import os
import subprocess
import sys


def main():
	here = os.path.dirname(os.path.abspath(__file__))
	files = []
	out = None
	name = None
	log = False
	vasm = os.environ.get('NTC_VASM', 'vasmm68k_mot')
	listing = None
	asmout = None
	extra = []
	for a in sys.argv[1:]:
		if a.startswith('--out='):
			out = a[6:]
		elif a.startswith('--name='):
			name = a[7:]
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
		print(__doc__ or 'mdbuild.py Main.bas ... --out=GAME.md')
		sys.exit(1)
	out = out or os.path.splitext(files[0])[0] + '.md'
	asmout = asmout or os.path.splitext(out)[0] + '.s'
	r = subprocess.run(['node', os.path.join(here, 'cli.js'), '--platform=md', '--name=' + os.path.splitext(os.path.basename(out))[0]] + extra + files, capture_output=True, text=True)
	errs = [l for l in r.stderr.splitlines() if l.startswith('ERR')]
	for l in r.stderr.splitlines():
		print(l, file=sys.stderr)
	if errs or r.returncode != 0:
		sys.exit(1)
	open(asmout, 'w').write(r.stdout)
	cmd = [vasm, '-quiet', '-spaces', '-Fbin', '-coalesced', '-o', out]
	if log:
		cmd.append('-DNTC_MDLOG=1')
	if listing:
		cmd += ['-L', listing]
	cmd.append(asmout)
	r = subprocess.run(cmd, capture_output=True, text=True)
	if r.returncode != 0:
		print(r.stdout + r.stderr, file=sys.stderr)
		sys.exit(1)
	rom = bytearray(open(out, 'rb').read())
	if len(rom) & 1:
		rom.append(0)
	if name is None:
		name = os.path.splitext(os.path.basename(out))[0]
	nm = name.upper().encode('ascii', 'replace')[:48].ljust(48, b' ')
	rom[0x120:0x150] = nm
	rom[0x150:0x180] = nm
	end = len(rom) - 1
	rom[0x1A4:0x1A8] = end.to_bytes(4, 'big')
	total = 0
	for i in range(0x200, len(rom), 2):
		total = (total + (rom[i] << 8) + rom[i + 1]) & 0xFFFF
	rom[0x18E:0x190] = total.to_bytes(2, 'big')
	open(out, 'wb').write(rom)
	print('%s: %d bytes' % (out, len(rom)))


if __name__ == '__main__':
	main()
