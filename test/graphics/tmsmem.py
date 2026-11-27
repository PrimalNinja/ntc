# tmsmem.py - gfx.bas on the TMS9918 platforms (msx, msxcard, msx9990, sc3000, colecovision):
# the cartridge run on the Z80 core with a model of the chip's two ports and its 16K of VRAM
# (no BIOS, no interrupts); Screen 2's pattern table compared with expect.py.
#   python3 test/graphics/tmsmem.py msx|msxcard|msx9990|sc3000|colecovision
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, re, subprocess, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(HERE, '..')); sys.path.insert(0, HERE)
import z80, cpcrun, expect

def main():
    plat = sys.argv[1]; d = tempfile.mkdtemp(prefix='gfx-'); asm = os.path.join(d, 'g.asm')
    r = subprocess.run(['node', os.path.join(HERE, '..', 'cli.js'), os.path.join(HERE, 'gfx.bas'), '--platform=' + plat], capture_output=True, text=True)
    if 'ERR ' in r.stderr: print(r.stderr); return 1
    open(asm, 'w').write(r.stdout)
    b, syms = cpcrun.assemble(asm)
    org = int(re.search(r'^\s*org\s+#([0-9A-Fa-f]+)', r.stdout, re.M).group(1), 16)
    m = z80.Z80Machine(); m.set_memory_block(org, b)
    data = {'msx': 0x98, 'msx9990': 0x98, 'msxcard': 0x88}.get(plat, 0xBE)
    v = {'ram': bytearray(0x4000), 'a': 0, 'latch': None, 'buf': 0, 'regs': {}, 'writes': 0}
    def out(p, x):
        p &= 0xFF
        if p == data: v['ram'][v['a'] & 0x3FFF] = x; v['a'] += 1; v['latch'] = None; v['writes'] += 1
        elif p == data + 1:
            if v['latch'] is None: v['latch'] = x
            else:
                if x & 0x80: v['regs'][x & 0x3F] = v['latch']
                else:
                    v['a'] = ((x & 0x3F) << 8) | v['latch']
                    if not x & 0x40: v['buf'] = v['ram'][v['a'] & 0x3FFF]; v['a'] += 1
                v['latch'] = None
    def inp(p):
        p &= 0xFF
        if p == data: x = v['buf']; v['buf'] = v['ram'][v['a'] & 0x3FFF]; v['a'] += 1; v['latch'] = None; return x
        if p == data + 1: v['latch'] = None; return 0x9F
        if 0x60 <= p <= 0x6F: return 0                                      # a V9990: never busy
        return 0xFF
    m.set_output_callback(out); m.set_input_callback(inp)
    mem = m.memory
    if plat[:3] == 'msx':                                                   # what the cartridge asks of the BIOS
        m.set_memory_block(6, bytes([0x98, 0x98]))                          # the VDP's ports
        for x in (0x0138, 0x0024, 0x009F): m.set_memory_block(x, bytes([0xC9]))   # RSLREG, ENASLT, CHGET: ret
        m.set_memory_block(0x009C, bytes([0xAF, 0xC9]))                     # CHSNS: no key
    m.pc = {'msx': mem[0x4002] | mem[0x4003] << 8, 'colecovision': mem[0x800A] | mem[0x800B] << 8}.get(plat[:3] == 'msx' and 'msx' or plat, org)
    for i in range(int(os.environ.get('GFX_TICKS', '6000'))):
        m.ticks_to_stop = 100000; m.run()
    lit = set()
    for y in range(192):
        for x in range(256):
            if v['ram'][(y // 8) * 256 + (x & 248) + (y & 7)] & (128 >> (x & 7)): lit.add((x, y))
    ok = expect.check(plat, lit, 256, 192, (0, 0, 31, 7))        # (the SC-3000's Print after the lines lands there)
    ink = set(v['ram'][0x2000 + (y // 8) * 256 + (x & 248) + (y & 7)] >> 4 for (x, y) in lit)
    print('             inks used %s, VRAM writes %d, pc #%04X' % (sorted(ink), v['writes'], m.pc))
    return 0 if ok and ink == {15} else 1
sys.exit(main())
