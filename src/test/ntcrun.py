# run an NTC program on an emulated host - scratch test tool, not delivered
#   python3 ntcrun.py prog.bas 'typed\n' [more files] [--turbo] [--platform=cpc|cpcfw|cpm|test]
#   (in the typed text: \n = Return, ~ = one look at the keyboard that finds no key)
# cpc   : the CPC hardware emulation in cpcrun.py (screen read back from video RAM)
# test  : the port console of asm/ntc_plat_test.asm
# cpcfw : CPC firmware jumpblock entries trapped (TXT, KM, SCR, MC, KL)
# cpm   : CP/M page zero, BDOS (call 5) trapped
# Prints the text screen, then a '---' status line (same form as cpcrun.py).
import sys, os, subprocess
import z80
import cpcrun

HERE = os.path.dirname(os.path.abspath(__file__))
FW = {0xBB06: 'km_wait', 0xBB09: 'km_read', 0xBB5A: 'txt_out', 0xBB6C: 'txt_clear', 0xBB75: 'txt_cursor',
      0xBC0E: 'scr_mode', 0xBD19: 'mc_flyback', 0xBD0D: 'kl_time'}

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
        s.loc = []; s.out_log = []
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
        m.set_output_callback(s.out); m.set_input_callback(s.inp)
    def key(s):
        # '~' in the typed text: this look at the keyboard finds no key (then the rest follow)
        if s.typed and s.typed[0] == '~':
            s.typed.pop(0)
            return 0
        return ord(s.typed.pop(0)) if s.typed else 0
    def ticks(s):
        return (s.T // 13333) & 0xFFFF
    def out(s, port, val):
        lo = port & 0xFF; m = s.m
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
    def inp(s, port):
        lo = port & 0xFF
        if s.p == 'test':
            if lo == 0xFD: return s.key() or 13
            if lo == 0xF8: return s.key()
            if lo == 0xF7: return s.ticks() & 0xFF
            if lo == 0xF6: return s.ticks() >> 8
        return 0xFF
    def run(s, limit=30000):
        n = 0
        while not s.m.halted:
            s.m.ticks_to_stop = 13333; s.m.run(); n += 1; s.T += 13333 - s.m.ticks_to_stop
            if s.m.halted: break
            steps = 0
            while not s.m.halted and steps < 2000:
                if s.m.iff1 and s.m.on_handle_active_int(): s.ints += 1; break
                s.m.ticks_to_stop = 1; s.m.run(); steps += 1; s.T += 1 - s.m.ticks_to_stop
            if n > limit: print('TIMEOUT pc=%04x sp=%04x' % (s.m.pc, s.m.sp)); break

def main():
    args = sys.argv[1:]
    plat = 'cpc'
    for a in list(args):
        if a.startswith('--platform='): plat = a[11:]; args.remove(a)
    bas = args[0]; typed = (args[1] if len(args) > 1 else '').replace('\\n', '\r').replace('\\x7f', '\x7f')
    extra = args[2:]
    asm = bas[:-4] + '.asm'
    r = subprocess.run(['node', os.path.join(HERE, 'cli.js'), bas, '--platform=' + plat] + extra, capture_output=True, text=True)
    if r.stderr: print(r.stderr)
    open(asm, 'w').write(r.stdout)
    b, syms = cpcrun.assemble(asm)
    if plat == 'cpc':
        c = cpcrun.CPC(b, syms.get('ntc_start', 0x4000), typed, syms); c.run()
        print(c.screen(cpcrun.loadfont(syms, c.m.memory)))
        print('--- halted' if c.m.halted else '--- NOT halted', 'sp=%04x' % c.m.sp, 'ints=%d' % c.ints, 'T=%d' % c.T)
        return
    org = syms.get('ntc_start', 0x100 if plat == 'cpm' else 0x4000)   # the program's org
    h = Host(plat, b, org, typed); h.run()
    print(h.scr.text())
    print('--- halted' if h.m.halted else '--- NOT halted', 'sp=%04x' % h.m.sp, 'ints=%d' % h.ints, 'T=%d' % h.T)

if __name__ == '__main__':
    main()
