# run_pi.py - PISHELL run with no CPC: the program on NTC's Z80 core, the CPLink's ports bridged to a live
# cosd with a store of three entries; it connects, opens the store and lists the root (the keys a harness
# can't type for a cpcfw program; the rest is the node's proven LIST / GET / PUT / DELETE traffic).
# The original header follows.
# run_pi.py - the Pi balls test run with no CPC and no link: the program on NTC's Z80 core
# (cpcrun), the CPLink's ports bridged to a cosd started on a TCP link, the Pi's STATE asked at
# the end: the twelve balls must be on the Pi, moving and animating. Proves Pi.cls's frames and
# hwlib's model on the Pi.   python3 src/hwlib/tests/cpc_pi/run_pi.py   (COS_PI= cyborg-os/pi)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, socket, subprocess, time, select
HERE = '/home/claude/ntc3/src/hwlib/tests/cpc_pi'
TILES = os.environ.get('PI_TEST') == 'tiles'
NTC = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(NTC, 'test'))
import cpcrun
COS_PI = os.environ.get('COS_PI', os.path.join(NTC, '..', 'cos', 'pi'))
PORT = 7415
store = '/tmp/hwlib-pi-store'; subprocess.run(['rm', '-rf', store]); os.makedirs(os.path.join(store, 'HWLIB', 'GRAPHICS', 'V9990'), exist_ok=True)
os.makedirs(os.path.join(store, 'PISHELL', 'GRAPHICS', 'V9990'), exist_ok=True); os.makedirs(os.path.join(store, 'PISHELL', 'GAMES', 'TERRASTR'), exist_ok=True)
open(os.path.join(store, 'PISHELL', 'GRAPHICS', 'V9990', 'TILES'), 'wb').write(bytes(128)); open(os.path.join(store, 'PISHELL', 'GAMES', 'TERRASTR', 'LEVEL1.BIN'), 'wb').write(bytes(18)); open(os.path.join(store, 'PISHELL', 'README.TXT'), 'wb').write(b'hello\n')
cosd = subprocess.Popen(['node', os.path.join(COS_PI, 'cosd.js'), '--link=tcp:%d' % PORT, '--store=' + store, '--vdu=8405'], stderr=open('/tmp/hwlib-pi-cosd.log', 'w'), stdout=subprocess.DEVNULL)
time.sleep(0.8)
sock = socket.create_connection(('127.0.0.1', PORT)); sock.setblocking(False)
inq = bytearray(); sent = bytearray(); recv_all = bytearray()
def pump():
    try:
        while True:
            b = sock.recv(65536)
            if not b: break
            inq.extend(b); recv_all.extend(b)
    except BlockingIOError: pass
# compile and assemble as cpcrun's main does
bas = '/home/claude/ntc3/src/apps/pishell/Main.bas'; asm = bas[:-4] + '.asm'
r = subprocess.run(['node', os.path.join(NTC, 'test', 'cli.js'), bas, '--platform=cpcfw'], capture_output=True, text=True)
open(asm, 'w').write(r.stdout)
b, syms = cpcrun.assemble(asm)
c = cpcrun.CPC(b, syms.get('ntc_start', 0x4000), '', syms)
old_out, old_inp = c.out, c.inp
def out(port, val):
    if (port & 0xFF00) == 0xFD00 and (port & 0xFF) == 0x80: sock.sendall(bytes([val])); sent.append(val)
    else: old_out(port, val)
def inp(port):
    if (port & 0xFF00) == 0xFD00:
        pump()
        if (port & 0xFF) == 0x81: return 0x02 | (0x01 if inq else 0)
        if (port & 0xFF) == 0x80: return inq.pop(0) if inq else 0
    return old_inp(port)
c.m.set_output_callback(out); c.m.set_input_callback(inp)
# run for a while (the program loops on Frame for ever): a few seconds of real time
deadline = time.time() + 6
while time.time() < deadline and not c.m.halted:
    c.m.ticks_to_stop = 40000; c.m.run(); pump()
# what the shell did: connected, opened the store, listed the root; its entries in memory
nent = syms.get('nent') or syms.get('g_nent')
cands = [k for k in syms if k.lower().endswith('nent')]

print('HELLO + OPEN store sent:', b'name=PISHELL' in bytes(sent) and b'OPEN store' in bytes(sent))
print('LIST / fmt=cpc sent:', b'LIST / fmt=cpc' in bytes(sent))
if cands:
    a = syms[cands[0]]; v = c.m.memory[a] | (c.m.memory[a + 1] << 8); print('entries listed (nent):', v, '(symbol', cands[0] + ')')
    en = [k for k in syms if k.lower().endswith('_en') or k.lower() == 'en']
    if en:
        b = syms[en[0]]; print('first entries:', bytes(c.m.memory[b:b + 36]).replace(b'\x00', b'.'))
else:
    print('nent symbol not found; symbols with "ent":', [k for k in syms if 'ent' in k.lower()][:6])
sock.close(); cosd.kill()
