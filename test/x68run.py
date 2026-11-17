#!/usr/bin/env python3
# x68run.py - run an X68000 disc image on the px68k libretro core, for NTC's x68000 platform
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# A small libretro front end (ctypes): no window, no sound. It boots a disc image (.xdf) for so
# many frames, types keys by a script, saves pictures and reads the 68000's RAM.
#
#   python3 x68run.py DISC.xdf [--frames=N] [--keys=SCRIPT] [--shot=out.png] [--log] [--untilend]
#                     [--ram=addr,len] [--core=path/to/px68k_libretro.so] [--sys=folder]
#
# SCRIPT: frame:text,... - at that frame the text is typed (\\n = Return), e.g. --keys=200:12\\n
# --log: an NTC test build (x68build --log) keeps what the console prints in RAM from NTC_X68LOG;
#   this prints it. --untilend stops when it has not grown for 2 seconds.
# The core: github.com/libretro/px68k-libretro (make -f Makefile.libretro). NTC_X68CORE (the
# environment) can give its path. --sys / NTC_X68SYS: the folder that has keropi/iplrom.dat and
# keropi/cgrom.dat (Sharp's X68000 ROMs).

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



LOGAT = 0x0F0000		# NTC_X68LOG: the transcript's start (its end's address in the long before it)
LOGCB = C.CFUNCTYPE(None, C.c_int, C.c_char_p)
KBCB = C.CFUNCTYPE(None, C.c_bool, C.c_uint, C.c_uint32, C.c_uint16)


class retro_keyboard_callback(C.Structure):
	_fields_ = [('callback', KBCB)]


class X68:
	def __init__(self, disc, core=None, sysdir=None):
		here = os.path.dirname(os.path.abspath(__file__))
		core = core or os.environ.get('NTC_X68CORE') or os.path.join(here, 'px68k_libretro.so')
		self.lib = C.CDLL(core)
		self.fmt = 0
		self.frame = None
		self.w = self.h = self.pitch = 0
		self.keys = set()
		self.kbcb = None
		self.sysdir = C.create_string_buffer(os.path.abspath(sysdir or os.environ.get('NTC_X68SYS') or here).encode())
		self._logcb = LOGCB(lambda level, fmt: (sys.stderr.write('core: ' + (fmt or b'').decode('latin-1')) if os.environ.get('NTC_X68CORELOG') else None) and None)
		self._cbs = [ENVCB(self.env), VIDEOCB(self.video), AUDIOCB(lambda l, r: None), AUDIOBATCHCB(lambda d, n: n), POLLCB(lambda: None), INPUTCB(self.input)]
		self.lib.retro_set_environment(self._cbs[0])
		self.lib.retro_set_video_refresh(self._cbs[1])
		self.lib.retro_set_audio_sample(self._cbs[2])
		self.lib.retro_set_audio_sample_batch(self._cbs[3])
		self.lib.retro_set_input_poll(self._cbs[4])
		self.lib.retro_set_input_state(self._cbs[5])
		self.lib.retro_init()
		self._path = os.path.abspath(disc).encode()
		info = retro_game_info(self._path, None, 0, None)
		if not self.lib.retro_load_game(C.byref(info)):
			raise RuntimeError('the core did not load ' + disc)
		self.lib.retro_get_memory_data.restype = C.c_void_p
		self.mem = self.lib.retro_get_memory_data(2)

	def env(self, cmd, data):
		cmd &= 0xffff
		if cmd in (RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY):
			C.cast(data, C.POINTER(C.c_void_p))[0] = C.addressof(self.sysdir)
			return True
		if cmd == RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
			self.fmt = C.cast(data, C.POINTER(C.c_int))[0]
			return True
		if cmd == RETRO_ENVIRONMENT_GET_CAN_DUPE:
			C.cast(data, C.POINTER(C.c_bool))[0] = True
			return True
		if cmd == RETRO_ENVIRONMENT_GET_LOG_INTERFACE:		# (the core calls its log without checking)
			C.cast(data, C.POINTER(C.c_void_p))[0] = C.cast(self._logcb, C.c_void_p).value
			return True
		if cmd == 12:		# SET_KEYBOARD_CALLBACK
			self.kbcb = C.cast(data, C.POINTER(retro_keyboard_callback))[0].callback
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
		if device == 3:		# the keyboard: ident = a RETROK code
			return 1 if ident in self.keys else 0
		return 0

	def key(self, code, down):
		if down:
			self.keys.add(code)
		else:
			self.keys.discard(code)
		if self.kbcb:
			self.kbcb(down, code, code if 32 <= code < 127 else 0, 0)

	def run(self, n=1):
		for _ in range(n):
			self.lib.retro_run()

	# the core keeps RAM as host words (bytes swapped on a little endian host)
	def ram(self, addr, n):
		raw = C.string_at(self.mem + (addr & ~1), n + 2)
		out = bytearray()
		for i in range(n):
			out.append(raw[((addr & 1) + i) ^ 1])
		return bytes(out)

	def log(self):
		end = int.from_bytes(self.ram(LOGAT - 4, 4), 'big')
		if end <= LOGAT or end > LOGAT + 0xF000:
			return ''
		return self.ram(LOGAT, end - LOGAT).decode('latin-1')

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
	disc = None
	frames = 600
	keys = {}
	shot = None
	want_log = False
	until_quiet = False
	ramreq = None
	core = None
	sysdir = None
	scale = 1
	for a in args:
		if a.startswith('--frames='):
			frames = int(a[9:])
		elif a.startswith('--keys='):
			for part in a[7:].split(','):
				f, t = part.split(':', 1)
				keys[int(f)] = t.replace('\\n', '\r')
		elif a.startswith('--shot='):
			shot = a[7:]
		elif a == '--log':
			want_log = True
		elif a == '--untilend':
			until_quiet = True
		elif a.startswith('--ram='):
			x, n = a[6:].split(',')
			ramreq = (int(x, 0), int(n, 0))
		elif a.startswith('--core='):
			core = a[7:]
		elif a.startswith('--sys='):
			sysdir = a[6:]
		elif a.startswith('--scale='):
			scale = int(a[8:])
		else:
			disc = a
	m = X68(disc, core, sysdir)
	typing = []		# (frame, code, down)
	for f0, t in keys.items():
		at = f0
		for ch in t:
			code = 13 if ch == '\r' else ord(ch.lower())
			if ch.isupper():
				typing.append((at, 304, True))		# left Shift held for a capital
				at += 2
			typing.append((at, code, True))
			typing.append((at + 4, code, False))
			if ch.isupper():
				typing.append((at + 6, 304, False))
			at += 8
	lastkey = max([x[0] for x in typing] + [0])
	quiet = 0
	last = None
	for f in range(frames):
		if until_quiet and (f % 30 == 0) and f >= 240 and f > lastkey + 60:
			cur = m.log()
			quiet = quiet + 1 if (cur == last and cur != '') else 0
			last = cur
			if quiet >= 4:
				break
		for (at, code, down) in typing:
			if at == f:
				m.key(code, down)
		m.run(1)
	if shot:
		m.png(shot, scale)
	if want_log:
		sys.stdout.write(m.log())
	if ramreq:
		print(m.ram(ramreq[0], ramreq[1]).hex())


if __name__ == '__main__':
	main()
