# run an NTC program on an emulated host - scratch test tool, not delivered
#   python3 ntcrun.py prog.bas 'typed\n' [more files] [--turbo] [--platform=cpc|cpcmin|cpcfw|cpm|test] [--ram=64|128|576|4160]
#   [--cmdline='file.txt'] (CP/M: the command tail at #80, made capitals as CP/M does)
#   (in the typed text: \n = Return, ~ = one look at the keyboard that finds no key, {n} = key number n held - Keys class)
# cpc   : the CPC hardware emulation in cpcrun.py (screen read back from video RAM)
# cpcmin: the same, with stand-ins for the firmware calls its FileSystem / System.Command make
# test  : the port console of asm/ntc_plat_test.asm
# cpcfw : CPC firmware jumpblock entries trapped (TXT, KM, SCR, MC, KL)
# cpm   : CP/M page zero, BDOS (call 5) trapped
# Prints the text screen, then a '---' status line (same form as cpcrun.py).
import sys, os, subprocess
import z80
import cpcrun

HERE = os.path.dirname(os.path.abspath(__file__))
FW = {0xBB06: 'km_wait', 0xBB09: 'km_read', 0xBB5A: 'txt_out', 0xBB6C: 'txt_clear', 0xBB75: 'txt_cursor',
      0xBC0E: 'scr_mode', 0xBD19: 'mc_flyback', 0xBD0D: 'kl_time',
      0xBC77: 'cas_in_open', 0xBC7A: 'cas_in_close', 0xBC7D: 'cas_in_abandon', 0xBC83: 'cas_in_direct',
      0xBC80: 'cas_in_char', 0xBC89: 'cas_test_eof', 0xBC95: 'cas_out_char',
      0xBC8C: 'cas_out_open', 0xBC8F: 'cas_out_close', 0xBC92: 'cas_out_abandon', 0xBC98: 'cas_out_direct',
      0xBCCB: 'kl_rom_walk', 0xBCCE: 'kl_init_back', 0xBCD4: 'kl_find_command', 0x001B: 'kl_far_pcall',
      0xBCE0: 'kl_new_fast_ticker', 0xBCE6: 'kl_del_fast_ticker',
      0xB900: 'kl_u_rom_enable', 0xB903: 'kl_u_rom_disable', 0xB90F: 'kl_rom_select', 0xB918: 'kl_rom_deselect'}
# Library: ROM (cpcfw): the keyword ROM's image in upper ROM slot XSLOT - at #C000 while selected
XSLOT = 6
def load_xroms():
    # the keyword ROM set: NTC_XROM is the main ROM (slot XSLOT); NAME2.ROM, NAME3.ROM ... next to it
    # (a set of more than one) go in slots XSLOT - 1, XSLOT - 2 ... ({slot: 16K image})
    # a ROMDISC (NTC_ROMDISC = its NTCDISC.ROM; NTCDISC2.ROM ... next to it): slots 10, 11 ...
    x = os.environ.get('NTC_XROM'); out = {}
    def img(p):
        d = open(p, 'rb').read(); return d[128:] if len(d) == 0x4080 else d
    if x:
        out[XSLOT] = img(x)
        base, ext = os.path.splitext(x)
        for k in range(2, 9):
            p = base + str(k) + ext
            if os.path.exists(p): out[XSLOT - k + 1] = img(p)
    d = os.environ.get('NTC_ROMDISC')
    if d:
        out[10] = img(d)
        base, ext = os.path.splitext(d)
        for k in range(2, 9):
            p = base + str(k) + ext
            if os.path.exists(p): out[9 + k] = img(p)
    return out
RSX = ['TAPE', 'DISC', 'A', 'B', 'C', 'M']   # AMSDOS's commands, and an M4-like DOS's C and M
# files for the FileSystem class (cpm: BDOS FCB calls, cpcfw: CAS calls) live in this folder
FILES = os.environ.get('NTC_FILES', os.path.join(HERE, 't', 'files'))

def amsdos_header(data, load=0, typ=2):
    # the 128 byte header AMSDOS writes for a binary file (as sjasmplus's SAVEAMSDOS does)
    h = bytearray(128); n = len(data)
    h[18] = typ; h[21:23] = load.to_bytes(2, 'little'); h[24:26] = n.to_bytes(2, 'little')
    h[26:28] = load.to_bytes(2, 'little'); h[64:67] = n.to_bytes(3, 'little')
    h[67:69] = (sum(h[0:67]) & 0xFFFF).to_bytes(2, 'little')
    return bytes(h)
def amsdos_header_of(d):
    # (load address, length) when d starts with a valid AMSDOS header, else None
    if len(d) < 128 or (sum(d[0:67]) & 0xFFFF) != int.from_bytes(d[67:69], 'little'): return None
    return int.from_bytes(d[21:23], 'little'), int.from_bytes(d[24:26], 'little')

class Screen:
    def __init__(s, cols, rows):
        s.cols = cols; s.rows = rows; s.clear()
    def clear(s):
        s.cells = [[' '] * 80 for _ in range(s.rows)]; s.x = 0; s.y = 0
    def newline(s):
        s.x = 0; s.y += 1
        if s.y >= s.rows:
            s.cells.pop(0); s.cells.append([' '] * 80); s.y = s.rows - 1
    def put(s, c):
        if s.x >= s.cols:
            s.newline()
        s.cells[s.y][s.x] = c; s.x += 1
        if getattr(s, 'immediate', False) and s.x >= s.cols:
            s.newline()      # the CPC firmware wraps as soon as the last column is written
    def back(s):
        if s.x == 0:
            if s.y == 0: return
            s.y -= 1; s.x = s.cols
        s.x -= 1; s.cells[s.y][s.x] = ' '
    def ctrl(s, v):
        # a byte as a terminal / the firmware treats it (CP/M: VT52 and ANSI codes too)
        if getattr(s, 'esc', None) is not None:
            s.esc.append(v); e = s.esc
            if e[0] == ord('E') or e[0] == ord('H'):
                if e[0] == ord('E'): s.clear()
                else: s.x = 0; s.y = 0
                s.esc = None
            elif e[0] == ord('Y'):
                if len(e) == 3: s.locate(e[2] - 31, e[1] - 31); s.esc = None
            elif e[0] == ord('['):
                if 64 <= v <= 126 and len(e) > 1:
                    body = bytes(e[1:-1]).decode()
                    if v == ord('J'): s.cells = [[' '] * 80 for _ in range(s.rows)]
                    elif v == ord('H'):
                        p = [int(x) for x in body.split(';')] if body else [1, 1]
                        s.locate(p[1], p[0])
                    s.esc = None
            else:
                s.esc = None
            return
        if v == 27: s.esc = []; return
        if v == 13: s.x = 0
        elif v == 10:
            s.y += 1
            if s.y >= s.rows:
                s.cells.pop(0); s.cells.append([' '] * 80); s.y = s.rows - 1
        elif v == 8:
            if s.x > 0: s.x -= 1
            elif s.y > 0: s.y -= 1; s.x = s.cols - 1
        elif v == 7: pass
        elif 32 <= v < 127: s.put(chr(v))
        else: s.put('?')
    def locate(s, x, y):
        s.x = max(0, min(s.cols - 1, x - 1)); s.y = max(0, min(s.rows - 1, y - 1))
    def text(s):
        out = [''.join(r[:s.cols]).rstrip() for r in s.cells]
        while out and not out[-1]: out.pop()
        return '\n'.join(out)

class Host:
    def __init__(s, platform, binary, org, typed):
        s.p = platform; s.m = m = z80.Z80Machine(); s.typed = list(typed); s.T = 0; s.ints = 0
        s.loc = []; s.out_log = []; s.dma = 0x80; s.cas_in = None; s.cas_out = None
        s.drive = 0; s.logged = 1                     # CP/M: current drive A, A logged in
        s.amsdos = False; s.cas_dev = 'TAPE'; s.disk = 'A'   # CPC: AMSDOS dropped by RUN" until KL ROM WALK
        s.cas_ascii = False; s.cas_load = 0
        os.makedirs(FILES, exist_ok=True)
        m.set_memory_block(org, binary)
        m.set_memory_block(0x38, bytes([0xFB, 0xC9]))       # stand in interrupt handler: ei / ret
        if platform == 'cpm':
            s.scr = Screen(80, 24)
            m.set_memory_block(0, bytes([0x76]))                # warm boot = the end
            m.set_memory_block(5, bytes([0xD3, 0xE5, 0xC9]))    # BDOS: out (#e5), a / ret
            m.sp = 0xFF00; m.set_memory_block(0xFF00, bytes([0, 0]))   # ret to 0 also ends
            m.set_memory_block(0xFEF0, bytes([0xED, 0x56, 0xC3, org & 255, org >> 8])); m.pc = 0xFEF0
        else:
            s.scr = Screen(40, 25)
            m.set_memory_block(0xBFF0, b'\x76'); m.set_memory_block(0xBE00 - 2, bytes([0xF0, 0xBF])); m.sp = 0xBE00 - 2
            m.set_memory_block(0xBFE0, bytes([0xED, 0x56, 0xC3, org & 255, org >> 8])); m.pc = 0xBFE0
            if platform == 'cpcfw':
                s.scr.immediate = True
                for i, a in enumerate(sorted(FW)):
                    m.set_memory_block(a, bytes([0xD3, 0xE0 + i, 0xC9]))
                s.fwport = {0xE0 + i: FW[a] for i, a in enumerate(sorted(FW))}
                m.set_memory_block(0x18, bytes([0xD3, 0xDF, 0xC9]))   # RST 3: a far call (AMSDOS's CAS entries)
        s.ram = cpcrun.RamBanks(m)                          # the gate array's RAM setting (Memory class)
        s.romsel = 0
        s.xroms = load_xroms() if platform == 'cpcfw' else {}
        m.set_output_callback(s.out); m.set_input_callback(s.inp)
    def key(s):
        # '~' in the typed text: this look at the keyboard finds no key (then the rest follow)
        if s.typed and s.typed[0] == '~':
            s.typed.pop(0)
            return 0
        if s.typed and s.typed[0] == '{': return 0     # a held key for the matrix (Keys), not a typed one
        return ord(s.typed.pop(0)) if s.typed else 0
    def ticks(s):
        return (s.T // 13333) & 0xFFFF
    def out(s, port, val):
        lo = port & 0xFF; m = s.m
        if s.p != 'cpm' and 0x78 <= (port >> 8) <= 0x7F and (val & 0xC0) == 0xC0:
            s.ram.set(val, port >> 8); return
        if s.p == 'cpcfw' and (port >> 8) == 0xF6:
            s.line = val & 15; return          # the PPI's port C: the keyboard line (Keys class)
        if s.p == 'test':
            if lo == 0xFE: s.scr.put(chr(val) if 32 <= val < 127 else '?')
            elif lo == 0xF9: s.scr.newline()
            elif lo == 0xF5: s.scr.back()
            elif lo == 0xFC: s.scr.clear()
            elif lo == 0xFA: s.scr.cols = {0: 20, 1: 40}.get(val, 80); s.scr.clear()
            elif lo == 0xFB:
                s.loc.append(val)
                if len(s.loc) == 2: s.scr.locate(s.loc[0], s.loc[1]); s.loc = []
        elif s.p == 'cpm' and lo == 0xE5:
            fn = m.c
            if fn == 6:
                if m.e == 0xFF:
                    r = s.key(); m.a = r; m.l = r
                else:
                    s.scr.ctrl(m.e)
            elif fn == 2:
                s.scr.ctrl(m.e)
            elif fn == 9:
                a = m.de
                while m.memory[a] != ord('$'): s.scr.ctrl(m.memory[a]); a += 1
            elif fn == 11:
                r = 0xFF if s.typed else 0; m.a = r; m.l = r
            elif fn in (15, 16, 19, 22, 23, 33, 34, 35):
                r = s.bdos_file(fn, m.de); m.a = r; m.l = r
            elif fn == 14:
                s.drive = m.e & 15; s.logged |= 1 << s.drive; m.a = 0; m.l = 0
            elif fn == 24:
                m.hl = s.logged; m.a = s.logged & 255
            elif fn == 25:
                m.a = s.drive; m.l = s.drive
            elif fn == 45:
                m.a = 0
            elif fn == 12:
                m.hl = 0x0031; m.a = 0x31                     # CP/M 3
            elif fn == 26:
                s.dma = m.de
        elif s.p == 'cpcfw' and lo == 0xDF:
            # RST 3 from a CAS entry AMSDOS took over (DF lo hi): carry it out; the caller of
            # the entry gets the result (the RST's own return address is dropped)
            sp = m.sp; ret = m.memory[sp] | (m.memory[sp + 1] << 8)
            ok = s.cas(FW[ret - 1])
            m.f = (m.f | 1) if ok else (m.f & 0xFE)
            m.sp = sp + 2
        elif s.p == 'cpcfw' and lo == 0xDD and m.pc == 0xBF86:
            s.evsel = s.romsel                  # the fast ticker event: the main ROM in for its call
            if s.xroms: m.set_memory_block(0xC000, s.xroms.get(XSLOT, b'\x80'))
        elif s.p == 'cpcfw' and lo == 0xDC and m.pc == 0xBF8B:
            if s.xroms: m.set_memory_block(0xC000, s.xroms.get(s.evsel, b'\x80'))
        elif s.p == 'cpcfw' and lo in getattr(s, 'fwport', {}):
            f = s.fwport[lo]
            if f == 'txt_out': s.scr.ctrl(val)
            elif f == 'txt_clear': s.scr.clear()
            elif f == 'txt_cursor': s.scr.locate(m.h, m.l)
            elif f == 'scr_mode': s.scr.cols = {0: 20, 1: 40}.get(val, 80); s.scr.clear()
            elif f == 'km_wait':
                m.a = s.key() or 13; m.f = m.f | 1
            elif f == 'km_read':
                k = s.key()
                if k:
                    m.a = k; m.f = m.f | 1
                else:
                    m.f = m.f & 0xFE
            elif f == 'kl_time':
                t = s.T // 13333; m.hl = t & 0xFFFF; m.de = (t >> 16) & 0xFFFF
            elif f.startswith('cas_'):
                ok = s.cas(f)
                m.f = (m.f | 1) if ok else (m.f & 0xFE)
            elif f == 'kl_rom_walk' or (f == 'kl_init_back' and m.c == 7):
                s.amsdos_on(); m.hl = 0xA6FB
            elif f == 'kl_find_command':
                a = m.hl; n = ''
                while True:
                    c = m.memory[a]; n += chr(c & 0x7F); a += 1
                    if c & 0x80: break
                if s.amsdos and n in RSX:
                    m.hl = 0x4000 + RSX.index(n); m.c = 7; m.f = m.f | 1
                else:
                    m.f = m.f & 0xFE
            elif f == 'kl_new_fast_ticker':
                # the firmware calls the event routine at every interrupt (300 a second): #38
                # jumps to a stub that keeps the registers and calls it. The real firmware calls an
                # EXPRESS asynchronous routine straight from the interrupt with the lower ROM on,
                # ignoring the far address (6128 ROM #01E2) - so one below #4000 would run ROM code
                r = m.de
                if (m.b & 0x40) and r < 0x4000:
                    print('ERROR: express event routine at #%04X: the firmware would run the lower ROM there' % r)
                # (KL FAR ICALL: the event's ROM - NTC's main ROM - is selected for the call, then the one
                # that was in: out (#DD) / out (#DC) here)
                stub = [0xF5, 0xC5, 0xD5, 0xE5, 0xD3, 0xDD, 0xCD, r & 255, r >> 8, 0xD3, 0xDC, 0xE1, 0xD1, 0xC1, 0xF1, 0xFB, 0xC9]
                m.set_memory_block(0xBF80, bytes(stub)); m.set_memory_block(0x38, bytes([0xC3, 0x80, 0xBF]))
            elif f == 'kl_del_fast_ticker':
                m.set_memory_block(0x38, bytes([0xFB, 0xC9]))
            elif f in ('kl_rom_select', 'kl_rom_deselect'):
                # the upper ROM selected: the keyword ROM's image at #C000 for its slot, anything
                # else looks like BASIC (#80: a foreground ROM) to the program's search
                old = s.romsel; s.romsel = m.c
                if m.c in s.xroms: m.set_memory_block(0xC000, s.xroms[m.c])
                else: m.set_memory_block(0xC000, b'\x80')
                m.c = old; m.b = 0
            elif f == 'kl_far_pcall':
                n = RSX[m.hl - 0x4000]
                if n == 'TAPE': s.cas_dev = 'TAPE'
                elif n == 'DISC': s.cas_dev = s.disk
                else:
                    s.disk = n
                    if s.cas_dev != 'TAPE': s.cas_dev = n
    def amsdos_on(s):
        # AMSDOS starts: drive A, and it takes over the cassette entries (far calls, RST 3)
        s.amsdos = True; s.cas_dev = s.disk
        for a, f in FW.items():
            if f.startswith('cas_'): s.m.set_memory_block(a, bytes([0xDF, 0, 0]))
    def fcbname(s, a, base=0):
        b = s.m.memory
        n = bytes(x & 0x7F for x in b[a + base + 1:a + base + 9]).decode().rstrip()
        e = bytes(x & 0x7F for x in b[a + base + 9:a + base + 12]).decode().rstrip()
        d = b[a] - 1 if b[a] else s.drive                  # the FCB's drive (0 = the current one)
        os.makedirs(os.path.join(FILES, 'ABCDEFGHIJKLMNOP'[d]), exist_ok=True)
        return os.path.join(FILES, 'ABCDEFGHIJKLMNOP'[d], n + ('.' + e if e else ''))
    def bdos_file(s, fn, fcb):
        # CP/M file calls on the folder FILES: 128 byte records, random read / write
        m = s.m; mem = m.memory; p = s.fcbname(fcb)
        if fn == 15: return 0 if os.path.exists(p) else 0xFF
        if fn == 16: return 0 if os.path.exists(p) else 0xFF
        if fn == 19:
            if not os.path.exists(p): return 0xFF
            os.remove(p); return 0
        if fn == 22: open(p, 'wb').close(); return 0
        if fn == 23:
            q = s.fcbname(fcb, 16)
            if not os.path.exists(p): return 0xFF
            os.rename(p, q); return 0
        rec = mem[fcb + 33] | (mem[fcb + 34] << 8) | (mem[fcb + 35] << 16)
        if fn == 35:
            n = (os.path.getsize(p) + 127) // 128 if os.path.exists(p) else 0
            mem[fcb + 33] = n & 255; mem[fcb + 34] = (n >> 8) & 255; mem[fcb + 35] = n >> 16
            return 0
        if not os.path.exists(p): return 0xFF
        data = bytearray(open(p, 'rb').read())
        if fn == 33:
            if rec * 128 >= len(data): return 1
            blk = data[rec * 128:rec * 128 + 128]
            blk += bytes([26]) * (128 - len(blk))
            for i in range(128): mem[(s.dma + i) & 0xFFFF] = blk[i]
            return 0
        if fn == 34:
            if len(data) < rec * 128: data += bytes(rec * 128 - len(data))
            data[rec * 128:rec * 128 + 128] = bytes(mem[(s.dma + i) & 0xFFFF] for i in range(128))
            open(p, 'wb').write(data); return 0
        return 0xFF
    def cas(s, f):
        # the firmware's cassette calls (AMSDOS: disc) on the folder FILES; carry = ok
        m = s.m; mem = m.memory
        def name():
            n = bytes(mem[m.hl:m.hl + m.b]).decode().upper(); d = s.cas_dev
            if ':' in n and s.cas_dev != 'TAPE': d, n = n.split(':', 1)     # "C:NAME": volume C
            os.makedirs(os.path.join(FILES, d), exist_ok=True)   # one folder per device / volume: TAPE, A, B, C ...
            return os.path.join(FILES, d, n)
        if f == 'cas_in_open':
            # AMSDOS: a file with a header is binary (its length from the header); one without
            # is ASCII text - CAS IN DIRECT won't load that (so a file needs its header)
            p = name()
            if not os.path.exists(p): m.a = 0x92; return False
            d = open(p, 'rb').read(); h = amsdos_header_of(d)
            s.cas_pos = 0
            if h is None:
                # ASCII: CAS IN CHAR reads it, up to a ^Z
                s.cas_in = None; s.cas_ascii = True; s.cas_chars = d.split(b'\x1a')[0]; m.bc = 0; m.de = 0; m.a = 0x16; return True
            s.cas_ascii = False; s.cas_in = d[128:128 + h[1]]; s.cas_chars = s.cas_in; m.bc = h[1]; m.de = h[0]; m.a = 2; return True
        if f == 'cas_in_char':
            c = getattr(s, 'cas_chars', None); p = getattr(s, 'cas_pos', 0)
            if c is None or p >= len(c): m.a = 0x1A; return False
            m.a = c[p]; s.cas_pos = p + 1; return True
        if f == 'cas_test_eof':
            c = getattr(s, 'cas_chars', None)
            return c is not None and getattr(s, 'cas_pos', 0) < len(c)
        if f == 'cas_in_direct':
            if s.cas_in is None: return False
            for i, x in enumerate(s.cas_in): mem[(m.hl + i) & 0xFFFF] = x
            m.hl = 0; return True
        if f in ('cas_in_close', 'cas_in_abandon'):
            s.cas_in = None; s.cas_chars = None; return True
        if f == 'cas_out_open':
            s.cas_out = [name(), b'']; s.cas_outch = None; return True
        if f == 'cas_out_char':
            if s.cas_out is None: return False
            if getattr(s, 'cas_outch', None) is None: s.cas_outch = bytearray()
            s.cas_outch.append(m.a); return True
        if f == 'cas_out_direct':
            if s.cas_out is None: return False
            s.cas_load = m.hl
            s.cas_out[1] = bytes(mem[(m.hl + i) & 0xFFFF] for i in range(m.de)); return True
        if f == 'cas_out_close':
            if s.cas_out is None: return False
            if getattr(s, 'cas_outch', None) is not None:
                # CAS OUT CHAR: an ASCII file, no header, ^Z at the end (as AMSDOS writes it)
                open(s.cas_out[0], 'wb').write(bytes(s.cas_outch) + b'\x1a'); s.cas_out = None; s.cas_outch = None; return True
            open(s.cas_out[0], 'wb').write(amsdos_header(s.cas_out[1], s.cas_load) + s.cas_out[1]); s.cas_out = None; return True
        if f == 'cas_out_abandon':
            s.cas_out = None; return True
        return False
    def inp(s, port):
        lo = port & 0xFF
        if s.p == 'cpcfw' and (port >> 8) == 0xF4:
            # the keyboard matrix (Keys class): {n} in the typed text holds key n for 12 scans
            v = 0xFF; h = getattr(s, 'held', None); line = getattr(s, 'line', 0)
            if h is not None and line == h // 8: v &= ~(1 << (h % 8))
            if line == 9:
                s.hscans = getattr(s, 'hscans', 0) + 1
                if h is not None and s.hscans >= 12: s.held = None
                elif h is None and s.typed and s.typed[0] == '{':
                    s.typed.pop(0); n = ''
                    while s.typed and s.typed[0] != '}': n += s.typed.pop(0)
                    if s.typed: s.typed.pop(0)
                    s.held = int(n); s.hscans = 0
                elif h is None and s.typed and s.typed[0] == '~':
                    s.typed.pop(0)
            return v & 0xFF
        if s.p == 'test':
            if lo == 0xFD: return s.key() or 13
            if lo == 0xF8: return s.key()
            if lo == 0xF7: return s.ticks() & 0xFF
            if lo == 0xF6: return s.ticks() >> 8
        return 0xFF
    def run(s, limit=30000):
        n = 0
        while not s.m.halted:
            s.m.ticks_to_stop = 13333; cpcrun.endkey_run(s); n += 1; s.T += 13333 - s.m.ticks_to_stop
            if s.m.halted: break
            steps = 0
            while not s.m.halted and steps < 2000:
                if s.m.iff1 and s.m.on_handle_active_int(): s.ints += 1; break
                s.m.ticks_to_stop = 1; cpcrun.endkey_run(s); steps += 1; s.T += 1 - s.m.ticks_to_stop
            if n > limit: print('TIMEOUT pc=%04x sp=%04x' % (s.m.pc, s.m.sp)); break

def main():
    args = sys.argv[1:]
    plat = 'cpc'; called = False; cmdline = ''
    for a in list(args):
        if a.startswith('--platform='): plat = a[11:]; args.remove(a)
        if a == '--called': called = True; args.remove(a)   # cpcfw: CALLed from BASIC, AMSDOS still running
        if a.startswith('--ram='): os.environ['NTC_RAM'] = a[6:]; args.remove(a)   # total RAM K: 64, 128 (default), 576 (512K expansion), 4160 (4MB)
        if a.startswith('--cmdline='): cmdline = a[10:]; args.remove(a)
    bas = args[0]; typed = (args[1] if len(args) > 1 else '').replace('\\n', '\r').replace('\\x7f', '\x7f')
    extra = args[2:]
    asm = bas[:-4] + '.asm'
    r = subprocess.run(['node', os.path.join(HERE, 'cli.js'), bas, '--platform=' + plat] + extra, capture_output=True, text=True)
    if r.stderr: print(r.stderr)
    open(asm, 'w').write(r.stdout)
    b, syms = cpcrun.assemble(asm)
    if plat in ('cpc', 'cpcmin', 'cpcfw') and 'NTC_XROM' not in os.environ and ('--library=rom' in extra or 'ntc_rj_block' in syms):
        # the program wants the keyword ROM (Option Library ROM / --library=rom): fitted in slot 6
        os.environ['NTC_XROM'] = os.path.join(os.environ.get('NTC_ROMDIR', os.path.join(HERE, '..', 'build', 'rom')), {'cpc': 'NTCCPC', 'cpcmin': 'NTCMIN', 'cpcfw': 'NTCFW'}[plat] + '.ROM')
    if 'ntc_rj_block' in syms:
        # the ROM's variables the harness reads (ntc_smode, ntc_font): from the registry
        for line in open(os.path.join(HERE, '..', 'asm', 'ntc_rom_' + plat + '.txt')):
            p = line.split()
            if len(p) >= 4 and p[0] == '-' and p[1] in ('data', 'bss') and p[2] not in syms: syms[p[2]] = int(p[3].lstrip('#'), 16)
    if plat in ('cpc', 'cpcmin'):     # the CPC hardware emulation (cpcmin: plus the firmware stand-ins)
        c = cpcrun.CPC(b, syms.get('ntc_start', 0x4000), typed, syms); c.run()
        print(c.screen(cpcrun.loadfont(syms, c.m.memory)))
        print('--- halted' if c.m.halted else '--- NOT halted', 'sp=%04x' % c.m.sp, 'ints=%d' % c.ints, 'T=%d' % c.T)
        return
    org = syms.get('ntc_start', 0x100 if plat == 'cpm' else 0x4000)   # the program's org
    h = Host(plat, b, org, typed)
    cpcrun.endkey_set(h.m, syms)
    if called and plat == 'cpcfw': h.amsdos_on()
    if plat == 'cpm':
        tail = (' ' + cmdline.upper()).encode() if cmdline else b''
        h.m.set_memory_block(0x80, bytes([len(tail)]) + tail + b'\0')
    h.run()
    print(h.scr.text())
    print('--- halted' if h.m.halted else '--- NOT halted', 'sp=%04x' % h.m.sp, 'ints=%d' % h.ints, 'T=%d' % h.T)

if __name__ == '__main__':
    main()
