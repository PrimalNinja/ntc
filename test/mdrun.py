#!/usr/bin/env python3
# mdrun.py - run a Mega Drive ROM on the Genesis Plus GX libretro core, for NTC's md platform
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# A small libretro front end (ctypes): no window, no sound. It runs a ROM for so many frames,
# holds pad buttons by a script, and can save pictures, print the text on plane A (NTC's md
# console: tile n = character n) and read the 68000's RAM.
#
#   python3 mdrun.py ROM.md [--frames=N] [--pad=SCRIPT] [--shot=out.png] [--shots=f1,f2:prefix]
#                    [--text] [--log] [--untilend] [--ram=addr,len] [--core=path/to/genesis_plus_gx_libretro.so]
#
# SCRIPT: frame:buttons,... - from that frame on the buttons are held (U D L R A B C S X Y Z M,
# '-' none), e.g. --pad=120:S,130:-,200:R,260:RA
# The core: build Genesis Plus GX (github.com/ekeeke/Genesis-Plus-GX) with
#   make -f Makefile.libretro
# after adding "vram; cram; reg; work_ram; m68k;" to the global: line of libretro/link.T, so
# this script can read the VDP's memory. NTC_MDCORE (the environment) can give its path.

import ctypes as C
import os
import struct
import sys
import zlib

RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY = 9
RETRO_ENVIRONMENT_SET_PIXEL_FORMAT = 10
RETRO_ENVIRONMENT_GET_VARIABLE = 15
RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE = 17
RETRO_ENVIRONMENT_GET_LOG_INTERFACE = 27
RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY = 31
RETRO_ENVIRONMENT_GET_CAN_DUPE = 3

PADBITS = {'B': 0, 'A': 1, 'S': 3, 'U': 4, 'D': 5, 'L': 6, 'R': 7, 'C': 8, 'Y': 9, 'X': 10, 'Z': 11, 'M': 2}
# retro ids as Genesis Plus GX maps them: MD A = retro Y (1), B = retro B (0), C = retro A (8),
# X = L (10), Y = X (9), Z = R (11), Mode = Select (2)


class retro_game_info(C.Structure):
	_fields_ = [('path', C.c_char_p), ('data', C.c_void_p), ('size', C.c_size_t), ('meta', C.c_char_p)]


class retro_variable(C.Structure):
	_fields_ = [('key', C.c_char_p), ('value', C.c_char_p)]


ENVCB = C.CFUNCTYPE(C.c_bool, C.c_uint, C.c_void_p)
VIDEOCB = C.CFUNCTYPE(None, C.c_void_p, C.c_uint, C.c_uint, C.c_size_t)
AUDIOCB = C.CFUNCTYPE(None, C.c_int16, C.c_int16)
AUDIOBATCHCB = C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t)
POLLCB = C.CFUNCTYPE(None)
INPUTCB = C.CFUNCTYPE(C.c_int16, C.c_uint, C.c_uint, C.c_uint, C.c_uint)


class MD:
	def __init__(self, rom, core=None):
		core = core or os.environ.get('NTC_MDCORE') or os.path.join(os.path.dirname(os.path.abspath(__file__)), 'genesis_plus_gx_libretro.so')
		self.lib = C.CDLL(core)
		self.fmt = 0			# 0 = 0RGB1555, 2 = RGB565, 1 = XRGB8888
		self.frame = None
		self.w = 0
		self.h = 0
		self.pitch = 0
		self.pad = [0, 0]
		self.sysdir = C.c_char_p(os.path.dirname(os.path.abspath(rom)).encode())
		self._cbs = [ENVCB(self.env), VIDEOCB(self.video), AUDIOCB(lambda l, r: None), AUDIOBATCHCB(lambda d, n: n), POLLCB(lambda: None), INPUTCB(self.input)]
		self.lib.retro_set_environment(self._cbs[0])
		self.lib.retro_set_video_refresh(self._cbs[1])
		self.lib.retro_set_audio_sample(self._cbs[2])
		self.lib.retro_set_audio_sample_batch(self._cbs[3])
		self.lib.retro_set_input_poll(self._cbs[4])
		self.lib.retro_set_input_state(self._cbs[5])
		self.lib.retro_init()
		data = open(rom, 'rb').read()
		self._rom = C.create_string_buffer(data, len(data))
		info = retro_game_info(rom.encode(), C.cast(self._rom, C.c_void_p), len(data), None)
		if not self.lib.retro_load_game(C.byref(info)):
			raise RuntimeError('the core did not load ' + rom)
		self.vram = (C.c_uint8 * 0x10000).in_dll(self.lib, 'vram')
		self.cram = (C.c_uint8 * 0x80).in_dll(self.lib, 'cram')
		self.reg = (C.c_uint8 * 0x20).in_dll(self.lib, 'reg')
		self.wram = (C.c_uint8 * 0x10000).in_dll(self.lib, 'work_ram')

	def env(self, cmd, data):
		cmd &= 0xffff
		if cmd in (RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY):
			C.cast(data, C.POINTER(C.c_char_p))[0] = self.sysdir.value
			return True
		if cmd == RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
			self.fmt = C.cast(data, C.POINTER(C.c_int))[0]
			return True
		if cmd == RETRO_ENVIRONMENT_GET_CAN_DUPE:
			C.cast(data, C.POINTER(C.c_bool))[0] = True
			return True
		if cmd == RETRO_ENVIRONMENT_GET_VARIABLE:
			v = C.cast(data, C.POINTER(retro_variable))[0]
			v.value = None
			return False
		return False

	def video(self, data, w, h, pitch):
		if data:
			self.w, self.h, self.pitch = w, h, pitch
			self.frame = C.string_at(data, pitch * h)

	def input(self, port, device, index, ident):
		if port > 1:
			return 0
		if ident == 256:
			return self.pad[port]
		return 1 if (self.pad[port] >> ident) & 1 else 0

	def set_pad(self, text, port=0):
		bits = 0
		for ch in text.upper():
			if ch in PADBITS:
				bits |= 1 << PADBITS[ch]
		self.pad[port] = bits

	def run(self, n=1):
		for _ in range(n):
			self.lib.retro_run()

	# ---- memory: the core keeps VRAM and work RAM as host words (bytes swapped on a little
	# endian host)
	def vword(self, addr):
		a = addr & 0xfffe
		return self.vram[a] | (self.vram[a + 1] << 8)

	def ram(self, addr, n):
		out = bytearray()
		for i in range(n):
			a = (addr + i) & 0xffff
			out.append(self.wram[a ^ 1])
		return bytes(out)

	def rword(self, addr):
		b = self.ram(addr, 2)
		return (b[0] << 8) | b[1]

	# plane A as text: NTC's md console puts character c in tile c (its name table at #C000,
	# 64 cells a row), so the low 11 bits of each cell are the character
	# NTC_MDLOG builds: what the console was given (from $FF0000, the end's address at $FF6FFC)
	def log(self):
		end = int.from_bytes(self.ram(0x6FFC, 4), 'big') & 0xFFFF
		if end <= 0 or end > 0x6FF0:
			return ''
		return self.ram(0, end).decode('latin-1')

	def text(self):
		base = (self.reg[2] & 0x38) << 10
		width = (32, 64, 64, 128)[self.reg[16] & 3]
		rows = []
		for y in range(28):
			s = ''
			for x in range(40):
				c = self.vword(base + (y * width + x) * 2) & 0x7ff
				s += chr(c) if 32 <= c < 127 else ' '
			rows.append(s.rstrip())
		while rows and rows[-1] == '':
			rows.pop()
		return '\n'.join(rows)

	def png(self, path, scale=1):
		w, h = self.w, self.h
		rows = []
		for y in range(h):
			line = bytearray([0])
			off = y * self.pitch
			for x in range(w):
				if self.fmt == 1:
					v = struct.unpack_from('<I', self.frame, off + x * 4)[0]
					r, g, b = (v >> 16) & 255, (v >> 8) & 255, v & 255
				else:
					v = struct.unpack_from('<H', self.frame, off + x * 2)[0]
					if self.fmt == 2:
						r, g, b = (v >> 11) << 3, ((v >> 5) & 63) << 2, (v & 31) << 3
					else:
						r, g, b = ((v >> 10) & 31) << 3, ((v >> 5) & 31) << 3, (v & 31) << 3
				line += bytes([r, g, b]) * scale
			for _ in range(scale):
				rows.append(bytes(line))
		raw = b''.join(rows)

		def chunk(t, d):
			c = struct.pack('>I', len(d)) + t + d
			return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
		data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w * scale, h * scale, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
		open(path, 'wb').write(data)


def main():
	args = sys.argv[1:]
	rom = None
	frames = 300
	pad = {}
	shot = None
	shots = []
	shotprefix = 'shot'
	want_text = False
	want_log = False
	until_quiet = False
	ramreq = None
	core = None
	scale = 1
	for a in args:
		if a.startswith('--frames='):
			frames = int(a[9:])
		elif a.startswith('--pad='):
			for part in a[6:].split(','):
				f, b = part.split(':')
				pad[int(f)] = b
		elif a.startswith('--shot='):
			shot = a[7:]
		elif a.startswith('--shots='):
			spec = a[8:]
			if ':' in spec:
				spec, shotprefix = spec.split(':', 1)
			shots = [int(x) for x in spec.split(',') if x]
		elif a == '--text':
			want_text = True
		elif a == '--log':
			want_log = True
		elif a == '--untilend':
			until_quiet = True
		elif a.startswith('--ram='):
			x, n = a[6:].split(',')
			ramreq = (int(x, 0), int(n, 0))
		elif a.startswith('--core='):
			core = a[7:]
		elif a.startswith('--scale='):
			scale = int(a[8:])
		else:
			rom = a
	md = MD(rom, core)
	quiet = 0
	last = None
	for f in range(frames):
		if until_quiet and (f % 30 == 0):
			cur = md.log()
			quiet = quiet + 1 if cur == last else 0
			last = cur
			if quiet >= 4:
				break
		if f in pad:
			md.set_pad(pad[f])
		md.run(1)
		if (f + 1) in shots:
			md.png('%s%05d.png' % (shotprefix, f + 1), scale)
	if shot:
		md.png(shot, scale)
	if want_text:
		print(md.text())
	if want_log:
		sys.stdout.write(md.log())
	if ramreq:
		print(md.ram(ramreq[0], ramreq[1]).hex())


if __name__ == '__main__':
	main()
