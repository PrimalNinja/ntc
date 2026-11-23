#!/usr/bin/env python3
# ngrun.py - run a Neo Geo cartridge (.neo) on the Geolith libretro core, for NTC's neogeo
# platform. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# A small libretro front end (ctypes): no window. It runs a cartridge for so many frames in
# Geolith's AES (home console) mode, holds pad buttons by a script, and can save pictures, print
# the fix layer's text (NTC's console: tile n = character n), read the 68000's RAM and keep the
# sound. The BIOS is test/ngsys/aes.zip (NTC's stand-in: test/ngbuild.js makes it).
#
#   python3 ngrun.py GAME.neo [--frames=N] [--pad=SCRIPT] [--shot=out.png] [--shots=f1,f2:prefix]
#                    [--text] [--log] [--untilend] [--ram=addr,len] [--wav=out.wav]
#                    [--core=path/to/geolith_libretro.so]
#
# SCRIPT: frame:buttons,... - from that frame on the buttons are held (U D L R A B C D S=Start
# E=Select, '-' none), e.g. --pad=120:S,130:-,200:R,260:RA
# The core: github.com/libretro/geolith-libretro, `make` in libretro/. NTC_NGCORE (the
# environment) can give its path.

import ctypes as C
import os
import struct
import sys
import wave
import zlib

RETRO_ENVIRONMENT_GET_CAN_DUPE = 3
RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY = 9
RETRO_ENVIRONMENT_SET_PIXEL_FORMAT = 10
RETRO_ENVIRONMENT_GET_VARIABLE = 15
RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE = 17
RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY = 31
RETRO_MEMORY_SYSTEM_RAM = 2
RETRO_MEMORY_VIDEO_RAM = 3

# the core's pad: retro ids (Geolith: A = retro B, B = retro A, C = retro Y, D = retro X)
PADBITS = {'U': 4, 'D': 5, 'L': 6, 'R': 7, 'A': 0, 'B': 8, 'C': 1, 'X': 9, 'S': 3, 'E': 2}
VARS = {b'geolith_system_type': b'aes', b'geolith_region': b'us', b'geolith_settingmode': b'off',
	b'geolith_4player': b'off', b'geolith_freeplay': b'off', b'geolith_memcard': b'off',
	b'geolith_sprlimit': b'96', b'geolith_overscan_t': b'0', b'geolith_overscan_b': b'0',
	b'geolith_overscan_l': b'0', b'geolith_overscan_r': b'0', b'geolith_palette': b'resnet'}


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


class NG:
	def __init__(self, rom, core=None, sound=False, vars=None):
		here = os.path.dirname(os.path.abspath(__file__))
		core = core or os.environ.get('NTC_NGCORE') or os.path.join(here, 'geolith_libretro.so')
		self.lib = C.CDLL(core)
		self.fmt = 1
		self.frame = None
		self.w = self.h = self.pitch = 0
		self.pad = [0, 0]
		self.sound = sound
		self.audio = bytearray()
		self.vars = dict(VARS)
		if vars:
			self.vars.update(vars)
		self._vals = {}
		self.sysdir = C.c_char_p(os.path.join(here, 'ngsys').encode())
		self._cbs = [ENVCB(self.env), VIDEOCB(self.video), AUDIOCB(lambda l, r: None), AUDIOBATCHCB(self.batch), POLLCB(lambda: None), INPUTCB(self.input)]
		self.lib.retro_set_environment(self._cbs[0])
		self.lib.retro_set_video_refresh(self._cbs[1])
		self.lib.retro_set_audio_sample(self._cbs[2])
		self.lib.retro_set_audio_sample_batch(self._cbs[3])
		self.lib.retro_set_input_poll(self._cbs[4])
		self.lib.retro_set_input_state(self._cbs[5])
		self.lib.retro_init()
		info = retro_game_info(os.path.abspath(rom).encode(), None, 0, None)
		if not self.lib.retro_load_game(C.byref(info)):
			raise RuntimeError('the core did not load ' + rom)
		self.lib.retro_get_memory_data.restype = C.c_void_p
		self.lib.retro_get_memory_size.restype = C.c_size_t
		p = self.lib.retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM)
		self.wram = (C.c_uint8 * 0x10000).from_address(p)
		p = self.lib.retro_get_memory_data(RETRO_MEMORY_VIDEO_RAM)
		self.vram = (C.c_uint16 * 0x10000).from_address(p)

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
			k = v.key
			if k in self.vars:
				if k not in self._vals:
					self._vals[k] = C.c_char_p(self.vars[k])
				v.value = self._vals[k].value
				return True
			v.value = None
			return False
		if cmd == RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
			C.cast(data, C.POINTER(C.c_bool))[0] = False
			return True
		return False

	def video(self, data, w, h, pitch):
		if data:
			self.w, self.h, self.pitch = w, h, pitch
			self.frame = C.string_at(data, pitch * h)

	def batch(self, data, n):
		if self.sound:
			self.audio += C.string_at(data, n * 4)
		return n

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

	# ---- the 68000's RAM ($100000-$10FFFF, as the 68000 sees it: big endian)
	def ram(self, addr, n):
		a = addr & 0xffff
		return bytes(self.wram[a:a + n])

	def rbyte(self, addr):
		return self.wram[addr & 0xffff]

	def rword(self, addr):
		a = addr & 0xffff
		return (self.wram[a] << 8) | self.wram[a + 1]

	def wword(self, addr, v):
		a = addr & 0xffff
		self.wram[a] = (v >> 8) & 255
		self.wram[a + 1] = v & 255

	# NTC_NGLOG builds: what the console was given (from $10C000, the end's address at $10DFFC)
	def log(self):
		end = int.from_bytes(self.ram(0xDFFC, 4), 'big') & 0xFFFF
		if end <= 0xC000 or end > 0xDFF0:
			return ''
		return self.ram(0xC000, end - 0xC000).decode('latin-1')

	# the fix layer as text (rows 2-29, 40 columns; tile n = character n)
	def text(self):
		rows = []
		for y in range(2, 30):
			s = ''
			for x in range(40):
				c = self.vram[0x7000 + x * 32 + y] & 0xfff
				s += chr(c) if 32 <= c < 127 else ' '
			rows.append(s.rstrip())
		while rows and rows[-1] == '':
			rows.pop()
		return '\n'.join(rows)

	def rgb(self):
		# the picture as rows of (r, g, b) bytes
		w, h = self.w, self.h
		out = []
		for y in range(h):
			line = bytearray()
			off = y * self.pitch
			for x in range(w):
				v = struct.unpack_from('<I', self.frame, off + x * 4)[0]
				line += bytes(((v >> 16) & 255, (v >> 8) & 255, v & 255))
			out.append(bytes(line))
		return out

	def png(self, path, scale=1):
		w, h = self.w, self.h
		rows = []
		for line in self.rgb():
			l2 = bytearray([0])
			for x in range(w):
				l2 += line[x * 3:x * 3 + 3] * scale
			for _ in range(scale):
				rows.append(bytes(l2))
		raw = b''.join(rows)

		def chunk(t, d):
			c = struct.pack('>I', len(d)) + t + d
			return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
		data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w * scale, h * scale, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
		open(path, 'wb').write(data)

	def rate(self):
		# the core's sample rate (retro_system_av_info: the geometry's 4 uints and a float, then (at 24)
		# fps and the sample rate as doubles)
		av = (C.c_uint8 * 64)()
		self.lib.retro_get_system_av_info(C.byref(av))
		return struct.unpack_from('<d', bytes(av), 32)[0]

	def wav(self, path):
		w = wave.open(path, 'wb')
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(int(round(self.rate())))
		w.writeframes(bytes(self.audio))
		w.close()


def main():
	args = sys.argv[1:]
	rom = None
	frames = 300
	pad = {}
	shot = None
	shots = []
	shotprefix = 'shot'
	want_text = want_log = until_quiet = False
	ramreq = None
	core = None
	wavout = None
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
		elif a.startswith('--wav='):
			wavout = a[6:]
		else:
			rom = a
	ng = NG(rom, core, sound=bool(wavout))
	quiet = 0
	last = None
	for f in range(frames):
		if until_quiet and (f % 30 == 0) and f > 120:
			cur = ng.log()
			quiet = quiet + 1 if cur == last else 0
			last = cur
			if quiet >= 4:
				break
		if f in pad:
			ng.set_pad(pad[f])
		ng.run(1)
		if (f + 1) in shots:
			ng.png('%s%05d.png' % (shotprefix, f + 1))
	if shot:
		ng.png(shot)
	if want_text:
		print(ng.text())
	if want_log:
		sys.stdout.write(ng.log())
	if ramreq:
		print(ng.ram(ramreq[0], ramreq[1]).hex())
	if wavout:
		ng.wav(wavout)


if __name__ == '__main__':
	main()
