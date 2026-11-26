#!/usr/bin/env python3
# amigarun.py - run an Amiga disc image on the PUAE libretro core, for NTC's amiga platform
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# A small libretro front end (ctypes): no window, no sound. It boots a disc image (.adf) for so
# many frames, types keys and holds the joystick by a script, changes discs, saves pictures and
# reads chip RAM.
#
#   python3 amigarun.py DISC.adf [DISC2.adf ...] [--frames=N] [--keys=SCRIPT] [--joy=SCRIPT] [--hold=frame:key]
#                       [--swap=SCRIPT] [--shot=out.png] [--log] [--untilend] [--ram=addr,len]
#                       [--model=A500OG] [--chip=512|1024|2048] [--slow=0|512|1024|1536]
#                       [--fast=0|1|2|4|8] [--ntsc] [--drives=1|2] [--speed=100|800|0]
#                       [--core=path/to/puae_libretro.so] [--sys=folder]
#
# --keys: frame:text,... - at that frame the text is typed (\\n = Return), e.g. --keys=200:12\\n
# --joy: frame:UDLRF,... - from that frame the joystick in port 2 is held that way (- = let go;
#   F fire, G the second button)
# --hold: frame:k - from that frame the key k is held down
# --swap: frame:n,... - at that frame the disc in DF0 is taken out and the n-th one given on the
#   command line (1 = the first) put in
# --drives=2 (two or more discs given): the second disc starts in DF1; else they are a set for DF0
# --model: the machine (A500OG: 512K chip, Kickstart 1.3 - the default; A500: + 512K slow;
#   A500ECS: 1 MB chip; A600OG / A1200OG ...); --chip / --slow / --fast change its memory (--fast
#   in MB). --ntsc: a 60 Hz machine. --speed: the drives' speed in per cent (0 = as fast as can be)
# --log: an NTC test build (amigabuild --log) keeps what the console prints in chip RAM from
#   $070000; this prints it. --untilend stops when it has not grown for 2 seconds.
# --kick=aros (the default): the Kickstart replacement the core carries (AROS). --kick=auto: the
#   model's own Kickstart ROM, a file in --sys / NTC_AMIGASYS (kick34005.A500 for the A500).
# The core: github.com/libretro/libretro-uae (make). NTC_AMIGACORE (the environment) can give
# its path.

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



LOGAT = 0x070000		# NTC_AMILOG: the transcript's start (its end's address in the long before it)
LOGCB = C.CFUNCTYPE(None, C.c_int, C.c_char_p, C.c_void_p, C.c_void_p, C.c_void_p, C.c_void_p)		# (printf style: up to four values shown)
KBCB = C.CFUNCTYPE(None, C.c_bool, C.c_uint, C.c_uint32, C.c_uint16)


class retro_keyboard_callback(C.Structure):
	_fields_ = [('callback', KBCB)]


class retro_disk_control_callback(C.Structure):
	_fields_ = [('set_eject_state', C.CFUNCTYPE(C.c_bool, C.c_bool)), ('get_eject_state', C.CFUNCTYPE(C.c_bool)),
		('get_image_index', C.CFUNCTYPE(C.c_uint)), ('set_image_index', C.CFUNCTYPE(C.c_bool, C.c_uint)),
		('get_num_images', C.CFUNCTYPE(C.c_uint)), ('replace_image_index', C.c_void_p), ('add_image_index', C.c_void_p)]


class Amiga:
	def __init__(self, disc, core=None, sysdir=None, opts=None):
		here = os.path.dirname(os.path.abspath(__file__))
		core = core or os.environ.get('NTC_AMIGACORE') or os.path.join(here, 'puae_libretro.so')
		self.opts = dict((k.encode(), C.create_string_buffer(v.encode())) for k, v in (opts or {}).items())
		self.disk = None
		self.pad = 0
		self.lib = C.CDLL(core)
		self.fmt = 0
		self.frame = None
		self.w = self.h = self.pitch = 0
		self.keys = set()
		self.kbcb = None
		self.savedir = C.create_string_buffer(os.path.dirname(os.path.abspath(disc)).encode())
		self.sysdir = C.create_string_buffer(os.path.abspath(sysdir or os.environ.get('NTC_AMIGASYS') or here).encode())
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
		self._path = os.path.abspath(disc).encode()
		info = retro_game_info(self._path, None, 0, None)
		if not self.lib.retro_load_game(C.byref(info)):
			raise RuntimeError('the core did not load ' + disc)
		self.lib.retro_set_controller_port_device(0, 1)		# a joypad in the first port: the Amiga's joystick
		self.lib.retro_get_memory_data.restype = C.c_void_p
		self.mem = self.lib.retro_get_memory_data(2)

	def corelog(self, level, fmt, a, b, c, d):
		if os.environ.get('NTC_AMIGACORELOG'):
			buf = C.create_string_buffer(1024)
			self._libc.snprintf(buf, 1024, fmt, C.c_void_p(a), C.c_void_p(b), C.c_void_p(c), C.c_void_p(d))
			sys.stderr.write('core: ' + buf.value.decode('latin-1'))

	def env(self, cmd, data):
		cmd &= 0xffff
		if cmd == RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
			C.cast(data, C.POINTER(C.c_void_p))[0] = C.addressof(self.sysdir)
			return True
		if cmd == RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:		# (the core keeps a copy of a disc that is written to: beside the disc)
			C.cast(data, C.POINTER(C.c_void_p))[0] = C.addressof(self.savedir)
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
		if cmd in (13, 58):		# SET_DISK_CONTROL_INTERFACE (and the extended one: the same first fields)
			self.disk = retro_disk_control_callback.from_buffer_copy(C.string_at(data, C.sizeof(retro_disk_control_callback)))
			return True
		if cmd == RETRO_ENVIRONMENT_GET_VARIABLE:
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
		if (device & 0xFF) == 1 and port == 0:		# the pad in the first port: the Amiga's joystick (port 2)
			if ident == 256:		# the whole mask
				return self.pad
			return 1 if (self.pad >> ident) & 1 else 0
		return 0

	# the disc in DF0 out, the n-th of the set in (0 = the first)
	def swap(self, n):
		if not self.disk:
			return
		self.disk.set_eject_state(True)
		self.run(20)
		self.disk.set_image_index(n)
		self.run(20)
		self.disk.set_eject_state(False)

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

	# chip RAM, as the 68000 has it
	def ram(self, addr, n):
		return C.string_at(self.mem + addr, n)

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
	# the core prints as it goes: its output is thrown away, this script's kept
	out = os.fdopen(os.dup(1), 'w')
	if not os.environ.get('NTC_AMIGACORELOG'):
		null = os.open(os.devnull, os.O_WRONLY)
		os.dup2(null, 1)
		os.dup2(null, 2)
	args = sys.argv[1:]
	discs = []
	frames = 900
	keys = {}
	joy = {}
	swaps = {}
	hold = None
	shot = None
	want_log = False
	until_quiet = False
	ramreq = None
	core = None
	sysdir = None
	scale = 1
	drives = 1
	opts = {'puae_model': 'A500OG', 'puae_floppy_speed': '100', 'puae_video_standard': 'PAL', 'puae_floppy_multidrive': 'disabled',
		'puae_cpu_compatibility': 'exact', 'puae_floppy_sound': '100', 'puae_use_whdload': 'disabled', 'puae_statusbar': 'disabled',
		'puae_kickstart': 'aros', 'puae_crop': 'disabled', 'puae_video_resolution': 'hires', 'puae_video_vresolution': 'single', 'puae_gfx_colors': '24bit'}
	for a in args:
		if a.startswith('--frames='):
			frames = int(a[9:])
		elif a.startswith('--keys='):
			for part in a[7:].split(','):
				f, t = part.split(':', 1)
				keys[int(f)] = t.replace('\\n', '\r')
		elif a.startswith('--joy='):
			for part in a[6:].split(','):
				f, t = part.split(':', 1)
				joy[int(f)] = sum({'U': 16, 'D': 32, 'L': 64, 'R': 128, 'F': 1, 'G': 256}.get(c, 0) for c in t.upper())
		elif a.startswith('--hold='):
			f, t = a[7:].split(':', 1)
			hold = (int(f), ord(t[0].lower()))
		elif a.startswith('--swap='):
			for part in a[7:].split(','):
				f, t = part.split(':', 1)
				swaps[int(f)] = int(t) - 1
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
		elif a.startswith('--model='):
			opts['puae_model'] = a[8:]
		elif a.startswith('--chip='):
			opts['puae_chipmem_size'] = {'512': '1', '1024': '2', '1536': '3', '2048': '4'}[a[7:]]
		elif a.startswith('--slow='):
			opts['puae_bogomem_size'] = {'0': '0', '512': '2', '1024': '4', '1536': '6'}[a[7:]]
		elif a.startswith('--fast='):
			opts['puae_fastmem_size'] = a[7:]
		elif a.startswith('--kick='):
			opts['puae_kickstart'] = a[7:]
		elif a == '--ntsc':
			opts['puae_video_standard'] = 'NTSC'
		elif a.startswith('--drives='):
			drives = int(a[9:])
		elif a.startswith('--speed='):
			opts['puae_floppy_speed'] = a[8:]
		else:
			discs.append(a)
	disc = discs[0]
	if len(discs) > 1:
		# a set: an .m3u list (with --drives=2 the core puts the second in DF1)
		disc = os.path.splitext(discs[0])[0] + '.m3u'
		open(disc, 'w').write(''.join(os.path.abspath(d) + '\n' for d in discs))
		if drives > 1:
			opts['puae_floppy_multidrive'] = 'enabled'
	m = Amiga(disc, core, sysdir, opts)
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
	lastkey = max([x[0] for x in typing] + [0] + list(swaps.keys()))
	quiet = 0
	last = None
	for f in range(frames):
		if until_quiet and (f % 30 == 0) and f >= 300 and f > lastkey + 60:
			cur = m.log()
			quiet = quiet + 1 if (cur == last and cur != '') else 0
			last = cur
			if quiet >= 4:
				break
		for (at, code, down) in typing:
			if at == f:
				m.key(code, down)
		if hold and f == hold[0]:
			m.key(hold[1], True)
		if f in joy:
			m.pad = joy[f]
		if f in swaps:
			m.swap(swaps[f])
		m.run(1)
	if shot:
		m.png(shot, scale)
	if want_log:
		out.write(m.log())
	if ramreq:
		out.write(m.ram(ramreq[0], ramreq[1]).hex() + '\n')
	out.flush()


if __name__ == '__main__':
	main()
