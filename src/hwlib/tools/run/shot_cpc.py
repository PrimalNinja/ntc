# shot_cpc.py - the CPC test in ZEsarUX (a CPC 6128): boots, loads build/cpc/CPC.BIN at #40 over the
# remote protocol, starts it at #40 with the ROMs off (a stub at #8000), and saves screenshots to
# build/shots/cpc_0..2.png
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys, os, time, socket, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('ZESARUX', '/tmp/claude-0/-home-claude/ac607555-f87f-5ddd-b185-d83b7802f0e0/scratchpad/zesarux/src/zesarux')
import zx
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
name = sys.argv[1] if len(sys.argv) > 1 else 'cpc'
BIN = os.path.abspath(os.path.join(R, 'build', name, name.upper().replace('_', '')[:8] + '.BIN'))
Z = os.environ['ZESARUX']; port = 15302

class Cpc(zx.Zx):
    def __init__(s):
        subprocess.run(['pkill', '-x', 'zesarux']); time.sleep(0.5)
        s.p = subprocess.Popen([Z, '--noconfigfile', '--machine', 'CPC6128', '--vo', 'null', '--ao', 'null', '--realvideo',
                                '--enable-remoteprotocol', '--remoteprotocol-port', str(port), '--fastwelcomemessage', '--quickexit'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=os.path.dirname(Z))
        for _ in range(50):
            try: s.s = socket.create_connection(('127.0.0.1', port)); break
            except OSError: time.sleep(0.2)
        s.read(0.5)

z = Cpc()
time.sleep(4)                                 # (BASIC up)
print(z.cmd('enter-cpu-step'))
RAW = os.path.join(R, 'build', 'shots', name + '.raw')      # (without its AMSDOS header)
os.makedirs(os.path.dirname(RAW), exist_ok=True)
open(RAW, 'wb').write(open(BIN, 'rb').read()[128:])
print(z.cmd('load-binary %s 64 %d' % (os.path.abspath(RAW), os.path.getsize(RAW))))
# (the lower ROM is in at #0000 under BASIC: a stub at #8000 turns both ROMs off and jumps to #40)
for i, b in enumerate([0xF3, 0x01, 0x8D, 0x7F, 0xED, 0x49, 0xC3, 0x40, 0x00]):
    z.cmd('write-memory %d %d' % (0x8000 + i, b))
print(z.cmd('set-register PC=8000H'))
print(z.cmd('exit-cpu-step'))
time.sleep(3)
os.makedirs(os.path.join(R, 'build', 'shots'), exist_ok=True)
for i in range(3):
    z.shot(os.path.join(R, 'build', 'shots', '%s_%d.png' % (name, i)), full=True); time.sleep(0.6)
z.close()
os.remove(RAW)
