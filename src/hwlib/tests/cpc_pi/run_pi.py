# run_pi.py - the Pi balls test run with no CPC and no link: the program on NTC's Z80 core
# (cpcrun), the CPLink's ports bridged to a cosd started on a TCP link, the Pi's STATE asked at
# the end: the twelve balls must be on the Pi, moving and animating. Proves Pi.cls's frames and
# hwlib's model on the Pi.   python3 src/hwlib/tests/cpc_pi/run_pi.py   (COS_PI= cyborg-os/pi)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, socket, subprocess, time, select
HERE = os.path.dirname(os.path.abspath(__file__))
NTC = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(NTC, 'test'))
import cpcrun
COS_PI = os.environ.get('COS_PI', os.path.join(NTC, '..', 'cos', 'pi'))
PORT = 7415
store = '/tmp/hwlib-pi-store'; os.makedirs(store, exist_ok=True)
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
# ask the Pi directly on the same session: STATE
def fr(ch, t, i, pl):
    hb = bytes([ch, t, i, len(pl) & 255, len(pl) >> 8]) + pl
    return b'\xa5' + hb + bytes([sum(hb) & 255])
inq.clear(); sock.sendall(fr(1, 2, 200, b'STATE')); time.sleep(0.5); pump()
raw = bytes(inq); st = ''; at = 0
while True:                      # the frames of the answer (RSP id 200, in parts with MORE): their texts joined
    at = raw.find(b'\xa5', at)
    if at < 0 or at + 7 > len(raw): break
    ln = raw[at + 4] | (raw[at + 5] << 8)
    if raw[at + 1] == 1 and (raw[at + 2] & 0x7F) == 3 and raw[at + 3] == 200: st += raw[at + 6:at + 6 + ln].decode('latin1', 'replace')
    at += 7 + ln
lines = [l[3:] if l.startswith('OK ') else l for l in st.split('\n') if l]   # the first line is 'OK ' then sprite 0's
ok_count = len(lines) >= 12
ok_moving = any(int(l.split()[1]) != 6 + int(l.split()[0]) * 19 for l in lines[:12]) if lines else False
ok_anim = any(int(l.split()[3]) > 0 for l in lines[:12]) if lines else False
print('HELLO and OPEN sent:', b'COS1 machine=cpc name=HWLIB' in bytes(sent) and b'OPEN vdp profile=v9990' in bytes(sent))
print('PATTERNS sent (4):', bytes(sent).count(b'PATTERNS ') == 4)
print('12 balls on the Pi:', ok_count, '(%d)' % len(lines))
print('moved from where they were put:', ok_moving)
print('animating (a pattern past 0):', ok_anim)
print('frames committed:', bytes(sent).count(bytes([0xA5, 1, 4, 0, 1, 0, 0x7F])) > 10, '(%d)' % bytes(sent).count(bytes([0xA5, 1, 4, 0, 1, 0, 0x7F])))
sock.close(); cosd.kill()
sys.exit(0 if (ok_count and ok_moving and ok_anim) else 1)
