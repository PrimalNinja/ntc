# streamer_test.py - the node tested end to end with no CPC and no UniDOS: build/streamer.rom at
# #C000 on NTC's Z80 core, its entries called the way UniDOS calls them (CheckDrive, GetName,
# Examine / ExamineNext, OutOpen / OutWrite / OutClose on CMD and PATTERNS, InOpen / InRead on
# EVENTS), and the CPLink's ports (&FD80 data, &FD81 status) bridged to a cosd started on a TCP
# link - so the frames the ROM sends go to the real vdp service and the events it reads back are
# the Pi's. Checks: the categories found by name, a root listed (files, then folders), the
# channel opened by the OPEN opcode, a sprite set moving with EDGE bounds and the EDGE event read
# back through EVENTS, an asset SAVEd into GRAPHICS:V9990/PATTERNS landing in the Pi's store and read
# back, a folder CATalogued from the Pi, SPEECH's TARGET, MUSIC, STORE's root.
#   python3 streamer/test/streamer_test.py      (needs node, the NTC test folder's z80 module)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, socket, subprocess, time, struct
HERE = os.path.dirname(os.path.abspath(__file__))
NTC = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(NTC, 'test'))
import z80
COS_PI = os.environ.get('COS_PI', os.path.join(NTC, '..', 'cos', 'pi'))
PORT = 7393
ROM = open(os.path.join(HERE, '..', 'build', 'streamer.rom'), 'rb').read()
ENTRY = {'Init': 1, 'CheckDrive': 2, 'GetStatus': 3, 'GetName': 4, 'GetDesc': 5, 'GetFreeSpace': 6, 'InOpen': 7, 'InRead': 8, 'InClose': 9,
         'OutOpen': 11, 'OutWrite': 12, 'OutClose': 13, 'Examine': 15, 'ExamineNext': 16}   # (entry 0 is the ROM's own InitROM)
fails = []
runs = [0]
def check(name, ok, got=''):
    runs[0] += 1
    print(('ok   ' if ok else 'FAIL ') + name + ('' if ok else ': ' + str(got)))
    if not ok: fails.append(name)

# ---- cosd on a TCP link, and a socket to it that the ROM's port writes go down
store = '/tmp/streamer-store'; import shutil; shutil.rmtree(store, ignore_errors=True)
os.makedirs(store, exist_ok=True)
cosd = subprocess.Popen(['node', os.path.join(COS_PI, 'cosd.js'), '--link=tcp:%d' % PORT, '--store=' + store, '--vdu=8396'], stderr=open('/tmp/streamer-cosd.log', 'w'), stdout=subprocess.DEVNULL)   # (a pipe nobody reads would fill and stop cosd)
time.sleep(0.8)
sock = socket.create_connection(('127.0.0.1', PORT)); sock.setblocking(False)
inq = bytearray()
def pump():
    try:
        while True:
            b = sock.recv(4096)
            if not b: break
            inq.extend(b)
    except BlockingIOError:
        pass
sent = bytearray()
allsent = bytearray()
speech = {0xFBEE: [], 0xFBFE: []}      # allophones written to each card
speech_polls = {0xFBEE: 0, 0xFBFE: 0}  # status reads since the last write (the card says busy for the first two)
speech_total = {0xFBEE: 0, 0xFBFE: 0}

# ---- the machine: the ROM at #C000, a stub at #4000 that calls entry n and halts
m = z80.Z80Machine()
m.set_memory_block(0xC000, ROM)
def out(port, val):
    if (port & 0xFF00) == 0xFD00 and (port & 0xFF) == 0x80:
        sock.sendall(bytes([val])); sent.append(val); allsent.append(val)
    if port in speech: speech[port].append(val); speech_polls[port] = 0
def inp(port):
    if port in speech:
        speech_polls[port] += 1; speech_total[port] += 1
        busy = speech_polls[port] <= 2                 # /LRQ 1 (busy) twice, then ready
        return (0x40 if busy else 0) if port == 0xFBEE else (0x80 if busy else 0)
    if (port & 0xFF00) == 0xFD00:
        if (port & 0xFF) == 0x81:
            pump(); return 0x02 | (0x01 if inq else 0)
        if (port & 0xFF) == 0x80:
            pump()
            if inq: return inq.pop(0)
            return 0
    return 0xFF
m.set_output_callback(out); m.set_input_callback(inp)
def call(entry, a=0, hl=0, de=0, bc=0, ticks=50000000):
    ad = 0xC006 + 3 * ENTRY[entry]
    m.set_memory_block(0x4000, bytes([0xCD, ad & 255, ad >> 8, 0x76]))   # call entry : halt
    m.a, m.hl, m.de, m.bc, m.sp, m.pc = a, hl, de, bc, 0xBE00, 0x4000
    m.ticks_to_stop = ticks
    deadline = time.time() + 20
    m.halted = False
    while not m.halted and time.time() < deadline:
        m.ticks_to_stop = 20000
        m.run()
        pump()
    f = m.f
    return {'a': m.a, 'de': m.de, 'hl': m.hl, 'c': bool(f & 1), 'z': bool(f & 64)}
def mem(ad, n): return bytes(m.memory[ad:ad + n])


def path(*names):   # UniDOS's normalized path: a count, then 11-character names
    b = bytes([len(names)])
    for n in names: b += n.ljust(11).encode('latin1')
    return b
def name(n):
    return n.ljust(11).encode('latin1')
ROOT = 0x5200; m.set_memory_block(ROOT, path())
P_V9990 = 0x5280; m.set_memory_block(P_V9990, path('V9990'))
# ---- the categories by name; a foreign number
for nm, dev in (('GRAPHICS', 0), ('SPEECH', 1), ('MUSIC', 2), ('STORE', 3)):
    b = nm[:-1].encode('latin1') + bytes([ord(nm[-1]) | 0x80])
    m.set_memory_block(0x5000, b)
    r = call('CheckDrive', a=0x33, hl=0x5000, bc=len(nm))
    check('CheckDrive %s: device %d' % (nm, dev), r['c'] and r['a'] == dev, r)
m.set_memory_block(0x5000, b'XY' + bytes([ord('Z') | 0x80]))
r = call('CheckDrive', a=0x33, hl=0x5000, bc=3)
check('CheckDrive XYZ: not ours, A kept', (not r['c']) and r['a'] == 0x33, r)
r = call('GetStatus', a=7)
check('GetStatus of a foreign number: not ours', not r['c'], r)
r = call('GetName', a=0, de=0x5100)
check('GetName: GRAPHICS with bit 7 on the S', mem(0x5100, 8) == b'GRAPHIC' + bytes([ord('S') | 0x80]), mem(0x5100, 8))
# ---- GRAPHICS: root: CMD, EVENTS, then the profile folders as directories
r = call('Examine', a=0, hl=0, de=ROOT)
entries = []
for i in range(9):
    r = call('ExamineNext', a=0, hl=0x5300, de=ROOT)
    if r['z']: entries.append((mem(0x5300, 11).decode('latin1').strip(), r['a']))
    else: break
check('GRAPHICS: root: CMD, EVENTS as files, then V9990 .. PINATIVE as folders (A bit 4)',
      entries == [('CMD', 0), ('EVENTS', 0), ('V9990', 0x10), ('V9938', 0x10), ('ZXNEXT', 0x10), ('MD', 0x10), ('PINATIVE', 0x10)], entries)
# ---- GRAPHICS:CMD - OPEN opcode, HELLO once, the channel; then commands and EVENTS as before
m.set_memory_block(0x5300, name('CMD'))
r = call('OutOpen', a=0, hl=0x5300, de=ROOT)
check('OutOpen GRAPHICS:CMD', r['c'] and r['z'], r)
txt = b'vdp profile=v9990 vsync=1'
m.set_memory_block(0x6000, bytes([0x80, len(txt)]) + txt)
r = call('OutWrite', a=0, hl=0x6000, de=2 + len(txt))
check('80 OPEN: HELLO once, OPEN vdp sent', bytes(sent).count(b'COS1 machine=cpc') == 1 and b'OPEN vdp profile=v9990' in bytes(sent), bytes(sent)[:60])
chan = mem(0xBE91, 1)[0]
check('the channel from the answer (1)', chan == 1, chan)
def w16(v): return struct.pack('<h', v)
cmds = bytes([1]) + w16(1) + w16(0) + w16(10) + w16(10) + bytes([1]) + bytes([5]) + w16(1) + w16(64) + w16(0) + bytes([6]) + w16(1) + bytes([4]) + bytes([0x7F])
m.set_memory_block(0x6000, cmds); sent[:] = b''
r = call('OutWrite', a=0, hl=0x6000, de=len(cmds))
check('each VDP command its own DATA frame (4)', bytes(sent).count(bytes([0xA5, 1, 4, 0])) == 4, bytes(sent)[:24])
r = call('OutClose', a=0)
m.set_memory_block(0x5300, name('EVENTS'))
r = call('InOpen', a=0, hl=0x5300, de=ROOT)
check('InOpen GRAPHICS:EVENTS', r['c'] and r['z'], r)
lines = []
for i in range(400):
    r = call('InRead', a=0, hl=0x6100, de=80)
    if not (r['c'] and r['z']): break
    line = mem(0x6100, r['de']).decode('latin1'); lines.append(line)
    if line.startswith('EDGE 1 1'): break
check('V n events read as lines', any(l.startswith('V ') and l.endswith('\r\n') for l in lines), lines[:2])
check('EDGE 1 1 arrived through EVENTS', any(l.startswith('EDGE 1 1') for l in lines), (lines[:2], len(lines)))
r = call('InClose', a=0)
# ---- an asset: SAVE into GRAPHICS:V9990/PATTERNS -> PUT GRAPHICS/V9990/PATTERNS in parts on the store channel; in the store on disk
m.set_memory_block(0x5300, name('PATTERNS'))
r = call('OutOpen', a=0, hl=0x5300, de=P_V9990)
check('OutOpen GRAPHICS:V9990/PATTERNS (a store file)', r['c'] and r['z'] and mem(0xBE81, 1)[0] == 10, (r, mem(0xBE81, 1)))
check('the tag made: GRAPHICS/V9990/PATTERNS', mem(0xBEA0, 24) == b'GRAPHICS/V9990/PATTERNS\x00', mem(0xBEA0, 24))
sent[:] = b''
m.set_memory_block(0x6200, bytes(range(256)))
r = call('OutWrite', a=0, hl=0x6200, de=256); r = call('OutClose', a=0)
check('PUT in parts: two with MORE, the last without', bytes(sent).count(b'PUT GRAPHICS/V9990/PATTERNS\x00') == 3, bytes(sent)[:70])
time.sleep(0.3)
fpat = os.path.join(store, 'TEST', 'GRAPHICS', 'V9990', 'PATTERNS')
check('the file is in the Pi store with the 256 bytes', os.path.exists(fpat) and open(fpat, 'rb').read() == bytes(range(256)), os.path.exists(fpat) and len(open(fpat, 'rb').read()))
# ---- read it back: LOAD GRAPHICS:V9990/PATTERNS -> GET, the bytes through InRead
r = call('InOpen', a=0, hl=0x5300, de=P_V9990)
check('InOpen the store file: GET answered', r['c'] and r['z'], r)
got = b''
for i in range(10):
    r = call('InRead', a=0, hl=0x6300, de=100)
    if not (r['c'] and r['z']) or r['de'] == 0: break
    got += mem(0x6300, r['de'])
check('the 256 bytes read back in pieces', got == bytes(range(256)), (len(got), got[:8]))
r = call('InClose', a=0)
# ---- CAT GRAPHICS:V9990/ : the Pi's LIST as entries
r = call('Examine', a=0, hl=0, de=P_V9990)
check('Examine of a folder: a LIST asked of the Pi', r['c'] and r['z'], r)
r = call('ExamineNext', a=0, hl=0x5300, de=P_V9990)
check('ExamineNext: PATTERNS, size 256', r['z'] and mem(0x5300, 11) == name('PATTERNS') and r['de'] == 256, (r, mem(0x5300, 11)))
r = call('ExamineNext', a=0, hl=0x5300, de=P_V9990)
check('then the end', not r['z'], r)
# ---- SPEECH: 85 TARGET 0 then allophones to &FBEE; TARGET 1 to &FBFE
m.set_memory_block(0x5300, name('CMD'))
r = call('OutOpen', a=1, hl=0x5300, de=ROOT)
m.set_memory_block(0x6300, bytes([0x85, 0, 27, 7, 55, 3, 200]))
r = call('OutWrite', a=1, hl=0x6300, de=7)
check('SPEECH: TARGET 0 then allophones out of &FBEE, the bad one masked', speech[0xFBEE] == [27, 7, 55, 3, 8], speech[0xFBEE])
check('SSA1: waited on bit 6 (3 polls an allophone)', speech_total[0xFBEE] == 15, speech_total[0xFBEE])
m.set_memory_block(0x6300, bytes([0x85, 1, 27, 7]))
r = call('OutWrite', a=1, hl=0x6300, de=4)
check('SPEECH: TARGET 1: out of &FBFE', speech[0xFBFE] == [27, 7], speech[0xFBFE])
r = call('OutClose', a=1)
# ---- SPEECH: TARGET 2 (the Pi's votrax): OPEN votrax, then the bytes as DATA
r = call('OutOpen', a=1, hl=0x5300, de=ROOT)
t3 = b'votrax'
m.set_memory_block(0x6000, bytes([0x85, 2, 0x80, len(t3)]) + t3)
r = call('OutWrite', a=1, hl=0x6000, de=4 + len(t3))
chan3 = mem(0xBE91, 1)[0]
check('SPEECH: TARGET 2 + OPEN votrax: a channel', chan3 > 0, chan3)
sent[:] = b''
m.set_memory_block(0x6000, bytes([0x1b, 0x07, 0x83, 0x03]))
r = call('OutWrite', a=1, hl=0x6000, de=4)
check('the phoneme bytes as one DATA frame, untouched', bytes(sent)[:6] == bytes([0xA5, chan3, 4, 0, 4, 0]) and bytes(sent)[6:10] == bytes([0x1b, 0x07, 0x83, 0x03]), bytes(sent)[:12])
r = call('OutClose', a=1)
# ---- MUSIC: 80 OPEN audio, a line a request, the answer on EVENTS
r = call('OutOpen', a=2, hl=0x5300, de=ROOT)
t2 = b'audio'
m.set_memory_block(0x6000, bytes([0x80, len(t2)]) + t2)
r = call('OutWrite', a=2, hl=0x6000, de=2 + len(t2))
chan2 = mem(0xBE91, 1)[0]
check('MUSIC: the audio channel opened', chan2 > 0, chan2)
sent[:] = b''
m.set_memory_block(0x6000, b'STATUS\r\n')
r = call('OutWrite', a=2, hl=0x6000, de=8)
check('MUSIC: a line is one REQ without its CR LF', bytes(sent)[:6] == bytes([0xA5, chan2, 2, 2, 6, 0]) and bytes(sent)[6:12] == b'STATUS', bytes(sent)[:14])
r = call('OutClose', a=2)
m.set_memory_block(0x5300, name('EVENTS')); r = call('InOpen', a=2, hl=0x5300, de=ROOT)
got = ''
for i in range(20):
    r = call('InRead', a=2, hl=0x6100, de=80)
    line = mem(0x6100, r['de']).decode('latin1')
    if line.startswith('OK idle') or line.startswith('OK playing'): got = line; break
check("MUSIC: STATUS's answer on EVENTS", got.startswith('OK'), got or line)
r = call('InClose', a=2)
# ---- STORE: root: SAVE "STORE:HELLO.TXT" -> PUT HELLO.TXT; CAT STORE: lists it from the Pi
m.set_memory_block(0x5300, b'HELLO   TXT')
r = call('OutOpen', a=3, hl=0x5300, de=ROOT)
check('STORE: a root file: the tag HELLO.TXT', r['c'] and r['z'] and mem(0xBEA0, 10) == b'HELLO.TXT\x00', mem(0xBEA0, 10))
m.set_memory_block(0x6200, b'hello from a CPC')
r = call('OutWrite', a=3, hl=0x6200, de=16); r = call('OutClose', a=3)
time.sleep(0.3)
check('STORE: the file on the Pi', open(os.path.join(store, 'TEST', 'HELLO.TXT'), 'rb').read() == b'hello from a CPC' if os.path.exists(os.path.join(store, 'TEST', 'HELLO.TXT')) else False, os.listdir(os.path.join(store, 'TEST')))
r = call('Examine', a=3, hl=0, de=ROOT)
names = []
for i in range(6):
    r = call('ExamineNext', a=3, hl=0x5300, de=ROOT)
    if r['z']: names.append(mem(0x5300, 11).decode('latin1').strip())
    else: break
check('CAT STORE: lists from the Pi (HELLO.TXT among the entries)', 'HELLO   TXT' in names or 'HELLO.TXT' in [n for n in names], names)
sock.close(); cosd.kill()
print('%d checks, %d failed' % (36, len(fails)))
sys.exit(1 if fails else 0)
