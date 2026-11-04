# run_pi.py - the Pi balls test run with no CPC and no link: the program on NTC's Z80 core
# (cpcrun), the CPLink's ports bridged to a cosd started on a TCP link, the Pi's STATE asked at
# the end: the twelve balls must be on the Pi, moving and animating. Proves Pi.cls's frames and
# hwlib's model on the Pi.   python3 src/hwlib/tests/cpc_pi/run_pi.py   (COS_PI= cyborg-os/pi)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, socket, subprocess, time, select
HERE = os.path.dirname(os.path.abspath(__file__))
TILES = os.environ.get('PI_TEST') == 'tiles'
NTC = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(NTC, 'test'))
import cpcrun
COS_PI = os.environ.get('COS_PI', os.path.join(NTC, '..', 'cos', 'pi'))
PORT = 7415
store = '/tmp/hwlib-pi-store'; subprocess.run(['rm', '-rf', store]); os.makedirs(os.path.join(store, 'HWLIB', 'GRAPHICS', 'V9990'), exist_ok=True)
open(os.path.join(store, 'HWLIB', 'GRAPHICS', 'V9990', 'TILES'), 'wb').write(bytes([0x11, 0x22, 0x33, 0x44] * 8 * 4))   # 4 tiles, 8 x 8 4-bit
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
bas = os.path.join(HERE, 'Main.bas'); asm = bas[:-4] + '.asm'
r = subprocess.run(['node', os.path.join(NTC, 'test', 'cli.js'), bas, os.path.join(HERE, '..', '..', 'lib', 'Pi.cls'), os.path.join(HERE, 'Art.cls'), '--platform=cpc'], capture_output=True, text=True)
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
# ask the Pi on the same session: TILEAT and STATE
def fr(ch, t, i, pl):
    hb = bytes([ch, t, i, len(pl) & 255, len(pl) >> 8]) + pl
    return b'\xa5' + hb + bytes([sum(hb) & 255])
def ask(txt):
    inq.clear(); sock.sendall(fr(1, 2, 200, txt.encode())); time.sleep(0.4); pump()
    raw = bytes(inq); i = raw.find(b'\xa5\x01\x03\xc8')
    if i < 0: return ''
    ln = raw[i + 4] | (raw[i + 5] << 8); return raw[i + 6:i + 6 + ln].decode('latin1', 'replace')
a = ask('TILEAT 1 20'); b = ask('TILEAT 3 3'); c = ask('TILEAT 9 9'); st = ask('STATE 0')
print('HELLO and OPEN sent:', b'OPEN vdp profile=v9990' in bytes(sent))
print('TILES 0 from the store tag sent:', b'TILES 0 GRAPHICS/V9990/TILES' in bytes(sent))
print('row 20 cell 1 is tile 1:', a == 'OK 1 0', repr(a))
print('cell (3,3) is tile 2 mirrored Y:', b == 'OK 2 2', repr(b))
print('an unset cell: none:', c == 'OK none', repr(c))
print('the sprite animates and moves (STATE 0):', st.startswith('OK 0 ') and st.split()[2] != '20', repr(st))
print('frames committed:', bytes(sent).count(bytes([0xA5, 1, 4, 0, 1, 0, 0x7F])) > 10)
sock.close(); cosd.kill()
sys.exit(0 if (a == 'OK 1 0' and b == 'OK 2 2' and c == 'OK none' and st.startswith('OK 0')) else 1)
