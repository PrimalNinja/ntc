# msxrun.py - the msxdos platform's harness: an MSX2 under MSX-DOS 2 / Nextor, as far as an NTC
# program (and CyborgOS's MSX hypervisor) sees it. ntcrun.py's CP/M host does the BDOS (the
# console, FCB files: MSX-DOS 2 is CP/M underneath); on top of it:
#   - the memory mapper: NTC_RAM K of 16K segments (default 576: a 512K mapper as a GR8NET's and
#     the machine's own 64K), ports #FC - #FF the segments in pages 0 - 3; the program starts in
#     segments 3, 2, 1, 0 (pages 0 - 3), as MSX-DOS 2 sets them. A segment in two pages at once
#     isn't modelled (each page has its own 16K here)
#   - MSX-DOS 2's mapper support: HOKVLD (#FB20) bit 0, EXTBIO (#FFCA) D = 4, E = 2 gives the
#     jump table (#F300: ALL_SEG, FRE_SEG ... PUT_P3, GET_P3 - stand-ins on ports #C0 - #CF);
#     ALL_SEG gives the lowest free segment from 4 up (0 - 3 are the TPA's, DOS 2's own are left
#     out); user segments are the program's
#   - the frame interrupt: every 71590 T (3.58 MHz / 50), #0038 in the DOS's page 0 (segment 3):
#     JIFFY (#FC9E) up, H.TIMI (#FD9F) called with every register kept, as the BIOS does
#   - the VDP (V9938) on #98 / #99: VRAM 128K, its registers (R#14 the high address bits), status
#     0; TEXT 2's characters read from the name table (R#2) for the screen's text when the program
#     set the VDP up (else the BDOS console's text, as ntcrun's CP/M); R#23's vertical scroll (the
#     name table a ring of 32 rows, CyborgOS's console)
#   - MSX-DOS 2's handle calls (#43 open, #44 create, #45 close, #48 read, #49 write, #4A seek,
#     #4D delete, #4E rename, #40 / #41 the search, #1B the free space, #5A chdir) on the files
#     folder (NTC_FILES: every drive letter is it; "\" a sub folder)
#   - RDSLT (#000C): the main ROM's CGTABL (#0004) points at a stand-in font (zeros); EXPTBL 0;
#     CALSLT (#001C) INITXT: the screen the BIOS's again (the text read from the BDOS console);
#     the main ROM's font (RDSLT from CGTABL) is NTC's ntc_font6
#   - NTC_V9990=1: a V9990 (GFX9000) at #60-#6F (v9990.py); the screen's text read off its picture
#     while it is on
#   - the keyboard's PPI (#AA the row, #A9 the keys): {n} in the typed text holds key n (row * 8 +
#     bit), {n,m} two together - {49,58} CTRL + ESC
# python3 msxrun.py prog.bas 'typed' [more .bas / .cls] [--ram=K] - or a .COM made already (run as it is)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ntcrun, cpcrun, v9990

FRAME = 71590
MTAB = 0xF300          # the mapper support jump table (16 entries, 3 bytes each)
NAMES = ['ALL_SEG', 'FRE_SEG', 'RD_SEG', 'WR_SEG', 'CAL_SEG', 'CALLS', 'PUT_PH', 'GET_PH',
         'PUT_P0', 'GET_P0', 'PUT_P1', 'GET_P1', 'PUT_P2', 'GET_P2', 'PUT_P3', 'GET_P3']

class Mapper:
    def __init__(s, m, kb):
        s.m = m; s.n = max(4, kb // 16); s.seg = [bytearray(0x4000) for _ in range(s.n)]
        s.view = [3, 2, 1, 0]; s.used = set([0, 1, 2, 3]); s.writes = 0
    def set(s, page, seg):
        s.writes += 1
        seg %= s.n
        if s.view[page] == seg: return
        mem = s.m.memory
        s.seg[s.view[page]][:] = bytes(mem[page * 0x4000:(page + 1) * 0x4000])
        s.m.set_memory_block(page * 0x4000, bytes(s.seg[seg]))
        s.view[page] = seg
    def segment(s, n):
        # segment n as it is now (in a page, or kept)
        for p in range(4):
            if s.view[p] == n: return bytes(s.m.memory[p * 0x4000:(p + 1) * 0x4000])
        return bytes(s.seg[n])

class MsxDos(ntcrun.Host):
    def __init__(s, binary, org, typed, kb=None):
        ntcrun.CPMVER = 0x22                    # MSX-DOS: BDOS 12 gives 2.2
        ntcrun.Host.__init__(s, 'cpm', binary, org, typed)
        m = s.m
        s.map = Mapper(m, int(kb or os.environ.get('NTC_RAM', '576')))
        s.vram = bytearray(0x20000); s.vreg = [0] * 64; s.vlatch = None; s.vaddr = 0; s.vset = False
        # #0038 (the DOS's page 0): every register kept, JIFFY up, H.TIMI called, ei, ret
        isr = [0xF5, 0xC5, 0xD5, 0xE5, 0xDD, 0xE5, 0xFD, 0xE5, 0x08, 0xD9, 0xF5, 0xC5, 0xD5, 0xE5,
               0x2A, 0x9E, 0xFC, 0x23, 0x22, 0x9E, 0xFC,          # ld hl, (JIFFY) : inc hl : ld (JIFFY), hl
               0xCD, 0x9F, 0xFD,                                  # call H.TIMI
               0xE1, 0xD1, 0xC1, 0xF1, 0xD9, 0x08, 0xFD, 0xE1, 0xDD, 0xE1, 0xE1, 0xD1, 0xC1, 0xF1, 0xFB, 0xC9]
        m.set_memory_block(0x38, bytes(isr))
        m.set_memory_block(0xFD9F, bytes([0xC9] * 5))         # H.TIMI: nothing
        m.set_memory_block(0xFC9E, bytes([0, 0]))             # JIFFY
        m.set_memory_block(0xFB20, bytes([1]))                # HOKVLD: EXTBIO is there
        m.set_memory_block(0xFFCA, bytes([0xD3, 0xE6, 0xC9]))  # EXTBIO: out (#E6), a : ret
        for i in range(16):
            m.set_memory_block(MTAB + i * 3, bytes([0xD3, 0xC0 + i, 0xC9]))
        m.set_memory_block(0x0C, bytes([0xD3, 0xE7, 0xC9]))    # RDSLT: out (#E7), a : ret
        m.set_memory_block(0x1C, bytes([0xD3, 0xE8, 0xC9]))    # CALSLT: out (#E8), a : ret (INITXT: the BDOS console again)
        m.set_memory_block(0xFCC1, bytes([0]))                # EXPTBL
        m.set_memory_block(0xFFE8, bytes([0x02]))             # RG9SAV: PAL (50 Hz)
        s.ppi = 0; s.hand = {}; s.srch = {}
        s.v99 = v9990.V9990() if os.environ.get('NTC_V9990') else None   # NTC_V9990=1: a GFX9000 at #60
        s.font = v9990.font6()
        m.set_output_callback(s.out2); m.set_input_callback(s.inp2)
    # ports
    def out2(s, port, val):
        lo = port & 0xFF; m = s.m
        if 0xFC <= lo <= 0xFF:
            s.map.set(lo - 0xFC, val); return
        if lo == 0x98:
            s.vram[s.vaddr & 0x1FFFF] = val; s.vaddr = (s.vaddr + 1) & 0x1FFFF; return
        if lo == 0x99:
            if s.vlatch is None: s.vlatch = val; return
            lo8 = s.vlatch; s.vlatch = None
            if val & 0x80:
                s.vreg[val & 0x3F] = lo8; s.vset = True
            else:
                s.vaddr = ((s.vreg[14] & 7) << 14) | ((val & 0x3F) << 8) | lo8
            return
        if lo == 0xE6 and m.pc == 0xFFCC:
            if m.d == 4 and m.e == 2:                       # mapper support: the table
                m.a = s.map.n; m.b = 0; m.c = s.map.n - len(s.map.used); m.hl = MTAB
            return
        if lo == 0xE7 and m.pc == 0x0E:                     # RDSLT: the ROM's byte at HL
            # CGTABL (#0004) = #1C00: the font there is NTC's ntc_font6 (characters 32-126)
            a = m.hl
            if a in (4, 5): m.a = {4: 0x00, 5: 0x1C}[a]
            elif 0x1C00 + 32 * 8 <= a < 0x1C00 + 127 * 8: m.a = s.font[a - 0x1C00 - 32 * 8]
            else: m.a = 0
            return
        if s.v99 is not None and 0x60 <= lo <= 0x6F: s.v99.out(lo - 0x60, val); return
        if lo == 0xE8 and m.pc == 0x1E:
            if m.ix == 0x006C: s.vset = False                 # INITXT: the BIOS's screen (the console's text)
            return
        if lo == 0xAA: s.ppi = val; return
        if lo == 0xE5 and m.c in (0x19, 0x1B, 0x40, 0x41, 0x43, 0x44, 0x45, 0x48, 0x49, 0x4A, 0x4D, 0x4E, 0x5A):
            s.dos2(m.c); return
        if 0xC0 <= lo <= 0xCF and m.pc == MTAB + (lo - 0xC0) * 3 + 2:
            s.mapcall(NAMES[lo - 0xC0]); return
        return ntcrun.Host.out(s, port, val)
    def inp2(s, port):
        lo = port & 0xFF
        if lo == 0x98:
            v = s.vram[s.vaddr & 0x1FFFF]; s.vaddr = (s.vaddr + 1) & 0x1FFFF; return v
        if lo == 0x99:
            s.vlatch = None; return 0
        if 0xFC <= lo <= 0xFF: return s.map.view[lo - 0xFC] | 0xC0 if s.map.n <= 64 else s.map.view[lo - 0xFC]
        if lo == 0xAA: return s.ppi
        if s.v99 is not None and 0x60 <= lo <= 0x6F: return s.v99.inp(lo - 0x60)
        if lo == 0xA9:
            # the keyboard matrix: {n} in the typed text holds key n (row * 8 + bit: 49 CTRL, 58 ESC,
            # 0 - 9 the digits 0 - 7 then row 1's 8, 9) for 12 scans of row 6 and 2 frames; {n,m} together
            v = 0xFF; h = getattr(s, 'held', None); row = s.ppi & 15
            if h is not None:
                for hk in h:
                    if row == hk // 8: v &= ~(1 << (hk % 8))
            if row == 6:
                s.hscans = getattr(s, 'hscans', 0) + 1
                if h is not None and s.hscans >= 12 and s.T - getattr(s, 'hstart', 0) >= 2 * FRAME: s.held = None
                elif h is None and s.typed and s.typed[0] == '{':
                    s.typed.pop(0); n = ''
                    while s.typed and s.typed[0] != '}': n += s.typed.pop(0)
                    if s.typed: s.typed.pop(0)
                    s.held = [int(x) for x in n.split(',')]; s.hstart = s.T; s.hscans = 0
            return v & 0xFF
        return ntcrun.Host.inp(s, port)
    def mapcall(s, f):
        m = s.m; mp = s.map
        if f == 'ALL_SEG':
            for n in range(4, mp.n):
                if n not in mp.used:
                    mp.used.add(n); m.a = n; m.b = 0; m.f = m.f & 0xFE; return
            m.f = m.f | 1
        elif f == 'FRE_SEG':
            mp.used.discard(m.a); m.f = m.f & 0xFE
        elif f.startswith('PUT_P'):
            mp.set(int(f[5]), m.a)
        elif f.startswith('GET_P'):
            m.a = mp.view[int(f[5])]
        else:
            print('msxrun: %s not modelled' % f)
    # MSX-DOS 2's handle calls, on the files folder
    def zstr(s, a):
        b = bytearray(); mem = s.m.memory
        while mem[a & 0xFFFF] and len(b) < 128: b.append(mem[a & 0xFFFF]); a += 1
        return b.decode('latin1')
    def hpath(s, name):
        n = name.split(':', 1)[1] if ':' in name[:2] else name
        parts = [x.rstrip('.') if x not in ('.', '..') else x for x in n.replace('\\', '/').split('/') if x]
        d = ntcrun.FILES
        for i, x in enumerate(parts):
            hit = [f for f in os.listdir(d) if f.upper() == x.upper()] if os.path.isdir(d) else []
            d = os.path.join(d, hit[0] if hit else x)
        return d
    def dos2(s, fn):
        m = s.m; mem = m.memory
        if os.environ.get('MSX_DOSLOG'):
            print('dos2 #%02X de=%04X(%s) b=%02X hl=%04X a=%02X' % (fn, m.de, s.zstr(m.de)[:30] if fn in (0x40, 0x43, 0x44, 0x4D, 0x4E, 0x5A) else '', m.b, m.hl, m.a), file=sys.stderr)
        def err(e): m.a = e; return
        if fn == 0x19:
            m.a = 0; m.l = 0; return
        if fn == 0x1B:
            m.a = 4; m.hl = 1000; m.de = 2000; m.bc = 512; return
        if fn == 0x43 or fn == 0x44:
            p = s.hpath(s.zstr(m.de))
            if fn == 0x44 and (m.b & 0x10):
                if os.path.exists(p): return err(0xCB)
                os.makedirs(p); m.a = 0; return
            if fn == 0x43 and not os.path.isfile(p): return err(0xD7)
            if fn == 0x44: open(p, 'wb').close()
            h = 5
            while h in s.hand: h += 1
            s.hand[h] = [p, bytearray(open(p, 'rb').read()), 0, fn == 0x44 or not (m.a & 1)]
            m.b = h; m.a = 0; return
        if fn in (0x45, 0x48, 0x49, 0x4A):
            hd = s.hand.get(m.b)
            if hd is None: return err(0xE5)
            if fn == 0x45:
                if hd[3]: open(hd[0], 'wb').write(hd[1])
                del s.hand[m.b]; m.a = 0; return
            if fn == 0x4A:
                off = (m.de << 16) | m.hl
                hd[2] = off if m.a == 0 else (hd[2] + off if m.a == 1 else len(hd[1]) + off)
                m.a = 0; return
            n = m.hl
            if fn == 0x48:
                if hd[2] >= len(hd[1]): m.hl = 0; return err(0xC7)
                blk = hd[1][hd[2]:hd[2] + n]
                for i, b in enumerate(blk): mem[(m.de + i) & 0xFFFF] = b
                hd[2] += len(blk); m.hl = len(blk); m.a = 0; return
            data = bytes(mem[(m.de + i) & 0xFFFF] for i in range(n))
            if len(hd[1]) < hd[2]: hd[1] += bytes(hd[2] - len(hd[1]))
            hd[1][hd[2]:hd[2] + n] = data; hd[2] += n; m.a = 0; return
        if fn == 0x4D:
            p = s.hpath(s.zstr(m.de))
            if os.path.isdir(p):
                try: os.rmdir(p)
                except OSError: return err(0xCA)
            elif os.path.isfile(p): os.remove(p)
            else: return err(0xD7)
            m.a = 0; return
        if fn == 0x4E:
            p = s.hpath(s.zstr(m.de)); q = os.path.join(os.path.dirname(p), s.zstr(m.hl))
            if not os.path.exists(p): return err(0xD7)
            os.rename(p, q); m.a = 0; return
        if fn == 0x5A:
            m.a = 0 if os.path.isdir(s.hpath(s.zstr(m.de))) else 0xD6; return
        if fn == 0x40:
            import fnmatch
            pat = s.zstr(m.de)
            p = s.hpath(pat)
            d, f = os.path.split(p)
            if os.path.isdir(p) and not any(c in pat for c in '*?'):
                d, f = os.path.dirname(p), os.path.basename(p)
            if not os.path.isdir(d): return err(0xD6)          # .NODIR
            hits = []
            for x in sorted(os.listdir(d)):
                full = os.path.join(d, x)
                if os.path.isdir(full) and not (m.b & 0x10): continue
                if fnmatch.fnmatch(x.upper(), f.upper()) or (f == '*.*' and '.' not in x): hits.append(full)
            s.srch[m.ix] = hits
            fn = 0x41
        if fn == 0x41:
            hits = s.srch.get(m.ix, [])
            if not hits: return err(0xD7)
            full = hits.pop(0); ix = m.ix
            fib = bytearray(64); fib[0] = 0xFF
            nm = os.path.basename(full).upper().encode()[:12]
            fib[1:1 + len(nm)] = nm
            fib[14] = 0x10 if os.path.isdir(full) else 0
            sz = 0 if os.path.isdir(full) else os.path.getsize(full)
            fib[21:25] = sz.to_bytes(4, 'little'); fib[25] = 1
            for i in range(64): mem[(ix + i) & 0xFFFF] = fib[i]
            m.a = 0; return
    def text(s):
        # the V9990's picture when it is on (its text read off it: ntc_font6), else TEXT 2's name
        # table (R#2) when the program set the VDP up, else the console's
        if s.v99 is not None and s.v99.shown(): return s.v99.ocr()
        if not s.vset: return s.scr.text()
        base = ((s.vreg[2] & 0x7C) << 10); cols = 80 if (s.vreg[1] & 0x10) and (s.vreg[0] & 0x04) else 40
        rows = 26 if (s.vreg[9] & 0x80) else 24
        top = s.vreg[23] // 8
        def row(r):
            a = base + ((r + top) & 31) * cols
            return ''.join(chr(b) if 32 <= b < 127 else ' ' for b in s.vram[a:a + cols]).rstrip()
        out = [row(r) for r in range(rows)]
        while out and not out[-1]: out.pop()
        return '\n'.join(out)
    def run(s, limit=30000):
        # a frame's T, then the frame interrupt (taken when interrupts are on - a HALT with them on
        # waits for it, as Frame does); a HALT with them off is the end (warm boot at #0000)
        n = 0
        m = s.m
        while True:
            if not m.halted:
                m.ticks_to_stop = FRAME; cpcrun.endkey_run(s); s.T += FRAME - m.ticks_to_stop
            if m.halted and (not m.iff1 or m.pc == 1): break   # (#0000: the warm boot - the end)
            n += 1
            steps = 0
            while steps < 4000:
                if m.iff1 and m.on_handle_active_int(): s.ints += 1; break
                if m.halted and m.pc == 1: break
                m.ticks_to_stop = 1; cpcrun.endkey_run(s); steps += 1; s.T += 1 - m.ticks_to_stop
            if m.halted and (not m.iff1 or m.pc == 1): break
            if n > limit: print('TIMEOUT pc=%04x sp=%04x' % (m.pc, m.sp)); break

def main():
    import subprocess
    args = sys.argv[1:]; cmdline = ''
    for a in list(args):
        if a.startswith('--ram='): os.environ['NTC_RAM'] = a[6:]; args.remove(a)
        if a.startswith('--cmdline='): cmdline = a[10:]; args.remove(a)
    bas = args[0]; typed = (args[1] if len(args) > 1 else '').replace('\\n', '\r')
    extra = args[2:]; asm = bas[:-4] + '.asm'
    if bas.upper().endswith('.COM'):
        # a .COM already made (CyborgOS's CYBORGOS.COM): run as it is, from #0100
        b = open(bas, 'rb').read(); syms = {'ntc_start': 0x100}
    else:
        r = subprocess.run(['node', os.path.join(HERE, 'cli.js'), bas, '--platform=msxdos'] + extra, capture_output=True, text=True)
        if r.stderr: print(r.stderr)
        open(asm, 'w').write(r.stdout)
        b, syms = cpcrun.assemble(asm)
    h = MsxDos(b, syms.get('ntc_start', 0x100), typed)
    cpcrun.endkey_set(h.m, syms)
    tail = (' ' + cmdline.upper()).encode() if cmdline else b''
    h.m.set_memory_block(0x80, bytes([len(tail)]) + tail + b'\0')
    h.run(int(os.environ.get('NTC_LIMIT', '3000')))
    print(h.text())
    if os.environ.get('MSX_BOTH') and not h.vset:
        h.vset = True; print('--- the VDP screen:'); print(h.text())
    print('--- halted' if h.m.halted else '--- NOT halted', 'pc=%04x' % h.m.pc, 'sp=%04x' % h.m.sp, 'ints=%d' % h.ints, 'T=%d' % h.T, 'segments', h.map.view)

if __name__ == '__main__':
    main()
