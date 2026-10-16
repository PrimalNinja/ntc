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
import sys, os, subprocess, random
import z80
import cpcrun

HERE = os.path.dirname(os.path.abspath(__file__))
# cpm: the CP/M version BDOS 12 gives (NTC_CPMVER=22 or 31, default 31). CP/M Plus is modelled as
# on a 6128: the program runs in RAM configuration C2 (the 64K seen is blocks 4-7), main RAM's
# blocks 0-3 (the screen: block 1) are reached with C1 (Graphics). NTC_GFXCHK=1: at the end, the
# number of screen bytes not 0 (Plus: block 1, 2.2: #C000-#EFFF)
CPMVER = int(os.environ.get('NTC_CPMVER', '31'), 16)
FW = {0xBB06: 'km_wait', 0xBB09: 'km_read', 0xBB0C: 'km_char_return', 0xBB5A: 'txt_out', 0xBB6C: 'txt_clear', 0xBB75: 'txt_cursor',
      0xBC0E: 'scr_mode', 0xBD19: 'mc_flyback', 0xBD0D: 'kl_time',
      0xBC77: 'cas_in_open', 0xBC7A: 'cas_in_close', 0xBC7D: 'cas_in_abandon', 0xBC83: 'cas_in_direct',
      0xBC80: 'cas_in_char', 0xBC89: 'cas_test_eof', 0xBC95: 'cas_out_char',
      0xBC8C: 'cas_out_open', 0xBC8F: 'cas_out_close', 0xBC92: 'cas_out_abandon', 0xBC98: 'cas_out_direct',
      0xBCCB: 'kl_rom_walk', 0xBCCE: 'kl_init_back', 0xBCD4: 'kl_find_command', 0x001B: 'kl_far_pcall',
      0xBCE0: 'kl_new_fast_ticker', 0xBCE6: 'kl_del_fast_ticker',
      0xBBAB: 'txt_set_m_table', 0xBC0B: 'scr_get_location', 0xBC4D: 'scr_hw_roll',
      0xB900: 'kl_u_rom_enable', 0xB903: 'kl_u_rom_disable', 0xB90F: 'kl_rom_select', 0xB918: 'kl_rom_deselect'}
# the stand-ins' out (n), a - the PC after each (the firmware entries', RST 3's, the interrupt stub's)
STANDPC = set(a + 2 for a in FW) | {0x1A, 0xBF86, 0xBF8B}
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
# NTC_PROF=file: the PC at the end of each 13333 T chunk, with the symbols, written there (a profile)
PROF = [] if os.environ.get('NTC_PROF') else None
RSX = ['TAPE', 'DISC', 'A', 'B', 'C', 'M', 'ERA', 'REN']   # AMSDOS's commands, and an M4-like DOS's C and M
# NTC_UNIDOS=IDE,SD: UniDOS stands in (cpcfw) - its Ctrl J BIOS command (devices, examine, read) and
# paths "IDE:GAMES/NAME.EXT" in the CAS calls: each device a folder in FILES (FILES/IDE/GAMES), as
# A and B are (logical drives). NTC_UNIDOS_NOEX=A: drives Ctrl J can't examine (AMSDOS's floppies)
UNIDOS = [x for x in os.environ.get('NTC_UNIDOS', '').split(',') if x]
UNIDOS_NOEX = [x for x in os.environ.get('NTC_UNIDOS_NOEX', '').split(',') if x]
CTRLJ = 0x4100
# files for the FileSystem class (cpm: BDOS FCB calls, cpcfw: CAS calls) live in this folder
FILES = os.environ.get('NTC_FILES', os.path.join(HERE, 't', 'files'))

def cyb_entry(name, length, long_name='', kind=1, what=1, flags=1, load=0x100, exe=0x100):
    """a CyborgOS FILES.DIR / NAME.HDR entry (64 bytes, bas/cyborgos/Main.bas): kind, the 8 + 3
    disc name, what (1 a CP/M .COM), flags, length, load, exec, long name, the sum of bytes 0-61"""
    b, _, x = name.upper().partition('.')
    e = bytearray(64); e[0] = kind; e[1:12] = (b.ljust(8)[:8] + x.ljust(3)[:3]).encode()
    e[12] = what; e[13] = flags; e[14:16] = length.to_bytes(2, 'little')
    e[16:18] = load.to_bytes(2, 'little'); e[18:20] = exe.to_bytes(2, 'little')
    ln = long_name.encode()[:38]; e[24:24 + len(ln)] = ln
    e[62:64] = (sum(e[:62]) & 0xFFFF).to_bytes(2, 'little'); return bytes(e)

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

def make_dsk(path, files, fmt='data'):
    """a CPC .DSK (40 tracks, 9 sectors of 512, interleaved): files [(user, 'NAME.EXT', bytes)] in
    CP/M's directory - data format (#C1-#C9) or system (#41-#49, 2 tracks kept) - for NTC_FDC"""
    base, off = (0xC1, 0) if fmt == 'data' else (0x41, 2)
    img = bytearray([0xE5]) * (40 * 9 * 512); dr = bytearray([0xE5]) * 2048; nb = 2; e = 0
    for u, nm, data in files:
        n, _, x = nm.partition('.'); name = (n.ljust(8) + x.ljust(3)).encode()
        data = data + bytes((-len(data)) % 128); recs = len(data) // 128
        for ex in range(max(1, (recs + 127) // 128)):
            part = data[ex * 16384:(ex + 1) * 16384]; ent = bytearray(32)
            ent[0] = u; ent[1:12] = name; ent[12] = ex & 31; ent[14] = ex >> 5; ent[15] = min(128, len(part) // 128)
            for j in range((len(part) + 1023) // 1024):
                ent[16 + j] = nb; b = part[j * 1024:(j + 1) * 1024]
                o = (off * 9 * 512) + nb * 1024; img[o:o + len(b)] = b; nb += 1
            dr[e * 32:e * 32 + 32] = ent; e += 1
    img[off * 9 * 512:off * 9 * 512 + 2048] = dr
    ts = 0x100 + 9 * 512; h = bytearray(256); h[0:34] = b'MV - CPCEMU Disk-File\r\nDisk-Info\r\n'
    h[0x30] = 40; h[0x31] = 1; h[0x32:0x34] = ts.to_bytes(2, 'little'); d = bytearray(h)
    order = [0, 5, 1, 6, 2, 7, 3, 8, 4]
    for t in range(40):
        ti = bytearray(256); ti[0:12] = b'Track-Info\r\n'; ti[0x10] = t; ti[0x14] = 2; ti[0x15] = 9; ti[0x16] = 0x52; ti[0x17] = 0xE5
        for i, sn in enumerate(order): ti[0x18 + i * 8:0x20 + i * 8] = bytes([t, 0, base + sn, 2, 0, 0, 0, 0])
        d += ti
        for sn in order: o = (t * 9 + sn) * 512; d += img[o:o + 512]
    open(path, 'wb').write(d)

class Fdc:
    """NTC_FDC=a.dsk[,b.dsk]: the CPC's disc controller (uPD765 at #FB7E status / #FB7F data, the
    motor at #FA7E) with .DSK images (standard or extended) in its drives, side 0: specify, recalibrate,
    seek, sense interrupt / drive status, read ID, read data, write data, format a track (FLOPPY.CYB).
    A write or a format saves the image again (as an extended DSK)"""
    LEN = {3: 3, 4: 2, 7: 2, 8: 1, 15: 3, 10: 2, 6: 9, 12: 9, 5: 9, 13: 6}
    def __init__(s, paths):
        s.paths = paths
        s.discs = [s.load(p) if p and os.path.exists(p) else ({} if p else None) for p in paths]
        s.motor = 0; s.cmd = []; s.out = []; s.data = b''; s.di = 0; s.ints = []; s.pcn = [0, 0, 0, 0]; s.idx = 0
        s.win = None                       # a write's or a format's bytes still to come: [what, bytes, need]
    @staticmethod
    def load(p):
        d = open(p, 'rb').read(); ext = d[:8] == b'EXTENDED'
        nt, ns = d[0x30], d[0x31]; o = 0x100; tr = {}
        for t in range(nt * ns):
            sz = (d[0x34 + t] * 256) if ext else (d[0x32] | d[0x33] << 8)
            if sz == 0: continue
            ti = d[o:o + sz]; nsec = ti[0x15]; q = o + 0x100; secs = []
            for i in range(nsec):
                c, h, r, n, s1, s2, al, ah = ti[0x18 + i * 8:0x20 + i * 8]
                ln = (al | ah << 8) if ext else (128 << ti[0x14])
                secs.append([c, h, r, n, bytearray(d[q:q + ln])]); q += ln
            tr[(ti[0x10], ti[0x11])] = secs; o += sz
        return tr
    @staticmethod
    def save(p, tr):
        nt = max([t for t, sd in tr] + [-1]) + 1
        h = bytearray(256); h[0:34] = b'EXTENDED CPC DSK File\r\nDisk-Info\r\n'; h[0x30] = nt; h[0x31] = 1; body = b''
        for t in range(nt):
            secs = tr.get((t, 0))
            if not secs: continue
            ti = bytearray(256); ti[0:12] = b'Track-Info\r\n'; ti[0x10] = t; ti[0x14] = secs[0][3]; ti[0x15] = len(secs); ti[0x16] = 0x4E; ti[0x17] = 0xE5
            dat = b''
            for i, (c, hh, r, n, b) in enumerate(secs):
                ti[0x18 + i * 8:0x20 + i * 8] = bytes([c, hh, r, n, 0, 0, len(b) & 255, len(b) >> 8]); dat += bytes(b)
            blk = bytes(ti) + dat; blk += bytes(-len(blk) % 256); h[0x34 + t] = len(blk) // 256; body += blk
        open(p, 'wb').write(bytes(h) + body)
    def msr(s):
        if s.win: return 0xB0
        if s.data and s.di < len(s.data): return 0xF0
        if s.out: return 0xD0
        return 0x90 if s.cmd else 0x80
    def rd(s):
        if s.data and s.di < len(s.data):
            v = s.data[s.di]; s.di += 1
            if s.di >= len(s.data): s.data = b''; s.out = s.res
            return v
        if s.out: return s.out.pop(0)
        return 0xFF
    def wr(s, v):
        if s.win:                          # the execution phase: a byte to write
            w = s.win; w[1].append(v)
            if len(w[1]) >= w[2]: s.win = None; w[0](bytes(w[1]))
            return
        if s.out or s.data: return
        s.cmd.append(v); c = s.cmd[0] & 0x1F; n = s.LEN.get(c, 1)
        if len(s.cmd) < n: return
        a = s.cmd; s.cmd = []; dn = a[1] & 3 if n > 1 else 0
        disc = s.discs[dn] if dn < len(s.discs) and s.motor else None
        if c == 3: return
        if c == 4: s.out = [0x20 | dn]; return
        if c == 7: s.pcn[dn] = 0; s.ints.append([0x20 | dn, 0]); return
        if c == 15: s.pcn[dn] = a[2]; s.ints.append([0x20 | dn, a[2]]); return
        if c == 8: s.out = s.ints.pop(0) if s.ints else [0x80]; return
        secs = disc.get((s.pcn[dn], 0)) if disc is not None else None
        if c == 10:
            if not secs: s.out = [0x40 | dn, 1, 0, 0, 0, 0, 0]; return
            q = secs[s.idx % len(secs)]; s.idx += 1
            s.out = [dn, 0, 0, q[0], q[1], q[2], q[3]]; return
        if c in (6, 12, 5):
            q = [x for x in (secs or []) if x[2] == a[4]]
            if not q: s.out = [0x40 | dn, 4 if secs else 1, 0, a[2], a[3], a[4], a[5]]; return
            q = q[0]; res = [0x40 | dn, 0x80, 0, q[0], q[1], q[2], q[3]]
            if c == 5:
                def done(b, q=q, res=res, dn=dn):
                    q[4] = bytearray(b); s.out = res; s.save(s.paths[dn], s.discs[dn])
                s.win = [done, bytearray(), 128 << a[5]]; return
            s.data = bytes(q[4][:128 << a[5]]); s.di = 0; s.res = res; return
        if c == 13:                        # format: SC sectors of N, their IDs (4 bytes each) to come
            if disc is None: s.out = [0x40 | dn, 1, 0, 0, 0, 0, 0]; return
            nn, sc, fill, t = a[2], a[3], a[5], s.pcn[dn]
            def fmt(b, nn=nn, sc=sc, fill=fill, t=t, dn=dn):
                disc[(t, 0)] = [[b[i * 4], b[i * 4 + 1], b[i * 4 + 2], b[i * 4 + 3], bytearray([fill]) * (128 << nn)] for i in range(sc)]
                s.out = [dn, 0, 0, t, 0, 0, nn]; s.save(s.paths[dn], disc)
            s.win = [fmt, bytearray(), sc * 4]; return
        s.out = [0x80]

FDC = Fdc(os.environ['NTC_FDC'].split(',')) if os.environ.get('NTC_FDC') else None

class Screen:
    def __init__(s, cols, rows):
        s.cols = cols; s.rows = rows; s.clear()
    def clear(s):
        s.cells = [[' '] * 80 for _ in range(s.rows)]; s.x = 0; s.y = 0
        # cpcfw: characters written straight into screen memory (mode 2, at SCR CHAR POSITION's
        # addresses; the matrices from TXT GET MATRIX hold the character code in their first
        # byte) are shown too; the firmware's scroll moves the screen's start (off)
        s.off = 0
        s.crtc = [0] * 32; s.crtc[1] = 40; s.crtc[6] = 25; s.crtc[12] = 0x30
        if getattr(s, 'mem', None) is not None: s.vset(0xC000, bytes(0x800))
    def vset(s, a, data):
        # screen RAM: the machine's memory, or (Library: ROM - the keyword ROM is at #C000) the
        # RAM under it that writes there go to
        if getattr(s, 'vram', None) is not None: s.vram[a - 0xC000:a - 0xC000 + len(data)] = data
        else: s.mem.set_memory_block(a, data)
    def vget(s, a):
        if getattr(s, 'vram', None) is not None: return s.vram[a - 0xC000]
        r = getattr(s, 'ram', None)
        if r is not None and r.view[3] != ('m', 3):
            # a bank's page is at #C000 now (a slot running): main RAM's page 3 from where it is kept
            return r.main_page(3)[a - 0xC000]
        return s.mem.memory[a]
    def scrolled(s):
        if getattr(s, 'mem', None) is None: return
        s.off = (s.off + 80) & 0x7FF
        for c in range(80): s.vset(0xC000 + ((s.off + 24 * 80 + c) & 0x7FF), b'\0')
    def newline(s):
        s.x = 0; s.y += 1
        if s.y >= s.rows:
            s.cells.pop(0); s.cells.append([' '] * 80); s.y = s.rows - 1; s.scrolled()
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
                s.cells.pop(0); s.cells.append([' '] * 80); s.y = s.rows - 1; s.scrolled()
        elif v == 8:
            if s.x > 0: s.x -= 1
            elif s.y > 0: s.y -= 1; s.x = s.cols - 1
        elif v == 7: pass
        elif 32 <= v < 127: s.put(chr(v))
        else: s.put('?')
    def locate(s, x, y):
        s.x = max(0, min(s.cols - 1, x - 1)); s.y = max(0, min(s.rows - 1, y - 1))
    def text(s):
        if getattr(s, 'mem', None) is not None and s.cols == 80 and getattr(s, 'crtc_used', False):
            # the CRTC was set by the program: its own width (R1 words), rows (R6) and start
            # (R12 / R13) - every row straight from screen memory
            c = s.crtc; cols = c[1] * 2; off = (((c[12] & 3) << 8) | c[13]) * 2
            out = [''.join(chr(b) if 32 <= b < 127 else ' ' for b in (s.vget(0xC000 + ((off + r * cols + x) & 0x7FF)) for x in range(cols))).rstrip() for r in range(c[6])]
            while out and not out[-1]: out.pop()
            return '\n'.join(out)
        if getattr(s, 'mem', None) is not None and s.cols == 80:
            for r in range(min(s.rows, 25)):
                for c in range(80):
                    b = s.vget(0xC000 + ((s.off + r * 80 + c) & 0x7FF))
                    if 32 <= b < 127: s.cells[r][c] = chr(b)
        out = [''.join(r[:s.cols]).rstrip() for r in s.cells]
        while out and not out[-1]: out.pop()
        return '\n'.join(out)

class Host:
    def __init__(s, platform, binary, org, typed):
        s.p = platform; s.m = m = z80.Z80Machine(); s.typed = list(typed); s.T = 0; s.ints = 0
        s.loc = []; s.out_log = []; s.dma = 0x80; s.cas_in = None; s.cas_out = None
        s.drive = 0; s.logged = 1                     # CP/M: current drive A, A logged in
        s.amsdos = False; s.cas_dev = 'TAPE'; s.disk = 'A'   # CPC: AMSDOS dropped by RUN" until KL ROM WALK
        s.amsdos_at_start = bool(os.environ.get('NTC_AMSDOS'))   # NTC_AMSDOS=1: AMSDOS on from the start (RUN" from a disc)
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
                s.scr.immediate = True; s.scr.mem = m; s.scr.clear()
                for i, a in enumerate(sorted(FW)):
                    m.set_memory_block(a, bytes([0xD3, 0xA0 + i, 0xC9]))
                s.fwport = {0xA0 + i: FW[a] for i, a in enumerate(sorted(FW))}
                m.set_memory_block(0x18, bytes([0xD3, 0xDF, 0xC9]))   # RST 3: a far call (AMSDOS's CAS entries)
                m.set_memory_block(0xB90C, bytes([0xC9]))   # KL ROM RESTORE: nothing to put back here (no stand-in: 32 ports at most)
                m.set_memory_block(0xBB54, bytes([0xC9, 0, 0, 0xC9]))   # TXT VDU ENABLE / DISABLE: nothing (this screen shows Print anyway)
                # KM SET DELAY / KM GET DELAY (#BB3F / #BB42): the delays kept at #BFD8 (start 30, repeat 2)
                m.set_memory_block(0xBB3F, bytes([0xC3, 0xC0, 0xBF, 0xC3, 0xC4, 0xBF]))
                m.set_memory_block(0xBFC0, bytes([0x22, 0xD8, 0xBF, 0xC9, 0x2A, 0xD8, 0xBF, 0xC9]))
                m.set_memory_block(0xBFD8, bytes([2, 30]))
        for pk in filter(None, os.environ.get('NTC_POKE', '').split(';')):
            # NTC_POKE=addr=text;...: text (0 after it) put at the hex address before the start (#BE80:
            # CyborgOS's command line)
            ad, _, tx = pk.partition('=')
            m.set_memory_block(int(ad, 16), tx.encode() + b'\0')
        s.ram = cpcrun.RamBanks(m)                          # the gate array's RAM setting (Memory class)
        s.scr.ram = s.ram                                   # (the screen is main RAM's page 3, wherever it is now)
        s.romsel = 0
        s.xroms = load_xroms() if platform == 'cpcfw' else {}
        if s.xroms and platform == 'cpcfw':
            # writes to #C000-#FFFF (the screen) go to the RAM under the keyword ROM, not over its image
            s.scr.vram = bytearray(0x4000)
            m.mark_addrs(0xC000, 0x4000, m.WRITE_MARK)
            m.set_write_callback(lambda a, v: s.scr.vram.__setitem__(a - 0xC000, v))
        m.set_output_callback(s.out); m.set_input_callback(s.inp)
        if s.amsdos_at_start and platform == 'cpcfw': s.amsdos_on()
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
        if FDC and (port >> 8) in (0xFA, 0xFB) and lo in (0x7E, 0x7F):
            if (port >> 8) == 0xFA: FDC.motor = val & 1
            elif lo == 0x7F: FDC.wr(val)
            return
        if (s.p != 'cpm' or CPMVER >= 0x30) and 0x78 <= (port >> 8) <= 0x7F and (val & 0xC0) == 0xC0:
            s.ram.set(val, port >> 8)
            if getattr(s.scr, 'vram', None) is not None:
                # Library: ROM: the screen RAM under the keyword ROM only while main RAM's block 3
                # is at #C000 (a task's bank there is written as it is)
                if s.ram.view[3] == ('m', 3): s.m.mark_addrs(0xC000, 0x4000, s.m.WRITE_MARK)
                else: s.m.unmark_addrs(0xC000, 0x4000, s.m.WRITE_MARK)
            return
        if s.p == 'cpcfw' and (port >> 8) in (0xBC, 0xBD) and m.pc not in STANDPC:
            # the CRTC (CyborgOS's screen modes and hardware scroll): register select, write -
            # the screen's text is read with its width, height and start (Screen.text). Not the
            # stand-ins' own out (n), a (their A can be #BC / #BD): known by where they are
            if (port >> 8) == 0xBC: s.scr.creg = val & 31
            else: s.scr.crtc[getattr(s.scr, 'creg', 0)] = val; s.scr.crtc_used = True
            return
        if s.p == 'cpcfw' and (port >> 8) == 0xF6 and lo != 0xDF and lo not in getattr(s, 'fwport', {}):
            # (out (#DF), a: the stand-in RST 3 with A = #F6 - a byte just read - is not the PPI)
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
                v = CPMVER; m.hl = v; m.a = v                 # CP/M 3 (NTC_CPMVER=22: 2.2)
            elif fn == 26:
                s.dma = m.de
        elif s.p == 'cpcfw' and lo == 0xDF:
            # RST 3 from a CAS entry AMSDOS took over (DF lo hi): carry it out; the caller of
            # the entry gets the result (the RST's own return address is dropped)
            sp = m.sp; ret = m.memory[sp] | (m.memory[sp + 1] << 8)
            if (ret - 1) not in FW and UNIDOS:
                # RST 3, a far address after it (UniDOS's Ctrl J: CyborgOS's page code calls it so)
                w = m.memory[ret] | (m.memory[ret + 1] << 8); fa = m.memory[w] | (m.memory[w + 1] << 8)
                if fa != CTRLJ: print(s.scr.text(), file=sys.stderr); raise RuntimeError('RST 3 to #%04X at #%04X: not Ctrl J' % (fa, ret - 1))
                s.ctrlj()
                m.memory[sp] = (ret + 2) & 255; m.memory[sp + 1] = (ret + 2) >> 8
                return
            if (ret - 1) not in FW: print(s.scr.text(), file=sys.stderr); raise RuntimeError('out (#%04X), #%02X at pc=#%04X is not the RST 3 stand-in' % (port, val, m.pc))
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
            elif f == 'txt_matrix':
                m.set_memory_block(0x4000, bytes(sum(([c] + [0] * 7 for c in range(32, 128)), [])))
                m.hl = 0x4000 + ((m.a - 32) & 0xFF) * 8
            elif f == 'txt_set_m_table':
                if m.d == 0: m.set_memory_block(m.hl, bytes(sum(([c] + [0] * 7 for c in range(m.e, 256)), [])))
            elif f == 'scr_char_pos':
                m.hl = 0xC000 + ((s.scr.off + m.l * 80 + m.h) & 0x7FF); m.b = 1
            elif f == 'scr_get_location':
                m.a = 0xC0; m.hl = s.scr.off
            elif f == 'scr_hw_roll':
                if m.b: s.scr.cells.pop(0); s.scr.cells.append([' '] * 80); s.scr.scrolled()
            elif f in ('kl_l_rom_enable', 'kl_u_rom_disable', 'kl_u_rom_enable'): m.a = 0
            elif f == 'kl_rom_restore': pass
            elif f == 'scr_mode': s.scr.cols = {0: 20, 1: 40}.get(val, 80); s.scr.clear()
            elif f == 'km_wait':
                m.a = (s.kret if getattr(s, 'kret', None) is not None else s.key()) or 13; m.f = m.f | 1; s.kret = None
            elif f == 'km_char_return':
                s.kret = m.a                                  # (KM READ / WAIT CHAR give it next)
            elif f == 'km_read':
                k = s.kret if getattr(s, 'kret', None) is not None else s.key(); s.kret = None
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
                s.amsdos_on(); m.hl = int(os.environ.get('NTC_ROMTOP', '0xA6FB'), 16)   # the highest byte the ROMs left (NTC_ROMTOP: more ROMs)
            elif f == 'kl_find_command':
                a = m.hl; n = ''
                while True:
                    c = m.memory[a]; n += chr(c & 0x7F); a += 1
                    if c & 0x80: break
                if s.amsdos and UNIDOS and n == chr(0x0A):
                    m.hl = CTRLJ; m.c = 7; m.f = m.f | 1     # UniDOS's Ctrl J (#8A)
                elif s.amsdos and n in RSX:
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
                if n == 'REN':
                    # |REN,"new","old": IX+0 the old name's descriptor, IX+2 the new one's
                    mem = m.memory
                    def sname(at):
                        d = mem[at] | (mem[at + 1] << 8); a = mem[d + 1] | (mem[d + 2] << 8)
                        nm = bytes(mem[a:a + mem[d]]).decode().upper(); dv = s.cas_dev
                        if ':' in nm: dv, nm = nm.split(':', 1)
                        return os.path.join(FILES, dv, *[x for x in nm.split('/') if x])
                    po, pn = sname(m.ix), sname(m.ix + 2)
                    if os.path.exists(po) and not os.path.exists(pn): os.rename(po, pn)
                elif n == 'ERA':
                    # |ERA,"name": IX = the parameters, the one there the string's descriptor (length, address)
                    mem = m.memory; d = mem[m.ix] | (mem[m.ix + 1] << 8)
                    a = mem[d + 1] | (mem[d + 2] << 8)
                    nm = bytes(mem[a:a + mem[d]]).decode().upper(); dv = s.cas_dev
                    if ':' in nm: dv, nm = nm.split(':', 1)
                    p = os.path.join(FILES, dv, *[x for x in nm.split('/') if x])
                    if not os.path.exists(p) and p.endswith('.'): p = p[:-1]   # ("NAME.": no extension)
                    if os.path.isdir(p):
                        # UniDOS: a folder, and all in it - once it is answered Y (KM WAIT CHAR:
                        # its question; a Y waiting from KM CHAR RETURN, else a typed key)
                        k = s.kret if getattr(s, 'kret', None) is not None else s.key(); s.kret = None
                        if k in (ord('Y'), ord('y'), ord('A'), ord('a')): import shutil; shutil.rmtree(p)
                    elif os.path.exists(p): os.remove(p)
                elif n == 'TAPE': s.cas_dev = 'TAPE'
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
        if os.environ.get('NTC_CASLOG'): print('--- cas', f, hex(m.hl), m.b, bytes(mem[m.hl:m.hl + m.b]).decode('latin-1') if f.endswith('open') else '', file=sys.stderr)
        def name():
            n = bytes(mem[m.hl:m.hl + m.b]).decode().upper(); d = s.cas_dev
            if ':' in n and s.cas_dev != 'TAPE': d, n = n.split(':', 1)     # "C:NAME": volume C
            os.makedirs(os.path.join(FILES, d), exist_ok=True)   # one folder per device / volume: TAPE, A, B, C ...
            return os.path.join(FILES, d, *[x for x in n.split('/') if x]) if UNIDOS else os.path.join(FILES, d, n)
        if f == 'cas_in_open':
            # AMSDOS: a file with a header is binary (its length from the header); one without
            # is ASCII text - CAS IN DIRECT won't load that (so a file needs its header)
            p = name()
            if not os.path.isfile(p): m.a = 0x92; return False
            d = open(p, 'rb').read(); h = amsdos_header_of(d)
            s.cas_pos = 0
            if h is None:
                # ASCII (no header): CAS IN CHAR reads it; each ^Z is a soft end of file and
                # reading goes on after it, to the end of the last 128 byte record (real AMSDOS,
                # checked with realcpc); the last record padded with ^Z (as AMSDOS and cpmcp -t do)
                s.cas_in = None; s.cas_ascii = True; s.cas_chars = d + b'\x1a' * (-len(d) % 128); m.bc = 0; m.de = 0; m.a = 0x16
                s.cas_raw = d
                hd = bytearray(69); hd[18] = 0x16; hd[64:67] = b'\x00\x00\x80'      # (UniDOS's made-up header: 24 bit length #800000)
            else:
                s.cas_ascii = False; s.cas_in = d[128:128 + h[1]]; s.cas_chars = s.cas_in; m.bc = h[1]; m.de = h[0]; m.a = 2
                s.cas_raw = s.cas_in
                hd = bytearray(d[:69]); hd[19] = hd[20] = 0                  # (its header, as UniDOS keeps it: BufferLeft 0)
            for i, x in enumerate(hd): mem[0xA700 + i] = x
            m.hl = 0xA700; return True
        if f == 'cas_in_char':
            c = getattr(s, 'cas_chars', None); p = getattr(s, 'cas_pos', 0)
            # the end: hard (#0F); a #1A byte comes as a soft end of file (A = #1A, no carry) and
            # reading goes on after it, in a binary or an ASCII file
            if c is None or p >= len(c): m.a = 0x0F; return False
            if c[p] == 0x1A: m.a = 0x1A; s.cas_pos = p + 1; return False
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
            if UNIDOS and bytes(mem[m.hl:m.hl + m.b]).endswith(b'/'):
                # UniDOS: a path ending "/" makes a folder (no carry, Z, A = #97: a folder found)
                p = name()
                if os.path.isfile(p): m.a = 0x1B; m.f &= ~0x40; return False
                os.makedirs(p, exist_ok=True); m.a = 0x97; m.f |= 0x40; return False
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
    def upath(s, n):
        # a UniDOS path ("IDE:GAMES/", "A:", "GAMES/X.BAS"): its folder or file here, the device
        d = s.cas_dev
        if ':' in n: d, n = n.split(':', 1)
        return os.path.join(FILES, d, *[x for x in n.split('/') if x]), d
    def ctrlj(s):
        # UniDOS's Ctrl J: C the command (carry: done; Z / NZ and A as UniDOS gives them)
        m = s.m; mem = m.memory; c = m.c
        def zf(z): m.f = (m.f | 0x41) if z else ((m.f | 1) & ~0x40)
        def n83(fn):
            b, _, e = fn.upper().partition('.')
            if not b or len(b) > 8 or len(e) > 3: return None
            return (b.ljust(8) + e.ljust(3)).encode()
        if c == 1:
            a = m.de
            for d in UNIDOS:
                bs = d.encode(); bs = bs[:-1] + bytes([bs[-1] | 0x80])
                for x in bs: mem[a] = x; a += 1
            mem[a] = 255; zf(True); return
        if c == 2:
            a = m.hl; n = ''
            while True:
                x = mem[a]; n += chr(x & 0x7F); a += 1
                if x & 0x80: break
            if n not in UNIDOS: m.f &= 0xFE; return
            o = m.de; info = bytes([0x23, 0xFF]) + (123456).to_bytes(4, 'little') + b'\xff' * 4
            ds = ('Emulated ' + n).encode(); info += ds[:-1] + bytes([ds[-1] | 0x80])
            for i, x in enumerate(info): mem[o + i] = x
            zf(True); return
        if c == 5:
            # cmd_cas_in_read: DE bytes of the file being read (its real length: no ^Z padding)
            # to HL; DE = how many, Z
            d = getattr(s, 'cas_raw', None); p = getattr(s, 'cas_pos', 0)
            if d is None: m.a = 0x0F; zf(False); return
            n = max(0, min(m.de, len(d) - p))
            for i in range(n): mem[(m.hl + i) & 0xFFFF] = d[p + i]
            s.cas_pos = p + n; m.de = n; zf(True); return
        if c == 12:
            n = bytes(mem[m.hl:m.hl + m.b]).decode('latin-1').upper()
            p, d = s.upath(n)
            if d in UNIDOS_NOEX: m.f &= 0xFE; return
            if n == '' or n.endswith('/') or n.endswith(':'):
                if not os.path.isdir(p): m.a = 0x12; zf(False); return
                s.ux = []
                for fn in sorted(os.listdir(p)):
                    k = n83(fn)
                    if k: s.ux.append((k, os.path.join(p, fn)))
                zf(True); return
            if not os.path.exists(p): m.a = 0x12; zf(False); return
            m.a = 0x10 if os.path.isdir(p) else 0
            z = 0 if os.path.isdir(p) else os.path.getsize(p); m.bc = z >> 16; m.de = z & 0xFFFF
            zf(True); return
        if c == 13:
            if not getattr(s, 'ux', None): m.a = 0x12; zf(False); return
            k, p = s.ux.pop(0)
            for i, x in enumerate(k): mem[m.hl + i] = x
            for i, x in enumerate([0xEA, 0x07, 10, 16, 12, 34, 56]): mem[m.ix + i] = x
            m.a = 0x10 if os.path.isdir(p) else 0
            z = 0 if os.path.isdir(p) else os.path.getsize(p); m.bc = z >> 16; m.de = z & 0xFFFF
            zf(True); return
        m.f &= 0xFE
    def inp(s, port):
        lo = port & 0xFF
        if FDC and (port >> 8) == 0xFB and lo in (0x7E, 0x7F): return FDC.msr() if lo == 0x7E else FDC.rd()
        if s.p in ('cpcfw', 'cpm') and port in (0xF991, 0xF994, 0xF995) and os.environ.get('NTC_MOUSE'):
            q = getattr(s, 'mq', [])
            if port == 0xF994: return (q[0][0] & 0xFF) if q else 0
            if port == 0xF995: return (q[0][1] & 0xFF) if q else 0
            if q: s.mbt = q.pop(0)[2]
            return (getattr(s, 'mbt', 0) & 7) << 4
        if s.p == 'cpcfw' and (port >> 8) == 0xF5:
            # the PPI's port B: bit 0 the vertical sync, for the first 1500 T of each 80000 T frame
            # (Graphics.Flip waits for it; the firmware itself is trapped, not run)
            return 0xFE | (1 if (s.T + 4000 - s.m.ticks_to_stop) % 80000 < 1500 else 0)
        if s.p == 'cpcfw' and (port >> 8) == 0xF4:
            # the keyboard matrix (Keys class): {n} in the typed text holds key n for 12 scans and
            # at least 2 frames (40 ms: a Keys.Down reads every line, so a program that looks at
            # many keys scans many times a frame), {n,m} keys n and m together ({23,40}: Control + 8)
            v = 0xFF; h = getattr(s, 'held', None); line = getattr(s, 'line', 0)
            if h is not None:
                for hk in h:
                    if line == hk // 8: v &= ~(1 << (hk % 8))
            if line == 9:
                s.hscans = getattr(s, 'hscans', 0) + 1
                if h is not None and s.hscans >= 12 and s.T - getattr(s, 'hstart', 0) >= 160000: s.held = None
                elif h is None and s.typed and s.typed[0] == '{':
                    s.typed.pop(0); n = ''
                    while s.typed and s.typed[0] != '}': n += s.typed.pop(0)
                    if s.typed: s.typed.pop(0)
                    if n.startswith('m'):
                        # {mdx,dy,b}: the mouse (NTC_MOUSE=1: the Amiga mouse card at #F991 / #F994
                        # / #F995): queued, one poll each (X, Y, then the buttons: b 1 left ...)
                        if not hasattr(s, 'mq'): s.mq = []
                        s.mq.append([int(x) for x in n[1:].split(',')])
                    else:
                        s.held = [int(x) for x in n.split(',')]; s.hstart = s.T; s.hscans = 0
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
            if PROF is not None:
                # a sample at a random point in the chunk (not at its end: that is when the interrupt comes)
                r = random.randint(100, 13200)
                s.m.ticks_to_stop = r; cpcrun.endkey_run(s); s.T += r - s.m.ticks_to_stop
                PROF.append((s.m.pc, 0 if s.ram.view[0] == ('m', 0) else 1, s.m.sp, s.m.memory[0] if False else 0))
                q = 13333 - r
            else:
                q = 13333
            s.m.ticks_to_stop = q; cpcrun.endkey_run(s); n += 1; s.T += q - s.m.ticks_to_stop
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
        if CPMVER >= 0x30:
            h.ram.mainp = [bytes(0x4000)] * 4; h.ram.view = [('x', 0, 0), ('x', 0, 1), ('x', 0, 2), ('x', 0, 3)]
    h.run(int(os.environ.get('NTC_LIMIT', '30000')))
    if os.environ.get('NTC_BPEEK'):     # bank memory: "bank:address" (hex address in the bank's 64K), 16 bytes
        for a in os.environ['NTC_BPEEK'].split(','):
            bk, ad = a.split(':'); o = int(bk) * 0x10000 + int(ad, 16)
            print('--- bpeek %s: %s' % (a, ' '.join('%02x' % x for x in h.ram.ext[o:o + 16])))
    if os.environ.get('NTC_PEEK'):
        for a in os.environ['NTC_PEEK'].split(','): print('--- peek %s: %s' % (a, ' '.join('%02x' % h.m.memory[int(a, 16) + i] for i in range(8))))
    print(h.scr.text())
    if os.environ.get('NTC_DUMP'): open(os.environ['NTC_DUMP'], 'wb').write(bytes(h.m.memory[0:0x10000]))   # NTC_DUMP=file: the 64K the Z80 sees at the end
    if os.environ.get('NTC_SHOT') and getattr(h, 'ram', None) is not None:
        # NTC_SHOT=file: main RAM's #4000 and #C000 (the two screens) and the CRTC's R12 at the end
        open(os.environ['NTC_SHOT'], 'wb').write(bytes([getattr(h.scr, 'crtc', [0] * 16)[12] & 255]) + h.ram.main_page(1) + (bytes(h.scr.vram) if getattr(h.scr, 'vram', None) is not None else h.ram.main_page(3)))
    if plat == 'cpm' and os.environ.get('NTC_GFXCHK'):
        scr = h.ram.main_page(1) if CPMVER >= 0x30 else bytes(h.m.memory[0xC000:0xF000])
        print('--- screen bytes set: %d' % sum(1 for x in scr if x))
    if PROF is not None:
        import json; json.dump({'pc': PROF, 'syms': syms}, open(os.environ['NTC_PROF'], 'w'))
    print('--- halted' if h.m.halted else '--- NOT halted', 'pc=%04x' % h.m.pc, 'sp=%04x' % h.m.sp, 'ints=%d' % h.ints, 'T=%d' % h.T)
    if plat == 'cpcfw' and bytes(h.m.memory[0xBFD8:0xBFDA]) != bytes([2, 30]): print('--- keys: start %d, repeat %d' % (h.m.memory[0xBFD9], h.m.memory[0xBFD8]))

if __name__ == '__main__':
    main()
