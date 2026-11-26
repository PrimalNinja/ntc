#!/usr/bin/env python3
# eprun.py - run an Enterprise program file on the ep128emu libretro core, for NTC's ep128 platform
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# A small libretro front end (ctypes): no window, no sound. The core starts an Enterprise 128
# (EXOS 2.1, IS-BASIC, EXDOS); this runs it for so many frames, types keys by a script, saves a
# picture and reads the machine's RAM.
#
#   python3 eprun.py GAME.IMG [--frames=N] [--keys=SCRIPT] [--hold=frame:key] [--joy=SCRIPT]
#                    [--joy2=SCRIPT] [--start=frames] [--shot=out.png] [--log] [--untilend]
#                    [--quiet=seconds] [--segs] [--core=path/to/ep128emu_core_libretro.so]
#
# GAME.IMG: the disc epbuild.js --img writes - EXDOS runs its EXDOS.INI, which loads the program
#   (a key at the title screen first: with --log or --untilend this presses Space there itself).
#   The sure way. GAME.COM: the program file alone, through the core's own file device and
#   IS-BASIC's START - it works most times, but the core's device now and then hands a program
#   over wrongly (one of a certain length nearly always), so the tests use the disc.
# --keys: frame:text,... - at that frame the text is typed (\\n = Enter), e.g. --keys=+100:12\\n
# --hold: frame:k - from that frame the key k is held down (a letter or digit; up down left right
#   space enter for those keys)
# --joy: frame:UDLRF,... - from that frame the joystick in control port 1 is held that way (- = let go);
#   --joy2 the same for control port 2 (the built in joystick is the cursor keys: --hold=frame:up)
# A frame written +n is n frames after the program started (its log first seen: --log builds).
# --start=frame,...: (a .COM) START (F1) pressed at those frames, instead of the script's own tries.
# --log: an NTC test build (epbuild --log) keeps what the console prints in a segment of its
#   own; this prints it. --untilend stops when the program has ended (or the text has not grown
#   for 3 seconds: --quiet=N for N seconds).
# --segs: the RAM segments the machine has.
# The machine's RAM: a GAME.ep128cfg beside the file with "memory.ram.size K" (epbuild --ram=K);
# 128K without. The core shows this script only the first 32 segments the machine has (ROMs
# included) - enough for 128K and up to about 448K. For more, build the core with the two
# limits in core/main.cpp's retro_load_game raised (desc[36] -> desc[304], dindex<32 -> dindex<300).
# The core: github.com/libretro/ep128emu-core (make). NTC_EPCORE (the environment) can give its path.

import ctypes as C
import os
import struct
import sys
import zlib

class retro_game_info(C.Structure):
	_fields_ = [('path', C.c_char_p), ('data', C.c_void_p), ('size', C.c_size_t), ('meta', C.c_char_p)]


class retro_variable(C.Structure):
	_fields_ = [('key', C.c_char_p), ('value', C.c_char_p)]


class retro_memory_descriptor(C.Structure):
	_fields_ = [('flags', C.c_uint64), ('ptr', C.c_void_p), ('offset', C.c_size_t), ('start', C.c_size_t), ('select', C.c_size_t),
		('disconnect', C.c_size_t), ('len', C.c_size_t), ('addrspace', C.c_char_p)]


class retro_memory_map(C.Structure):
	_fields_ = [('descriptors', C.POINTER(retro_memory_descriptor)), ('num', C.c_uint)]


ENVCB = C.CFUNCTYPE(C.c_bool, C.c_uint, C.c_void_p)
VIDEOCB = C.CFUNCTYPE(None, C.c_void_p, C.c_uint, C.c_uint, C.c_size_t)
AUDIOCB = C.CFUNCTYPE(None, C.c_int16, C.c_int16)
AUDIOBATCHCB = C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t)
POLLCB = C.CFUNCTYPE(None)
INPUTCB = C.CFUNCTYPE(C.c_int16, C.c_uint, C.c_uint, C.c_uint, C.c_uint)
LOGCB = C.CFUNCTYPE(None, C.c_int, C.c_char_p, C.c_void_p, C.c_void_p, C.c_void_p, C.c_void_p)
KBCB = C.CFUNCTYPE(None, C.c_bool, C.c_uint, C.c_uint32, C.c_uint16)


class retro_keyboard_callback(C.Structure):
	_fields_ = [('callback', KBCB)]


FTCB = C.CFUNCTYPE(None, C.c_int64)


class retro_frame_time_callback(C.Structure):
	_fields_ = [('callback', FTCB), ('reference', C.c_int64)]


KEYNAMES = {'up': 273, 'down': 274, 'right': 275, 'left': 276, 'space': 32, 'enter': 13, 'esc': 27, 'shift': 304}


class Enterprise:
	def __init__(self, prog, core=None, opts=None):
		here = os.path.dirname(os.path.abspath(__file__))
		core = core or os.environ.get('NTC_EPCORE') or os.path.join(here, 'ep128emu_core_libretro.so')
		self.opts = dict((k.encode(), C.create_string_buffer(v.encode())) for k, v in (opts or {}).items())
		self.pads = [0, 0, 0]
		self.lib = C.CDLL(core)
		self.fmt = 0
		self.frame = None
		self.w = self.h = self.pitch = 0
		self.keys = set()
		self.kbcb = None
		self.ftcb = None
		self.segs = {}		# segment number -> where its 16K is
		self.dir = C.create_string_buffer(os.path.dirname(os.path.abspath(prog)).encode())
		self._libc = C.CDLL(None)
		self._logcb = LOGCB(self.corelog)
		self._cbs = [ENVCB(self.env), VIDEOCB(self.video), AUDIOCB(lambda l, r: None), AUDIOBATCHCB(lambda d, n: n), POLLCB(lambda: None), INPUTCB(self.input)]
		self.lib.retro_set_environment(self._cbs[0])
		self.lib.retro_set_video_refresh(self._cbs[1])
		self.lib.retro_set_audio_sample(self._cbs[2])
		self.lib.retro_set_audio_sample_batch(self._cbs[3])
		self.lib.retro_set_input_poll(self._cbs[4])
		self.lib.retro_set_input_state(self._cbs[5])
		self.lib.retro_init()
		self._path = os.path.abspath(prog).encode()
		info = retro_game_info(self._path, None, 0, None)
		if not self.lib.retro_load_game(C.byref(info)):
			raise RuntimeError('the core did not load ' + prog)

	def corelog(self, level, fmt, a, b, c, d):
		if os.environ.get('NTC_EPCORELOG'):
			buf = C.create_string_buffer(1024)
			self._libc.snprintf(buf, 1024, fmt, C.c_void_p(a), C.c_void_p(b), C.c_void_p(c), C.c_void_p(d))
			sys.stderr.write('core: ' + buf.value.decode('latin-1'))

	def env(self, cmd, data):
		cmd &= 0xffff
		if cmd in (9, 31):		# GET_SYSTEM_DIRECTORY, GET_SAVE_DIRECTORY: beside the program
			C.cast(data, C.POINTER(C.c_void_p))[0] = C.addressof(self.dir)
			return True
		if cmd == 10:		# SET_PIXEL_FORMAT
			self.fmt = C.cast(data, C.POINTER(C.c_int))[0]
			return True
		if cmd == 3:		# GET_CAN_DUPE
			C.cast(data, C.POINTER(C.c_bool))[0] = True
			return True
		if cmd == 27:		# GET_LOG_INTERFACE
			C.cast(data, C.POINTER(C.c_void_p))[0] = C.cast(self._logcb, C.c_void_p).value
			return True
		if cmd == 12:		# SET_KEYBOARD_CALLBACK
			self.kbcb = KBCB(C.cast(data, C.POINTER(C.c_void_p))[0])
			return True
		if cmd == 21:		# SET_FRAME_TIME_CALLBACK: the core runs the machine for the time it is told has passed
			self.ftcb = FTCB(C.cast(data, C.POINTER(C.c_void_p))[0])		# (the address copied: the core's own record is gone after this call)
			return True
		if cmd == 36:		# SET_MEMORY_MAPS: the machine's segments (the list is the core's own for this call only)
			mm = C.cast(data, C.POINTER(retro_memory_map))[0]
			for i in range(mm.num):
				d = mm.descriptors[i]
				if d.ptr and d.len == 0x4000:
					self.segs[d.start >> 14] = d.ptr
			return True
		if cmd == 15:		# GET_VARIABLE
			v = C.cast(data, C.POINTER(retro_variable))
			if v[0].key in self.opts:
				v[0].value = C.cast(self.opts[v[0].key], C.c_char_p)
				return True
			v[0].value = None
			return False
		return False

	def video(self, data, w, h, pitch):
		if data:
			self.w, self.h, self.pitch = w, h, pitch
			self.frame = C.string_at(data, pitch * h)

	def input(self, port, device, index, ident):
		if device == 3:		# the keyboard: ident = a RETROK code
			return 1 if ident in self.keys else 0
		if (device & 0xFF) == 1 and port < 3:		# the pads: 0 the built in joystick, 1 / 2 the control ports'
			if ident == 256:
				return self.pads[port]
			return 1 if (self.pads[port] >> ident) & 1 else 0
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
			if self.ftcb:
				self.ftcb(20000)		# a 50 Hz frame
			self.lib.retro_run()

	# a segment's 16K (None: not one the core shows)
	def seg(self, n):
		if n not in self.segs:
			return None
		return C.string_at(self.segs[n], 0x4000)

	# the log's segment number (None: there is none)
	def log_seg(self):
		for n in sorted(self.segs):
			if C.string_at(self.segs[n], 8) == b'NTCLOG\0\0':
				return n
		return None

	# the log: (text, ended) - ('', False) when there is none
	def log(self):
		n = self.log_seg()
		if n is None:
			return '', False
		s = self.seg(n)
		end = s[8] + s[9] * 256
		if end < 0xC010:
			end = 0x10000		# (full: the pointer went round)
		return self.text(s[16:end - 0xC000]), s[10] != 0

	@staticmethod
	def text(raw):
		out = []
		for b in raw:
			if b == 8:
				if out and out[-1] != '\n':
					out.pop()
			else:
				out.append(chr(b))
		return ''.join(out)

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


def keycode(t):
	t = t.lower()
	return KEYNAMES[t] if t in KEYNAMES else ord(t[0])


REL = 1000000		# a frame number of REL or more: that many frames less REL after the program started


# a frame number as given: "+n" = n frames after the program's log is first there (--log / --untilend)
def when(s):
	return REL + int(s[1:]) if s.startswith('+') else int(s)


def main():
	# the core prints as it goes: its output is thrown away, this script's kept
	out = os.fdopen(os.dup(1), 'w')
	if not os.environ.get('NTC_EPCORELOG'):
		null = os.open(os.devnull, os.O_WRONLY)
		os.dup2(null, 1)
		os.dup2(null, 2)
	args = sys.argv[1:]
	prog = None
	frames = 1500
	keys = {}
	joy = {}
	hold = None
	shot = None
	want_log = False
	until_end = False
	want_segs = False
	core = None
	scale = 1
	starts = []
	quiet_for = 5
	opts = {'ep128emu_wait': '0', 'ep128emu_sdhq': '0', 'ep128emu_useh': '1', 'ep128emu_romv': os.environ.get('NTC_EPROM', 'Original')}
	for a in args:
		if a.startswith('--frames='):
			frames = int(a[9:])
		elif a.startswith('--keys='):
			for part in a[7:].split(','):
				f, t = part.split(':', 1)
				keys[when(f)] = t.replace('\\n', '\r')
		elif a.startswith('--joy=') or a.startswith('--joy2='):
			port = {'--joy': 1, '--joy2': 2}[a.split('=')[0]]
			for part in a.split('=', 1)[1].split(','):
				f, t = part.split(':', 1)
				joy[(when(f), port)] = sum({'U': 16, 'D': 32, 'L': 64, 'R': 128, 'F': 512}.get(c, 0) for c in t.upper())
		elif a.startswith('--hold='):
			f, t = a[7:].split(':', 1)
			hold = (when(f), keycode(t))
		elif a.startswith('--shot='):
			shot = a[7:]
		elif a == '--log':
			want_log = True
		elif a == '--untilend':
			until_end = True
		elif a == '--segs':
			want_segs = True
		elif a.startswith('--quiet='):
			quiet_for = max(1, int(float(a[8:]) * 50 / 30))
		elif a.startswith('--start='):
			starts = [int(x) for x in a[8:].split(',')]
		elif a.startswith('--core='):
			core = a[7:]
		elif a.startswith('--scale='):
			scale = int(a[8:])
		else:
			prog = a
	is_disc = prog.lower().endswith('.img')
	m = Enterprise(prog, core, opts)
	typing = []		# (frame, code, down)
	for f0, t in keys.items():
		at = f0
		for ch in t:
			code = 13 if ch == '\r' else ord(ch.lower())
			if ch.isupper():
				typing.append((at, 304, True))		# left Shift held for a capital
				at += 3
			typing.append((at, code, True))
			typing.append((at + 5, code, False))
			if ch.isupper():
				typing.append((at + 8, 304, False))
			at += 10
	lastkey = max([x[0] for x in typing if x[0] < REL] + [0])
	quiet = 0
	last = None
	started = False
	pressed = -1000
	for f in range(frames):
		# getting the program started, until its log is there (--log / --untilend). A disc image
		# (.img: EXDOS runs its EXDOS.INI, which loads the program): Space at the title screen (a
		# picture with a lot in it), again every second while nothing has come of it. A program
		# file (.com): the core presses Space and START (F1) itself, too early for a machine with
		# much more than 128K - so Space at the title screen, and once BASIC has said how many
		# bytes are unused, START, again after 6 seconds
		if (want_log or until_end) and not starts and not started and f >= 300 and f % 10 == 0:
			started = m.log_seg() is not None
			if started:
				# the frames given as "+n" count from here
				typing = [((at - REL + f) if at >= REL else at, code, down) for at, code, down in typing]
				joy = dict((((k[0] - REL + f) if k[0] >= REL else k[0], k[1]), v) for k, v in joy.items())
				if hold and hold[0] >= REL:
					hold = (hold[0] - REL + f, hold[1])
				lastkey = max([x[0] for x in typing] + [0])
			title = (not started) and m.frame and sum(1 for b in m.frame[::7] if b) > 700
			if started:
				pass
			elif is_disc:
				if title and f - pressed >= 50:
					pressed = f
					typing.append((f + 1, 32, True))
					typing.append((f + 8, 32, False))
			elif f >= 900 and f % 50 == 0:
				basic = b'bytes unused' in (m.seg(0xFF) or b'')
				if basic and f - pressed >= 300:
					pressed = f
					typing.append((f + 1, 282, True))
					typing.append((f + 11, 282, False))
				elif not basic and title:
					typing.append((f + 1, 32, True))
					typing.append((f + 8, 32, False))
		if f in starts:
			typing.append((f + 1, 282, True))
			typing.append((f + 8, 282, False))
		if until_end and (f % 30 == 0) and f >= 600 and f > lastkey + 60 and not any(x[0] >= REL for x in typing):
			cur, ended = m.log()
			if ended:
				break
			quiet = quiet + 1 if (cur == last and cur != '') else 0
			last = cur
			if quiet >= quiet_for:
				break
		for at, code, down in typing:
			if at == f:
				m.key(code, down)
		for port in range(3):
			if (f, port) in joy:
				m.pads[port] = joy[(f, port)]
		if hold and hold[0] == f:
			m.key(hold[1], True)
		m.run()
	if shot:
		m.png(shot, scale)
	if want_segs:
		out.write('segments: ' + ' '.join('%02X' % n for n in sorted(m.segs)) + '\n')
	if want_log:
		text, ended = m.log()
		out.write(text)
		if not text.endswith('\n'):
			out.write('\n')
		out.write('[ended]\n' if ended else '[still running]\n')
	out.flush()
	os._exit(0)


if __name__ == '__main__':
	main()
