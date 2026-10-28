# zxnrun.py - a ZX Spectrum Next for the zxn platform's tests (scratch test tool, not delivered).
# ntcrun.py --platform=zxn uses it: the program's NEX file (SAVENEX, written by the assembly) is
# loaded as NextZXOS loads one and run on a Z80 with the Next's parts the platform uses:
#   - 8K pages in 8 MMU slots (NextRegs #50-#57; 255 = the ROM in slots 0, 1), from a NEX file:
#     its banks (16K: pages 2n, 2n+1) in the file's order 5, 2, 0, 1, 3, 4, 6, 7, 8 ..., its PC and
#     SP; slots 2-7 banks 5, 2, 0 and the ROM in 0-1 when it starts
#   - NextRegs through ports #243B (select) / #253B (value): read back as written; #02 bit 0 (a
#     soft reset) ends the run; #07 the CPU speed (3.5, 7, 14, 28MHz: the frame's length in T);
#     #1E / #1F the raster line (from the T count in the frame)
#   - interrupts, IM 1 (the Z80 module): the ULA's at each frame's start (69888 T at 3.5MHz, x2,
#     x4, x8 - 312 lines) unless NextReg #22 bit 2 is set; the line interrupt (#22 bit 1) at its
#     line (#22 bit 0, #23); each held until the Z80 takes it
#   - the keyboard, 8 half rows on port #xxFE (the high byte's 0 bits pick them): typed text as
#     in cpcrun (\n = Enter, \x7f = DEL: Caps + 0, ~ = a scan with no key, {n} = key n held -
#     half row * 8 + bit; {a+b} = keys a and b held together, a chord: {0+25} Caps Shift + 2); a key is down for 3 scans by ntc_plat_scankey (one a scan: at half
#     row 7), up for 3; the Keys class's reads (one half row each) count for {n} and ~ only;
#     {n*}: key n held from then on (until more is typed: the key Option PressAnyKeyOnEnd waits for)
#   - Kempston joysticks on #1F, #37: nothing pressed
#   - the screen: the tilemap (NextRegs #6B, #6E, #6F) in bank 5 read back as text through the
#     program's font (ntc_font): a cell whose tile isn't one of the font's characters shows '#';
#     NTC_SHOT=file.png: the Layer 2 buffer shown (320 x 256) as a picture, its pixels set counted
import os, re, sys
import z80

HERE = os.path.dirname(os.path.abspath(__file__))
NEX_ORDER = [5, 2, 0, 1, 3, 4] + list(range(6, 112))

# typed character -> (half row, bit, modifier: None, 'caps', 'sym')
KEYS = {}
ROWS = [['caps', 'z', 'x', 'c', 'v'], ['a', 's', 'd', 'f', 'g'], ['q', 'w', 'e', 'r', 't'], ['1', '2', '3', '4', '5'],
        ['0', '9', '8', '7', '6'], ['p', 'o', 'i', 'u', 'y'], ['\r', 'l', 'k', 'j', 'h'], [' ', 'sym', 'm', 'n', 'b']]
for r, keys in enumerate(ROWS):
    for b, k in enumerate(keys):
        if len(k) == 1:
            KEYS[k] = (r, b, None)
            if k.isalpha(): KEYS[k.upper()] = (r, b, 'caps')
SYM = {(0, 1): ':', (0, 3): '?', (0, 4): '/', (1, 0): '~', (1, 1): '|', (1, 2): '\\', (1, 3): '{', (1, 4): '}',
       (2, 3): '<', (2, 4): '>', (3, 0): '!', (3, 1): '@', (3, 2): '#', (3, 3): '$', (3, 4): '%',
       (4, 0): '_', (4, 1): ')', (4, 2): '(', (4, 3): "'", (4, 4): '&', (5, 0): '"', (5, 1): ';', (5, 3): ']', (5, 4): '[',
       (6, 1): '=', (6, 2): '+', (6, 3): '-', (6, 4): '^', (7, 2): '.', (7, 3): ',', (7, 4): '*'}
for (r, b), c in SYM.items(): KEYS[c] = (r, b, 'sym')
KEYS['\x7f'] = (4, 0, 'caps')     # DEL: Caps + 0
KEYS['\x1b'] = (7, 0, 'caps')     # Break: Caps + Space

def read_nex(path):
    d = open(path, 'rb').read()
    if d[:4] != b'Next': raise ValueError('not a NEX file: ' + path)
    nbanks = d[9]; sp = d[12] | d[13] << 8; pc = d[14] | d[15] << 8
    present = [i for i in range(112) if d[18 + i]]
    if len(present) != nbanks: raise ValueError('NEX: %d banks in the header, %d marked' % (nbanks, len(present)))
    if d[10]: raise ValueError('NEX: loading screens not handled here')
    o = 512; banks = {}
    for b in NEX_ORDER:
        if b in present:
            banks[b] = d[o:o + 0x4000]; o += 0x4000
    if o != len(d): raise ValueError('NEX: %d bytes after the banks' % (len(d) - o))
    return banks, pc, sp, d[139]

class Next:
    def __init__(s, nexpath, typed, syms):
        banks, pc, sp, entry = read_nex(nexpath)
        s.pages = {}
        for b, data in banks.items():
            s.pages[2 * b] = bytearray(data[:0x2000]); s.pages[2 * b + 1] = bytearray(data[0x2000:])
        s.m = m = z80.Z80Machine()
        s.mmu = [None] * 8
        for k, p in enumerate([255, 255, 10, 11, 4, 5, 2 * entry, 2 * entry + 1]): s.map(k, p)
        m.pc = pc; m.sp = sp
        s.regs = {0x07: 0, 0x06: 0x18, 0x0A: 0x10}   # (the NMI buttons and DivMMC's paging on, as NextZXOS leaves them)
        s.sel = 0; s.reset = False; s.typed = list(typed); s.syms = syms
        s.q = 0; s.stop = False; s.cur = None; s.phase = 0; s.tkey = False; s.scans = 0; s.ints = 0; s.missed = 0; s.T = 0; s.tframe = 0; s.palette = {}
        s.palidx = 0
        s.spat = bytearray(64 * 256); s.sattr = [[0] * 5 for _ in range(128)]; s.ssel = 0; s.sab = 0; s.spp = 0
        m.set_output_callback(s.out); m.set_input_callback(s.inp)
        import cpcrun
        cpcrun.endkey_set(m, syms)
    def page(s, p):
        if p == 255: return bytearray(b'\xff' * 0x2000)    # the ROM: not needed by the platform
        if p not in s.pages: s.pages[p] = bytearray(0x2000)
        return s.pages[p]
    def store(s, k):
        p = s.mmu[k]
        if p is not None and p != 255: s.pages[p] = bytearray(s.m.memory[k * 0x2000:(k + 1) * 0x2000])
    def map(s, k, p):
        if s.mmu[k] == p: return
        s.store(k)
        for j in range(8):          # the page in another slot too: that copy is the one to load
            if j != k and s.mmu[j] == p: s.store(j)
        s.m.set_memory_block(k * 0x2000, bytes(s.page(p)))
        s.mmu[k] = p
    def frame_t(s):
        return 69888 << (s.regs.get(0x07, 0) & 3)
    def line(s):
        # (in the middle of a run: the T done so far in it - the Z80 module counts ticks_to_stop down)
        t = s.tframe + (s.q - s.m.ticks_to_stop if s.q else 0)
        return min(311, (t * 312) // s.frame_t())
    def nreg_write(s, r, v):
        s.regs[r] = v
        if 0x50 <= r <= 0x57: s.map(r - 0x50, v)
        elif r == 0x02 and v & 1: s.reset = True; s.m.ticks_to_stop = 1   # (1: stop after this instruction - 0 would be no limit)
        elif r in (0x22, 0x23, 0x07) and s.q > 1 and not s.stop:   # the next interrupt moves: work it out again
            s.stopdone = s.q - s.m.ticks_to_stop; s.stop = True; s.m.ticks_to_stop = 1   # (the T done so far kept: 1 left now)
        elif r == 0x40: s.palidx = v; s.p44 = 0
        elif r == 0x41: s.palette[((s.regs.get(0x43, 0) >> 4) & 7, s.palidx)] = v; getattr(s, 'blo', {}).pop(((s.regs.get(0x43, 0) >> 4) & 7, s.palidx), None); s.palidx = (s.palidx + 1) & 255
        elif r == 0x44:             # 9-bit colours: RRRGGGBB, then the blue's low bit; the index moves on after the second
            if getattr(s, 'p44', 0) == 0: s.palette[((s.regs.get(0x43, 0) >> 4) & 7, s.palidx)] = v; s.p44 = 1
            else:
                if not hasattr(s, 'blo'): s.blo = {}
                s.blo[((s.regs.get(0x43, 0) >> 4) & 7, s.palidx)] = v & 1
                s.p44 = 0; s.palidx = (s.palidx + 1) & 255
    def nreg_read(s, r):
        if 0x50 <= r <= 0x57: return s.mmu[r - 0x50]
        if r == 0x1E: return s.line() >> 8
        if r == 0x1F: return s.line() & 255
        return s.regs.get(r, 0)
    def out(s, port, val):
        if port == 0x303B: s.ssel = val & 127; s.sab = 0; s.spp = (val & 63) * 256
        elif (port & 0xFF) == 0x57:
            a = s.sattr[s.ssel]; a[s.sab] = val; s.sab += 1
            if s.sab == 4 and not (a[3] & 0x40): a[4] = 0; s.sab = 5
            if s.sab >= 5: s.sab = 0; s.ssel = (s.ssel + 1) & 127
        elif (port & 0xFF) == 0x5B: s.spat[s.spp] = val; s.spp = (s.spp + 1) % len(s.spat)
        elif port == 0x243B: s.sel = val
        elif port == 0x253B: s.nreg_write(s.sel, val)
        elif (port & 0xFF) == 0xE3: s.divmmc = val
    def inp(s, port):
        if port == 0x253B: return s.nreg_read(s.sel)
        if (port & 0xFF) == 0xFE:
            hi = port >> 8; v = 0xFF
            for r in range(8):
                if not hi & (1 << r):
                    for rr, b, mod in (s.cur if isinstance(s.cur, list) else ([s.cur] if s.cur else [])):
                        if rr == r: v &= ~(1 << b)
                        if mod == 'caps' and r == 0: v &= ~1
                        if mod == 'sym' and r == 7: v &= ~2
            # ntc_plat_scankey's scan (Inkey ...) moves the typed text on once a scan (at half row 7);
            # any other read (the Keys class: one half row) moves on held keys ({n}) and pauses (~)
            # only - typed keys are for the scan, which a program's Keys calls mustn't hurry
            ks = s.syms.get('ntc_ks_line')
            inscan = ks is not None and ks <= s.m.pc < ks + 16
            typedkey = (s.phase == 1 and s.tkey) or (s.phase == 0 and s.typed and s.typed[0] not in '{~')
            if (inscan and hi == 0x7F) or (not inscan and not typedkey): s.tick()
            return v & 0xFF
        if (port & 0xFF) in (0x1F, 0x37): return 0
        return 0xFF
    def tick(s):
        s.scans += 1
        if s.phase == 2:            # {n*}: held until more is typed (the end's key: endkey_run types it)
            if s.typed and s.typed[0] == '~' and s.scans % 3 == 0: s.typed.pop(0); return   # (~ while held: the hold goes on a scan)
            if not s.typed or s.typed[0] == '~': return
            s.cur = None; s.phase = 0
        if s.phase == 0 and s.typed and s.scans % 3 == 0:
            c = s.typed.pop(0)
            if c == '{':
                n = ''
                while s.typed and s.typed[0] != '}': n += s.typed.pop(0)
                if s.typed: s.typed.pop(0)
                s.cur = [(int(k) // 8, int(k) % 8, None) for k in n.rstrip('*').split('+')]; s.tkey = False   # {a+b}: keys together (a chord)
                if n.endswith('*'): s.phase = 2; return        # {n*}: held from now on
            else:
                s.cur = None if c == '~' else KEYS[c]; s.tkey = (c != '~')
            s.phase = 1
        elif s.phase == 1 and s.scans % 3 == 0: s.cur = None; s.phase = 0; s.tkey = False
    def next_event(s):
        # T (in this frame, past tframe: may be past the frame's end) of the next interrupt: the
        # ULA's at each frame's start (NextReg #22 bit 2 turns it off), the line interrupt at its
        # line (#22 bit 1 on; the line: #22 bit 0, #23)
        ft = s.frame_t(); tl = ft // 312; evs = []
        r22 = s.regs.get(0x22, 0)
        if not r22 & 4: evs.append(ft)
        if r22 & 2:
            t = (((r22 & 1) << 8) | s.regs.get(0x23, 0)) * tl
            evs.append(t if t > s.tframe else t + ft)
        return min(evs) if evs else s.tframe + ft
    def run(s, limit=30000):
        import cpcrun
        n = 0; s.w0 = None
        while not s.m.halted and not s.reset:
            q = max(1, s.next_event() - s.tframe)
            s.stop = False; left = q
            while left > 0 and not (s.stop or s.m.halted or s.reset):   # (the module's own events may end a run early)
                if PROFT and PROFT[0] <= s.T + left and s.T < PROFT[1]:   # NTC_PROFT=a,b: the T spent at each PC from T a to b
                    pc = s.m.pc
                    if pc in PROFTLOG: print('--- at %s T %d line %d de=%04X' % (PROFTLOG[pc], s.T, s.line(), s.m.de))
                    s.q = 1; s.m.ticks_to_stop = 1; cpcrun.endkey_run(s); s.q = 0
                    d = 1 - s.m.ticks_to_stop; s.T += d; s.tframe += d; left -= d
                    if s.T >= PROFT[0]: PROFTC[pc] = PROFTC.get(pc, 0) + d
                    continue
                if TRACEZ is not None and s.T + left >= TRACEZ_AFTER:   # (NTC_TRACEZ_AFTER=T: fast until then)          # NTC_TRACEZ: an instruction at a time, the last ones kept (tracez)
                    s.q = 1; s.m.ticks_to_stop = 1; cpcrun.endkey_run(s); s.q = 0
                    d = 1 - s.m.ticks_to_stop; s.T += d; s.tframe += d; left -= d; s.tracez()
                    continue
                s.q = left; s.m.ticks_to_stop = left; cpcrun.endkey_run(s); s.q = 0
                d = (s.stopdone + 1) if s.stop else (left - s.m.ticks_to_stop)
                s.T += d; s.tframe += d; left -= d
            n += 1
            if LOGV and n % LOGV[0] == 0:       # NTC_LOGVARS=every,lab,lab: those words every so many chunks (6 a frame)
                mem = s.m.memory               # (the program's variables: in the mapped memory as it is)
                print('--- log T %d %s' % (s.T, ' '.join('%s=%d' % (nm[4:] if nm.startswith('var_') else nm, (lambda v: v - 65536 if v > 32767 else v)(mem[s.syms[nm]] | (mem[s.syms[nm] + 1] << 8))) for nm in LOGV[1:] if nm in s.syms)))
            if WATCH is not None:
                b = s.m.memory[WATCH]
                if s.w0 is None: s.w0 = b
                elif b != s.w0: print('--- watch %04X: %02X -> %02X by T %d pc=%04X' % (WATCH, s.w0, b, s.T, s.m.pc)); s.w0 = b
            if PROFZ is not None and not s.stop: PROFZ.append(s.m.pc)
            if s.m.halted or s.reset: break
            if s.stop:          # stopped early (an interrupt register written): no interrupt yet
                while s.tframe >= s.frame_t(): s.tframe -= s.frame_t()
                continue
            steps = 0; held = 0
            while not s.m.halted and not s.reset and steps < 4000:   # the interrupt held until taken (INTPULSE: for that long only)
                if s.m.iff1 and INTCHK and not (0xBE00 <= s.m.sp <= 0xC000):
                    print('--- intchk: interrupt taken with SP %04X (the thread?) at PC %04X, frame T %d' % (s.m.sp, s.m.pc, s.T)); s.reset = True; break
                if s.m.iff1 and s.m.on_handle_active_int(): s.ints += 1; break
                if INTPULSE and held >= INTPULSE << (s.regs.get(0x07, 0) & 3): s.missed += 1; break
                s.q = 1; s.m.ticks_to_stop = 1; cpcrun.endkey_run(s); steps += 1; d = 1 - s.m.ticks_to_stop; s.q = 0; s.T += d; s.tframe += d; held += d
            if TRACEZ is not None: s.tracez()
            while s.tframe >= s.frame_t(): s.tframe -= s.frame_t()
            if n > limit: print('TIMEOUT pc=%04x sp=%04x' % (s.m.pc, s.m.sp)); break
    def rgb9(s, g, i, v):
        # a palette entry as RGB: the blue's low bit from the second #44 write, else (an 8-bit
        # write) the OR of the two blue bits, as the Next does
        lo = getattr(s, 'blo', {}).get((g, i))
        if lo is None: lo = (v | (v >> 1)) & 1
        return (((v >> 5) & 7) * 255 // 7, ((v >> 2) & 7) * 255 // 7, (((v & 3) << 1) | lo) * 255 // 7)
    def layer2(s, path):
        # NTC_SHOT=file.png: the Layer 2 buffer shown (NextReg #12: 5 banks, 320 x 256 column by
        # column) through its palette (the first Layer 2 palette's writes; else index as grey), the
        # tilemap over it; the count: Layer 2's lit pixels that can be seen (0: Layer 2 off)
        for k in range(8): s.store(k)
        b = s.regs.get(0x12, 8)
        data = b''.join(bytes(s.page(p)) for p in range(2 * b, 2 * b + 10))
        from PIL import Image
        img = Image.new('RGB', (320, 256))
        px = img.load()
        pal = {}
        for i in range(256):
            v = s.palette.get((1, i))
            if v is None: pal[i] = (i, i, i)
            else: pal[i] = s.rgb9(1, i, v)
        # the tilemap over it (the order: the ULA and the tilemap over Layer 2), as the Next shows
        # it: in text mode (NextReg #6B bit 3) a pixel is see-through when its colour is the global
        # transparent colour (NextReg #14, #E3 at reset) - NextReg #4C's index is for 4-bit tiles
        over = [None] * (320 * 256)
        c6b = s.regs.get(0x6B, 0)
        if c6b & 0x80:
            b5 = s.bank5()
            mapo = (s.regs.get(0x6E, 0x6C) & 63) << 8; tilo = (s.regs.get(0x6F, 0x4C) & 63) << 8
            cols = 80 if c6b & 0x40 else 40; w = 320 // cols; text = c6b & 8; gt = s.regs.get(0x14, 0xE3)
            for r in range(32):
                for c in range(cols):
                    t = b5[mapo + r * cols + c]
                    for yy in range(8):
                        row = b5[tilo + t * 8 + yy]
                        for xx in range(w):
                            bit = (row >> (7 - xx * 8 // w)) & 1
                            v = s.palette.get((3, bit))
                            see = (v == gt) if text else (bit == (s.regs.get(0x4C, 0x0F) & 15))
                            if v is not None and not see: over[(c * w + xx) * 256 + r * 8 + yy] = v
        # the sprites (NextReg #15 bit 0), over Layer 2 and under the tilemap: 8-bit patterns,
        # x / y with their 9th bits, mirror X / Y, the palette offset, scaled 1/2/4/8 (the 5th byte)
        spr = {}
        if s.regs.get(0x15, 0) & 1:
            spal = {}
            for i in range(256):
                v = s.palette.get((2, i))
                spal[i] = None if v is None else s.rgb9(2, i, v)
            tr = s.regs.get(0x4B, 0xE3)
            for n in range(128):
                a = s.sattr[n]
                if not a[3] & 0x80: continue
                sx = a[0] | ((a[2] & 1) << 8); sy = a[1] | ((a[4] & 1) << 8 if a[3] & 0x40 else 0)
                pat = a[3] & 63; po = a[2] & 0xF0; mx = a[2] & 8; my = a[2] & 4
                kx = 1 << ((a[4] >> 3) & 3) if a[3] & 0x40 else 1; ky = 1 << ((a[4] >> 1) & 3) if a[3] & 0x40 else 1
                for py in range(16):
                    for pxx in range(16):
                        v = s.spat[pat * 256 + (15 - py if my else py) * 16 + (15 - pxx if mx else pxx)]
                        if v == tr: continue
                        c = spal.get((v + po) & 255) or (255, 0, 255)
                        for yy in range(ky):
                            for xx in range(kx):
                                X = sx + pxx * kx + xx; Y = sy + py * ky + yy
                                if 0 <= X < 320 and 0 <= Y < 256: spr[X * 256 + Y] = c
        scr = (s.regs.get(0x16, 0) | ((s.regs.get(0x71, 0) & 1) << 8)) % 320
        shown = 0
        for x in range(320):
            for y in range(256):
                o = over[x * 256 + y]
                if o is None and (x * 256 + y) in spr: px[x, y] = spr[x * 256 + y]
                elif o is None:
                    d = data[((x + scr) % 320) * 256 + y]
                    px[x, y] = pal[d]
                    if d: shown += 1
                else: px[x, y] = s.rgb9(3, 1, o)
        img.save(path)
        if not s.regs.get(0x69, 0) & 0x80: return 0
        return shown
    def bank5(s):
        for k in range(8): s.store(k)
        return s.page(10) + s.page(11)
    def screen(s):
        m = s.m; syms = s.syms
        font = {}
        if 'ntc_font' in syms:
            mem = bytes(m.memory); base = syms['ntc_font']
            for c in range(32, 127): font[bytes(mem[base + (c - 32) * 8:base + (c - 31) * 8])] = chr(c)
        c6b = s.regs.get(0x6B, 0)
        if not c6b & 0x80: return '(the tilemap is off)'
        b5 = s.bank5()
        mapo = (s.regs.get(0x6E, 0x6C) & 63) << 8; tilo = (s.regs.get(0x6F, 0x4C) & 63) << 8
        cols = 80 if c6b & 0x40 else 40
        out = []
        for r in range(32):
            line = ''
            for c in range(cols):
                t = b5[mapo + r * cols + c]
                line += font.get(bytes(b5[tilo + t * 8:tilo + t * 8 + 8]), '#')
            out.append(line.rstrip())
        while out and not out[-1]: out.pop()
        return '\n'.join(out)

def nex_name(asm):
    for line in open(asm):
        m = re.match(r'^\s+SAVENEX\s+OPEN\s+"([^"]+)"', line)
        if m: return os.path.join(os.path.dirname(os.path.abspath(asm)), m.group(1))
    return None

INTCHK = os.environ.get('NTC_INTCHK')           # NTC_INTCHK=1: stop when an interrupt would be taken with SP off the real stack (#BE00-#C000)
INTPULSE = int(os.environ.get('NTC_INTPULSE', '0'))   # NTC_INTPULSE=32: INT is a pulse of that many 3.5MHz T (the real Next: 32),
                                                        # not held - a program with interrupts off misses it (ints / missed at the end)
PROFZ = [] if os.environ.get('NTC_PROFZ') else None   # NTC_PROFZ=1: the PC at each interrupt, the busiest labels at the end
# NTC_TRACEZ=sp>c000: an instruction at a time (slow), the last 300 (PC, SP, AF, BC, DE, HL, IX, the MMU)
# kept; when the condition holds (sp>hex, sp<hex, pc=hex; spin=a-b: SP inside a-b; irq=a: PC at a
# with SP off the real stack; chg=a: the byte at a changed) they are printed and the run ends.
# NTC_TRACEZ_AFTER=T: run at full speed until T, then trace (a late bug found in minutes)
TRACEZ = os.environ.get('NTC_TRACEZ')
TRACEZ_AFTER = int(os.environ.get('NTC_TRACEZ_AFTER', '0'))
# NTC_PROFT=a,b: an instruction at a time from T a to b, the T spent at each label printed at the
# end - exact (NTC_PROFZ samples at interrupts only); also the instruction-accurate timing (the
# chunks between events are approximate around a pending line interrupt). NTC_PROFTLOG=lab,lab:
# a line (T, raster line, DE) each time one of those labels is reached in that stretch
PROFT = [int(x) for x in os.environ['NTC_PROFT'].split(',')] if os.environ.get('NTC_PROFT') else None
PROFTC = {}
PROFTLOG = {}
# NTC_WATCH=hex: the byte at that address: each change (old -> new, T, PC at the chunk's end)
LOGV = (lambda v: [int(v[0])] + v[1:])(os.environ['NTC_LOGVARS'].split(',')) if os.environ.get('NTC_LOGVARS') else None
WATCH = int(os.environ['NTC_WATCH'], 16) if os.environ.get('NTC_WATCH') else None
def tracez_init(z):
    import collections
    z.tzq = collections.deque(maxlen=300)
    if TRACEZ.startswith('chg='):      # chg=a: the byte at a changed
        k, v = 'cg', int(TRACEZ[4:], 16); z.tz0 = None
    elif TRACEZ.startswith('irq='):      # irq=a: PC at a with SP off the real stack (#BE00-#C000)
        k, v = 'ir', int(TRACEZ[4:], 16)
    elif TRACEZ.startswith('spin='):     # spin=a-b: SP inside that range (hex)
        lo, hi = (int(x, 16) for x in TRACEZ[5:].split('-')); k, v = 'si', 0
    else:
        k, v = TRACEZ[:2], int(TRACEZ[3:], 16)
    skip = [tuple(int(x, 16) for x in r.split('-')) for r in os.environ.get('NTC_TRACEZ_SKIP', '').split(',') if r]   # PC ranges left out (hex a-b,...)
    def hit():
        for a, b in skip:
            if a <= z.m.pc <= b: return False
        if k == 'cg':
            b = z.m.memory[v]
            if z.tz0 is None: z.tz0 = b
            return b != z.tz0
        if k == 'ir': return z.m.pc == v and not (0xBE00 <= z.m.sp <= 0xC000)
        if k == 'si': return lo <= z.m.sp <= hi
        if k == 'sp': return z.m.sp > v if TRACEZ[2] == '>' else z.m.sp < v
        if TRACEZ[2] == '>': return z.m.pc > v
        return z.m.pc == v
    def tracez():
        m = z.m
        z.tzq.append('%04X sp=%04X af=%04X bc=%04X de=%04X hl=%04X ix=%04X iff=%d mmu=%s' % (m.pc, m.sp, m.a << 8 | m.f, m.bc, m.de, m.hl, m.ix, m.iff1, ' '.join('%d' % p for p in z.mmu)))
        if hit():
            print('--- tracez %s:' % TRACEZ)
            for l in z.tzq: print(l)
            z.reset = True
    z.tracez = tracez

def run(asm, syms, typed):
    nex = nex_name(asm)
    z = Next(nex, typed, syms)
    for nm in os.environ.get('NTC_PROFTLOG', '').split(','):
        if nm in syms: PROFTLOG[syms[nm]] = nm
    if TRACEZ is not None: tracez_init(z)
    z.run(int(os.environ.get('NTC_LIMIT', '30000')))
    print(z.screen())
    if os.environ.get('NTC_SHOT'):
        print('--- layer 2: %d pixels set' % z.layer2(os.environ['NTC_SHOT']))
    if os.environ.get('NTC_ZXNREGS'):
        print('--- nextregs %s' % ' '.join('%02X=%02X' % (r, v) for r, v in sorted(z.regs.items())))
        print('--- mmu %s' % ' '.join(str(p) for p in z.mmu))
        print('--- palette %s' % ' '.join('%d/%d=%02X' % (k[0], k[1], v) for k, v in sorted(z.palette.items())))
    if PROFTC:
        import bisect, collections
        lab = sorted((v, k) for k, v in syms.items() if isinstance(v, int) and not k.startswith('var_') and not k.endswith('_end'))
        ad = [v for v, k in lab]; c = collections.Counter()
        for pc, n in PROFTC.items():
            i = bisect.bisect_right(ad, pc) - 1
            c[lab[i][1] if i >= 0 else '?'] += n
        tot = sum(c.values())
        for k, n in c.most_common(40): print('--- proft %5.1f%% %8d %s' % (100.0 * n / tot, n, k))
    if PROFZ:
        import bisect, collections
        lab = sorted((v, k) for k, v in syms.items() if isinstance(v, int) and not k.startswith('var_') and not k.endswith('_end'))
        ad = [v for v, k in lab]; c = collections.Counter()
        for pc in PROFZ:
            i = bisect.bisect_right(ad, pc) - 1
            c[lab[i][1] if i >= 0 else '?'] += 1
        for k, n in c.most_common(int(os.environ.get('NTC_PROFZ_N', '20'))): print('--- prof %5.1f%% %s' % (100.0 * n / len(PROFZ), k))
    if os.environ.get('NTC_PEEK'):          # NTC_PEEK=w_nl,w_cull: words at labels ending so (a class's #asm labels are prefixed)
        for k in range(8): z.store(k)
        mem = bytes(z.m.memory)
        for nm in os.environ['NTC_PEEK'].split(','):
            ks = [k for k in syms if k == nm or k.endswith('_' + nm)]
            for k in ks[:1]: print('--- peek %s = %d' % (nm, mem[syms[k]] | (mem[syms[k] + 1] << 8)))
    print('--- halted (a soft reset: NextReg 2)' if z.reset else ('--- halted' if z.m.halted else '--- NOT halted'), 'pc=%04x' % z.m.pc, 'sp=%04x' % z.m.sp, 'ints=%d' % z.ints, 'missed=%d' % z.missed, 'T=%d' % z.T)
    return z
