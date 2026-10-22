# cosbot.py <dir: NTC.NEX, Main.sym> typed keys=frames:k,k;... shots=f,f frames=n texts=f,f out=prefix
# CyborgOS-Next in nextemu: typed text (\n = Enter) for the command line, held keys by frame,
# shots and the tilemap's text at frames
import sys, os
sys.path.insert(0, '/home/claude/work/ntc/src/test')
import zxnrun, cpcrun          # (the current NTC's: chords)
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
d = sys.argv[1]; typed = sys.argv[2].replace('\\n', '\r')
kw = dict(a.split('=', 1) for a in sys.argv[3:])
z = nextemu.NextX(os.path.join(d, 'NTC.NEX'), os.path.join(d, 'Main.sym'))
z.typed = list(typed)
def run_one(s=z):
    # one frame's worth of T, as zxnrun.run steps (its interrupt timing: nextemu's run_one loses
    # the hypervisor's interrupts)
    start = s.T; ft = s.frame_t()
    while not s.m.halted and not s.reset and s.T - start < ft:
        q = max(1, s.next_event() - s.tframe)
        s.stop = False; left = q
        while left > 0 and not (s.stop or s.m.halted or s.reset):
            s.q = left; s.m.ticks_to_stop = left; s.run_bp(); s.q = 0
            d = (s.stopdone + 1) if s.stop else (left - s.m.ticks_to_stop)
            s.T += d; s.tframe += d; left -= d
        if s.m.halted or s.reset: break
        if s.stop:
            while s.tframe >= s.frame_t(): s.tframe -= s.frame_t()
            continue
        steps = 0
        while not s.m.halted and not s.reset and steps < 4000:
            if s.m.iff1 and s.m.on_handle_active_int(): s.ints += 1; break
            s.q = 1; s.m.ticks_to_stop = 1; s.run_bp(); steps += 1; d = 1 - s.m.ticks_to_stop; s.q = 0; s.T += d; s.tframe += d
        while s.tframe >= s.frame_t(): s.tframe -= s.frame_t()
z.run_one = run_one
# no SD card here: esxDOS's rst 8 (the ROM in slot 0) answers every hook with an error (carry,
# A = 5 "no such file") and returns past the hook byte - CyborgOS-Next then goes by its archive
# the SD card: no esxDOS in the emulator, so rst 8 (with the ROM in slot 0) is answered here.
# sd=FOLDER: a host folder is the card (open / read / write / close / seek / the folder's
# entries / chdir / the drive); without it every call is an error (no card)
BP = {}
SD = kw.get('sd')
hs = {}; nh = [0]
def sd_path(m, a):
    t = b''
    while m.memory[a]: t += bytes([m.memory[a]]); a += 1
    t = t.decode('latin-1').replace('\\', '/')
    if len(t) > 1 and t[1] == ':': t = t[2:]
    return t.strip('/')
def sd_find(rel):
    d = SD
    for part in [x for x in rel.split('/') if x]:
        if not os.path.isdir(d): return None
        m = [f for f in os.listdir(d) if f.upper() == part.upper()]
        if not m: return None
        d = os.path.join(d, m[0])
    return d
def esx(z):
    m = z.m
    if z.mmu[0] != 255: return False
    sp = m.sp; ret = m.memory[sp] | m.memory[sp + 1] << 8
    hook = m.memory[ret]
    m.sp = (sp + 2) & 0xFFFF; m.pc = (ret + 1) & 0xFFFF
    ok = lambda: setattr(m, 'f', m.f & 0xFE)
    def err(c=5): m.a = c; m.f = m.f | 1
    if not SD: return err() or True
    ix = m.ix
    if hook == 0x89: m.a = (2 << 3) | 1; ok()                       # M_GETSETDRV: C:
    elif hook == 0xA9: ok()                                          # F_CHDIR
    elif hook == 0x9A:                                               # F_OPEN
        rel = sd_path(m, ix); f = sd_find(rel); wr = m.b & 0x0E
        if wr:
            if f is None: f = os.path.join(SD, *rel.split('/'))
            fh = open(f, 'w+b')
        elif f is None or not os.path.isfile(f): return err() or True
        else: fh = open(f, 'rb')
        nh[0] += 1; hs[nh[0]] = fh; m.a = nh[0]; ok()
    elif hook == 0x9D:                                               # F_READ
        fh = hs.get(m.a)
        if fh is None or hasattr(fh, 'ents'): return err() or True
        d = fh.read(m.bc)
        for i, x in enumerate(d): m.memory[(ix + i) & 0xFFFF] = x
        m.bc = len(d); ok()
    elif hook == 0x9E:                                               # F_WRITE
        fh = hs.get(m.a); fh.write(bytes(m.memory[ix:ix + m.bc])); ok()
    elif hook == 0x9B:                                               # F_CLOSE
        fh = hs.pop(m.a, None)
        if fh is not None and not hasattr(fh, 'ents'): fh.close()
        ok()
    elif hook == 0x9F:                                               # F_SEEK (from the start)
        fh = hs.get(m.a); fh.seek((m.bc << 16) | m.de); ok()
    elif hook == 0xA3:                                               # F_OPENDIR
        f = sd_find(sd_path(m, ix))
        if f is None or not os.path.isdir(f): return err() or True
        class Dir: pass
        dh = Dir(); dh.ents = sorted(os.listdir(f)); dh.at = f
        nh[0] += 1; hs[nh[0]] = dh; m.a = nh[0]; ok()
    elif hook == 0xA4:                                               # F_READDIR
        dh = hs.get(m.a)
        if not dh.ents: m.a = 0; ok(); return True
        nm = dh.ents.pop(0); full = os.path.join(dh.at, nm)
        b = bytes([0x10 if os.path.isdir(full) else 0]) + nm.upper().encode() + b'\0' + bytes(4) + os.path.getsize(full).to_bytes(4, 'little')
        for i, x in enumerate(b): m.memory[(ix + i) & 0xFFFF] = x
        m.a = 1; ok()
    else: err()
    return True
BP[0x0008] = esx
def run_bp(s=z):
    m = s.m; ev = m.run()
    while ev & 1:
        pc = m.pc
        if pc in s.mulpcs and m.memory[pc] == 0xED and m.memory[pc + 1] == 0x30:
            m.de = (m.d * m.e) & 0xFFFF
            m.pc = (pc + 2) & 0xFFFF
            m.ticks_to_stop = max(1, m.ticks_to_stop - 8)
        else:
            if pc in BP and BP[pc](s): pass
            else: ev = m.step_over_breakpoint()
            if m.halted or m.ticks_to_stop <= 0: break
        ev = m.run()
z.run_bp = run_bp
for a in BP: z.m.set_breakpoint(a)
# palette reads (#41, #44 at #40's index - the real Next has them; nextemu doesn't)
raw = {}; w0 = z.nreg_write; r0 = z.nreg_read
def nw(r, v):
    sel = (z.regs.get(0x43, 0) >> 4) & 7; i = getattr(z, 'palidx', 0)
    if r == 0x41: raw[(sel, i)] = (v, (v & 3 != 0) and 1 or 0)
    if r == 0x44:
        if not getattr(z, 'p44', False): raw[(sel, i)] = (v, raw.get((sel, i), (0, 0))[1])
        else: raw[(sel, i)] = (raw.get((sel, i), (0, 0))[0], v)
    w0(r, v)
def nr(r):
    sel = (z.regs.get(0x43, 0) >> 4) & 7; i = getattr(z, 'palidx', 0)
    if r == 0x41: return raw.get((sel, i), (0, 0))[0]
    if r == 0x44: return raw.get((sel, i), (0, 0))[1]
    return r0(r)
z.nreg_write = nw; z.nreg_read = nr
ev = nextemu.parse_keys(kw.get('keys'))
z.keysheld = lambda f: {k for a, b, ks in ev if a <= f <= b for k in ks}
out = kw.get('out', '/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad/cb')
for f in kw.get('shots', '').split(','):
    if f: z.shots[int(f)] = '%s_%s.png' % (out, f)
texts = [int(f) for f in kw.get('texts', '').split(',') if f]
WATCH = [n for n in kw.get('watch', '').split(',') if n]
def per(z):
    if WATCH and z.frame % int(kw.get('every', 50)) == 0: print(z.frame, ' '.join('%s=%d' % (n, z.var(n)) for n in WATCH), 'ints', z.ints, 'pc=%04x sp=%04x iff=%d' % (z.m.pc, z.m.sp, z.m.iff1), 'mmu', z.mmu, flush=True)
    if z.frame in texts: print('--- text at', z.frame); print(z.text())
z.hooks.append(per)
# GVAR=slot:addr,addr: words in a slot's bank, printed with the watch (the game's variables)
if 'gvar' in kw:
    gs, ga = kw['gvar'].split(':'); gs = int(gs); ga = [int(a, 16) for a in ga.split(',')]
    def gpeek(a, gs=gs):
        if a >= 0x10000: gs, a = a >> 16, a & 0xFFFF       # (slot n's: n0000 + address)
        bk = z.deek(z.symtab['arr_bk'] + 2 * gs)
        b16 = z.symtab['ZXN_FIRSTBANK'] + 4 * bk - 4 + (a >> 14)
        pg = z.page(2 * b16 + ((a >> 13) & 1)); o = a & 0x1FFF
        return pg[o] | pg[o + 1] << 8
    def gper(z):
        if z.frame % int(kw.get('every', 50)) == 0:
            for k in range(8): z.store(k)
            print(z.frame, 'game', ' '.join('%04x=%d' % (a, gpeek(a)) for a in ga), flush=True)
    z.hooks.append(gper)
z.run_frames(int(kw.get('frames', 1000)))
print('frame', z.frame, 'pc=%04x' % z.m.pc, 'halted' if z.m.halted else '', 'reset' if z.reset else '', 'ints', z.ints)
print(z.text())
