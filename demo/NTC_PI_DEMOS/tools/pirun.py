# pirun.py - one of the NTC PI DEMOS run with no CPC and no card: the program on NTC's Z80 core
# with its firmware stand-in (test/ntcrun.py, platform cpcfw), the card's ports (&FD80 / &FD81)
# joined to a real cosd started here. What the program printed comes out at the end.
#
#   python3 tools/pirun.py [--card=cplink|cplink2] [--keys=TEXT] [--limit=N] [--platform=cpcfw|cpc]
#                          [--keep] PROGRAM.bas [Class.cls ...]
#
#   NTC      the NTC folder (the one with src/ and test/)        default ../NTC beside this folder
#   COS_PI   CyborgOS's pi folder (the one with cosd.js)          default ../CYBORGOS/pi
#   --card=cplink2   the status byte's bits 4-7 read 0001 (the card's version) and cosd is started on a cplink2 link:
#                    big answers come through the Pi ROM (ROM 32 / 33 at &C000), this script
#                    standing in for cplink-bridge
#   --card=none      no card: both ports read &FF
#   --dead   the card takes bytes and the Pi never answers (what a program does with no Pi)
#   --keep   the store, the volumes and cosd's log are left in the work folder (printed)
# The players (mpg123, aplay, sidplayfp) are stand-ins made here: each "plays" for 0.3 seconds.
#   PI_MODELS  a folder of .MDL files for the mind service; NTCK_NODE  the built pi/ntck/ntck.node
# (c) 2026 Cyborg Unicorn Pty Ltd
import os, sys, socket, subprocess, time, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
NTC = os.path.abspath(os.environ.get('NTC', os.path.join(ROOT, '..', 'NTC')))
COS_PI = os.path.abspath(os.environ.get('COS_PI', os.path.join(ROOT, '..', 'CYBORGOS', 'pi')))

def main():
    args = sys.argv[1:]; card = 'cplink'; keys = ''; limit = 6000; plat = 'cpcfw'; keep = False; dead = False
    for a in list(args):
        if a.startswith('--card='): card = a[7:]; args.remove(a)
        elif a.startswith('--keys='): keys = a[7:].replace('\\n', '\r'); args.remove(a)
        elif a.startswith('--limit='): limit = int(a[8:]); args.remove(a)
        elif a.startswith('--platform='): plat = a[11:]; args.remove(a)
        elif a == '--keep': keep = True; args.remove(a)
        elif a == '--dead': dead = True; args.remove(a)
    if not args: print(__doc__ or 'pirun.py PROGRAM.bas [Class.cls ...]'); return 2
    sys.path.insert(0, os.path.join(NTC, 'test'))
    import cpcrun, ntcrun
    work = tempfile.mkdtemp(prefix='pirun-')
    store = os.path.join(work, 'store'); vols = os.path.join(work, 'volumes'); models = os.path.join(work, 'models')
    for d in (store, vols, models): os.makedirs(d)
    if os.environ.get('PI_MODELS'):         # .MDL files for the mind service (it needs pi/ntck built: NTCK_NODE= its ntck.node)
        for f in os.listdir(os.environ['PI_MODELS']):
            if f.upper().endswith('.MDL'): shutil.copy(os.path.join(os.environ['PI_MODELS'], f), models)
    fake = {}                                # stand-ins for the Pi's players: each runs for 0.3 seconds
    for n in ('aplay', 'mpg123', 'sidplayfp'):
        fake[n] = os.path.join(work, 'fake-' + n); open(fake[n], 'w').write('#!/bin/sh\nsleep 0.3\n'); os.chmod(fake[n], 0o755)

    # ---- this script as the card's bridge: cosd connects to it (the FIFO; the Pi ROM on port + 1)
    port = 7600 + (os.getpid() % 300) * 2
    srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); srv.bind(('127.0.0.1', port)); srv.listen(1)
    rsrv = socket.socket(); rsrv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); rsrv.bind(('127.0.0.1', port + 1)); rsrv.listen(4); rsrv.setblocking(False)
    cmd = ['node', os.path.join(COS_PI, 'cosd.js'), '--link=%s:%d' % ('cplink' if card == 'none' else card, port), '--store=' + store, '--volumes=' + vols,
           '--models=' + models, '--vdu=%d' % (port + 2), '--trace',
           '--mpg123=' + fake['mpg123'], '--aplay=' + fake['aplay'], '--sidplay=' + fake['sidplayfp']]
    log = open(os.path.join(work, 'cosd.log'), 'w')
    cosd = subprocess.Popen(cmd, stdout=log, stderr=log)
    srv.settimeout(10)
    try: sock, _ = srv.accept()
    except socket.timeout: print('pirun: cosd did not connect (see %s)' % log.name); cosd.kill(); return 2
    sock.setblocking(False)
    inq = bytearray(); stats = {'in': 0, 'out': 0, 'rom': 0, 'unread': 0}
    pirom = bytearray(0x8000)
    ror = {32: False, 33: False}             # the card's ROR1 / ROR2: new data in the ROM, the CPC has not read it

    def pump():
        try:
            while True:
                b = sock.recv(65536)
                if not b: break
                inq.extend(b); stats['in'] += len(b)
        except (BlockingIOError, ConnectionResetError): pass
        try:                                   # a Pi ROM write: all of a connection's bytes, from offset 0
            c, _ = rsrv.accept(); c.settimeout(2); d = bytearray()
            while True:
                b = c.recv(65536)
                if not b: break
                d.extend(b)
            if ror[32] or ror[33]: stats['unread'] += 1      # the real bridge waits here until both are read: for ever
            pirom[0:len(d)] = d[:0x8000] + bytes(0x8000 - min(len(d), 0x8000)); stats['rom'] += 1
            ror[32] = ror[33] = True                         # both set when RNF falls, whatever the length
            try: c.sendall(b'OK %d\n' % len(d))
            except OSError: pass
            c.close()
        except (BlockingIOError, socket.timeout): pass

    # ---- compile, assemble, the machine
    srcs = [os.path.abspath(a) for a in args]
    asm = os.path.join(work, os.path.basename(srcs[0])[:-4] + '.asm')
    r = subprocess.run(['node', os.path.join(NTC, 'test', 'cli.js')] + srcs + ['--platform=' + plat], capture_output=True, text=True)
    if r.stderr.strip(): print(r.stderr.strip())
    if 'ERR ' in r.stderr: cosd.kill(); return 2
    open(asm, 'w').write(r.stdout)
    b, syms = cpcrun.assemble(asm)
    typed = list(keys)
    printed = []
    if plat == 'cpcfw':
        h = ntcrun.Host('cpcfw', b, syms.get('ntc_start', 0x40), typed); cpcrun.endkey_set(h.m, syms)
        m = h.m; old_out, old_inp = h.out, h.inp
        txt = [k for k, v in h.fwport.items() if v == 'txt_out']
        sel = [k for k, v in h.fwport.items() if v == 'kl_rom_select']
    else:
        h = cpcrun.CPC(b, syms.get('ntc_start', 0x4000), keys, syms)
        m = h.m; old_out, old_inp = h.out, h.inp; txt = []; sel = []
    status_hi = 0x10 if card == 'cplink2' else 0x00      # bits 4-7: the CPLink2's version, 1

    def out(p, v):
        if p == 0xFD80:
            if dead: stats['out'] += 1; return
            try: sock.sendall(bytes([v]))
            except OSError: pass
            stats['out'] += 1; return
        lo = p & 0xFF
        if lo in txt: printed.append(chr(v) if (32 <= v < 127 or v in (10, 13)) else '')
        rom = m.c if lo in sel else -1
        old_out(p, v)
        if rom in (32, 33):
            m.set_memory_block(0xC000, bytes(pirom[(rom - 32) * 0x4000:(rom - 31) * 0x4000]))
            ror[rom] = False                                 # (the card clears it when the ROM is deselected)
    def inp(p):
        if card == 'none' and p in (0xFD80, 0xFD81): return 0xFF
        if p == 0xFD81:
            pump()
            if not inq: time.sleep(0.0003)      # (the emulated CPC waits about as long as a real one)
            return status_hi | 0x02 | (0x01 if inq else 0) | (0x04 if ror[32] else 0) | (0x08 if ror[33] else 0)
        if p == 0xFD80: return inq.pop(0) if inq else 0xFF
        return old_inp(p)
    m.set_output_callback(out); m.set_input_callback(inp)
    if plat == 'cpcfw':
        h.run(limit)
        text = ''.join(printed).replace('\r\n', '\n').replace('\r', '')
        print(text if text.strip() else h.scr.text())
    else:
        h.run(); print(h.screen(cpcrun.loadfont(syms, m.memory)))
    print('--- %s  bytes to the Pi %d, from the Pi %d, Pi ROM writes %d  (%s)' % ('ended' if m.halted else 'NOT ended', stats['out'], stats['in'], stats['rom'], card))
    if stats['unread']: print('--- FAIL  %d Pi ROM write(s) came while the CPC had not read ROM 32 and 33 of the last one: the real bridge waits there' % stats['unread'])
    sock.close(); cosd.kill(); log.close()
    if keep: print('--- kept:', work)
    else: shutil.rmtree(work, ignore_errors=True)
    return 0

if __name__ == '__main__':
    sys.exit(main())
