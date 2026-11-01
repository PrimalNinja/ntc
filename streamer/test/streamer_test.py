# streamer_test.py - the node tested end to end with no CPC and no UniDOS: build/streamer.rom at
# #C000 on NTC's Z80 core, its entries called the way UniDOS calls them (the normalized path at DE
# as UniDOS makes it: a count byte, then 11-character names), the CPLink's ports (&FD80 data,
# &FD81 status) bridged to a cosd started on a TCP link, the speech cards' ports answered here.
# The categories: GRAPHICS (CMD, EVENTS, the profile folders as store paths), SPEECH (CMD with
# 85 TARGET), MUSIC (CMD a line a request, its folders), STORE (the Pi's store as files).
#   python3 streamer/test/streamer_test.py      (needs node, the NTC test folder's z80 module)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, socket, subprocess, time, struct
HERE = os.path.dirname(os.path.abspath(__file__))
NTC = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(NTC, 'test'))
import z80
COS_PI = os.environ.get('COS_PI', os.path.join(NTC, '..', 'cos', 'pi'))
def free_port():
    t = socket.socket(); t.bind(('127.0.0.1', 0)); n = t.getsockname()[1]; t.close(); return n
PORT = free_port(); VDU = free_port()
ROM = open(os.path.join(HERE, '..', 'build', 'streamer.rom'), 'rb').read()
ENTRY = {'Init': 1, 'CheckDrive': 2, 'GetStatus': 3, 'GetName': 4, 'GetDesc': 5, 'GetFreeSpace': 6, 'InOpen': 7, 'InRead': 8, 'InClose': 9,
         'OutOpen': 11, 'OutWrite': 12, 'OutClose': 13, 'Examine': 15, 'ExamineNext': 16}   # (entry 0 is the ROM's own InitROM)
fails = []; count = [0]
def check(name, ok, got=''):
    count[0] += 1
    print(('ok   ' if ok else 'FAIL ') + name + ('' if ok else ': ' + str(got)))
    if not ok: fails.append(name)

# ---- cosd on a TCP link, and the socket the ROM's port writes go down
store = '/tmp/streamer-store'
subprocess.run(['rm', '-rf', store]); os.makedirs(store, exist_ok=True)
cosd = subprocess.Popen(['node', os.path.join(COS_PI, 'cosd.js'), '--link=tcp:%d' % PORT, '--store=' + store, '--vdu=%d' % VDU], stderr=open('/tmp/streamer-cosd.log', 'w'), stdout=subprocess.DEVNULL)
time.sleep(0.8)
sock = socket.create_connection(('127.0.0.1', PORT)); sock.setblocking(False)
inq = bytearray(); sent = bytearray()
speech = {0xFBEE: [], 0xFBFE: []}; polls = {0xFBEE: 0, 0xFBFE: 0}
def pump():
    try:
        while True:
            b = sock.recv(65536)
            if not b: break
            inq.extend(b)
    except BlockingIOError:
        pass

# ---- the machine: the ROM at #C000, a stub at #4000 that calls entry n and halts
m = z80.Z80Machine()
m.set_memory_block(0xC000, ROM)
def out(port, val):
    if (port & 0xFF00) == 0xFD00 and (port & 0xFF) == 0x80: sock.sendall(bytes([val])); sent.append(val)
    if port in speech: speech[port].append(val); polls[port] = 0
def inp(port):
    if port in speech:
        polls[port] += 1
        busy = polls[port] <= 2
        return (0x40 if busy else 0) if port == 0xFBEE else (0x80 if busy else 0)
    if (port & 0xFF00) == 0xFD00:
        pump()
        if (port & 0xFF) == 0x81: return 0x02 | (0x01 if inq else 0)
        if (port & 0xFF) == 0x80: return inq.pop(0) if inq else 0
    return 0xFF
m.set_output_callback(out); m.set_input_callback(inp)
def call(entry, a=0, hl=0, de=0, bc=0):
    ad = 0xC006 + 3 * ENTRY[entry]
    m.set_memory_block(0x4000, bytes([0xCD, ad & 255, ad >> 8, 0x76]))
    m.a, m.hl, m.de, m.bc, m.sp, m.pc = a, hl, de, bc, 0xBE00, 0x4000
    m.halted = False
    deadline = time.time() + 20
    while not m.halted and time.time() < deadline:
        m.ticks_to_stop = 20000; m.run(); pump()
    f = m.f
    return {'a': m.a, 'de': m.de, 'hl': m.hl, 'bc': m.bc, 'c': bool(f & 1), 'z': bool(f & 64), 'timeout': not m.halted}
def mem(ad, n): return bytes(m.memory[ad:ad + n])
def nm(s): return s.ljust(11).encode('latin1')[:11]
def path_at(ad, comps):
    b = bytes([len(comps)]) + b''.join(nm(c) for c in comps)
    m.set_memory_block(ad, b); return ad
NAME, PATH, BUF, DATA = 0x5300, 0x5200, 0x6100, 0x6200
ROOT = path_at(PATH, [])

# ---- the categories by name; a foreign number refused; the names and status
for n, want in (('GRAPHICS', 0), ('SPEECH', 1), ('MUSIC', 2), ('STORE', 3)):
    m.set_memory_block(0x5000, n[:-1].encode() + bytes([ord(n[-1]) | 0x80]))
    r = call('CheckDrive', a=0x33, hl=0x5000, bc=len(n))
    check('CheckDrive %s: device %d' % (n, want), r['c'] and r['a'] == want, r)
m.set_memory_block(0x5000, b'XY' + bytes([ord('Z') | 0x80])); r = call('CheckDrive', a=0x33, hl=0x5000, bc=3)
check('CheckDrive XYZ: not ours, A kept', (not r['c']) and r['a'] == 0x33, r)
r = call('GetStatus', a=7); check('GetStatus of a foreign number: not ours', not r['c'], r)
r = call('GetStatus', a=0); check('GetStatus GRAPHICS: a stream, the new API', r['c'] and r['a'] == 0x31, r)
r = call('GetName', a=2, de=0x5100); check('GetName MUSIC', mem(0x5100, 5) == b'MUSI' + bytes([ord('C') | 0x80]), mem(0x5100, 5))

# ---- GRAPHICS root: CAT lists CMD, EVENTS, then the profile folders as directories
r = call('Examine', a=0, hl=0, de=ROOT)
names = []
for i in range(10):
    r = call('ExamineNext', a=0, hl=NAME, de=ROOT)
    if r['z']: names.append((mem(NAME, 11).decode('latin1').strip(), 'dir' if r['a'] & 0x10 else 'file'))
    else: break
check('GRAPHICS: lists CMD, EVENTS then the five folders', names == [('CMD', 'file'), ('EVENTS', 'file'), ('V9990', 'dir'), ('V9938', 'dir'), ('ZXNEXT', 'dir'), ('MD', 'dir'), ('PINATIVE', 'dir')], names)
r = call('Examine', a=2, hl=0, de=ROOT); names = []
for i in range(14):
    r = call('ExamineNext', a=2, hl=NAME, de=ROOT)
    if r['z']: names.append(mem(NAME, 11).decode('latin1').strip())
    else: break
check('MUSIC: lists CMD, EVENTS and its ten type folders', names[:2] == ['CMD', 'EVENTS'] and 'SID' in names and 'GME' in names and len(names) == 12, names)

# ---- an asset: SAVE into GRAPHICS:V9990/PATTERNS -> PUT GRAPHICS/V9990/PATTERNS on the Pi's store (in parts)
V9990 = path_at(0x5250, ['V9990'])
m.set_memory_block(NAME, nm('PATTERNS'))
r = call('OutOpen', a=0, hl=NAME, de=V9990)
check('OutOpen GRAPHICS:V9990/PATTERNS', r['c'] and r['z'], r)
check('the tag built from the path', mem(0xBEA0, 24).split(b'\x00')[0] == b'GRAPHICS/V9990/PATTERNS', mem(0xBEA0, 24))
check('HELLO once, the store channel opened', b'COS1 machine=cpc name=STREAMER' in bytes(sent) and b'OPEN store' in bytes(sent), bytes(sent)[:80])
sent[:] = b''
m.set_memory_block(DATA, bytes([0x11] * 256))
r = call('OutWrite', a=0, hl=DATA, de=256)
check('the bytes as a PUT in two parts with MORE', bytes(sent).count(b'PUT GRAPHICS/V9990/PATTERNS\x00') == 2 and bytes(sent)[2] == 0x82, bytes(sent)[:40])
r = call('OutClose', a=0)
time.sleep(0.3)
f = os.path.join(store, 'STREAMER', 'GRAPHICS', 'V9990', 'PATTERNS')
check('the file is on the Pi, 256 bytes', os.path.exists(f) and os.path.getsize(f) == 256, f)

# ---- read it back: LOAD from GRAPHICS:V9990/PATTERNS -> GET, the data through InRead
r = call('InOpen', a=0, hl=NAME, de=V9990)
check('InOpen GRAPHICS:V9990/PATTERNS (GET)', r['c'] and r['z'], r)
got = b''
for i in range(10):
    r = call('InRead', a=0, hl=BUF, de=100)
    if r['de'] == 0: break
    got += mem(BUF, r['de'])
check('the 256 bytes read back in chunks', got == bytes([0x11] * 256), (len(got), got[:8]))
r = call('InClose', a=0)

# ---- CAT GRAPHICS:V9990/ : the Pi's LIST as entries, with the size
r = call('Examine', a=0, hl=0, de=V9990); entries = []
for i in range(6):
    r = call('ExamineNext', a=0, hl=NAME, de=V9990)
    if r['z']: entries.append((mem(NAME, 11).decode('latin1').strip(), r['de']))
    else: break
check('CAT V9990/: PATTERNS 256', entries == [('PATTERNS', 256)], entries)

# ---- GRAPHICS:CMD: 80 OPEN the profile; the installed PATTERNS are the display's; a sprite moves; EVENTS
m.set_memory_block(NAME, nm('CMD')); r = call('OutOpen', a=0, hl=NAME, de=ROOT)
check('OutOpen GRAPHICS:CMD', r['c'] and r['z'], r)
txt = b'vdp profile=v9990 vsync=1'; m.set_memory_block(DATA, bytes([0x80, len(txt)]) + txt); sent[:] = b''
r = call('OutWrite', a=0, hl=DATA, de=2 + len(txt))
chg = mem(0xBE91, 1)[0]
check('80 OPEN vdp: sent, the version byte after it', b'OPEN vdp profile=v9990' in bytes(sent) and bytes(sent)[-8:-1] == bytes([0xA5, chg, 4, 0, 1, 0, 1]), bytes(sent)[-20:])
def w16(v): return struct.pack('<h', v)
cmds = bytes([1]) + w16(1) + w16(1) + w16(10) + w16(10) + bytes([1]) + bytes([5]) + w16(1) + w16(64) + w16(0) + bytes([6]) + w16(1) + bytes([4]) + bytes([0x7F])
m.set_memory_block(DATA, cmds); sent[:] = b''
r = call('OutWrite', a=0, hl=DATA, de=len(cmds))
check('four VDP commands, a DATA frame each', bytes(sent).count(bytes([0xA5, chg, 4, 0])) == 4, bytes(sent)[:16])
r = call('OutClose', a=0)
m.set_memory_block(NAME, nm('EVENTS')); r = call('InOpen', a=0, hl=NAME, de=ROOT)
lines = []
for i in range(300):
    r = call('InRead', a=0, hl=BUF, de=80)
    if not (r['c'] and r['z']): break
    line = mem(BUF, r['de']).decode('latin1'); lines.append(line)
    if line.startswith('EDGE 1 1'): break
check('EVENTS: V lines then EDGE 1 1 (the sprite used installed pattern 1)', any(l.startswith('EDGE 1 1') for l in lines) and any(l.startswith('V ') for l in lines), lines[-2:])
r = call('InClose', a=0)

# ---- SPEECH: 85 TARGET 0 (SSA1) then allophones to &FBEE; TARGET 1 to &FBFE; TARGET 2 and OPEN votrax: DATA
m.set_memory_block(NAME, nm('CMD')); r = call('OutOpen', a=1, hl=NAME, de=ROOT)
m.set_memory_block(DATA, bytes([0x85, 0, 27, 7, 55, 3, 200])); r = call('OutWrite', a=1, hl=DATA, de=7)
check('SPEECH TARGET 0: allophones out of &FBEE, the bad one masked', speech[0xFBEE] == [27, 7, 55, 3, 8], speech[0xFBEE])
m.set_memory_block(DATA, bytes([0x85, 1, 27, 7])); r = call('OutWrite', a=1, hl=DATA, de=4)
check('SPEECH TARGET 1: out of &FBFE', speech[0xFBFE] == [27, 7], speech[0xFBFE])
t3 = b'votrax'; m.set_memory_block(DATA, bytes([0x85, 2, 0x80, len(t3)]) + t3); r = call('OutWrite', a=1, hl=DATA, de=4 + len(t3)); sent[:] = b''
chv = mem(0xBE91, 1)[0]
m.set_memory_block(DATA, bytes([0x1b, 0x07, 0x83])); r = call('OutWrite', a=1, hl=DATA, de=3)
check('SPEECH TARGET 2 (VOTRAX on the Pi): the phoneme bytes as one DATA frame', chv > 0 and bytes(sent)[:6] == bytes([0xA5, chv, 4, 0, 3, 0]), (chv, bytes(sent)[:10]))
r = call('OutClose', a=1)

# ---- MUSIC: OPEN audio, a line a request, the answer on EVENTS
m.set_memory_block(NAME, nm('CMD')); r = call('OutOpen', a=2, hl=NAME, de=ROOT)
t2 = b'audio'; m.set_memory_block(DATA, bytes([0x80, len(t2)]) + t2); r = call('OutWrite', a=2, hl=DATA, de=2 + len(t2))
chm = mem(0xBE91, 1)[0]; sent[:] = b''
m.set_memory_block(DATA, b'STATUS\r\n'); r = call('OutWrite', a=2, hl=DATA, de=8)
check('MUSIC: a line is one REQ without its CR LF', chm > 0 and bytes(sent)[:6] == bytes([0xA5, chm, 2, 2, 6, 0]) and bytes(sent)[6:12] == b'STATUS', bytes(sent)[:14])
r = call('OutClose', a=2)
m.set_memory_block(NAME, nm('EVENTS')); r = call('InOpen', a=2, hl=NAME, de=ROOT); got = ''
for i in range(20):
    r = call('InRead', a=2, hl=BUF, de=80); line = mem(BUF, r['de']).decode('latin1')
    if line.startswith('OK idle') or line.startswith('OK playing'): got = line; break
check("MUSIC: STATUS's answer on EVENTS", got.startswith('OK'), got or line)
r = call('InClose', a=2)

# ---- STORE: a file at the root and in a folder; CAT of the folder
m.set_memory_block(NAME, nm('HELLO   TXT')); r = call('OutOpen', a=3, hl=NAME, de=ROOT)
check('OutOpen STORE:HELLO.TXT: the tag HELLO.TXT', r['c'] and r['z'] and mem(0xBEA0, 12).split(b'\x00')[0] == b'HELLO.TXT', mem(0xBEA0, 12))
m.set_memory_block(DATA, b'hello from the CPC'); r = call('OutWrite', a=3, hl=DATA, de=18); r = call('OutClose', a=3)
time.sleep(0.3)
fh = os.path.join(store, 'STREAMER', 'HELLO.TXT')
check('STORE:HELLO.TXT is on the Pi', os.path.exists(fh) and open(fh, 'rb').read() == b'hello from the CPC', fh)
GAMES = path_at(0x5280, ['GAMES', 'TERRASTR'])
m.set_memory_block(NAME, nm('LEVEL1  BIN')); r = call('OutOpen', a=3, hl=NAME, de=GAMES)
check('STORE:GAMES/TERRASTR/LEVEL1.BIN: the tag', mem(0xBEA0, 30).split(b'\x00')[0] == b'GAMES/TERRASTR/LEVEL1.BIN', mem(0xBEA0, 30))
r = call('OutWrite', a=3, hl=DATA, de=18); r = call('OutClose', a=3)
r = call('Examine', a=3, hl=0, de=GAMES); entries = []
for i in range(6):
    r = call('ExamineNext', a=3, hl=NAME, de=GAMES)
    if r['z']: entries.append((mem(NAME, 11).decode('latin1'), r['de']))
    else: break
check('CAT STORE:GAMES/TERRASTR/: LEVEL1.BIN 18', entries == [('LEVEL1  BIN', 18)], entries)
sock.close(); cosd.kill()
print('%d checks, %d failed' % (count[0], len(fails)))
sys.exit(1 if fails else 0)
