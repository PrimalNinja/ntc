#!/usr/bin/env python3
# c64run.py - run a C64 PRG on the VICE (x64sc) libretro core with an REU, for testing NTC's
# c64reu platform
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
#   python3 c64run.py GAME.PRG [--frames=N] [--untilend] [--log] [--shot=out.png] [--screen]
#                     [--keys=+N:text] [--hold=+N:key[,frames]] [--joy=+N:udlrf[,frames]]
#                     [--reu=512kB|none|...] [--quiet]
#
# The core: github.com/libretro/vice-libretro (make EMUTYPE=x64sc). NTC_C64CORE gives its path.
# The core loads the PRG and types RUN itself.
# --log: prints what the program's console printed (a c64build.js --log build keeps it in
#   $F000-$F7FF; this script reads it as it comes).
# --untilend: stops when the program has ended (End), or after --frames.
# --screen: prints the screen's 25 lines at the end (BASIC's own screen if the program never started).
# --keys=+N:text: types text from N frames after the program started (\n = RETURN).
# --hold=+N:key,frames: holds a key down (a letter, or up down left right space return).
# --joy=+N:udlrf,frames: holds the port 2 joystick (u d l r f).
import ctypes as C, os, struct, sys, zlib

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
KBCB = C.CFUNCTYPE(None, C.c_bool, C.c_uint, C.c_uint32, C.c_uint16)
LOGCB = C.CFUNCTYPE(None, C.c_int, C.c_char_p, C.c_void_p, C.c_void_p, C.c_void_p, C.c_void_p)

RETROK = {'\n': 13, ' ': 32, 'up': 273, 'down': 274, 'right': 275, 'left': 276, 'space': 32, 'return': 13, 'del': 8, 'shift': 304, 'rshift': 303, 'stop': 27}
JOYID = {'f': 0, 'u': 4, 'd': 5, 'l': 6, 'r': 7}

class C64:
	def __init__(self, prog, core, opts):
		self.opts = dict((k.encode(), C.create_string_buffer(v.encode())) for k, v in opts.items())
		self.lib = C.CDLL(core)
		self.fmt = 0; self.frame = None; self.w = self.h = self.pitch = 0
		self.keys = set(); self.joy = set(); self.kbcb = None; self.kdown = set()
		self.dir = C.create_string_buffer(os.path.dirname(os.path.abspath(prog)).encode())
		self._logcb = LOGCB(lambda *a: None)
		self._cbs = [ENVCB(self.env), VIDEOCB(self.video), AUDIOCB(lambda l, r: None), AUDIOBATCHCB(lambda d, n: n), POLLCB(lambda: None), INPUTCB(self.input)]
		self.lib.retro_set_environment(self._cbs[0]); self.lib.retro_set_video_refresh(self._cbs[1])
		self.lib.retro_set_audio_sample(self._cbs[2]); self.lib.retro_set_audio_sample_batch(self._cbs[3])
		self.lib.retro_set_input_poll(self._cbs[4]); self.lib.retro_set_input_state(self._cbs[5])
		self.lib.retro_init()
		self._path = os.path.abspath(prog).encode()
		info = retro_game_info(self._path, None, 0, None)
		if not self.lib.retro_load_game(C.byref(info)):
			raise RuntimeError('the core did not load ' + prog)
		self.lib.retro_set_controller_port_device(0, 1)		# a joypad in each port
		self.lib.retro_set_controller_port_device(1, 1)
		self.av = C.create_string_buffer(64)
		self.lib.retro_get_system_av_info(self.av)		# (the core sets its timing here)
		self.lib.retro_get_memory_data.restype = C.c_void_p
		self.lib.retro_get_memory_size.restype = C.c_size_t
	def input(self, port, device, index, id):
		if device == 3:
			return 1 if id in self.keys else 0
		if device == 1 and port == 0:
			return 1 if id in self.joy else 0
		return 0
	def env(self, cmd, data):
		cmd &= 0xffff
		if cmd in (9, 31):
			C.cast(data, C.POINTER(C.c_void_p))[0] = C.addressof(self.dir); return True
		if cmd == 10:
			self.fmt = C.cast(data, C.POINTER(C.c_int))[0]; return True
		if cmd == 3:
			C.cast(data, C.POINTER(C.c_bool))[0] = True; return True
		if cmd == 12:		# SET_KEYBOARD_CALLBACK: the core wants key presses told to it
			self.kbcb = KBCB(C.cast(data, C.POINTER(C.c_void_p))[0]); return True
		if cmd == 27:
			C.cast(data, C.POINTER(C.c_void_p))[0] = C.cast(self._logcb, C.c_void_p).value; return True
		if cmd == 16:		# SET_VARIABLES: the core's options - each one's first value is its default
			v = C.cast(data, C.POINTER(retro_variable)); i = 0
			while v[i].key:
				val = v[i].value.decode('latin-1').split('; ', 1)[-1].split('|')[0]
				self.opts.setdefault(v[i].key, C.create_string_buffer(val.encode()))
				i += 1
			return True
		if cmd == 15:
			v = C.cast(data, C.POINTER(retro_variable))
			if v[0].key in self.opts:
				v[0].value = C.cast(self.opts[v[0].key], C.c_char_p); return True
			v[0].value = None; return False
		return False
	def video(self, data, w, h, pitch):
		if data:
			self.w, self.h, self.pitch = w, h, pitch
			self.frame = C.string_at(data, pitch * h)
	def run(self, n=1):
		for _ in range(n):
			if self.kbcb:
				for k in self.keys - self.kdown: self.kbcb(True, k, 0, 1 if 304 in self.keys else 0)
				for k in self.kdown - self.keys: self.kbcb(False, k, 0, 0)
			self.kdown = set(self.keys)
			self.lib.retro_run()
	def ram(self, a, n):
		p = self.lib.retro_get_memory_data(2)
		return C.string_at(p + a, n)
	def png(self, path):
		w, h = self.w, self.h; rows = []
		for y in range(h):
			line = bytearray([0]); off = y * self.pitch
			for x in range(w):
				if self.fmt == 1:
					v = struct.unpack_from('<I', self.frame, off + x * 4)[0]; r, g, b = (v >> 16) & 255, (v >> 8) & 255, v & 255
				else:
					v = struct.unpack_from('<H', self.frame, off + x * 2)[0]; r, g, b = (v >> 11) << 3, ((v >> 5) & 63) << 2, (v & 31) << 3
				line += bytes([r, g, b])
			rows.append(bytes(line))
		def chunk(t, d):
			c = struct.pack('>I', len(d)) + t + d
			return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
		open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b''))

def screen(m):
	s = m.ram(0xE000, 1000)
	return [''.join(chr(c) if 32 <= c < 127 else '.' for c in s[y * 40:y * 40 + 40]).rstrip() for y in range(25)]

def kscreen(m):
	# the KERNAL's own screen ($0400, screen codes): what BASIC shows when the program never started
	s = m.ram(0x0400, 1000)
	return [''.join(chr(c + 64) if 1 <= c <= 26 else (chr(c) if 32 <= c < 64 else '.') for c in s[y * 40:y * 40 + 40]).rstrip() for y in range(25)]

def keycodes(ch):
	# a character -> the RetroArch keys to hold for it
	if ch in RETROK: return [RETROK[ch]]
	if len(ch) == 1: return [ord(ch)]
	return []

def main():
	out = os.fdopen(os.dup(1), 'w')
	null = os.open(os.devnull, os.O_WRONLY); os.dup2(null, 1); os.dup2(null, 2)
	prog = None; frames = 3000; shot = None; reu = '512kB'; log = False; untilend = False; scr = False; quiet = False
	events = []		# (frame after start, kind, value, frames held)
	for a in sys.argv[1:]:
		if a.startswith('--frames='): frames = int(a[9:])
		elif a.startswith('--shot='): shot = a[7:]
		elif a.startswith('--reu='): reu = a[6:]
		elif a == '--log': log = True
		elif a == '--untilend': untilend = True
		elif a == '--screen': scr = True
		elif a == '--quiet': quiet = True
		elif a.startswith('--keys='):
			at, text = a[7:].split(':', 1); at = int(at.lstrip('+'))
			for ch in text.replace('\\n', '\n'):
				if 'A' <= ch <= 'Z':		# (SHIFT goes down first: the core wants it so)
					events.append((at, 'key', 'shift', 10)); events.append((at + 4, 'key', ch.lower(), 4))
				else:
					events.append((at, 'key', ch, 4))
				at += 12
		elif a.startswith('--hold='):
			at, rest = a[7:].split(':', 1); k, _, n = rest.partition(',')
			events.append((int(at.lstrip('+')), 'key', k, int(n or 50)))
		elif a.startswith('--joy='):
			at, rest = a[6:].split(':', 1); k, _, n = rest.partition(',')
			events.append((int(at.lstrip('+')), 'joy', k, int(n or 50)))
		else: prog = a
	core = os.environ.get('NTC_C64CORE') or os.path.join(os.path.dirname(os.path.abspath(__file__)), 'vice_x64sc_libretro.so')
	m = C64(prog, core, {'vice_ram_expansion_unit': reu, 'vice_autostart': 'enabled', 'vice_autoloadwarp': 'enabled', 'vice_c64_model': 'C64 PAL', 'vice_read_vicerc': 'disabled'})
	started = -1; seen = 0; ended = False; text = []
	for f in range(frames):
		m.keys = set(); m.joy = set()
		if started >= 0:
			t = f - started
			for at, kind, v, n in events:
				if at <= t < at + n:
					if kind == 'key': m.keys.update(keycodes(v))
					else: m.joy.update(JOYID[c] for c in v if c in JOYID)
		m.run()
		note = m.ram(0x02F0, 4)
		if started < 0:
			if note[3] == 0x5A: started = f
			else: continue
		n = note[0] + note[1] * 256
		d = (n - seen) & 0xFFFF
		if d:
			ring = m.ram(0xF000, 0x800)
			if d > 0x800: text.append('\n[c64run: %d bytes of the log were lost]\n' % (d - 0x800)); seen = (n - 0x800) & 0xFFFF; d = 0x800
			text.append(''.join(chr(ring[(seen + i) & 0x7FF]) for i in range(d)))
			seen = n
		if note[2] == 0xA5:
			ended = True
			if untilend: break
	if shot: m.png(shot)
	if log: out.write(''.join(text))
	if scr: out.write('\n'.join('%2d |%s' % (i, x) for i, x in enumerate(screen(m) if started >= 0 else kscreen(m))) + '\n')
	if not quiet:
		out.write('[c64run: %s after %d frames%s]\n' % ('ended' if ended else ('still running' if started >= 0 else 'never started'), f + 1, '' if started < 0 else ', started at frame %d' % started))
	out.flush(); os._exit(0)

if __name__ == '__main__':
	main()
