# zx.py - drive a headless ZEsarUX (ZX Spectrum Next) over its remote protocol (ZRCP): load a NEX,
# run (28MHz allowed), press keys, take screenshots, read memory and symbols.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
# Keys: send-keys-event takes the character's code ('a' = 97, ' ' = 32, '0' = 48 ...).
import socket, subprocess, time, os, sys
# the emulator: ZESARUX=path, else ./zesarux/src/zesarux beside this file (setup.sh builds it there)
ZBIN = os.environ.get('ZESARUX', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zesarux', 'src', 'zesarux'))

class Zx:
    def __init__(s, nex, port=10000, speed=100, wait=5):
        subprocess.run(['pkill', '-x', 'zesarux'])
        time.sleep(0.5)
        args = [ZBIN, '--noconfigfile', '--machine', 'TBBlue', '--tbblue-fast-boot-mode', '--allowturbotbbluerom', '--vo', 'null', '--ao', 'null',
                '--realvideo', '--enable-remoteprotocol', '--remoteprotocol-port', str(port), '--fastwelcomemessage', '--quickexit']
        if speed != 100: args += ['--emulatorspeed', str(speed)]
        args.append(nex)
        s.p = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=os.path.dirname(ZBIN))
        for _ in range(50):
            try:
                s.s = socket.create_connection(('127.0.0.1', port)); break
            except OSError: time.sleep(0.2)
        s.read(0.5)
        time.sleep(wait)

    def read(s, wait):
        s.s.settimeout(wait); out = b''
        try:
            while True:
                d = s.s.recv(65536)
                if not d: break
                out += d
                if out.endswith(b'command> '): break
        except Exception: pass
        return out.decode(errors='replace')

    def cmd(s, c, wait=2.0):
        s.s.sendall((c + '\n').encode())
        return s.read(wait).replace('command> ', '').strip()

    def shot(s, path, full=False):
        bmp = path.rsplit('.', 1)[0] + '.bmp'
        s.cmd('save-screen ' + bmp)
        time.sleep(0.3)
        from PIL import Image
        im = Image.open(bmp).convert('RGB')
        w, h = im.size
        if not full:
            z = 2 if w >= 640 else 1
            cx, cy = w // 2, h // 2
            im = im.crop((cx - 160 * z, cy - 128 * z, cx + 160 * z, cy + 128 * z))
            if z == 2: im = im.resize((320, 256), Image.NEAREST)
        im.save(path); os.remove(bmp)
        return path

    def key(s, k, down):
        s.cmd('send-keys-event %d %d' % (k, 1 if down else 0), 0.2)

    def tap(s, ch, hold=0.12):
        k = ord(ch.lower()) if isinstance(ch, str) else ch
        s.key(k, 1); time.sleep(hold); s.key(k, 0); time.sleep(0.05)

    def mem(s, addr, n):
        r = s.cmd('read-memory %d %d' % (addr, n), 1.0)
        return bytes.fromhex(r.split()[0]) if r else b''

    def close(s):
        try: s.cmd('exit-emulator', 0.5)
        except Exception: pass
        s.p.kill()

def syms(path):
    d = {}
    for l in open(path):
        if ':' in l and 'EQU' in l.upper():
            name = l.split(':')[0].strip()
            v = l.upper().split('EQU')[1].strip().replace('0X', '').replace('$', '').replace('#', '')
            try: d[name] = int(v, 16)
            except ValueError: pass
    return d
