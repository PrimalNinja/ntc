# dotrun.py - a ZX Spectrum Next running NextZXOS, for the dot command platforms' tests (zxndot,
# zxndotl; scratch test tool, not delivered). ntcrun.py --platform=zxndot / zxndotl uses it: the
# NAME.DOT the assembly wrote is loaded as NextZXOS loads a dot command and run on zxnrun's Next
# (the MMU, the NextRegs, the ULA frame interrupt) with a stand-in for what the command sees of
# NextZXOS and the 48K ROM:
#   - slots at entry: 0 = the esxDOS ROM (a stand-in page: rst 8 / rst #10 / rst #18 trap to the
#     harness through ports, the IM 1 handler at #0038 bumps FRAMES and gives the typed keys as
#     LAST_K - the program's own IM 2 handler runs while its memory is in the slots), 1 = DivMMC's RAM page holding the dot command's first 8K, 2-7 = BASIC's pages 10,
#     11 (bank 5: the system variables), 4, 5 (bank 2), 0, 1 (bank 0: the stack at #FF40)
#   - entry as NextZXOS does it: PC #2000, HL = the arguments (--cmdline=, 0 when none; the line
#     is put in BASIC's E_LINE area), BC = the whole line, SP = BASIC's, the return address a
#     halt in bank 0 - reaching it ends the run; the carry flag then is the result (0 OK / error)
#   - esxDOS hooks: M_GETHANDLE (the file open after its first 8K), F_READ from it, F_CLOSE,
#     M_GETSETDRV, M_P3DOS with IDE_BANK (allocate / free 8K pages: the free pool is pages 16 on,
#     from the top down, as NextZXOS's; a page freed twice or never allocated is an error)
#   - the ROM's print (rst #10): a 32 x 24 text screen (NTC_DOTCOLS=n: n columns, as BASIC in a
#     wider layer mode): 13 new line, 22 AT row column, 8 back, scrolling at the bottom; rst #18: CLS (#0D6B) clears it, CHAN-OPEN (#1601) does nothing
#   - keys: typed text, one key a frame interrupt when the program has taken the last (FLAGS bit
#     5): \n = Enter (13), \x7f = Delete (12 - the ROM's code), ~ = a frame with no key
#   At the end: the screen's text, whether the exit was clean (slots 2-7 and SP as at entry,
#   every allocated page freed), and the usual --- halted line.
import os, sys
import z80
import zxnrun

HERE = os.path.dirname(os.path.abspath(__file__))
ROMPG = 254     # the stand-in esxDOS ROM's page id (slot 0)
DOTPG = 253     # DivMMC's RAM page: the dot command (slot 1)
BASIC_SLOTS = [10, 11, 4, 5, 0, 1]      # banks 5, 2, 0 in slots 2-7
BASIC_SP = 0xFF40
RET_AT = 0xFF50                         # halt: the return to BASIC
ELINE = 0x5D00                          # where the command line is put (BASIC's workspace)
FIRST_FREE = 16                         # the allocator's pool: pages 16-223, from the top down

class ZxScreen:
    def __init__(s, cols=32, rows=24):
        s.cols = cols; s.rows = rows; s.cells = [[' '] * cols for _ in range(rows)]; s.x = 0; s.y = 0; s.pend = []
    def put(s, c):
        if s.pend:
            s.pend.append(c)
            if len(s.pend) == 3:
                s.y = min(s.rows - 1, s.pend[1]); s.x = min(s.cols - 1, s.pend[2]); s.pend = []
            return
        if c == 22: s.pend = [22]; return
        if c == 13: s.x = 0; s.y += 1
        elif c == 8:
            if s.x > 0: s.x -= 1
            elif s.y > 0: s.y -= 1; s.x = s.cols - 1
        elif 32 <= c < 128:
            s.cells[s.y][s.x] = chr(c); s.x += 1
            if s.x >= s.cols: s.x = 0; s.y += 1
        if s.y >= s.rows:
            s.cells.pop(0); s.cells.append([' '] * s.cols); s.y = s.rows - 1
    def clear(s):
        s.cells = [[' '] * s.cols for _ in range(s.rows)]; s.x = 0; s.y = 0
    def text(s):
        out = [''.join(r).rstrip() for r in s.cells]
        while out and not out[-1]: out.pop()
        return '\n'.join(out)

class DotNext(zxnrun.Next):
    def __init__(s, dotpath, typed, syms, cmdline):
        d = open(dotpath, 'rb').read()
        s.file = d; s.filepos = 0x2000; s.handle = 3; s.closed = False
        s.pages = {}
        rom = bytearray(0x2000)
        rom[0x0008:0x000B] = bytes([0xD3, 0xE7, 0xC9])          # rst 8: out (#E7), a / ret (the hook byte after the call: skipped by the harness)
        rom[0x0010:0x0013] = bytes([0xD3, 0xE6, 0xC9])          # rst #10: out (#E6), a / ret
        rom[0x0018:0x001B] = bytes([0xD3, 0xE9, 0xC9])          # rst #18: out (#E9), a / ret (the dw after it: skipped)
        rom[0x0038:0x003F] = bytes([0xF5, 0xD3, 0xEA, 0xF1, 0xFB, 0xED, 0x4D])   # IM 1: push af / out (#EA), a / pop af / ei / reti
        s.pages[ROMPG] = rom
        s.pages[DOTPG] = bytearray(d[:0x2000]) + bytearray(0x2000 - min(0x2000, len(d)))
        for p in BASIC_SLOTS: s.pages[p] = bytearray(0x2000)
        s.pages[1][RET_AT - 0xE000] = 0x76                      # halt: back in BASIC
        s.pages[1][BASIC_SP - 0xE000] = RET_AT & 255; s.pages[1][BASIC_SP - 0xE000 + 1] = RET_AT >> 8
        line = ('.main ' + cmdline).encode() if cmdline else b'.main'
        s.pages[10][ELINE - 0x4000:ELINE - 0x4000 + len(line) + 1] = line + b'\r'
        s.m = m = z80.Z80Machine()
        s.mmu = [None] * 8
        for k, p in enumerate([ROMPG, DOTPG] + BASIC_SLOTS): s.map(k, p)
        m.pc = 0x2000; m.sp = BASIC_SP; m.iy = 0x5C3A; m.i = 0x3F
        m.hl = (ELINE + 6) if cmdline else 0
        m.bc = ELINE + 1
        m.iff1 = True; m.iff2 = True
        s.regs = {0x07: 0, 0x06: 0x18, 0x0A: 0x10}
        s.sel = 0; s.reset = False; s.typed = list(typed); s.syms = syms
        s.q = 0; s.stop = False; s.cur = None; s.phase = 0; s.tkey = False; s.scans = 0; s.ints = 0; s.missed = 0; s.T = 0; s.tframe = 0; s.palette = {}
        s.palidx = 0
        s.spat = bytearray(64 * 256); s.sattr = [[0] * 5 for _ in range(128)]; s.ssel = 0; s.sab = 0; s.spp = 0
        s.scr = ZxScreen(int(os.environ.get('NTC_DOTCOLS', '32')))      # NTC_DOTCOLS=80: BASIC in an 80-column layer mode (the shared reference outputs)
        s.alloc = []; s.allocs = 0; s.frees = 0; s.badfree = 0; s.nextpage = 223; s.keywait = 0
        s.hooks = []
        m.set_output_callback(s.out); m.set_input_callback(s.inp)
        import cpcrun
        cpcrun.endkey_set(m, syms)
    def page(s, p):
        if p == 255: return bytearray(b'\xff' * 0x2000)
        if p not in s.pages: s.pages[p] = bytearray(0x2000)
        return s.pages[p]
    # a byte of BASIC's bank 5 (page 10): through the live memory when it is in slot 2
    def sv_rd(s, a):
        if s.mmu[2] == 10: return s.m.memory[a]
        return s.pages[10][a - 0x4000]
    def sv_wr(s, a, v):
        if s.mmu[2] == 10: s.m.set_memory_block(a, bytes([v]))
        else: s.pages[10][a - 0x4000] = v
    def skip_ret(s, n):
        # the bytes after the rst's return address: read, and the return address moved past them
        sp = s.m.sp; ra = s.m.memory[sp] | (s.m.memory[sp + 1] << 8)
        b = bytes(s.m.memory[ra:ra + n]); ra += n
        s.m.set_memory_block(sp, bytes([ra & 255, ra >> 8]))
        return b
    def carry(s, on):
        s.m.f = (s.m.f | 1) if on else (s.m.f & 0xFE)
    def out(s, port, val):
        lo = port & 0xFF; m = s.m
        if lo == 0xE6:              # rst #10
            s.scr.put(val); return
        if lo == 0xE9:              # rst #18, dw routine
            b = s.skip_ret(2); ad = b[0] | (b[1] << 8)
            if ad == 0x0D6B: s.scr.clear()
            elif ad == 0x1601: pass
            else: print('--- rst #18 to %04X: not emulated' % ad)
            return
        if lo == 0xEA:              # the frame interrupt: FRAMES, a typed key into LAST_K
            fr = s.sv_rd(0x5C78) | (s.sv_rd(0x5C79) << 8); fr = (fr + 1) & 0xFFFF
            s.sv_wr(0x5C78, fr & 255); s.sv_wr(0x5C79, fr >> 8)
            fl = s.sv_rd(0x5C3B)
            if s.typed and not (fl & 0x20):
                s.keywait += 1
                if s.keywait >= 2:
                    s.keywait = 0
                    c = s.typed.pop(0)
                    if c != '~':
                        code = {'\r': 13, '\n': 13, '\x7f': 12}.get(c, ord(c))
                        s.sv_wr(0x5C08, code & 255); s.sv_wr(0x5C3B, fl | 0x20)
            return
        if lo == 0xE7:              # rst 8, db hook
            hook = s.skip_ret(1)[0]; s.hooks.append(hook)
            if hook == 0x8D:        # M_GETHANDLE
                m.a = s.handle; s.carry(False)
            elif hook == 0x9D:      # F_READ: A = handle, HL = where, BC = count
                if m.a != s.handle or s.closed: m.a = 9; s.carry(True); return
                n = min(m.bc, len(s.file) - s.filepos)
                if n > 0: m.set_memory_block(m.hl, bytes(s.file[s.filepos:s.filepos + n]))
                s.filepos += n; m.bc = n; m.de = n; m.hl = (m.hl + n) & 0xFFFF; s.carry(False)
            elif hook == 0x9B:      # F_CLOSE
                if m.a == s.handle: s.closed = True
                m.a = 0; s.carry(False)
            elif hook == 0x89:      # M_GETSETDRV
                m.a = (2 << 3) | 1; s.carry(False)     # C:
            elif hook == 0x94:      # M_P3DOS: DE = the call, C = the bank, the call's registers in the alternate set
                if m.de == 0x01BD:  # IDE_BANK: H' = 0 (ZX 8K pages), L' = 1 allocate / 3 free (E')
                    if m.c != 7: print('--- IDE_BANK with C = %d (7 expected)' % m.c)
                    if m.alt_h != 0: m.a = 0x15; s.carry(False); return
                    if m.alt_l == 1:
                        if s.nextpage < FIRST_FREE: m.a = 0x2A; s.carry(False); return   # rc_inuse: none
                        s.alloc.append(s.nextpage); m.e = s.nextpage; s.nextpage -= 1; s.allocs += 1; s.carry(True)
                    elif m.alt_l == 3:
                        if m.alt_e in s.alloc: s.alloc.remove(m.alt_e); s.frees += 1; s.carry(True)
                        else: s.badfree += 1; m.a = 0x15; s.carry(False)
                    elif m.alt_l == 0: m.e = 224; s.carry(True)
                    elif m.alt_l == 4: m.e = s.nextpage - FIRST_FREE + 1; s.carry(True)
                    else: m.a = 0x15; s.carry(False)
                else:
                    print('--- M_P3DOS call %04X: not emulated' % m.de); m.a = 0x15; s.carry(False)
            else:
                print('--- esxDOS hook %02X: not emulated' % hook); m.a = 0x15; s.carry(True)
            return
        zxnrun.Next.out(s, port, val)
    def inp(s, port):
        if (port & 0xFF) == 0xFE: return 0xFF       # (the keyboard matrix: nothing held - keys come through the ROM's LAST_K here)
        return zxnrun.Next.inp(s, port)
    def exit_report(s):
        ok = []
        if s.m.pc != RET_AT + 1 and s.m.pc != RET_AT: ok.append('not back in BASIC (pc=%04X)' % s.m.pc)
        if s.mmu[2:8] != BASIC_SLOTS: ok.append('slots 2-7 not BASIC\'s: %s' % s.mmu[2:8])
        if s.m.sp != BASIC_SP + 2: ok.append('SP %04X (BASIC\'s %04X expected)' % (s.m.sp, BASIC_SP + 2))
        if s.alloc: ok.append('%d page(s) still allocated: %s' % (len(s.alloc), s.alloc))
        if s.badfree: ok.append('%d bad free(s)' % s.badfree)
        if not s.m.iff1: ok.append('interrupts off')
        if s.m.i != 0x3F: ok.append('I register %02X (BASIC\'s #3F expected)' % s.m.i)
        res = 'error (carry set, A=%d)' % s.m.a if s.m.f & 1 else '0 OK'
        if (s.m.f & 1) and s.m.a == 0:
            msg = ''; a = s.m.hl
            while len(msg) < 80:
                b = s.m.memory[a]; msg += chr(b & 0x7F); a += 1
                if b & 0x80: break
            res += ' "%s"' % msg
        return '--- exit: %s, pages allocated %d freed %d%s' % (res, s.allocs, s.frees, (' - ' + '; '.join(ok)) if ok else ' - clean')

def dot_name(asm):
    import re
    for line in open(asm):
        m = re.match(r'^\s+OUTPUT\s+"([^"]+\.DOT)"', line)
        if m: return os.path.join(os.path.dirname(os.path.abspath(asm)), m.group(1))
    raise ValueError('no OUTPUT "NAME.DOT" in ' + asm)

def run(asm, syms, typed, cmdline=''):
    z = DotNext(dot_name(asm), typed, syms, cmdline)
    z.run(int(os.environ.get('NTC_LIMIT', '30000')))
    print(z.scr.text())
    print(z.exit_report())
    if os.environ.get('NTC_ZXNREGS'):
        print('--- mmu %s' % ' '.join(str(p) for p in z.mmu))
        print('--- hooks %s' % ' '.join('%02X' % h for h in z.hooks))
    print('--- halted' if z.m.halted else '--- NOT halted', 'pc=%04x' % z.m.pc, 'sp=%04x' % z.m.sp, 'ints=%d' % z.ints, 'T=%d' % z.T)
    return z
